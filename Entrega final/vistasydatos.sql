-- =============================================
-- Autor: Alexei Sandoval
-- =============================================

USE vinoteca_el_copihue;

-- ----------------------------------------------------
--                     VISTAS
-- ----------------------------------------------------

CREATE VIEW vw_catalogo_vinos AS
SELECT
    v.vino_id,
    v.nombre_vino,
    v.cosecha,
    v.precio,
    p.nombre_proveedor AS proveedor,
    GROUP_CONCAT(DISTINCT c.nombre_categoria SEPARATOR ', ') AS categorias,
    GROUP_CONCAT(DISTINCT u.nombre_uva SEPARATOR ', ') AS uvas,
    b.nombre_bodega AS bodega,
    b.region,
    b.pais
FROM vino v
JOIN proveedor p ON v.proveedor_id = p.proveedor_id
LEFT JOIN vino_categoria vc ON v.vino_id = vc.vino_id
LEFT JOIN categoria c ON vc.categoria_id = c.categoria_id
LEFT JOIN vino_uva vu ON v.vino_id = vu.vino_id
LEFT JOIN uva u ON vu.uva_id = u.uva_id
LEFT JOIN vino_bodega vb ON v.vino_id = vb.vino_id
LEFT JOIN bodega b ON vb.bodega_id = b.bodega_id
GROUP BY v.vino_id, v.nombre_vino, v.cosecha, v.precio, proveedor, bodega, region, pais
ORDER BY v.nombre_vino;

CREATE VIEW vw_resumen_ventas_cliente AS
SELECT
    c.cliente_id,
    c.nombre,
    c.apellido,
    COUNT(p.pedido_id) AS total_pedidos,
    SUM(p.total) AS total_gastado,
    MAX(p.fecha_pedido) AS ultima_compra
FROM cliente c
JOIN pedido p ON c.cliente_id = p.cliente_id
GROUP BY c.cliente_id
ORDER BY total_gastado DESC;

CREATE VIEW vw_stock_sucursal AS
SELECT
    s.sucursal_id,
    s.nombre AS nombre_sucursal,
    v.vino_id,
    v.nombre_vino,
    t.cantidad AS stock_actual
FROM stock t
JOIN sucursal s ON t.sucursal_id = s.sucursal_id
JOIN vino v ON t.vino_id = v.vino_id;

CREATE VIEW vw_productos_mas_vendidos AS
SELECT
    v.vino_id,
    v.nombre_vino,
    SUM(dp.cantidad) AS total_vendido
FROM detalle_pedido dp
JOIN vino v ON dp.vino_id = v.vino_id
GROUP BY v.vino_id
ORDER BY total_vendido DESC
LIMIT 10;

CREATE VIEW vw_detalle_pedido_completo AS
SELECT
    p.pedido_id,
    p.fecha_pedido,
    c.nombre AS nombre_cliente,
    c.apellido AS apellido_cliente,
    s.nombre AS nombre_sucursal,
    v.nombre_vino,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal
FROM pedido p
JOIN cliente c ON p.cliente_id = c.cliente_id
JOIN sucursal s ON p.sucursal_id = s.sucursal_id
JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id
JOIN vino v ON dp.vino_id = v.vino_id
ORDER BY p.fecha_pedido DESC;

-- ----------------------------------------------------
--             FUNCIONES Y PROCEDIMIENTOS ALMACENADOS
-- ----------------------------------------------------

DELIMITER //

CREATE FUNCTION fn_calcular_total_pedido(p_pedido_id INT)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(10, 2);
    SELECT SUM(cantidad * precio_unitario) INTO v_total
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id;
    RETURN IFNULL(v_total, 0.00);
END //

