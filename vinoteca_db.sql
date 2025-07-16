-- =============================================
-- Autor: Alexei Sandoval
-- =============================================

DROP DATABASE IF EXISTS vinoteca_el_copihue;
CREATE DATABASE vinoteca_el_copihue CHARACTER SET utf8mb4;
USE vinoteca_el_copihue;

-- --- Creación de Tablas ---

CREATE TABLE clientes (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  telefono VARCHAR(20),
  direccion VARCHAR(255),
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX (apellido, nombre)
) ENGINE=InnoDB;

CREATE TABLE proveedores (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  nombre_proveedor VARCHAR(150) NOT NULL,
  contacto_persona VARCHAR(100),
  telefono VARCHAR(20) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE categorias (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;

CREATE TABLE productos (
  id_producto INT AUTO_INCREMENT PRIMARY KEY,
  nombre_producto VARCHAR(200) NOT NULL,
  descripcion TEXT,
  precio INT NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  id_categoria INT NOT NULL,
  id_proveedor INT NOT NULL,
  INDEX (nombre_producto),
  FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
  FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
) ENGINE=InnoDB;

CREATE TABLE pedidos (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT NOT NULL,
  fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total INT NOT NULL,
  estado VARCHAR(50) NOT NULL DEFAULT 'En proceso',
  FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ENGINE=InnoDB;

CREATE TABLE detalles_pedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario INT NOT NULL,
  FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
  FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;


-- --- Informacion para las tablas ---

INSERT INTO categorias (nombre_categoria, descripcion) VALUES
('Tinto', 'Vinos elaborados a partir de uvas tintas. La fermentación se realiza con los hollejos para extraer color y taninos.'),
('Blanco', 'Vinos de uvas blancas o tintas de pulpa blanca. Fermentados sin los hollejos.'),
('Ensamblaje', 'Vino que es resultado de la mezcla de dos o más cepas diferentes para lograr mayor complejidad.'),
('Rosé', 'Vinos rosados, elaborados con una maceración corta de uvas tintas. Son ligeros y frescos.'),
('Espumante', 'Vino con gas carbónico disuelto que se produce de forma natural en la segunda fermentación.');

INSERT INTO proveedores (nombre_proveedor, contacto_persona, telefono, email) VALUES
('Viña Santa Rita', 'Andrés Lavados', '+56223622000', 'contacto@santarita.cl'),
('Viña Concha y Toro', 'Eduardo Guilisasti', '+56224765000', 'info@conchaytoro.cl'),
('Viña Undurraga', 'Ernesto Müller', '+56223722100', 'ventas@undurraga.cl'),
('Viña Montes', 'Aurelio Montes', '+56222484805', 'info@monteswines.com');

INSERT INTO clientes (nombre, apellido, email, telefono, direccion) VALUES
('Javier', 'González', 'javier.gonzalez@correo.cl', '+56987654321', 'Los Cerezos 123, Ñuñoa, Santiago'),
('Carolina', 'Soto', 'caro.soto@correo.cl', '+56912345678', 'Av. Alemania 45, Depto 10, Concepción'),
('Matías', 'Rojas', 'matias.rojas@correo.cl', '+56955554444', 'Errázuriz 789, Valparaíso'),
('Valentina', 'Muñoz', 'vale.munoz@correo.cl', '+56988887777', 'Av. del Mar 2100, La Serena'),
('Benjamín', 'Díaz', 'benja.diaz@correo.cl', '+56944443333', 'O Higgins 555, Temuco');

INSERT INTO productos (nombre_producto, descripcion, precio, stock, id_categoria, id_proveedor) VALUES
('Santa Rita 120 Carménère', 'Un clásico Carménère del Valle Central, suave y especiado.', 4990, 150, 1, 1),
('Casillero del Diablo Cabernet Sauvignon', 'Vino reserva, intenso y con notas a frutos rojos y cassis.', 6490, 200, 1, 2),
('Undurraga TH Sauvignon Blanc', 'Vino de Leyda, fresco, mineral y con notas cítricas.', 8990, 80, 2, 3),
('Marqués de Casa Concha Ensamblaje', 'Potente mezcla de tintos del Valle del Maipo.', 14990, 60, 3, 2),
('Santa Digna Estelado Rosé', 'Espumante rosado del tipo País, único y refrescante.', 7500, 110, 4, 1),
('Montes Alpha Cabernet Sauvignon', 'Vino ícono de Colchagua, elegante y de gran cuerpo.', 18990, 50, 1, 4),
('Concha y Toro Amelia Chardonnay', 'Chardonnay del valle de Limarí, complejo y con notas a madera.', 19990, 40, 2, 2),
('Undurraga Brut Royal', 'Espumante de método tradicional, ideal para celebraciones.', 9990, 90, 5, 3);

INSERT INTO pedidos (id_cliente, total, estado) VALUES
(1, 16470, 'Entregado'),
(2, 23980, 'Despachado'),
(4, 38970, 'En proceso'),
(1, 28980, 'En proceso');

INSERT INTO detalles_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(1, 1, 2, 4990),
(1, 2, 1, 6490),
(2, 3, 1, 8990),
(2, 4, 1, 14990),
(3, 6, 1, 18990),
(3, 7, 1, 19990),
(4, 8, 2, 9990),
(4, 1, 2, 4990);
