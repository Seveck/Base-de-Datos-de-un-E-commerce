USE ecommerce_db;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_place_new_order //
CREATE PROCEDURE sp_place_new_order(
    IN p_customer_id INT,
    IN p_branch_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    OUT p_order_id INT
)
proc_label: BEGIN
    DECLARE v_current_price DECIMAL(10, 2);
    DECLARE v_current_stock INT;
    DECLARE v_shipping_cost DECIMAL(10, 2) DEFAULT 0.00;
    DECLARE v_product_weight DECIMAL(8, 3);
    DECLARE v_new_order_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order rejected: Quantity must be greater than zero.';
    END IF;

    SELECT price, stock, weight_kg 
    INTO v_current_price, v_current_stock, v_product_weight
    FROM products
    WHERE product_id = p_product_id AND is_active = TRUE;

    IF v_current_price IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order rejected: Product does not exist or is inactive.';
    END IF;

    IF v_current_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order rejected: Insufficient stock available.';
    END IF;

    SET v_shipping_cost = 5.00 + (v_product_weight * p_quantity * 2.50);

    START TRANSACTION;

        INSERT INTO orders (customer_id, branch_id, order_date, status, total_amount, shipping_cost)
        VALUES (p_customer_id, p_branch_id, NOW(), 'Pending Payment', (v_current_price * p_quantity) + v_shipping_cost, v_shipping_cost);

        SET v_new_order_id = LAST_INSERT_ID();
        SET p_order_id = v_new_order_id;

        INSERT INTO order_details (order_id, product_id, quantity, frozen_unit_price)
        VALUES (v_new_order_id, p_product_id, p_quantity, v_current_price);

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_add_new_product //
CREATE PROCEDURE sp_add_new_product(
    IN p_name VARCHAR(150),
    IN p_description TEXT,
    IN p_price DECIMAL(10, 2),
    IN p_cost DECIMAL(10, 2),
    IN p_stock INT,
    IN p_sku VARCHAR(60),
    IN p_weight_kg DECIMAL(8, 3),
    IN p_min_threshold INT,
    IN p_warehouse_location VARCHAR(50),
    IN p_category_id INT,
    IN p_supplier_id INT,
    OUT p_product_id INT
)
BEGIN
    IF p_price <= 0.00 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation error: Selling price must be greater than zero.';
    END IF;

    IF p_cost < 0.00 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation error: Cost cannot be negative.';
    END IF;

    IF p_stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation error: Initial stock cannot be negative.';
    END IF;

    INSERT INTO products (
        name, description, price, cost, stock, sku, weight_kg,
        min_threshold, warehouse_location, category_id, supplier_id, is_active
    ) VALUES (
        p_name, p_description, p_price, p_cost, p_stock, p_sku, p_weight_kg,
        COALESCE(p_min_threshold, 10), COALESCE(p_warehouse_location, 'Aisle 1 - Section A'),
        p_category_id, p_supplier_id, TRUE
    );

    SET p_product_id = LAST_INSERT_ID();
END //

DROP PROCEDURE IF EXISTS sp_update_customer_address //
CREATE PROCEDURE sp_update_customer_address(
    IN p_customer_id INT,
    IN p_new_address VARCHAR(255),
    IN p_new_city VARCHAR(100)
)
BEGIN
    DECLARE v_old_address VARCHAR(255);
    DECLARE v_old_city VARCHAR(100);

    SELECT shipping_address, city INTO v_old_address, v_old_city
    FROM customers
    WHERE customer_id = p_customer_id;

    IF v_old_address IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer record not found.';
    END IF;

    UPDATE customers
    SET shipping_address = p_new_address,
        city = p_new_city
    WHERE customer_id = p_customer_id;

    INSERT INTO customer_logs (customer_id, action, details, logged_at)
    VALUES (
        p_customer_id,
        'ADDRESS_UPDATED',
        CONCAT('Address changed from [', v_old_city, ': ', v_old_address, '] to [', p_new_city, ': ', p_new_address, ']'),
        NOW()
    );