CREATE FUNCTION fn_obtener_stock_disponible(p_sucursal_id INT, p_vino_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_stock INT;
    SELECT cantidad INTO v_stock
    FROM stock
    WHERE sucursal_id = p_sucursal_id AND vino_id = p_vino_id;
    RETURN IFNULL(v_stock, 0);
END //

CREATE PROCEDURE sp_crear_pedido(
    IN p_cliente_id INT,
    IN p_empleado_id INT,
    IN p_sucursal_id INT,
    IN p_items_json JSON
)
BEGIN
    DECLARE v_pedido_id INT;
    DECLARE v_item_count INT;
    DECLARE i INT DEFAULT 0;
    DECLARE v_vino_id INT;
    DECLARE v_cantidad INT;
    DECLARE v_precio DECIMAL(10, 2);

    START TRANSACTION;

    INSERT INTO pedido (cliente_id, empleado_id, sucursal_id, estado, total)
    VALUES (p_cliente_id, p_empleado_id, p_sucursal_id, 'En proceso', 0);
    SET v_pedido_id = LAST_INSERT_ID();

    SET v_item_count = JSON_LENGTH(p_items_json);

    WHILE i < v_item_count DO
        SET v_vino_id = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].vino_id')));
        SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].cantidad')));
        SELECT precio INTO v_precio FROM vino WHERE vino_id = v_vino_id;

        INSERT INTO detalle_pedido (pedido_id, vino_id, cantidad, precio_unitario)
        VALUES (v_pedido_id, v_vino_id, v_cantidad, v_precio);

        SET i = i + 1;
    END WHILE;

    COMMIT;
END //

CREATE PROCEDURE sp_obtener_historial_cliente(
    IN p_cliente_id INT
)
BEGIN
    SELECT
        p.pedido_id,
        p.fecha_pedido,
        s.nombre AS nombre_sucursal,
        v.nombre_vino,
        dp.cantidad,
        dp.precio_unitario,
        (dp.cantidad * dp.precio_unitario) AS subtotal_item
    FROM pedido p
    JOIN sucursal s ON p.sucursal_id = s.sucursal_id
    JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id
    JOIN vino v ON dp.vino_id = v.vino_id
    WHERE p.cliente_id = p_cliente_id
    ORDER BY p.fecha_pedido DESC, p.pedido_id;
END //

-- ----------------------------------------------------
--                     TRIGGERS
-- ----------------------------------------------------

CREATE TRIGGER tr_disminuir_stock_pedido
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    DECLARE v_stock_actual INT;
    
    SELECT s.cantidad INTO v_stock_actual
    FROM stock s
    JOIN pedido p ON p.sucursal_id = s.sucursal_id
    WHERE s.vino_id = NEW.vino_id AND p.pedido_id = NEW.pedido_id;

    IF v_stock_actual < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Stock insuficiente para el vino solicitado.';
    ELSE
        UPDATE stock
        SET cantidad = cantidad - NEW.cantidad
        WHERE vino_id = NEW.vino_id AND sucursal_id = (SELECT sucursal_id FROM pedido WHERE pedido_id = NEW.pedido_id);
        
        INSERT INTO movimiento_stock (sucursal_id, vino_id, tipo_movimiento, cantidad, observaciones)
        VALUES ((SELECT sucursal_id FROM pedido WHERE pedido_id = NEW.pedido_id), NEW.vino_id, 'Salida', NEW.cantidad, 'Venta por pedido');
    END IF;
END //

CREATE TRIGGER tr_actualizar_total_pedido
AFTER INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE pedido
    SET total = fn_calcular_total_pedido(NEW.pedido_id)
    WHERE pedido_id = NEW.pedido_id;
END //

DELIMITER ;

USE vinoteca_el_copihue;

SET autocommit=0;
SET FOREIGN_KEY_CHECKS=0;

-- Limpiar tablas
TRUNCATE TABLE movimiento_stock;
TRUNCATE TABLE stock;
TRUNCATE TABLE detalle_pedido;
TRUNCATE TABLE pago;
TRUNCATE TABLE envio;
TRUNCATE TABLE pedido;
TRUNCATE TABLE fact_venta;
TRUNCATE TABLE dim_fecha;
TRUNCATE TABLE vino_categoria;
TRUNCATE TABLE vino_uva;
TRUNCATE TABLE vino_bodega;
TRUNCATE TABLE vino;
TRUNCATE TABLE categoria;
TRUNCATE TABLE uva;
TRUNCATE TABLE bodega;
TRUNCATE TABLE proveedor;
TRUNCATE TABLE cliente;
TRUNCATE TABLE empleado;
TRUNCATE TABLE sucursal;

