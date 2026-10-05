-- =============================================================================
-- ACTIVIDAD: AUDITORÍA DE SEGURIDAD EN INFORMACIÓN SENSIBLE DE CLIENTES
-- =============================================================================
-- Objetivo:
-- Registrar detalladamente cualquier modificación en los datos sensibles
-- (email o direccion_envio) en la tabla 'Clientes', almacenando el historial
-- en la tabla 'Auditoria_Clientes'.
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- 1. CREACIÓN DE LA TABLA DE AUDITORÍA: Auditoria_Clientes
-- -----------------------------------------------------------------------------
-- Esta tabla almacena de forma persistente cada cambio realizado.
-- Estructura de campos:
--   - id_auditoria: Clave primaria autoincremental única para cada registro de auditoría.
--   - id_cliente: Identificador del cliente que sufrió la modificación.
--   - campo_modificado: Nombre del campo sensible alterado ('email' o 'direccion_envio').
--   - valor_antiguo: Valor que tenía el campo antes de la actualización (OLD).
--   - valor_nuevo: Nuevo valor asignado al campo tras la actualización (NEW).
--   - fecha_modificacion: Marca de tiempo exacta del momento en que ocurrió el cambio.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Auditoria_Clientes (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_antiguo TEXT NULL,
    valor_nuevo TEXT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 2. CREACIÓN DEL DISPARADOR: trg_audit_cliente_after_update
-- -----------------------------------------------------------------------------
-- Momento de ejecución: AFTER UPDATE (después de que el registro haya sido actualizado con éxito).
-- Frecuencia: FOR EACH ROW (se ejecuta por cada fila afectada en la sentencia UPDATE).
--
-- Lógica del Trigger:
-- 1. Evalúa si el campo 'email' ha cambiado. Si cambió, inserta una fila en
--    Auditoria_Clientes guardando el valor anterior (OLD.email) y el nuevo (NEW.email).
-- 2. Evalúa si el campo 'direccion_envio' ha cambiado. Si cambió, inserta una fila en
--    Auditoria_Clientes guardando el valor anterior (OLD.direccion_envio) y el nuevo (NEW.direccion_envio).
-- 3. Si ambos campos cambian en una misma instrucción UPDATE, se insertan dos registros
--    distintos para mantener la granularidad atómica de la auditoría por campo.
-- 4. Se utiliza el operador seguro de nulos 'NOT (OLD <=> NEW)' para detectar cambios
--    incluso si alguno de los valores fuese NULL.
-- -----------------------------------------------------------------------------

DELIMITER //

DROP TRIGGER IF EXISTS trg_audit_cliente_after_update //

CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON Clientes
FOR EACH ROW
BEGIN
    -- Verificación de cambio en el campo 'email'
    IF NOT (OLD.email <=> NEW.email) THEN
        INSERT INTO Auditoria_Clientes (
            id_cliente,
            campo_modificado,
            valor_antiguo,
            valor_nuevo,
            fecha_modificacion
        ) VALUES (
            NEW.id_cliente,
            'email',
            OLD.email,
            NEW.email,
            NOW()
        );
    END IF;

    -- Verificación de cambio en el campo 'direccion_envio'
    IF NOT (OLD.direccion_envio <=> NEW.direccion_envio) THEN
        INSERT INTO Auditoria_Clientes (
            id_cliente,
            campo_modificado,
            valor_antiguo,
            valor_nuevo,
            fecha_modificacion
        ) VALUES (
            NEW.id_cliente,
            'direccion_envio',
            OLD.direccion_envio,
            NEW.direccion_envio,
            NOW()
        );
    END IF;
END //

DELIMITER ;

-- =============================================================================
-- NOTA DE COMPATIBILIDAD CON LA BASE DE DATOS PREVIA (ecommerce_db)
-- =============================================================================
-- En la base de datos desarrollada previamente (01_Esquema_y_Datos.sql),
-- la tabla se nombró en inglés 'customers', con los campos 'customer_id' y
-- 'shipping_address'.
--
-- Si tu entorno de evaluación ejecuta las pruebas sobre la tabla en inglés,
-- la versión equivalente del disparador es:
--
-- DELIMITER //
-- CREATE TRIGGER trg_audit_cliente_after_update
-- AFTER UPDATE ON customers
-- FOR EACH ROW
-- BEGIN
--     IF NOT (OLD.email <=> NEW.email) THEN
--         INSERT INTO Auditoria_Clientes (id_cliente, campo_modificado, valor_antiguo, valor_nuevo, fecha_modificacion)
--         VALUES (NEW.customer_id, 'email', OLD.email, NEW.email, NOW());
--     END IF;
--     IF NOT (OLD.shipping_address <=> NEW.shipping_address) THEN
--         INSERT INTO Auditoria_Clientes (id_cliente, campo_modificado, valor_antiguo, valor_nuevo, fecha_modificacion)
--         VALUES (NEW.customer_id, 'shipping_address', OLD.shipping_address, NEW.shipping_address, NOW());
--     END IF;
-- END //
-- DELIMITER ;
-- =============================================================================

