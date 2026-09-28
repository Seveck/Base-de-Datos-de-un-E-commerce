USE ecommerce_db;

SET GLOBAL event_scheduler = ON;

CREATE TABLE IF NOT EXISTS weekly_sales_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_year INT NOT NULL,
    report_week INT NOT NULL,
    total_orders INT NOT NULL,
    total_revenue DECIMAL(14, 2) NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_weekly_sales (report_year, report_week)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reorder_list (
    reorder_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    current_stock INT NOT NULL,
    min_threshold INT NOT NULL,
    suggested_order_qty INT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reorder_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customer_birthday_coupons (
    coupon_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    coupon_code VARCHAR(50) NOT NULL UNIQUE,
    issued_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    is_redeemed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_bday_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS database_size_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    database_name VARCHAR(100) NOT NULL,
    size_mb DECIMAL(10, 2) NOT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_rankings (
    ranking_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    total_units_sold INT NOT NULL,
    rank_position INT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rankings_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS backup_snapshot_logs (
    snapshot_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    row_count INT NOT NULL,
    snapshot_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mat_category_summary (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    total_products INT NOT NULL,
    total_stock INT NOT NULL,
    total_sales_revenue DECIMAL(14, 2) NOT NULL,
    refreshed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER //

DROP EVENT IF EXISTS evt_generate_weekly_sales_report //
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-10-04 23:55:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO weekly_sales_reports (report_year, report_week, total_orders, total_revenue, generated_at)
    SELECT 
        YEAR(CURDATE()),
        WEEK(CURDATE(), 1),
        COUNT(DISTINCT order_id),
        COALESCE(SUM(total_amount), 0.00),
        NOW()
    FROM orders
    WHERE order_date >= (CURDATE() - INTERVAL 7 DAY)
      AND status NOT IN ('Cancelled')
    ON DUPLICATE KEY UPDATE
        total_orders = VALUES(total_orders),
        total_revenue = VALUES(total_revenue),
        generated_at = NOW();
END //

DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily //
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 03:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM shopping_carts
    WHERE updated_at < (NOW() - INTERVAL 7 DAY)
      AND cart_id NOT IN (SELECT DISTINCT cart_id FROM cart_items);
END //

DROP EVENT IF EXISTS evt_archive_old_logs_monthly //
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-10-01 02:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM customer_logs WHERE logged_at < (NOW() - INTERVAL 180 DAY);
    DELETE FROM order_status_logs WHERE changed_at < (NOW() - INTERVAL 180 DAY);
    DELETE FROM security_logs WHERE logged_at < (NOW() - INTERVAL 180 DAY);
END //

DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly //
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS '2026-09-28 00:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE promotions
    SET is_active = FALSE
    WHERE end_date < NOW() AND is_active = TRUE;
END //

DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly //
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 01:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE customers c
    JOIN (
        SELECT 
            customer_id,
            COALESCE(SUM(total_amount), 0.00) AS calculated_spend
        FROM orders
        WHERE status NOT IN ('Cancelled')
        GROUP BY customer_id
    ) o_spend ON c.customer_id = o_spend.customer_id
    SET 
        c.total_spent = o_spend.calculated_spend,
        c.loyalty_tier = CASE 
            WHEN o_spend.calculated_spend >= 5000.00 THEN 'Platinum'
            WHEN o_spend.calculated_spend >= 2500.00 THEN 'Gold'
            WHEN o_spend.calculated_spend >= 1000.00 THEN 'Silver'
            ELSE 'Bronze'
        END;
END //

DROP EVENT IF EXISTS evt_generate_reorder_list_daily //
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 04:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    TRUNCATE TABLE reorder_list;

    INSERT INTO reorder_list (product_id, current_stock, min_threshold, suggested_order_qty, generated_at)
    SELECT 
        product_id,
        stock,
        min_threshold,
        ((min_threshold * 2) - stock),
        NOW()
    FROM products
    WHERE stock <= min_threshold
      AND is_active = TRUE;
END //

DROP EVENT IF EXISTS evt_rebuild_indexes_weekly //
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-10-04 04:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    ANALYZE TABLE products;
    ANALYZE TABLE orders;
    ANALYZE TABLE order_details;
    ANALYZE TABLE customers;
END //

DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly //
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
STARTS '2026-10-01 02:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE customers
    SET is_active = FALSE
    WHERE (last_order_date IS NULL AND created_at < (NOW() - INTERVAL 365 DAY))
       OR (last_order_date < (NOW() - INTERVAL 365 DAY));
END //

DROP EVENT IF EXISTS evt_aggregate_daily_sales_data //
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 23:59:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO daily_sales_summary (summary_date, total_orders, total_sales, total_cost, total_profit, created_at)
    SELECT 
        CURDATE(),
        COUNT(DISTINCT o.order_id),
        COALESCE(SUM(od.quantity * od.frozen_unit_price), 0.00),
        COALESCE(SUM(od.quantity * p.cost), 0.00),
        COALESCE(SUM(od.quantity * (od.frozen_unit_price - p.cost)), 0.00),
        NOW()
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN products p ON od.product_id = p.product_id
    WHERE DATE(o.order_date) = CURDATE()
      AND o.status NOT IN ('Cancelled')
    ON DUPLICATE KEY UPDATE
        total_orders = VALUES(total_orders),
        total_sales = VALUES(total_sales),
        total_cost = VALUES(total_cost),
        total_profit = VALUES(total_profit);
END //

DROP EVENT IF EXISTS evt_check_data_consistency_nightly //
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 01:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_empty_orders_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_empty_orders_count
    FROM orders o
    LEFT JOIN order_details od ON o.order_id = od.order_id
    WHERE od.order_detail_id IS NULL;

    IF v_empty_orders_count > 0 THEN
        INSERT INTO security_logs (username, event_type, event_details, ip_address, logged_at)
        VALUES (
            'SYSTEM_INTEGRITY_CHECK',
            'DATA_INCONSISTENCY_WARNING',
            CONCAT('Integrity warning: Found ', v_empty_orders_count, ' orders without line details.'),
            '127.0.0.1',
            NOW()
        );
    END IF;
END //

DROP EVENT IF EXISTS evt_send_birthday_greetings_daily //
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 06:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO customer_birthday_coupons (customer_id, coupon_code, issued_date, expiry_date, is_redeemed)
    SELECT 
        customer_id,
        CONCAT('BDAY-', customer_id, '-', YEAR(CURDATE())),
        CURDATE(),
        CURDATE() + INTERVAL 30 DAY,
        FALSE
    FROM customers
    WHERE MONTH(birth_date) = MONTH(CURDATE())
      AND DAY(birth_date) = DAY(CURDATE())
      AND is_active = TRUE
    ON DUPLICATE KEY UPDATE issued_date = VALUES(issued_date);
END //

DROP EVENT IF EXISTS evt_update_product_rankings_hourly //
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS '2026-09-28 00:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    TRUNCATE TABLE product_rankings;

    INSERT INTO product_rankings (product_id, product_name, total_units_sold, rank_position, updated_at)
    SELECT 
        p.product_id,
        p.name,
        COALESCE(SUM(od.quantity), 0) AS units_sold,
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(od.quantity), 0) DESC) AS rank_pos,
        NOW()
    FROM products p
    LEFT JOIN order_details od ON p.product_id = od.product_id
    LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
    GROUP BY p.product_id, p.name
    LIMIT 20;
END //

DROP EVENT IF EXISTS evt_backup_critical_tables_daily //
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 04:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO backup_snapshot_logs (table_name, row_count, snapshot_date)
    SELECT 'products', COUNT(*), NOW() FROM products
    UNION ALL
    SELECT 'customers', COUNT(*), NOW() FROM customers
    UNION ALL
    SELECT 'orders', COUNT(*), NOW() FROM orders
    UNION ALL
    SELECT 'order_details', COUNT(*), NOW() FROM order_details;
END //

DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily //
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 05:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE shopping_carts
    SET is_abandoned = TRUE
    WHERE updated_at < (NOW() - INTERVAL 72 HOUR)
      AND is_abandoned = FALSE;

    DELETE FROM cart_items
    WHERE cart_id IN (
        SELECT cart_id FROM shopping_carts 
        WHERE updated_at < (NOW() - INTERVAL 14 DAY)
    );
END //

DROP EVENT IF EXISTS evt_calculate_monthly_kpis //
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-10-01 00:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_prev_month INT;
    DECLARE v_prev_year INT;

    SET v_prev_month = MONTH(CURDATE() - INTERVAL 1 MONTH);
    SET v_prev_year = YEAR(CURDATE() - INTERVAL 1 MONTH);

    INSERT INTO monthly_kpis (metric_month, metric_year, total_revenue, active_customers, average_order_value, new_customers_count, calculated_at)
    SELECT 
        v_prev_month,
        v_prev_year,
        COALESCE(SUM(o.total_amount), 0.00),
        COUNT(DISTINCT o.customer_id),
        COALESCE(AVG(o.total_amount), 0.00),
        (
            SELECT COUNT(*) 
            FROM customers c 
            WHERE MONTH(c.created_at) = v_prev_month AND YEAR(c.created_at) = v_prev_year
        ),
        NOW()
    FROM orders o
    WHERE MONTH(o.order_date) = v_prev_month 
      AND YEAR(o.order_date) = v_prev_year
      AND o.status NOT IN ('Cancelled')
    ON DUPLICATE KEY UPDATE
        total_revenue = VALUES(total_revenue),
        active_customers = VALUES(active_customers),
        average_order_value = VALUES(average_order_value),
        new_customers_count = VALUES(new_customers_count),
        calculated_at = NOW();
END //

DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly //
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-09-28 03:30:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    TRUNCATE TABLE mat_category_summary;

    INSERT INTO mat_category_summary (category_id, category_name, total_products, total_stock, total_sales_revenue, refreshed_at)
    SELECT 
        c.category_id,
        c.name,
        COUNT(DISTINCT p.product_id),
        COALESCE(SUM(p.stock), 0),
        COALESCE(SUM(od.quantity * od.frozen_unit_price), 0.00),
        NOW()
    FROM categories c
    LEFT JOIN products p ON c.category_id = p.category_id
    LEFT JOIN order_details od ON p.product_id = od.product_id
    LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
    GROUP BY c.category_id, c.name;
END //

DROP EVENT IF EXISTS evt_log_database_size_weekly //
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-10-04 00:05:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO database_size_logs (database_name, size_mb, logged_at)
    SELECT 
        table_schema,
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2),
        NOW()
    FROM information_schema.tables
    WHERE table_schema = 'ecommerce_db'
    GROUP BY table_schema;
END //

DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly //
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS '2026-09-28 00:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO security_logs (username, event_type, event_details, ip_address, logged_at)
    SELECT 
        CONCAT('Customer ID: ', customer_id),
        'SUSPICIOUS_ORDER_VELOCITY',
        CONCAT('Rapid order frequency detected: ', COUNT(*), ' orders placed within the last 60 minutes.'),
        '127.0.0.1',
        NOW()
    FROM orders
    WHERE order_date >= (NOW() - INTERVAL 1 HOUR)
    GROUP BY customer_id
    HAVING COUNT(*) >= 3;
END //

DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly //
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-10-01 01:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_prev_month INT;
    DECLARE v_prev_year INT;

    SET v_prev_month = MONTH(CURDATE() - INTERVAL 1 MONTH);
    SET v_prev_year = YEAR(CURDATE() - INTERVAL 1 MONTH);

    INSERT INTO supplier_performance_reports (supplier_id, report_month, report_year, total_units_sold, total_sales_volume, generated_at)
    SELECT 
        s.supplier_id,
        v_prev_month,
        v_prev_year,
        COALESCE(SUM(od.quantity), 0),
        COALESCE(SUM(od.quantity * od.frozen_unit_price), 0.00),
        NOW()
    FROM suppliers s
    JOIN products p ON s.supplier_id = p.supplier_id
    LEFT JOIN order_details od ON p.product_id = od.product_id
    LEFT JOIN orders o ON od.order_id = o.order_id 
        AND MONTH(o.order_date) = v_prev_month 
        AND YEAR(o.order_date) = v_prev_year
        AND o.status NOT IN ('Cancelled')
    GROUP BY s.supplier_id;
END //

DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly //
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-10-04 03:00:00'
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM stock_alerts
    WHERE is_resolved = TRUE AND alert_date < (NOW() - INTERVAL 30 DAY);

    DELETE FROM customer_birthday_coupons
    WHERE is_redeemed = TRUE AND expiry_date < (CURDATE() - INTERVAL 60 DAY);
END //

DELIMITER ;