END //

DROP PROCEDURE IF EXISTS sp_process_product_return //
CREATE PROCEDURE sp_process_product_return(
    IN p_order_id INT,
    IN p_product_id INT,
    IN p_return_quantity INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_purchased_quantity INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT quantity INTO v_purchased_quantity
    FROM order_details
    WHERE order_id = p_order_id AND product_id = p_product_id;

    IF v_purchased_quantity = 0 OR p_return_quantity > v_purchased_quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid return: Quantity exceeds original order purchase.';
    END IF;

    START TRANSACTION;
        UPDATE products
        SET stock = stock + p_return_quantity
        WHERE product_id = p_product_id;

        INSERT INTO customer_logs (customer_id, action, details, logged_at)
        SELECT 
            customer_id,
            'PRODUCT_RETURNED',
            CONCAT('Returned ', p_return_quantity, ' units of Product #', p_product_id, ' from Order #', p_order_id, '. Reason: ', p_reason),
            NOW()
        FROM orders
        WHERE order_id = p_order_id;
    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_get_customer_purchase_history //
CREATE PROCEDURE sp_get_customer_purchase_history(IN p_customer_id INT)
BEGIN
    SELECT 
        o.order_id,
        o.order_date,
        o.status,
        b.name AS branch_name,
        p.name AS product_name,
        od.quantity,
        od.frozen_unit_price,
        (od.quantity * od.frozen_unit_price) AS line_subtotal,
        o.shipping_cost,
        o.total_amount AS order_total
    FROM orders o
    JOIN branches b ON o.branch_id = b.branch_id
    JOIN order_details od ON o.order_id = od.order_id
    JOIN products p ON od.product_id = p.product_id
    WHERE o.customer_id = p_customer_id
    ORDER BY o.order_date DESC, od.order_detail_id ASC;
END //

DROP PROCEDURE IF EXISTS sp_adjust_stock_level //
CREATE PROCEDURE sp_adjust_stock_level(
    IN p_product_id INT,
    IN p_adjustment_qty INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_new_stock INT;

    SELECT stock INTO v_current_stock
    FROM products
    WHERE product_id = p_product_id;

    IF v_current_stock IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Product not found.';
    END IF;

    SET v_new_stock = v_current_stock + p_adjustment_qty;

    IF v_new_stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Adjustment error: Resulting inventory stock cannot be negative.';
    END IF;

    UPDATE products
    SET stock = v_new_stock
    WHERE product_id = p_product_id;

    INSERT INTO security_logs (username, event_type, event_details, ip_address, logged_at)
    VALUES (
        USER(),
        'MANUAL_STOCK_ADJUSTMENT',
        CONCAT('Product #', p_product_id, ' stock adjusted from ', v_current_stock, ' to ', v_new_stock, '. Reason: ', p_reason),
        '127.0.0.1',
        NOW()
    );
END //

DROP PROCEDURE IF EXISTS sp_safely_delete_customer //
CREATE PROCEDURE sp_safely_delete_customer(IN p_customer_id INT)
BEGIN
    DECLARE v_exists INT;

    SELECT COUNT(*) INTO v_exists
    FROM customers
    WHERE customer_id = p_customer_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer ID does not exist.';
    END IF;

    UPDATE customers
    SET first_name = 'Anonymized',
        last_name = 'Customer',
        email = CONCAT('anonymized_', p_customer_id, '@gdpr.removed'),
        password_hash = 'REDACTED_ACCOUNT_DISABLED',
        shipping_address = 'Address Permanently Redacted',
        city = 'Redacted',
        birth_date = '1970-01-01',
        is_active = FALSE
    WHERE customer_id = p_customer_id;

    INSERT INTO customer_logs (customer_id, action, details, logged_at)
    VALUES (
        p_customer_id,
        'ACCOUNT_ANONYMIZED',
        'Customer PII safely anonymized to preserve commercial transaction history.',
        NOW()
    );
END //

DROP PROCEDURE IF EXISTS sp_apply_discount_by_category //
CREATE PROCEDURE sp_apply_discount_by_category(
    IN p_category_id INT,
    IN p_discount_percentage DECIMAL(5, 2)
)
BEGIN
    IF p_discount_percentage <= 0 OR p_discount_percentage >= 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Discount percentage must be between 1 and 99.';
    END IF;

    UPDATE products
    SET price = ROUND(price * (1.00 - (p_discount_percentage / 100.00)), 2)
    WHERE category_id = p_category_id
      AND is_active = TRUE;
END //

DROP PROCEDURE IF EXISTS sp_generate_monthly_sales_report //
CREATE PROCEDURE sp_generate_monthly_sales_report(
    IN p_month INT,
    IN p_year INT
)
BEGIN
    SELECT 
        p_month AS report_month,
        p_year AS report_year,
        COUNT(DISTINCT o.order_id) AS total_orders_placed,
        COUNT(DISTINCT o.customer_id) AS unique_purchasing_customers,
        COALESCE(SUM(od.quantity), 0) AS total_items_sold,
        COALESCE(ROUND(SUM(od.quantity * od.frozen_unit_price), 2), 0.00) AS total_gross_sales,
        COALESCE(ROUND(AVG(o.total_amount), 2), 0.00) AS average_ticket_aov
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    WHERE MONTH(o.order_date) = p_month 
      AND YEAR(o.order_date) = p_year
      AND o.status NOT IN ('Cancelled');
END //

DROP PROCEDURE IF EXISTS sp_change_order_status //
CREATE PROCEDURE sp_change_order_status(
    IN p_order_id INT,
    IN p_new_status VARCHAR(50)
)
BEGIN
    DECLARE v_current_status VARCHAR(50);

    SELECT status INTO v_current_status
    FROM orders
    WHERE order_id = p_order_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order not found.';
    END IF;

    IF p_new_status NOT IN ('Pending Payment', 'Processing', 'Shipped', 'Delivered', 'Cancelled') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid order status value provided.';
    END IF;

    UPDATE orders
    SET status = p_new_status
    WHERE order_id = p_order_id;
END //

DROP PROCEDURE IF EXISTS sp_register_new_customer //
CREATE PROCEDURE sp_register_new_customer(
    IN p_first_name VARCHAR(100),
    IN p_last_name VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_password VARCHAR(255),
    IN p_shipping_address VARCHAR(255),
    IN p_city VARCHAR(100),
    IN p_birth_date DATE,
    IN p_referred_by_id INT,
    OUT p_customer_id INT
)
BEGIN
    DECLARE v_email_exists INT;

    SELECT COUNT(*) INTO v_email_exists
    FROM customers
    WHERE email = p_email;

    IF v_email_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Registration failed: Email address already registered.';
    END IF;

    IF CHAR_LENGTH(p_password) < 8 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Registration failed: Password must have at least 8 characters.';
    END IF;

    INSERT INTO customers (
        first_name, last_name, email, password_hash,
        shipping_address, city, birth_date, referred_by_id, is_active
    ) VALUES (
        p_first_name, p_last_name, p_email,
        SHA2(p_password, 256),
        p_shipping_address, p_city, p_birth_date, p_referred_by_id, TRUE
    );

    SET p_customer_id = LAST_INSERT_ID();
END //

DROP PROCEDURE IF EXISTS sp_get_full_product_details //
CREATE PROCEDURE sp_get_full_product_details(IN p_product_id INT)
BEGIN
    SELECT 
        p.product_id,
        p.name AS product_name,
        p.description,
        p.sku,
        p.price,
        p.cost,
        p.stock,
        p.weight_kg,
        p.warehouse_location,
        p.views_count,
        c.name AS category_name,
        s.company_name AS supplier_name,
        s.contact_email AS supplier_email,
        COUNT(pr.review_id) AS total_reviews,
        COALESCE(ROUND(AVG(pr.rating), 1), 0.0) AS average_rating
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    JOIN suppliers s ON p.supplier_id = s.supplier_id
    LEFT JOIN product_reviews pr ON p.product_id = pr.product_id
    WHERE p.product_id = p_product_id
    GROUP BY p.product_id, c.name, s.company_name, s.contact_email;
END //

DROP PROCEDURE IF EXISTS sp_merge_customer_accounts //
CREATE PROCEDURE sp_merge_customer_accounts(
    IN p_source_customer_id INT,
    IN p_target_customer_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_source_customer_id = p_target_customer_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Merge error: Source and target customer IDs must differ.';
    END IF;

    START TRANSACTION;
        UPDATE orders
        SET customer_id = p_target_customer_id
        WHERE customer_id = p_source_customer_id;

        UPDATE product_reviews
        SET customer_id = p_target_customer_id
        WHERE customer_id = p_source_customer_id;

        UPDATE shopping_carts
        SET customer_id = p_target_customer_id
        WHERE customer_id = p_source_customer_id;

        UPDATE customers
        SET is_active = FALSE,
            email = CONCAT('merged_into_', p_target_customer_id, '_', email)
        WHERE customer_id = p_source_customer_id;

        UPDATE customers
        SET total_spent = (
            SELECT COALESCE(SUM(total_amount), 0.00)
            FROM orders
            WHERE customer_id = p_target_customer_id AND status NOT IN ('Cancelled')
        )
        WHERE customer_id = p_target_customer_id;
    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_assign_product_to_supplier //
CREATE PROCEDURE sp_assign_product_to_supplier(
    IN p_product_id INT,
    IN p_supplier_id INT
)
BEGIN
    DECLARE v_supplier_exists INT;

    SELECT COUNT(*) INTO v_supplier_exists
    FROM suppliers
    WHERE supplier_id = p_supplier_id;

    IF v_supplier_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assignment failed: Specified supplier ID does not exist.';
    END IF;

    UPDATE products
    SET supplier_id = p_supplier_id
    WHERE product_id = p_product_id;
END //

DROP PROCEDURE IF EXISTS sp_search_products //
CREATE PROCEDURE sp_search_products(
    IN p_search_term VARCHAR(100),
    IN p_category_id INT,
    IN p_min_price DECIMAL(10, 2),
    IN p_max_price DECIMAL(10, 2),
    IN p_in_stock_only BOOLEAN
)
BEGIN
    SELECT 
        p.product_id,
        p.name,
        c.name AS category_name,
        p.price,
        p.stock,
        p.sku,
        p.is_active
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    WHERE (p_search_term IS NULL OR p.name LIKE CONCAT('%', p_search_term, '%') OR p.description LIKE CONCAT('%', p_search_term, '%'))
      AND (p_category_id IS NULL OR p.category_id = p_category_id)
      AND (p_min_price IS NULL OR p.price >= p_min_price)
      AND (p_max_price IS NULL OR p.price <= p_max_price)
      AND (p_in_stock_only IS FALSE OR p.stock > 0)
      AND p.is_active = TRUE
    ORDER BY p.price ASC;
END //

DROP PROCEDURE IF EXISTS sp_get_admin_dashboard_kpis //
CREATE PROCEDURE sp_get_admin_dashboard_kpis()
BEGIN
    SELECT 
        (SELECT COALESCE(SUM(total_amount), 0.00) FROM orders WHERE DATE(order_date) = CURDATE() AND status NOT IN ('Cancelled')) AS today_sales_revenue,
        (SELECT COUNT(*) FROM orders WHERE DATE(order_date) = CURDATE() AND status NOT IN ('Cancelled')) AS today_orders_count,
        (SELECT COUNT(*) FROM orders WHERE status = 'Pending Payment') AS pending_payment_orders,
        (SELECT COUNT(*) FROM products WHERE stock <= min_threshold AND is_active = TRUE) AS products_below_threshold,
        (SELECT COUNT(*) FROM customers WHERE created_at >= (NOW() - INTERVAL 7 DAY)) AS new_customers_last_7_days,
        (SELECT COUNT(*) FROM shopping_carts WHERE is_abandoned = TRUE) AS abandoned_carts_count;
END //

DROP PROCEDURE IF EXISTS sp_process_payment //
CREATE PROCEDURE sp_process_payment(
    IN p_order_id INT,
    IN p_payment_method VARCHAR(50),
    OUT p_payment_status VARCHAR(50)
)
BEGIN
    DECLARE v_current_status VARCHAR(50);

    SELECT status INTO v_current_status
    FROM orders
    WHERE order_id = p_order_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order not found.';
    END IF;

    IF v_current_status <> 'Pending Payment' THEN
        SET p_payment_status = 'PAYMENT_ALREADY_SETTLED';
    ELSE
        UPDATE orders
        SET status = 'Processing'
        WHERE order_id = p_order_id;

        INSERT INTO customer_logs (customer_id, action, details, logged_at)
        SELECT 
            customer_id,
            'PAYMENT_CAPTURED',
            CONCAT('Payment of $', total_amount, ' captured successfully via ', p_payment_method, ' for Order #', p_order_id),
            NOW()
        FROM orders
        WHERE order_id = p_order_id;

        SET p_payment_status = 'PAYMENT_SUCCESSFUL';
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_add_product_review //
CREATE PROCEDURE sp_add_product_review(
    IN p_product_id INT,
    IN p_customer_id INT,
    IN p_rating INT,
    IN p_comment TEXT
)
BEGIN
    DECLARE v_has_purchased INT;

    IF p_rating < 1 OR p_rating > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Review rejected: Rating must be between 1 and 5 stars.';
    END IF;

    SELECT COUNT(*) INTO v_has_purchased
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    WHERE o.customer_id = p_customer_id
      AND od.product_id = p_product_id
      AND o.status IN ('Delivered', 'Shipped');

    IF v_has_purchased = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Review rejected: Only verified purchasers can review this product.';
    END IF;

    INSERT INTO product_reviews (product_id, customer_id, rating, comment, created_at)
    VALUES (p_product_id, p_customer_id, p_rating, p_comment, NOW());
END //

DROP PROCEDURE IF EXISTS sp_get_related_products //
CREATE PROCEDURE sp_get_related_products(
    IN p_product_id INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        p.product_id,
        p.name AS recommended_product_name,
        c.name AS category_name,
        p.price,
        COUNT(*) AS co_purchase_frequency
    FROM order_details od1
    JOIN order_details od2 
        ON od1.order_id = od2.order_id 
       AND od1.product_id <> od2.product_id
    JOIN products p ON od2.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    JOIN orders o ON od1.order_id = o.order_id
    WHERE od1.product_id = p_product_id
      AND o.status NOT IN ('Cancelled')
      AND p.is_active = TRUE
    GROUP BY p.product_id, p.name, c.name, p.price
    ORDER BY co_purchase_frequency DESC
    LIMIT p_limit;
END //

DROP PROCEDURE IF EXISTS sp_move_products_between_categories //
CREATE PROCEDURE sp_move_products_between_categories(
    IN p_from_category_id INT,
    IN p_to_category_id INT
)
BEGIN
    DECLARE v_to_exists INT;

    SELECT COUNT(*) INTO v_to_exists
    FROM categories
    WHERE category_id = p_to_category_id;

    IF v_to_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Target category does not exist.';
    END IF;

    START TRANSACTION;
        UPDATE products
        SET category_id = p_to_category_id
        WHERE category_id = p_from_category_id;

        UPDATE categories
        SET products_count = (SELECT COUNT(*) FROM products WHERE category_id = p_from_category_id)
        WHERE category_id = p_from_category_id;

        UPDATE categories
        SET products_count = (SELECT COUNT(*) FROM products WHERE category_id = p_to_category_id)
        WHERE category_id = p_to_category_id;
    COMMIT;
END //

DELIMITER ;
