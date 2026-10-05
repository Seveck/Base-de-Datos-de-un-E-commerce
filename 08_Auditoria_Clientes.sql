USE ecommerce_db;

-- Tabla de auditoria para registrar modificaciones en datos sensibles de clientes
CREATE TABLE IF NOT EXISTS Auditoria_Clientes (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_antiguo TEXT NULL,
    valor_nuevo TEXT NULL,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //

DROP TRIGGER IF EXISTS trg_audit_cliente_after_update //

-- Disparador que audita cambios en email o direccion_envio tras una actualizacion
CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON Clientes
FOR EACH ROW
BEGIN
    -- Registra el valor anterior y nuevo si el email fue modificado
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

    -- Registra el valor anterior y nuevo si la direccion de envio fue modificada
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
