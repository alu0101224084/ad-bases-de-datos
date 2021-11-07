-- MySQL Script generated by MySQL Workbench
-- Sun Oct 31 12:53:16 2021
-- Model: New Model    Version: 1.0
-- MySQL Workbench Forward Engineering

-- -----------------------------------------------------
-- Table VIVEROS
-- -----------------------------------------------------
DROP TABLE IF EXISTS VIVEROS CASCADE;

CREATE TABLE IF NOT EXISTS VIVEROS (
	  Nombre VARCHAR(40) NOT NULL,
	  Latitud FLOAT NOT NULL,
	  Longitud FLOAT NOT NULL,
	  PRIMARY KEY (Nombre));


	-- -----------------------------------------------------
-- Table ZONAS
-- -----------------------------------------------------
DROP TABLE IF EXISTS ZONAS CASCADE;

CREATE TABLE IF NOT EXISTS ZONAS (
	  Codigo INT NOT NULL,
	  Tipo VARCHAR(40) NOT NULL,
	  VIVEROS_Nombre VARCHAR(40) NOT NULL,
	  PRIMARY KEY (Codigo),
	  CONSTRAINT fk_ZONAS_VIVEROS
	    FOREIGN KEY (VIVEROS_Nombre)
	    REFERENCES VIVEROS (Nombre)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION);


	-- -----------------------------------------------------
-- Table PRODUCTOS
-- -----------------------------------------------------
DROP TABLE IF EXISTS PRODUCTOS CASCADE;

CREATE TABLE IF NOT EXISTS PRODUCTOS (
	  ID INT NOT NULL,
	  Precio FLOAT NOT NULL,
	  Categoria VARCHAR(45) NOT NULL,
	  PRIMARY KEY (ID));


	-- -----------------------------------------------------
-- Table ZONAS_has_PRODUCTOS
-- -----------------------------------------------------
DROP TABLE IF EXISTS ZONAS_has_PRODUCTOS CASCADE;

CREATE TABLE IF NOT EXISTS ZONAS_has_PRODUCTOS (
	  PRODUCTOS_ID INT NOT NULL,
	  Stock INT NOT NULL,
	  ZONAS_Codigo INT NOT NULL,
	  PRIMARY KEY (ZONAS_Codigo, PRODUCTOS_ID),
	  CONSTRAINT fk_ZONAS_has_PRODUCTOS_PRODUCTOS1
	    FOREIGN KEY (PRODUCTOS_ID)
	    REFERENCES PRODUCTOS (ID)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION,
	  CONSTRAINT fk_ZONAS_has_PRODUCTOS_ZONAS1
	    FOREIGN KEY (ZONAS_Codigo)
	    REFERENCES ZONAS (Codigo)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION);


	-- -----------------------------------------------------
-- Table EMPLEADOS
-- -----------------------------------------------------
DROP TABLE IF EXISTS EMPLEADOS CASCADE;

CREATE TABLE IF NOT EXISTS EMPLEADOS (
	  DNI INT NOT NULL,
	  Nombre VARCHAR(45) NOT NULL,
	  PRIMARY KEY (DNI));


	-- -----------------------------------------------------
-- Table CLIENTES
-- -----------------------------------------------------
DROP TABLE IF EXISTS CLIENTES CASCADE;

CREATE TABLE IF NOT EXISTS CLIENTES (
	  DNI INT NOT NULL,
	  Nombre VARCHAR(45) NOT NULL,
	  Email VARCHAR(45),
	  PRIMARY KEY (DNI));


	-- -----------------------------------------------------
-- Table PEDIDOS
-- -----------------------------------------------------
DROP TABLE IF EXISTS PEDIDOS CASCADE;

CREATE TABLE IF NOT EXISTS PEDIDOS (
	  Codigo INT NOT NULL,
	  Fecha DATE NOT NULL,
	  EMPLEADOS_DNI INT NOT NULL,
	  CLIENTES_DNI INT NOT NULL,
	  PRIMARY KEY (Codigo),
	  CONSTRAINT fk_PEDIDOS_EMPLEADOS1
	    FOREIGN KEY (EMPLEADOS_DNI)
	    REFERENCES EMPLEADOS (DNI)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION,
	  CONSTRAINT fk_PEDIDOS_CLIENTES1
	    FOREIGN KEY (CLIENTES_DNI)
	    REFERENCES CLIENTES (DNI)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION);


	-- -----------------------------------------------------
-- Table PEDIDOS_has_PRODUCTOS
-- -----------------------------------------------------
DROP TABLE IF EXISTS PEDIDOS_has_PRODUCTOS CASCADE;

