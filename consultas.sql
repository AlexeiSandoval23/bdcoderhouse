-- =============================================
-- Testeo
-- =============================================

USE vinoteca_el_copihue;

-- 1. Ver todos los clientes registrados.
SELECT * FROM clientes;

-- 2. Ver todos los productos, mostrando el nombre de su categoría y proveedor.
SELECT
  p.nombre_producto,
  p.precio,
  p.stock,
  c.nombre_categoria,
  pr.nombre_proveedor
FROM productos p
JOIN categorias c ON p.id_categoria = c.id_categoria
JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor;

-- 3. Ver el detalle de un pedido específico (ej: pedido con id=1).
SELECT
  pe.id_pedido,
  pe.fecha_pedido,
  cl.nombre,
  cl.apellido,
  pr.nombre_producto,
  dp.cantidad,
  dp.precio_unitario
FROM pedidos pe
JOIN clientes cl ON pe.id_cliente = cl.id_cliente
JOIN detalles_pedido dp ON pe.id_pedido = dp.id_pedido
JOIN productos pr ON dp.id_producto = pr.id_producto
WHERE pe.id_pedido = 1;

-- 4. Contar cuántos productos hay por cada categoría.
SELECT
  c.nombre_categoria,
  COUNT(p.id_producto) AS total_productos
FROM productos p
JOIN categorias c ON p.id_categoria = c.id_categoria
GROUP BY c.nombre_categoria;

-- 5. Mostrar los pedidos de un cliente específico (ej: cliente con id=1).
SELECT * FROM pedidos WHERE id_cliente = 1;
