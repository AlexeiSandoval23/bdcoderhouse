-- =============================================
-- Autor: Alexei Sandoval
-- =============================================

SET autocommit=0;
SET FOREIGN_KEY_CHECKS=0;

DROP DATABASE IF EXISTS vinoteca_el_copihue;
CREATE DATABASE vinoteca_el_copihue CHARACTER SET utf8mb4 COLLATE utf8mb4_spanish_ci;
USE vinoteca_el_copihue;

-- ----------------------------------------------------
--                     TABLAS
-- ----------------------------------------------------

CREATE TABLE cliente (
  cliente_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  telefono VARCHAR(20),
  direccion VARCHAR(255),
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (apellido, nombre)
) ENGINE=InnoDB;

CREATE TABLE empleado (
  empleado_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  puesto VARCHAR(100) NOT NULL,
  fecha_contratacion DATE,
  email VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE sucursal (
  sucursal_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  direccion VARCHAR(255) NOT NULL,
  ciudad VARCHAR(100),
  telefono VARCHAR(20)
) ENGINE=InnoDB;

CREATE TABLE proveedor (
  proveedor_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_proveedor VARCHAR(150) NOT NULL,
  contacto_persona VARCHAR(100),
  telefono VARCHAR(20) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE vino (
  vino_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_vino VARCHAR(200) NOT NULL,
  descripcion TEXT,
  cosecha YEAR,
  precio DECIMAL(10, 2) NOT NULL,
  proveedor_id INT NOT NULL,
  INDEX (nombre_vino),
  FOREIGN KEY (proveedor_id) REFERENCES proveedor(proveedor_id)
) ENGINE=InnoDB;

CREATE TABLE categoria (
  categoria_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;

CREATE TABLE vino_categoria (
  vino_id INT NOT NULL,
  categoria_id INT NOT NULL,
  PRIMARY KEY (vino_id, categoria_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id),
  FOREIGN KEY (categoria_id) REFERENCES categoria(categoria_id)
) ENGINE=InnoDB;

CREATE TABLE uva (
  uva_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_uva VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;

CREATE TABLE vino_uva (
  vino_id INT NOT NULL,
  uva_id INT NOT NULL,
  porcentaje DECIMAL(5, 2),
  PRIMARY KEY (vino_id, uva_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id),
  FOREIGN KEY (uva_id) REFERENCES uva(uva_id)
) ENGINE=InnoDB;

CREATE TABLE stock (
  stock_id INT AUTO_INCREMENT PRIMARY KEY,
  sucursal_id INT NOT NULL,
  vino_id INT NOT NULL,
  cantidad INT NOT NULL DEFAULT 0,
  FOREIGN KEY (sucursal_id) REFERENCES sucursal(sucursal_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id),
  UNIQUE KEY unique_stock (sucursal_id, vino_id)
) ENGINE=InnoDB;

CREATE TABLE fact_venta (
  venta_id INT AUTO_INCREMENT PRIMARY KEY,
  fecha_id INT NOT NULL,
  sucursal_id INT NOT NULL,
  cliente_id INT NOT NULL,
  empleado_id INT NOT NULL,
  vino_id INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10, 2) NOT NULL,
  subtotal DECIMAL(10, 2) NOT NULL,
  FOREIGN KEY (fecha_id) REFERENCES dim_fecha(fecha_id),
  FOREIGN KEY (sucursal_id) REFERENCES sucursal(sucursal_id),
  FOREIGN KEY (cliente_id) REFERENCES cliente(cliente_id),
  FOREIGN KEY (empleado_id) REFERENCES empleado(empleado_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id)
) ENGINE=InnoDB;

CREATE TABLE dim_fecha (
  fecha_id INT PRIMARY KEY,
  fecha DATE NOT NULL UNIQUE,
  dia_semana VARCHAR(15),
  dia_mes INT,
  mes INT,
  anio INT,
  trimestre INT,
  es_fin_de_semana BOOLEAN,
  nombre_mes VARCHAR(20)
) ENGINE=InnoDB;

CREATE TABLE pedido (
  pedido_id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT NOT NULL,
  empleado_id INT NOT NULL,
  sucursal_id INT NOT NULL,
  fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  estado VARCHAR(50) NOT NULL DEFAULT 'En proceso',
  total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  INDEX (fecha_pedido),
  FOREIGN KEY (cliente_id) REFERENCES cliente(cliente_id),
  FOREIGN KEY (empleado_id) REFERENCES empleado(empleado_id),
  FOREIGN KEY (sucursal_id) REFERENCES sucursal(sucursal_id)
) ENGINE=InnoDB;

CREATE TABLE detalle_pedido (
  detalle_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  vino_id INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10, 2) NOT NULL,
  FOREIGN KEY (pedido_id) REFERENCES pedido(pedido_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id)
) ENGINE=InnoDB;

CREATE TABLE pago (
  pago_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  monto DECIMAL(10, 2) NOT NULL,
  metodo_pago ENUM('Tarjeta de Crédito', 'Tarjeta de Débito', 'Transferencia', 'Efectivo'),
  fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedido(pedido_id)
) ENGINE=InnoDB;

CREATE TABLE envio (
  envio_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  sucursal_id INT NOT NULL,
  transportista VARCHAR(100),
  fecha_despacho TIMESTAMP,
  fecha_entrega TIMESTAMP,
  estado_envio ENUM('Preparando', 'En Camino', 'Entregado', 'Devuelto'),
  FOREIGN KEY (pedido_id) REFERENCES pedido(pedido_id),
  FOREIGN KEY (sucursal_id) REFERENCES sucursal(sucursal_id)
) ENGINE=InnoDB;

CREATE TABLE bodega (
  bodega_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_bodega VARCHAR(100) NOT NULL,
  region VARCHAR(100),
  pais VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE vino_bodega (
  vino_id INT NOT NULL,
  bodega_id INT NOT NULL,
  PRIMARY KEY (vino_id, bodega_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id),
  FOREIGN KEY (bodega_id) REFERENCES bodega(bodega_id)
) ENGINE=InnoDB;

CREATE TABLE movimiento_stock (
  movimiento_id INT AUTO_INCREMENT PRIMARY KEY,
  sucursal_id INT NOT NULL,
  vino_id INT NOT NULL,
  tipo_movimiento ENUM('Entrada', 'Salida') NOT NULL,
  cantidad INT NOT NULL,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  observaciones TEXT,
  FOREIGN KEY (sucursal_id) REFERENCES sucursal(sucursal_id),
  FOREIGN KEY (vino_id) REFERENCES vino(vino_id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS=1;
COMMIT;
