-- Autor: Alexei Sandoval
USE vinoteca_el_copihue;

CREATE VIEW vista_detalle_ventas AS
SELECT
    p.id_pedido,
    c.nombre AS nombre_cliente,
    c.apellido AS apellido_cliente,
    p.fecha_pedido,
    pr.nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal_linea
FROM pedidos p
JOIN clientes c ON p.id_cliente = c.id_cliente
JOIN detalles_pedido dp ON p.id_pedido = dp.id_pedido
JOIN productos pr ON dp.id_producto = pr.id_producto;

CREATE VIEW vista_resumen_stock AS
SELECT
    pr.nombre_producto,
    c.nombre_categoria,
    p.nombre_proveedor,
    pr.stock
FROM productos pr
JOIN categorias c ON pr.id_categoria = c.id_categoria
JOIN proveedores p ON pr.id_proveedor = p.id_proveedor;

DELIMITER //
CREATE FUNCTION calcular_total_pedido(id_pedido_in INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_pedido INT;
    SELECT SUM(cantidad * precio_unitario) INTO total_pedido
    FROM detalles_pedido
    WHERE id_pedido = id_pedido_in;
    RETURN total_pedido;
END //
DELIMITER ;

DELIMITER //
CREATE FUNCTION obtener_stock_disponible(id_producto_in INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE stock_actual INT;
    SELECT stock INTO stock_actual
    FROM productos
    WHERE id_producto = id_producto_in;
    RETURN stock_actual;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_insertar_nuevo_pedido(
    IN id_cliente_in INT,
    IN id_producto_in INT,
    IN cantidad_in INT
)
BEGIN
    DECLARE nuevo_id_pedido INT;
    DECLARE precio_prod INT;

    START TRANSACTION;
    INSERT INTO pedidos (id_cliente, total) VALUES (id_cliente_in, 0);
    SET nuevo_id_pedido = LAST_INSERT_ID();
    SELECT precio INTO precio_prod FROM productos WHERE id_producto = id_producto_in;
    INSERT INTO detalles_pedido (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (nuevo_id_pedido, id_producto_in, cantidad_in, precio_prod);
    COMMIT;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_obtener_ventas_cliente(IN id_cliente_in INT)
BEGIN
    SELECT
        p.id_pedido,
        p.fecha_pedido,
        p.total,
        pr.nombre_producto,
        dp.cantidad,
        dp.precio_unitario
    FROM pedidos p
    JOIN detalles_pedido dp ON p.id_pedido = dp.id_pedido
    JOIN productos pr ON dp.id_producto = pr.id_producto
    WHERE p.id_cliente = id_cliente_in
    ORDER BY p.fecha_pedido DESC;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER tr_actualizar_total_pedido
AFTER INSERT ON detalles_pedido
FOR EACH ROW
BEGIN
    UPDATE pedidos
    SET total = calcular_total_pedido(NEW.id_pedido)
    WHERE id_pedido = NEW.id_pedido;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER tr_disminuir_stock
BEFORE INSERT ON detalles_pedido
FOR EACH ROW
BEGIN
    DECLARE stock_actual INT;
    SELECT stock INTO stock_actual FROM productos WHERE id_producto = NEW.id_producto;
    IF stock_actual < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente';
    ELSE
        UPDATE productos
        SET stock = stock - NEW.cantidad
        WHERE id_producto = NEW.id_producto;
    END IF;
END //
DELIMITER ;
