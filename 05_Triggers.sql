USE ecommerce_db;

CREATE TABLE IF NOT EXISTS price_change_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    old_price DECIMAL(10, 2) NOT NULL,
    new_price DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) DEFAULT CURRENT_USER,
    CONSTRAINT fk_price_logs_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

DELIMITER //

DROP TRIGGER IF EXISTS trg_audit_price_change_after_update //
CREATE TRIGGER trg_audit_price_change_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO price_change_logs (product_id, old_price, new_price, changed_at, changed_by)
        VALUES (NEW.product_id, OLD.price, NEW.price, NOW(), USER());
    END IF;
END //

DROP TRIGGER IF EXISTS trg_check_stock_before_insert_order_detail //
CREATE TRIGGER trg_check_stock_before_insert_order_detail
BEFORE INSERT ON order_details
FOR EACH ROW
BEGIN
    DECLARE v_available_stock INT DEFAULT 0;

    SELECT stock INTO v_available_stock
    FROM products
    WHERE product_id = NEW.product_id;

    IF v_available_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Operation aborted: Insufficient product stock available.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_update_stock_after_insert_order_detail //
CREATE TRIGGER trg_update_stock_after_insert_order_detail
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;
END //

DROP TRIGGER IF EXISTS trg_prevent_delete_category_with_products //
CREATE TRIGGER trg_prevent_delete_category_with_products
BEFORE DELETE ON categories
FOR EACH ROW
BEGIN
    DECLARE v_product_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_product_count
    FROM products
    WHERE category_id = OLD.category_id;

    IF v_product_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity violation: Cannot delete category containing active products.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert //
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON customers
FOR EACH ROW
BEGIN
    INSERT INTO customer_logs (customer_id, action, details, logged_at)
    VALUES (
        NEW.customer_id,
        'NEW_CUSTOMER_REGISTERED',
        CONCAT('Customer account created for ', NEW.first_name, ' ', NEW.last_name, ' (', NEW.email, ') in city: ', NEW.city),
        NOW()
    );
END //

DROP TRIGGER IF EXISTS trg_update_customer_total_spent //
CREATE TRIGGER trg_update_customer_total_spent
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    DECLARE v_new_spent DECIMAL(12, 2) DEFAULT 0.00;

    IF OLD.total_amount <> NEW.total_amount OR OLD.status <> NEW.status THEN
        SELECT COALESCE(SUM(total_amount), 0.00) INTO v_new_spent
        FROM orders
        WHERE customer_id = NEW.customer_id
          AND status NOT IN ('Cancelled');

        UPDATE customers
        SET total_spent = v_new_spent,
            loyalty_tier = CASE 
                WHEN v_new_spent >= 5000.00 THEN 'Platinum'
                WHEN v_new_spent >= 2500.00 THEN 'Gold'
                WHEN v_new_spent >= 1000.00 THEN 'Silver'
                ELSE 'Bronze'
            END
        WHERE customer_id = NEW.customer_id;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_set_product_modification_date //
CREATE TRIGGER trg_set_product_modification_date
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    SET NEW.updated_at = NOW();
END //

DROP TRIGGER IF EXISTS trg_prevent_negative_stock //
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity constraint violation: Product inventory stock cannot be negative.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_capitalize_customer_name //
CREATE TRIGGER trg_capitalize_customer_name
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
    IF NEW.first_name IS NOT NULL AND CHAR_LENGTH(NEW.first_name) > 0 THEN
        SET NEW.first_name = CONCAT(UPPER(SUBSTRING(NEW.first_name, 1, 1)), LOWER(SUBSTRING(NEW.first_name, 2)));
    END IF;

    IF NEW.last_name IS NOT NULL AND CHAR_LENGTH(NEW.last_name) > 0 THEN
        SET NEW.last_name = CONCAT(UPPER(SUBSTRING(NEW.last_name, 1, 1)), LOWER(SUBSTRING(NEW.last_name, 2)));
    END IF;
