USE ecommerce_db;
FLUSH PRIVILEGES;

CREATE ROLE IF NOT EXISTS 'role_system_admin';
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'role_system_admin' WITH GRANT OPTION;

CREATE ROLE IF NOT EXISTS 'role_marketing_manager';
GRANT SELECT ON ecommerce_db.customers TO 'role_marketing_manager';
GRANT SELECT ON ecommerce_db.orders TO 'role_marketing_manager';
GRANT SELECT ON ecommerce_db.order_details TO 'role_marketing_manager';
GRANT SELECT ON ecommerce_db.promotions TO 'role_marketing_manager';
GRANT SELECT ON ecommerce_db.product_reviews TO 'role_marketing_manager';

CREATE ROLE IF NOT EXISTS 'role_data_analyst';
GRANT SELECT ON ecommerce_db.branches TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.categories TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.suppliers TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.products TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.customers TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.orders TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.order_details TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.promotions TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.shopping_carts TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.cart_items TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.product_reviews TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.stock_alerts TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.weekly_sales_reports TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.daily_sales_summary TO 'role_data_analyst';
GRANT SELECT ON ecommerce_db.monthly_kpis TO 'role_data_analyst';

CREATE ROLE IF NOT EXISTS 'role_inventory_clerk';
GRANT SELECT ON ecommerce_db.products TO 'role_inventory_clerk';
GRANT SELECT ON ecommerce_db.categories TO 'role_inventory_clerk';
GRANT SELECT ON ecommerce_db.suppliers TO 'role_inventory_clerk';
GRANT SELECT ON ecommerce_db.stock_alerts TO 'role_inventory_clerk';
GRANT UPDATE (stock, warehouse_location) ON ecommerce_db.products TO 'role_inventory_clerk';

CREATE ROLE IF NOT EXISTS 'role_customer_support';
GRANT SELECT ON ecommerce_db.orders TO 'role_customer_support';
GRANT SELECT ON ecommerce_db.order_details TO 'role_customer_support';
GRANT SELECT ON ecommerce_db.products TO 'role_customer_support';
GRANT SELECT ON ecommerce_db.product_reviews TO 'role_customer_support';

CREATE ROLE IF NOT EXISTS 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.orders TO 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.order_details TO 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.products TO 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.price_change_logs TO 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.daily_sales_summary TO 'role_financial_auditor';
GRANT SELECT ON ecommerce_db.monthly_kpis TO 'role_financial_auditor';

CREATE USER IF NOT EXISTS 'admin_user'@'localhost' 
    IDENTIFIED BY 'Admin#P@ssw0rd2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'role_system_admin' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'role_system_admin' FOR 'admin_user'@'localhost';

CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' 
    IDENTIFIED BY 'Mktg#P@ssw0rd2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'role_marketing_manager' TO 'marketing_user'@'localhost';
SET DEFAULT ROLE 'role_marketing_manager' FOR 'marketing_user'@'localhost';

CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' 
    IDENTIFIED BY 'Inven#P@ssw0rd2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'role_inventory_clerk' TO 'inventory_user'@'localhost';
SET DEFAULT ROLE 'role_inventory_clerk' FOR 'inventory_user'@'localhost';

CREATE USER IF NOT EXISTS 'support_user'@'localhost' 
    IDENTIFIED BY 'Supp#P@ssw0rd2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'role_customer_support' TO 'support_user'@'localhost';
SET DEFAULT ROLE 'role_customer_support' FOR 'support_user'@'localhost';

CREATE USER IF NOT EXISTS 'analyst_user'@'localhost'
    IDENTIFIED BY 'Data#P@ssw0rd2026!'
    PASSWORD EXPIRE INTERVAL 90 DAY;
GRANT 'role_data_analyst' TO 'analyst_user'@'localhost';
SET DEFAULT ROLE 'role_data_analyst' FOR 'analyst_user'@'localhost';

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS sp_generate_monthly_sales_report(IN p_month INT, IN p_year INT)
BEGIN
    SELECT 'Placeholder: Real implementation is loaded in 07_Procedimientos_Almacenados.sql' AS status;
END //
DELIMITER ;

GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_generate_monthly_sales_report TO 'role_marketing_manager';

CREATE OR REPLACE VIEW v_basic_customer_info AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    CONCAT(SUBSTRING(c.email, 1, 2), '****@', SUBSTRING_INDEX(c.email, '@', -1)) AS masked_email,
    CONCAT(c.city, ' (Street address confidential)') AS generalized_location,
    c.loyalty_tier,
    c.total_spent,
    c.last_order_date,
    c.created_at AS member_since
FROM customers c;

GRANT SELECT ON ecommerce_db.v_basic_customer_info TO 'role_customer_support';

ALTER USER 'admin_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'marketing_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'inventory_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'support_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'analyst_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;

DELETE FROM mysql.user 
WHERE User = 'root' 
  AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;

CREATE ROLE IF NOT EXISTS 'role_guest';
GRANT SELECT ON ecommerce_db.products TO 'role_guest';

ALTER USER 'analyst_user'@'localhost' 
    WITH MAX_QUERIES_PER_HOUR 1000;

CREATE TABLE IF NOT EXISTS user_branch_assignments (
    username VARCHAR(100) PRIMARY KEY,
    branch_id INT NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_branch_assignments_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO user_branch_assignments (username, branch_id) VALUES
('support_user', 1),
('inventory_user', 2)
ON DUPLICATE KEY UPDATE branch_id = VALUES(branch_id);

CREATE OR REPLACE VIEW v_branch_scoped_orders AS
SELECT 
    o.order_id,
    o.customer_id,
    o.branch_id,
    b.name AS branch_name,
    b.city AS branch_city,
    o.order_date,
    o.status,
    o.total_amount
FROM orders o
JOIN branches b ON o.branch_id = b.branch_id
JOIN user_branch_assignments uba ON o.branch_id = uba.branch_id
WHERE uba.username = SUBSTRING_INDEX(USER(), '@', 1)
   OR USER() LIKE 'root@%'
   OR USER() LIKE 'admin_user@%';

GRANT SELECT ON ecommerce_db.v_branch_scoped_orders TO 'role_customer_support';
GRANT SELECT ON ecommerce_db.v_branch_scoped_orders TO 'role_inventory_clerk';

DELIMITER //

DROP PROCEDURE IF EXISTS sp_audit_failed_login //
CREATE PROCEDURE sp_audit_failed_login(
    IN p_attempted_user VARCHAR(100),
    IN p_client_ip VARCHAR(50),
    IN p_failure_reason VARCHAR(255)
)
BEGIN
    INSERT INTO security_logs (username, event_type, event_details, ip_address, logged_at)
    VALUES (
        COALESCE(p_attempted_user, 'UNKNOWN'),
        'FAILED_LOGIN_ATTEMPT',
        CONCAT('Authentication failure: ', COALESCE(p_failure_reason, 'Invalid credentials')),
        COALESCE(p_client_ip, '127.0.0.1'),
        NOW()
    );
END //

DELIMITER ;

FLUSH PRIVILEGES;
