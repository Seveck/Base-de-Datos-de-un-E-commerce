USE ecommerce_db;

DELIMITER //

DROP FUNCTION IF EXISTS fn_calculate_sale_total //
CREATE FUNCTION fn_calculate_sale_total(p_order_id INT)
RETURNS DECIMAL(12, 2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(quantity * frozen_unit_price), 0.00)
    INTO v_total
    FROM order_details
    WHERE order_id = p_order_id;

    RETURN v_total;
END //

DROP FUNCTION IF EXISTS fn_check_stock_availability //
CREATE FUNCTION fn_check_stock_availability(p_product_id INT, p_requested_quantity INT)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_current_stock INT DEFAULT 0;

    SELECT stock INTO v_current_stock
    FROM products
    WHERE product_id = p_product_id AND is_active = TRUE;

    IF v_current_stock IS NULL OR p_requested_quantity <= 0 THEN
        RETURN FALSE;
    END IF;

    RETURN v_current_stock >= p_requested_quantity;
END //

DROP FUNCTION IF EXISTS fn_get_product_price //
CREATE FUNCTION fn_get_product_price(p_product_id INT)
RETURNS DECIMAL(10, 2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_price DECIMAL(10, 2) DEFAULT 0.00;

    SELECT price INTO v_price
    FROM products
    WHERE product_id = p_product_id;

    RETURN COALESCE(v_price, 0.00);
END //

DROP FUNCTION IF EXISTS fn_calculate_customer_age //
CREATE FUNCTION fn_calculate_customer_age(p_customer_id INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_birth_date DATE;
    DECLARE v_age INT DEFAULT 0;

    SELECT birth_date INTO v_birth_date
    FROM customers
    WHERE customer_id = p_customer_id;

    IF v_birth_date IS NULL THEN
        RETURN 0;
    END IF;

    SET v_age = TIMESTAMPDIFF(YEAR, v_birth_date, CURDATE());
    RETURN v_age;
END //

DROP FUNCTION IF EXISTS fn_format_full_name //
CREATE FUNCTION fn_format_full_name(p_first_name VARCHAR(100), p_last_name VARCHAR(100))
RETURNS VARCHAR(210)
NO SQL
DETERMINISTIC
BEGIN
    DECLARE v_clean_first VARCHAR(100);
    DECLARE v_clean_last VARCHAR(100);

    SET v_clean_first = TRIM(COALESCE(p_first_name, ''));
    SET v_clean_last = TRIM(COALESCE(p_last_name, ''));

    IF v_clean_last = '' THEN
        RETURN v_clean_first;
    END IF;

    IF v_clean_first = '' THEN
        RETURN v_clean_last;
    END IF;

    RETURN CONCAT(v_clean_last, ', ', v_clean_first);
END //

DROP FUNCTION IF EXISTS fn_is_new_customer //
CREATE FUNCTION fn_is_new_customer(p_customer_id INT)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_first_order_date DATETIME;

    SELECT MIN(order_date) INTO v_first_order_date
    FROM orders
    WHERE customer_id = p_customer_id 
      AND status NOT IN ('Cancelled');

    IF v_first_order_date IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN v_first_order_date >= (NOW() - INTERVAL 30 DAY);
END //

DROP FUNCTION IF EXISTS fn_calculate_shipping_cost //
CREATE FUNCTION fn_calculate_shipping_cost(p_order_id INT)
RETURNS DECIMAL(10, 2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total_weight DECIMAL(10, 3) DEFAULT 0.000;
    DECLARE v_shipping_cost DECIMAL(10, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(od.quantity * p.weight_kg), 0.000)
    INTO v_total_weight
    FROM order_details od
    JOIN products p ON od.product_id = p.product_id
    WHERE od.order_id = p_order_id;

    IF v_total_weight <= 0 THEN
        RETURN 0.00;
    END IF;

    SET v_shipping_cost = 5.00 + (v_total_weight * 2.50);
    RETURN ROUND(v_shipping_cost, 2);
END //

DROP FUNCTION IF EXISTS fn_apply_discount //
CREATE FUNCTION fn_apply_discount(p_amount DECIMAL(12, 2), p_discount_percentage DECIMAL(5, 2))
RETURNS DECIMAL(12, 2)
NO SQL
DETERMINISTIC
BEGIN
    DECLARE v_discounted_amount DECIMAL(12, 2);

    IF p_amount <= 0 OR p_discount_percentage <= 0 THEN
        RETURN p_amount;
    END IF;

    IF p_discount_percentage >= 100.00 THEN
        RETURN 0.00;
    END IF;

    SET v_discounted_amount = p_amount * (1.00 - (p_discount_percentage / 100.00));
    RETURN ROUND(v_discounted_amount, 2);
END //

DROP FUNCTION IF EXISTS fn_get_last_purchase_date //
CREATE FUNCTION fn_get_last_purchase_date(p_customer_id INT)
RETURNS DATETIME
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_last_date DATETIME;

    SELECT MAX(order_date) INTO v_last_date
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('Cancelled');

    RETURN v_last_date;
END //

DROP FUNCTION IF EXISTS fn_validate_email_format //
CREATE FUNCTION fn_validate_email_format(p_email VARCHAR(255))
RETURNS BOOLEAN
NO SQL
DETERMINISTIC
BEGIN
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RETURN FALSE;
    END IF;

    IF p_email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END //

DROP FUNCTION IF EXISTS fn_get_category_name //
CREATE FUNCTION fn_get_category_name(p_product_id INT)
RETURNS VARCHAR(100)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_category_name VARCHAR(100) DEFAULT 'Uncategorized';

    SELECT c.name INTO v_category_name
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    WHERE p.product_id = p_product_id;

    RETURN COALESCE(v_category_name, 'Uncategorized');
END //

DROP FUNCTION IF EXISTS fn_count_customer_orders //
CREATE FUNCTION fn_count_customer_orders(p_customer_id INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_order_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_order_count
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('Cancelled');

    RETURN v_order_count;
END //

DROP FUNCTION IF EXISTS fn_days_since_last_purchase //
CREATE FUNCTION fn_days_since_last_purchase(p_customer_id INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_last_purchase DATETIME;

    SELECT MAX(order_date) INTO v_last_purchase
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('Cancelled');

    IF v_last_purchase IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN DATEDIFF(NOW(), v_last_purchase);
END //

DROP FUNCTION IF EXISTS fn_determine_loyalty_tier //
CREATE FUNCTION fn_determine_loyalty_tier(p_customer_id INT)
RETURNS VARCHAR(20)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total_spent DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(total_amount), 0.00) INTO v_total_spent
    FROM orders
    WHERE customer_id = p_customer_id
      AND status NOT IN ('Cancelled');

    IF v_total_spent >= 5000.00 THEN
        RETURN 'Platinum';
    ELSEIF v_total_spent >= 2500.00 THEN
        RETURN 'Gold';
    ELSEIF v_total_spent >= 1000.00 THEN
        RETURN 'Silver';
    ELSE
        RETURN 'Bronze';
    END IF;
END //

DROP FUNCTION IF EXISTS fn_generate_sku //
CREATE FUNCTION fn_generate_sku(p_product_name VARCHAR(150), p_category_id INT)
RETURNS VARCHAR(60)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_cat_code VARCHAR(10) DEFAULT 'GEN';
    DECLARE v_prod_code VARCHAR(10);
    DECLARE v_random_suffix VARCHAR(6);

    SELECT UPPER(SUBSTRING(REPLACE(name, ' ', ''), 1, 3)) INTO v_cat_code
    FROM categories
    WHERE category_id = p_category_id;

    SET v_cat_code = COALESCE(v_cat_code, 'GEN');
    SET v_prod_code = UPPER(SUBSTRING(REPLACE(p_product_name, ' ', ''), 1, 4));
    SET v_random_suffix = LPAD(FLOOR(RAND() * 9000 + 1000), 4, '0');

    RETURN CONCAT('SKU-', v_cat_code, '-', v_prod_code, '-', v_random_suffix);
END //

DROP FUNCTION IF EXISTS fn_calculate_vat //
CREATE FUNCTION fn_calculate_vat(p_amount DECIMAL(12, 2))
RETURNS DECIMAL(12, 2)
NO SQL
DETERMINISTIC
BEGIN
    IF p_amount <= 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(p_amount * 0.16, 2);
END //

DROP FUNCTION IF EXISTS fn_get_total_stock_by_category //
CREATE FUNCTION fn_get_total_stock_by_category(p_category_id INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total_stock INT DEFAULT 0;

    SELECT COALESCE(SUM(stock), 0) INTO v_total_stock
    FROM products
    WHERE category_id = p_category_id
      AND is_active = TRUE;

    RETURN v_total_stock;
END //

DROP FUNCTION IF EXISTS fn_estimate_delivery_date //
CREATE FUNCTION fn_estimate_delivery_date(p_order_id INT)
RETURNS DATE
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_order_date DATETIME;
    DECLARE v_city VARCHAR(100);
    DECLARE v_transit_days INT DEFAULT 5;

    SELECT o.order_date, c.city 
    INTO v_order_date, v_city
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_id = p_order_id;

    IF v_order_date IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_city IN ('New York', 'Jersey City') THEN
        SET v_transit_days = 2;
    ELSEIF v_city IN ('Los Angeles', 'Chicago', 'Miami', 'Houston') THEN
        SET v_transit_days = 3;
    ELSE
        SET v_transit_days = 5;
    END IF;

    RETURN DATE_ADD(DATE(v_order_date), INTERVAL v_transit_days DAY);
END //

DROP FUNCTION IF EXISTS fn_convert_currency //
CREATE FUNCTION fn_convert_currency(p_amount DECIMAL(12, 2), p_exchange_rate DECIMAL(10, 4))
RETURNS DECIMAL(12, 2)
NO SQL
DETERMINISTIC
BEGIN
    IF p_amount <= 0 OR p_exchange_rate <= 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(p_amount * p_exchange_rate, 2);
END //

DROP FUNCTION IF EXISTS fn_validate_password_complexity //
CREATE FUNCTION fn_validate_password_complexity(p_password VARCHAR(255))
RETURNS BOOLEAN
NO SQL
DETERMINISTIC
BEGIN
    IF p_password IS NULL OR CHAR_LENGTH(p_password) < 8 THEN
        RETURN FALSE;
    END IF;

    IF NOT (p_password REGEXP '[A-Z]') THEN
        RETURN FALSE;
    END IF;

    IF NOT (p_password REGEXP '[a-z]') THEN
        RETURN FALSE;
    END IF;

    IF NOT (p_password REGEXP '[0-9]') THEN
        RETURN FALSE;
    END IF;

    IF NOT (p_password REGEXP '[@#$%^&*!_+=\\-\\?\\.]') THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END //

DELIMITER ;