END //

DROP TRIGGER IF EXISTS trg_recalculate_order_total_on_detail_change //
CREATE TRIGGER trg_recalculate_order_total_on_detail_change
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * frozen_unit_price), 0.00)
        FROM order_details
        WHERE order_id = NEW.order_id
    ) + shipping_cost
    WHERE order_id = NEW.order_id;
END //

DROP TRIGGER IF EXISTS trg_log_order_status_change //
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_status_logs (order_id, old_status, new_status, changed_at, changed_by)
        VALUES (NEW.order_id, OLD.status, NEW.status, NOW(), USER());
    END IF;
END //

DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less //
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    IF NEW.price <= 0.00 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation error: Product selling price must be strictly greater than zero.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock //
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.stock <= NEW.min_threshold AND OLD.stock > NEW.min_threshold THEN
        INSERT INTO stock_alerts (product_id, current_stock, min_threshold, alert_message, alert_date, is_resolved)
        VALUES (
            NEW.product_id,
            NEW.stock,
            NEW.min_threshold,
            CONCAT('LOW STOCK WARNING: ', NEW.name, ' has reached ', NEW.stock, ' units (Safety threshold: ', NEW.min_threshold, ').'),
            NOW(),
            FALSE
        );
    END IF;
END //

DROP TRIGGER IF EXISTS trg_archive_deleted_order //
CREATE TRIGGER trg_archive_deleted_order
BEFORE DELETE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO archived_orders (archived_order_id, customer_id, branch_id, order_date, status, total_amount, archived_at)
    VALUES (OLD.order_id, OLD.customer_id, OLD.branch_id, OLD.order_date, OLD.status, OLD.total_amount, NOW());

    INSERT INTO archived_order_details (archived_order_id, product_id, quantity, frozen_unit_price, archived_at)
    SELECT order_id, product_id, quantity, frozen_unit_price, NOW()
    FROM order_details
    WHERE order_id = OLD.order_id;
END //

DROP TRIGGER IF EXISTS trg_validate_customer_email_format //
CREATE TRIGGER trg_validate_customer_email_format
BEFORE INSERT ON customers
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation error: The provided customer email address format is invalid.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_update_customer_last_order_date //
CREATE TRIGGER trg_update_customer_last_order_date
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    UPDATE customers
    SET last_order_date = NEW.order_date
    WHERE customer_id = NEW.customer_id;
END //

DROP TRIGGER IF EXISTS trg_prevent_customer_self_referral //
CREATE TRIGGER trg_prevent_customer_self_referral
BEFORE UPDATE ON customers
FOR EACH ROW
BEGIN
    IF NEW.referred_by_id IS NOT NULL AND NEW.referred_by_id = NEW.customer_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Security policy violation: Customers cannot refer themselves in referral campaigns.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_log_permission_changes //
CREATE TRIGGER trg_log_permission_changes
AFTER INSERT ON user_branch_assignments
FOR EACH ROW
BEGIN
    INSERT INTO security_logs (username, event_type, event_details, ip_address, logged_at)
    VALUES (
        USER(),
        'USER_BRANCH_ASSIGNMENT_CREATED',
        CONCAT('User: ', NEW.username, ' was assigned to Branch ID: ', NEW.branch_id),
        '127.0.0.1',
        NOW()
    );
END //

DROP TRIGGER IF EXISTS trg_assign_default_category_on_null //
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    DECLARE v_default_cat_id INT;

    IF NEW.category_id IS NULL THEN
        SELECT category_id INTO v_default_cat_id
        FROM categories
        WHERE name = 'General'
        LIMIT 1;

        SET NEW.category_id = v_default_cat_id;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_update_product_count_in_category //
CREATE TRIGGER trg_update_product_count_in_category
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    IF NEW.category_id IS NOT NULL THEN
        UPDATE categories
        SET products_count = products_count + 1
        WHERE category_id = NEW.category_id;
    END IF;
END //

DELIMITER ;