CREATE TABLE IF NOT EXISTS PEDIDOS_has_PRODUCTOS (
	  PEDIDOS_Codigo INT NOT NULL,
	  PRODUCTOS_ID INT NOT NULL,
	  Cantidad INT NOT NULL,
	  PRIMARY KEY (PRODUCTOS_ID, PEDIDOS_Codigo),
	  CONSTRAINT fk_PEDIDOS_has_PRODUCTOS_PEDIDOS1
	    FOREIGN KEY (PEDIDOS_Codigo)
	    REFERENCES PEDIDOS (Codigo)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION,
	  CONSTRAINT fk_PEDIDOS_has_PRODUCTOS_PRODUCTOS1
	    FOREIGN KEY (PRODUCTOS_ID)
	    REFERENCES PRODUCTOS (ID)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION);


	-- -----------------------------------------------------
-- Table ASIGNACION_ZONA_EMPLEADO
-- -----------------------------------------------------
DROP TABLE IF EXISTS ASIGNACION_ZONA_EMPLEADO CASCADE;

CREATE TABLE IF NOT EXISTS ASIGNACION_ZONA_EMPLEADO (
	  Fecha_Inicio DATE NOT NULL,
	  Fecha_Fin DATE NULL,
	  EMPLEADOS_DNI INT NOT NULL,
	  ZONAS_Codigo INT NOT NULL,
	  PRIMARY KEY (Fecha_Inicio, EMPLEADOS_DNI),
	  CONSTRAINT fk_ASIGNACION_ZONA_EMPLEADO_EMPLEADOS1
	    FOREIGN KEY (EMPLEADOS_DNI)
	    REFERENCES EMPLEADOS (DNI)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION,
	  CONSTRAINT fk_ASIGNACION_ZONA_EMPLEADO_ZONAS1
	    FOREIGN KEY (ZONAS_Codigo)
	    REFERENCES ZONAS (Codigo)
	    ON DELETE NO ACTION
	    ON UPDATE NO ACTION);

	-- Procedures

CREATE OR REPLACE FUNCTION crear_email() RETURNS trigger AS $$
BEGIN
    IF NEW.Email IS NULL THEN
	IF TG_NARGS = 0 THEN
	    RAISE EXCEPTION 'A domain is needed for creating an email account';
	END IF;
	NEW.Email := NEW.Nombre || '@' || TG_ARGV[0];
    END IF;
    IF (New.Email !~* '^[A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$') THEN
		RAISE EXCEPTION 'Given email is not valid';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER trigger_crear_email_before_insert
    BEFORE INSERT
    ON CLIENTES
    FOR EACH ROW
    EXECUTE PROCEDURE crear_email('viveros.es');

CREATE OR REPLACE FUNCTION comprobar_coor() RETURNS TRIGGER AS $$
BEGIN
    IF ('t' = ANY(SELECT (NEW.latitud = latitud AND NEW.longitud = longitud) FROM viveros)) THEN
		RAISE EXCEPTION 'Invalid insertion: latitud and longitud are already in the database';
	END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_insert BEFORE INSERT on VIVEROS
FOR EACH ROW
EXECUTE PROCEDURE comprobar_coor();

CREATE OR REPLACE FUNCTION actualizar_stock() RETURNS TRIGGER AS $$
DECLARE
	empleado_dni integer;
	zona integer;
	stock_value integer;
BEGIN
	SELECT EMPLEADOS_DNI INTO empleado_dni FROM PEDIDOS
		WHERE PEDIDOS.Codigo  = NEW.PEDIDOS_Codigo;
	SELECT Codigo INTO zona FROM ZONAS CROSS JOIN ASIGNACION_ZONA_EMPLEADO
		WHERE ZONAS.Codigo = ASIGNACION_ZONA_EMPLEADO.ZONAS_Codigo AND Fecha_Fin IS NULL AND EMPLEADOS_DNI = empleado_dni;
	SELECT Stock INTO stock_value FROM ZONAS_has_PRODUCTOS WHERE ZONAS_Codigo = zona AND PRODUCTOS_ID = NEW.PRODUCTOS_ID;
	IF stock_value < NEW.Cantidad THEN
		RAISE EXCEPTION 'Can''t sell more than the stock stored in the zone';
	END IF;
	UPDATE ZONAS_has_PRODUCTOS SET Stock = stock_value - NEW.Cantidad WHERE ZONAS_Codigo = zona AND PRODUCTOS_ID = NEW.PRODUCTOS_ID;
    return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ventas_stock BEFORE INSERT on PEDIDOS_has_PRODUCTOS
FOR EACH ROW
EXECUTE PROCEDURE actualizar_stock();


					-- -----------------------------------------------------
