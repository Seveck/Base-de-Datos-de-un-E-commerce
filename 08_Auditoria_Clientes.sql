USE ecommerce_db;

-- Audit table for tracking sensitive customer data modifications
CREATE TABLE IF NOT EXISTS customer_audit_logs (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    changed_field VARCHAR(50) NOT NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_audit_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Compatibility view mapping English schema to Spanish specification
CREATE OR REPLACE VIEW Auditoria_Clientes AS
SELECT 
    audit_id AS id_auditoria,
    customer_id AS id_cliente,
    changed_field AS campo_modificado,
    old_value AS valor_antiguo,
    new_value AS valor_nuevo,
    changed_at AS fecha_modificacion
FROM customer_audit_logs;

DELIMITER //

DROP TRIGGER IF EXISTS trg_audit_customer_after_update //
DROP TRIGGER IF EXISTS trg_audit_cliente_after_update //

-- Trigger that audits modifications to email or shipping_address upon update
CREATE TRIGGER trg_audit_customer_after_update
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    -- GDPR Compliance: Skip audit capturing if this update is an account anonymization action
    IF NOT (NEW.first_name = 'Anonymized' AND NEW.last_name = 'Customer') THEN
        -- Audit email modifications
        IF NOT (OLD.email <=> NEW.email) THEN
            INSERT INTO customer_audit_logs (
                customer_id,
                changed_field,
                old_value,
                new_value,
                changed_at
            ) VALUES (
                NEW.customer_id,
                'email',
                OLD.email,
                NEW.email,
                NOW()
            );
        END IF;

        -- Audit shipping address modifications
        IF NOT (OLD.shipping_address <=> NEW.shipping_address) THEN
            INSERT INTO customer_audit_logs (
                customer_id,
                changed_field,
                old_value,
                new_value,
                changed_at
            ) VALUES (
                NEW.customer_id,
                'shipping_address',
                OLD.shipping_address,
                NEW.shipping_address,
                NOW()
            );
        END IF;
    END IF;
END //

DELIMITER ;