-- ----------------------------------------------------
-- DATOS
-- ----------------------------------------------------

INSERT INTO empleado (nombre, apellido, puesto, fecha_contratacion, email) VALUES
('Juan', 'Pérez', 'Gerente', '2023-01-15', 'juan.perez@vinoteca.com'),
('María', 'Gómez', 'Asistente de Ventas', '2023-02-20', 'maria.gomez@vinoteca.com'),
('Carlos', 'López', 'Asesor de Clientes', '2023-03-10', 'carlos.lopez@vinoteca.com'),
('Ana', 'Fernández', 'Cajero', '2023-04-05', 'ana.fernandez@vinoteca.com'),
('Pedro', 'Díaz', 'Logística', '2023-05-18', 'pedro.diaz@vinoteca.com');

INSERT INTO sucursal (nombre, direccion, ciudad, telefono) VALUES
('Vinoteca Central', 'Av. Vitacura 2969', 'Santiago', '+56222345678'),
('Vinoteca Costanera', 'Nueva Providencia 222', 'Santiago', '+56222876543'),
('Vinoteca Viña del Mar', 'Av. San Martín 123', 'Viña del Mar', '+56322987654');

INSERT INTO cliente (nombre, apellido, email, telefono, direccion) VALUES
('Javier', 'González', 'javier.gonzalez@correo.cl', '+56987654321', 'Los Cerezos 123, Ñuñoa, Santiago'),
('Carolina', 'Soto', 'caro.soto@correo.cl', '+56912345678', 'Av. Alemania 45, Concepción'),
('Matías', 'Rojas', 'matias.rojas@correo.cl', '+56955554444', 'Errázuriz 789, Valparaíso'),
('Valentina', 'Muñoz', 'vale.munoz@correo.cl', '+56988887777', 'Av. del Mar 2100, La Serena'),
('Benjamín', 'Díaz', 'benja.diaz@correo.cl', '+56944443333', 'O Higgins 555, Temuco');

INSERT INTO proveedor (nombre_proveedor, contacto_persona, telefono, email) VALUES
('Viña Santa Rita', 'Andrés Lavados', '+56223622000', 'contacto@santarita.cl'),
('Viña Concha y Toro', 'Eduardo Guilisasti', '+56224765000', 'info@conchaytoro.cl'),
('Viña Undurraga', 'Ernesto Müller', '+56223722100', 'ventas@undurraga.cl'),
('Viña Montes', 'Aurelio Montes', '+56222484805', 'info@monteswines.com'),
('Viña Tarapacá', 'Ricardo Osorio', '+56228786000', 'ventas@tarapaca.cl');

INSERT INTO bodega (nombre_bodega, region, pais) VALUES
('Viña Santa Rita', 'Valle del Maipo', 'Chile'),
('Viña Concha y Toro', 'Valle Central', 'Chile'),
('Viña Undurraga', 'Valle de Leyda', 'Chile'),
('Viña Montes', 'Valle de Colchagua', 'Chile'),
('Viña Tarapacá', 'Valle del Maipo', 'Chile');

INSERT INTO categoria (nombre_categoria, descripcion) VALUES
('Tinto', 'Vinos elaborados a partir de uvas tintas.'),
('Blanco', 'Vinos de uvas blancas o tintas de pulpa blanca.'),
('Ensamblaje', 'Vino que es resultado de la mezcla de dos o más cepas.'),
('Rosé', 'Vinos rosados, elaborados con una maceración corta de uvas tintas.'),
('Espumante', 'Vino con gas carbónico, producido por segunda fermentación.');

INSERT INTO uva (nombre_uva, descripcion) VALUES
('Carménère', 'Uva tinta de origen francés, principal en Chile.'),
('Cabernet Sauvignon', 'Uva tinta de origen bordelés, la más plantada del mundo.'),
('Merlot', 'Uva tinta de origen bordelés, con sabores a ciruela y cereza.'),
('Sauvignon Blanc', 'Uva blanca de origen francés, de notas cítricas y herbáceas.'),
('Chardonnay', 'Uva blanca versátil, se adapta a distintos climas.'),
('Pinot Noir', 'Uva tinta de origen francés, de aromas afrutados.'),
('Syrah', 'Uva tinta de origen francés, produce vinos especiados.');

