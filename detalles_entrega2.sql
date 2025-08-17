-- detalles_entrega2.sql

-- Alexei Sandoval


SELECT * FROM vista_detalle_ventas;

SELECT * FROM vista_resumen_stock;

SELECT calcular_total_pedido(1);

SELECT obtener_stock_disponible(1);

CALL sp_insertar_nuevo_pedido(2, 6, 3);

CALL sp_obtener_ventas_cliente(1);
