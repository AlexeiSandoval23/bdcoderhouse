-- =============================================
-- Autor: Alexei Sandoval
-- =============================================

USE vinoteca_el_copihue;

-- 1. Ventas Totales por Mes y Año
SELECT
    df.nombre_mes AS mes,
    df.anio AS anio,
    SUM(p.total) AS total_ventas,
    COUNT(p.pedido_id) AS total_pedidos
FROM pedido p
JOIN dim_fecha df ON DATE_FORMAT(p.fecha_pedido, '%Y%m%d') = df.fecha_id
GROUP BY df.anio, df.nombre_mes, df.mes
ORDER BY df.anio, df.mes;

-- 2. Los 10 Vinos Más Vendidos por Cantidad
SELECT * FROM vw_productos_mas_vendidos;

-- 3. Resumen de Ventas por Sucursal
SELECT
    s.nombre AS nombre_sucursal,
    COUNT(p.pedido_id) AS total_pedidos,
    SUM(p.total) AS total_ventas
FROM pedido p
JOIN sucursal s ON p.sucursal_id = s.sucursal_id
GROUP BY s.nombre
ORDER BY total_ventas DESC;

-- 4. Distribución de Vinos por Categoría
SELECT
    c.nombre_categoria,
    COUNT(vc.vino_id) AS cantidad_vinos
FROM categoria c
JOIN vino_categoria vc ON c.categoria_id = vc.categoria_id
GROUP BY c.nombre_categoria
ORDER BY cantidad_vinos DESC;

-- 5. Clientes Más Frecuentes y con Mayor Gasto
SELECT
    c.nombre,
    c.apellido,
    COUNT(p.pedido_id) AS numero_pedidos,
    SUM(p.total) AS gasto_total
FROM cliente c
JOIN pedido p ON c.cliente_id = p.cliente_id
GROUP BY c.cliente_id
ORDER BY gasto_total DESC, numero_pedidos DESC;

-- 6. Vinos con Stock Bajo
SELECT
    s.nombre AS nombre_sucursal,
    v.nombre_vino,
    t.cantidad AS stock_actual
FROM stock t
JOIN sucursal s ON t.sucursal_id = s.sucursal_id
JOIN vino v ON t.vino_id = v.vino_id
WHERE t.cantidad < 15
ORDER BY t.cantidad ASC;

-- 7. Historial de Pagos por Método
SELECT
    metodo_pago,
    COUNT(pago_id) AS total_pagos,
    SUM(monto) AS monto_total
FROM pago
GROUP BY metodo_pago
ORDER BY monto_total DESC;

-- 8. Vinos por Uva
SELECT
    u.nombre_uva,
    COUNT(vu.vino_id) AS cantidad_vinos
FROM uva u
JOIN vino_uva vu ON u.uva_id = vu.uva_id
GROUP BY u.nombre_uva
ORDER BY cantidad_vinos DESC;

-- 9. Pedidos que no han sido entregados
SELECT
    p.pedido_id,
    c.nombre AS nombre_cliente,
    c.apellido AS apellido_cliente,
    p.estado,
    p.fecha_pedido
FROM pedido p
JOIN cliente c ON p.cliente_id = c.cliente_id
WHERE p.estado IN ('En proceso', 'En Camino')
ORDER BY p.fecha_pedido ASC;

-- 10. Movimientos de Stock Recientes
SELECT
    m.movimiento_id,
    s.nombre AS nombre_sucursal,
    v.nombre_vino,
    m.tipo_movimiento,
    m.cantidad,
    m.fecha
FROM movimiento_stock m
JOIN sucursal s ON m.sucursal_id = s.sucursal_id
JOIN vino v ON m.vino_id = v.vino_id
ORDER BY m.fecha DESC
LIMIT 10;