-- Data for table VIVEROS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO VIVEROS (Nombre, Latitud, Longitud) VALUES ('Flores Viren', 7, 8);
INSERT INTO VIVEROS (Nombre, Latitud, Longitud) VALUES ('Flores Angel', 1, 2);
INSERT INTO VIVEROS (Nombre, Latitud, Longitud) VALUES ('Flores Daniel', 3, 4);
INSERT INTO VIVEROS (Nombre, Latitud, Longitud) VALUES ('Flores Javier', 5, 6);
INSERT INTO VIVEROS (Nombre, Latitud, Longitud) VALUES ('Flores Cristopher', 9, 10);

COMMIT;


-- -----------------------------------------------------
-- Data for table ZONAS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (0, 'Exterior', 'Flores Angel');
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (1, 'Cajas', 'Flores Daniel');
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (2, 'Almacen', 'Flores Daniel');
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (3, 'Cajas', 'Flores Javier');
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (4, 'Cajas', 'Flores Daniel');
INSERT INTO ZONAS (Codigo, Tipo, VIVEROS_Nombre) VALUES (5, 'Exterior', 'Flores Cristopher');

COMMIT;


-- -----------------------------------------------------
-- Data for table PRODUCTOS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO PRODUCTOS (ID, Precio, Categoria) VALUES (0, 1337, 'Arbol');

COMMIT;


-- -----------------------------------------------------
-- Data for table ZONAS_has_PRODUCTOS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO ZONAS_has_PRODUCTOS (PRODUCTOS_ID, Stock, ZONAS_Codigo) VALUES (0, 10, 0);
INSERT INTO ZONAS_has_PRODUCTOS (PRODUCTOS_ID, Stock, ZONAS_Codigo) VALUES (0, 1, 1);
INSERT INTO ZONAS_has_PRODUCTOS (PRODUCTOS_ID, Stock, ZONAS_Codigo) VALUES (0, 12, 2);
INSERT INTO ZONAS_has_PRODUCTOS (PRODUCTOS_ID, Stock, ZONAS_Codigo) VALUES (0, 15, 3);
INSERT INTO ZONAS_has_PRODUCTOS (PRODUCTOS_ID, Stock, ZONAS_Codigo) VALUES (0, 20, 4);

COMMIT;


-- -----------------------------------------------------
-- Data for table EMPLEADOS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO EMPLEADOS (DNI, Nombre) VALUES (12345678, 'Jose Daniel');
INSERT INTO EMPLEADOS (DNI, Nombre) VALUES (98765432, 'Nerea');
INSERT INTO EMPLEADOS (DNI, Nombre) VALUES (11223344, 'Perita');
INSERT INTO EMPLEADOS (DNI, Nombre) VALUES (75315946, 'Gabriel');
INSERT INTO EMPLEADOS (DNI, Nombre) VALUES (45678921, 'Kevin');

COMMIT;

-- -----------------------------------------------------
-- Data for table ASIGNACION_ZONA_EMPLEADO
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO ASIGNACION_ZONA_EMPLEADO (Fecha_Inicio, Fecha_Fin, EMPLEADOS_DNI, ZONAS_Codigo) VALUES ('1970-01-01', '1971-01-01', 12345678, 0);
INSERT INTO ASIGNACION_ZONA_EMPLEADO (Fecha_Inicio, Fecha_Fin, EMPLEADOS_DNI, ZONAS_Codigo) VALUES ('2020-03-14', '2020-03-15', 45678921, 1);
INSERT INTO ASIGNACION_ZONA_EMPLEADO (Fecha_Inicio, Fecha_Fin, EMPLEADOS_DNI, ZONAS_Codigo) VALUES ('2020-09-09', NULL, 98765432, 2);
INSERT INTO ASIGNACION_ZONA_EMPLEADO (Fecha_Inicio, Fecha_Fin, EMPLEADOS_DNI, ZONAS_Codigo) VALUES ('2000-07-26', '2000-08-26', 11223344, 3);
INSERT INTO ASIGNACION_ZONA_EMPLEADO (Fecha_Inicio, Fecha_Fin, EMPLEADOS_DNI, ZONAS_Codigo) VALUES ('2018-01-01', NULL, 75315946, 4);

COMMIT;

-- -----------------------------------------------------
-- Data for table CLIENTES
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO CLIENTES (DNI, Nombre, Email) VALUES (35715968, 'Elena', NULL);

COMMIT;


-- -----------------------------------------------------
-- Data for table PEDIDOS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO PEDIDOS (Codigo, Fecha, EMPLEADOS_DNI, CLIENTES_DNI) VALUES (0, '2021-10-31', 98765432, 35715968);

COMMIT;


-- -----------------------------------------------------
-- Data for table PEDIDOS_has_PRODUCTOS
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO PEDIDOS_has_PRODUCTOS (PEDIDOS_Codigo, PRODUCTOS_ID, Cantidad) VALUES (0, 0, 50);

COMMIT;