INSERT INTO vino (nombre_vino, descripcion, cosecha, precio, proveedor_id) VALUES
('Santa Rita 120 Carménère', 'Un clásico Carménère del Valle Central, suave y especiado.', 2022, 4990.00, 1),
('Casillero del Diablo Cabernet Sauvignon', 'Vino reserva, intenso y con notas a frutos rojos y cassis.', 2021, 6490.00, 2),
('Undurraga TH Sauvignon Blanc', 'Vino de Leyda, fresco, mineral y con notas cítricas.', 2023, 8990.00, 3),
('Marqués de Casa Concha Ensamblaje', 'Potente mezcla de tintos del Valle del Maipo.', 2020, 14990.00, 2),
('Santa Digna Estelado Rosé', 'Espumante rosado del tipo País, único y refrescante.', 2023, 7500.00, 1),
('Montes Alpha Cabernet Sauvignon', 'Vino ícono de Colchagua, elegante y de gran cuerpo.', 2021, 18990.00, 4),
('Concha y Toro Amelia Chardonnay', 'Chardonnay del valle de Limarí, complejo y con notas a madera.', 2022, 19990.00, 2),
('Undurraga Brut Royal', 'Espumante de método tradicional, ideal para celebraciones.', 2020, 9990.00, 3),
('Tarapacá Gran Reserva Syrah', 'Vino especiado y con notas a pimienta negra.', 2021, 12500.00, 5),
('Montes Alpha Pinot Noir', 'Pinot Noir elegante, con notas a cereza y frambuesa.', 2022, 16990.00, 4),
('Santa Rita Medalla Real Chardonnay', 'Chardonnay de estilo borgoñés, con notas a mantequilla y vainilla.', 2022, 11990.00, 1),
('Undurraga Vigno Carignan', 'Vino tinto de la cepa Carignan, de gran acidez y taninos.', 2020, 25000.00, 3),
('Viñedo Chadwick', 'Icono de viñedos chadwick, con notas a chocolate amargo y vainilla.', 2019, 250000.00, 2),
('Montes Folly Syrah', 'Vino de gran intensidad, de aromas a frutas negras y especias.', 2021, 35000.00, 4),
('Santa Rita Casa Real Cabernet Sauvignon', 'Vino ícono de Santa Rita, con gran potencial de guarda.', 2018, 55000.00, 1),
('Don Melchor', 'Icono de Concha y Toro, un clásico Cabernet Sauvignon.', 2020, 80000.00, 2),
('Viña Tarapacá Merlot', 'Vino tinto de la cepa Merlot, suave y fácil de beber.', 2022, 7990.00, 5),
('Casillero del Diablo Reserva Rosé', 'Vino rosado de la cepa Syrah, fresco y afrutado.', 2023, 5990.00, 2),
('Undurraga Late Harvest Sauvignon Blanc', 'Vino dulce de la cepa Sauvignon Blanc.', 2022, 8500.00, 3),
('Santa Rita 120 Sauvignon Blanc', 'Un clásico Sauvignon Blanc, fresco y de notas cítricas.', 2023, 4990.00, 1);

-- ----------------------------------------------------
-- INSERCIÓN DE DATOS DE UNIÓN
-- ----------------------------------------------------

INSERT INTO vino_categoria (vino_id, categoria_id) VALUES
(1, 1), (2, 1), (3, 2), (4, 3), (5, 4), (6, 1), (7, 2), (8, 5), (9, 1), (10, 1),
(11, 2), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1), (17, 1), (18, 4), (19, 2), (20, 2);

INSERT INTO vino_uva (vino_id, uva_id) VALUES
(1, 1), (2, 2), (3, 4), (4, 2), (4, 3), (4, 1), (5, 1), (6, 2), (7, 5), (8, 5),
(9, 7), (10, 6), (11, 5), (12, 1), (13, 2), (14, 7), (15, 2), (16, 2), (17, 3),
(18, 7), (19, 4), (20, 4);

INSERT INTO vino_bodega (vino_id, bodega_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 2), (5, 1), (6, 4), (7, 2), (8, 3), (9, 5), (10, 4),
(11, 1), (12, 3), (13, 2), (14, 4), (15, 1), (16, 2), (17, 5), (18, 2), (19, 3), (20, 1);

-- ----------------------------------------------------
-- TRANSACCIONALES Y DE HECHOS
-- ----------------------------------------------------

INSERT INTO dim_fecha (fecha_id, fecha, dia_semana, dia_mes, mes, anio, trimestre, es_fin_de_semana, nombre_mes)
SELECT
    DATE_FORMAT(calendar_date, '%Y%m%d') AS fecha_id,
    calendar_date AS fecha,
    DAYNAME(calendar_date) AS dia_semana,
    DAY(calendar_date) AS dia_mes,
    MONTH(calendar_date) AS mes,
    YEAR(calendar_date) AS anio,
    QUARTER(calendar_date) AS trimestre,
    (DAYOFWEEK(calendar_date) IN (1, 7)) AS es_fin_de_semana,
    MONTHNAME(calendar_date) AS nombre_mes
FROM (
    SELECT ADDDATE('2024-01-01', t4.i*10000 + t3.i*1000 + t2.i*100 + t1.i*10 + t0.i) AS calendar_date
    FROM
        (SELECT 0 i UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t0,
        (SELECT 0 i UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
        (SELECT 0 i UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
        (SELECT 0 i UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t3,
        (SELECT 0 i UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t4
) v
WHERE calendar_date BETWEEN '2024-01-01' AND '2025-12-31';

INSERT INTO stock (sucursal_id, vino_id, cantidad) VALUES
(1, 1, 100), (1, 2, 80), (1, 3, 50), (1, 4, 30), (1, 5, 40),
(2, 1, 60), (2, 2, 70), (2, 3, 40), (2, 6, 25), (2, 7, 20),
(3, 1, 50), (3, 8, 45), (3, 9, 35), (3, 10, 25), (3, 11, 30);

CALL sp_crear_pedido(1, 1, 1, '[{"vino_id": 1, "cantidad": 2}, {"vino_id": 2, "cantidad": 1}]');

CALL sp_crear_pedido(2, 2, 2, '[{"vino_id": 3, "cantidad": 1}, {"vino_id": 4, "cantidad": 1}]');

CALL sp_crear_pedido(4, 3, 3, '[{"vino_id": 6, "cantidad": 1}, {"vino_id": 7, "cantidad": 1}]');

CALL sp_crear_pedido(1, 1, 1, '[{"vino_id": 8, "cantidad": 2}, {"vino_id": 1, "cantidad": 2}, {"vino_id": 11, "cantidad": 1}]');

INSERT INTO pago (pedido_id, monto, metodo_pago) VALUES
(1, (SELECT total FROM pedido WHERE pedido_id = 1), 'Tarjeta de Crédito'),
(2, (SELECT total FROM pedido WHERE pedido_id = 2), 'Transferencia'),
(3, (SELECT total FROM pedido WHERE pedido_id = 3), 'Tarjeta de Débito'),
(4, (SELECT total FROM pedido WHERE pedido_id = 4), 'Tarjeta de Crédito');

INSERT INTO envio (pedido_id, sucursal_id, transportista, fecha_despacho, estado_envio) VALUES
(1, 1, 'Chilexpress', '2024-01-02 10:00:00', 'Entregado'),
(2, 2, 'Correos de Chile', '2024-01-05 15:00:00', 'En Camino'),
(3, 3, 'DHL', '2024-01-10 12:00:00', 'Preparando'),
(4, 1, 'Chilexpress', '2024-01-15 11:00:00', 'En Camino');

INSERT INTO fact_venta (fecha_id, sucursal_id, cliente_id, empleado_id, vino_id, cantidad, precio_unitario, subtotal)
SELECT
    DATE_FORMAT(p.fecha_pedido, '%Y%m%d') AS fecha_id,
    p.sucursal_id,
    p.cliente_id,
    p.empleado_id,
    dp.vino_id,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal
FROM pedido p
JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id;

SET FOREIGN_KEY_CHECKS=1;
COMMIT;