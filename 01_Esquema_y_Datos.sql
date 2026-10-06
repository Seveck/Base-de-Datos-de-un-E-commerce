DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ecommerce_db;

CREATE TABLE branches (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(30) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NULL,
    products_count INT NOT NULL DEFAULT 0,
    CONSTRAINT chk_categories_products_count CHECK (products_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(150) NOT NULL,
    contact_email VARCHAR(150) NOT NULL UNIQUE,
    contact_phone VARCHAR(50) NULL,
    address VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT NULL,
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    sku VARCHAR(60) NOT NULL UNIQUE,
    weight_kg DECIMAL(8, 3) NOT NULL DEFAULT 0.500,
    min_threshold INT NOT NULL DEFAULT 10,
    warehouse_location VARCHAR(50) NOT NULL DEFAULT 'Aisle A - Section 1',
    views_count INT NOT NULL DEFAULT 0,
    category_id INT NULL,
    supplier_id INT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_products_price CHECK (price > 0),
    CONSTRAINT chk_products_cost CHECK (cost >= 0),
    CONSTRAINT chk_products_stock CHECK (stock >= 0),
    CONSTRAINT chk_products_weight CHECK (weight_kg >= 0),
    CONSTRAINT chk_products_min_threshold CHECK (min_threshold >= 0),
    CONSTRAINT chk_products_views_count CHECK (views_count >= 0),
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_products_supplier FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    shipping_address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL DEFAULT 'New York',
    birth_date DATE NOT NULL,
    total_spent DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    last_order_date DATETIME NULL,
    loyalty_tier ENUM('Bronze', 'Silver', 'Gold', 'Platinum') NOT NULL DEFAULT 'Bronze',
    referred_by_id INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_customers_total_spent CHECK (total_spent >= 0),
    CONSTRAINT fk_customers_referred_by FOREIGN KEY (referred_by_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending Payment', 'Processing', 'Shipped', 'Delivered', 'Cancelled') NOT NULL DEFAULT 'Pending Payment',
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    shipping_cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_orders_total_amount CHECK (total_amount >= 0),
    CONSTRAINT chk_orders_shipping_cost CHECK (shipping_cost >= 0),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orders_branch FOREIGN KEY (branch_id)
        REFERENCES branches(branch_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE order_details (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    frozen_unit_price DECIMAL(10, 2) NOT NULL,
    CONSTRAINT chk_order_details_quantity CHECK (quantity > 0),
    CONSTRAINT chk_order_details_frozen_price CHECK (frozen_unit_price > 0),
    CONSTRAINT fk_order_details_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_order_details_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE promotions (
    promotion_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    discount_percentage DECIMAL(5, 2) NOT NULL,
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_promotions_discount CHECK (discount_percentage BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE shopping_carts (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_abandoned BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_shopping_carts_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_cart_items_quantity CHECK (quantity > 0),
    CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id)
        REFERENCES shopping_carts(cart_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE product_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    rating INT NOT NULL,
    comment TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_product_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT fk_reviews_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE stock_alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    current_stock INT NOT NULL,
    min_threshold INT NOT NULL,
    alert_message VARCHAR(255) NOT NULL,
    alert_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_stock_alerts_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE price_change_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    old_price DECIMAL(10, 2) NOT NULL,
    new_price DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    CONSTRAINT fk_price_logs_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE customer_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_logs_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE order_status_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    old_status VARCHAR(50) NOT NULL,
    new_status VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    CONSTRAINT fk_status_logs_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_returns (
    return_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    returned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_product_returns_qty CHECK (quantity > 0),
    CONSTRAINT fk_product_returns_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_product_returns_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

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
) ENGINE=InnoDB;

CREATE TABLE security_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_details TEXT NULL,
    ip_address VARCHAR(50) NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE archived_orders (
    archived_order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE archived_order_details (
    archived_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    archived_order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    frozen_unit_price DECIMAL(10, 2) NOT NULL,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_archived_details_order FOREIGN KEY (archived_order_id)
        REFERENCES archived_orders(archived_order_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE weekly_sales_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    report_year INT NOT NULL,
    report_week INT NOT NULL,
    total_orders INT NOT NULL,
    total_revenue DECIMAL(14, 2) NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_weekly_sales (report_year, report_week)
) ENGINE=InnoDB;

CREATE TABLE daily_sales_summary (
    summary_id INT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL UNIQUE,
    total_orders INT NOT NULL,
    total_sales DECIMAL(14, 2) NOT NULL,
    total_cost DECIMAL(14, 2) NOT NULL,
    total_profit DECIMAL(14, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE monthly_kpis (
    kpi_id INT AUTO_INCREMENT PRIMARY KEY,
    metric_month INT NOT NULL,
    metric_year INT NOT NULL,
    total_revenue DECIMAL(14, 2) NOT NULL,
    active_customers INT NOT NULL,
    average_order_value DECIMAL(10, 2) NOT NULL,
    new_customers_count INT NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_monthly_kpis (metric_year, metric_month)
) ENGINE=InnoDB;

CREATE TABLE supplier_performance_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    report_month INT NOT NULL,
    report_year INT NOT NULL,
    total_units_sold INT NOT NULL,
    total_sales_volume DECIMAL(14, 2) NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_supplier_reports_supplier FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE reorder_list (
    reorder_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    current_stock INT NOT NULL,
    min_threshold INT NOT NULL,
    suggested_order_qty INT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reorder_list_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE customer_birthday_coupons (
    coupon_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    coupon_code VARCHAR(50) NOT NULL UNIQUE,
    issued_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    is_redeemed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_birthday_coupons_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE database_size_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    database_name VARCHAR(100) NOT NULL,
    size_mb DECIMAL(10, 2) NOT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT INTO branches (branch_id, name, city, state, address, phone) VALUES
(1, 'Manhattan Flagship', 'New York', 'NY', '500 5th Avenue, New York, NY 10110', '+1-212-555-0101'),
(2, 'Downtown Los Angeles', 'Los Angeles', 'CA', '700 S Flower St, Los Angeles, CA 90017', '+1-213-555-0102'),
(3, 'Chicago Loop Hub', 'Chicago', 'IL', '100 N LaSalle St, Chicago, IL 60602', '+1-312-555-0103'),
(4, 'Miami Brickell Center', 'Miami', 'FL', '800 Brickell Ave, Miami, FL 33131', '+1-305-555-0104'),
(5, 'Houston Galleria', 'Houston', 'TX', '5085 Westheimer Rd, Houston, TX 77056', '+1-713-555-0105');

INSERT INTO categories (category_id, name, description, products_count) VALUES
(1, 'Laptops & Computers', 'High performance portable and desktop workstations', 0),
(2, 'Smartphones & Accessories', 'Mobile devices, cases, screen protectors and chargers', 0),
(3, 'Audio & Headphones', 'Studio monitors, noise-canceling headphones and earbuds', 0),
(4, 'Gaming & Consoles', 'Next-gen gaming systems, controllers and peripherals', 0),
(5, 'Wearables & Smartwatches', 'Fitness trackers, smartwatches and smart bands', 0),
(6, 'Cameras & Photography', 'DSLR, mirrorless cameras, lenses and gimbals', 0),
(7, 'Smart Home & IoT', 'Automated lighting, smart plugs, speakers and security', 0),
(8, 'General', 'Default category for uncategorized commercial items', 0);

INSERT INTO suppliers (supplier_id, company_name, contact_email, contact_phone, address) VALUES
(1, 'TechWorld Distributing Inc.', 'sales@techworlddist.com', '+1-800-555-1001', '100 Silicon Way, San Jose, CA 95134'),
(2, 'Global Silicon Supplies', 'procurement@globalsilicon.com', '+1-800-555-1002', '450 Microchip Blvd, Austin, TX 78701'),
(3, 'Apex Electronics Corp', 'b2b@apexelectronics.com', '+1-800-555-1003', '12 Industrial Pkwy, Cleveland, OH 44135'),
(4, 'Nexus Gadgets Logistics', 'orders@nexusgadgets.com', '+1-800-555-1004', '88 Logistics Drive, Seattle, WA 98101'),
(5, 'Horizon Sound & Vision', 'support@horizonsound.com', '+1-800-555-1005', '77 Acoustic Way, Nashville, TN 37203'),
(6, 'Quantum Hardware Imports', 'contact@quantumhardware.com', '+1-800-555-1006', '300 Harbor Blvd, Long Beach, CA 90802'),
(7, 'Velocity Gaming Supply', 'partners@velocitygaming.com', '+1-800-555-1007', '150 Arcade St, Atlanta, GA 30303'),
(8, 'Omnitech Devices Group', 'info@omnitechgroup.com', '+1-800-555-1008', '50 Innovation Way, Boston, MA 02110');

INSERT INTO products (product_id, name, description, price, cost, stock, sku, weight_kg, min_threshold, warehouse_location, views_count, category_id, supplier_id, is_active) VALUES
(1, 'AeroBook Pro 15', '15.6 inch Intel i9 32GB RAM 1TB SSD Ultra-thin Laptop', 1899.99, 1350.00, 45, 'SKU-LAP-001', 1.850, 10, 'Aisle 1 - Bin A1', 1250, 1, 1, TRUE),
(2, 'AeroBook Air 13', '13.3 inch M3 Chip 16GB RAM 512GB SSD Lightweight Laptop', 1199.99, 820.00, 60, 'SKU-LAP-002', 1.240, 15, 'Aisle 1 - Bin A2', 1800, 1, 1, TRUE),
(3, 'Titan Gaming Desktop X', 'Liquid-cooled RTX 4080 64GB DDR5 2TB NVMe Gaming PC', 2699.99, 1950.00, 18, 'SKU-LAP-003', 14.500, 5, 'Aisle 1 - Bin B1', 950, 1, 2, TRUE),
(4, 'NovaPhone 15 Pro', '6.7 inch OLED 256GB Titanium Frame Flagship Smartphone', 1099.99, 740.00, 85, 'SKU-PHN-001', 0.220, 20, 'Aisle 2 - Bin A1', 3400, 2, 4, TRUE),
(5, 'NovaPhone 15 Standard', '6.1 inch OLED 128GB High Performance Smartphone', 799.99, 520.00, 70, 'SKU-PHN-002', 0.180, 15, 'Aisle 2 - Bin A2', 2900, 2, 4, TRUE),
(6, 'UltraShield Armor Case', 'Military-grade drop protection shockproof case', 39.99, 8.50, 250, 'SKU-ACC-001', 0.080, 40, 'Aisle 2 - Bin C1', 450, 2, 3, TRUE),
(7, 'FastCharge 65W GaN Charger', 'Compact dual USB-C rapid charging power adapter', 49.99, 14.00, 180, 'SKU-ACC-002', 0.120, 30, 'Aisle 2 - Bin C2', 680, 2, 3, TRUE),
(8, 'SoundWave Elite ANC Headphones', 'Over-ear active noise canceling wireless headphones with 40h battery', 299.99, 160.00, 55, 'SKU-AUD-001', 0.290, 12, 'Aisle 3 - Bin A1', 1400, 3, 5, TRUE),
(9, 'SoundPods Pro Wireless Earbuds', 'Spatial audio wireless earbuds with wireless charging case', 179.99, 95.00, 110, 'SKU-AUD-002', 0.055, 25, 'Aisle 3 - Bin A2', 2200, 3, 5, TRUE),
(10, 'SoundBar Studio 360', 'Dolby Atmos home theater soundbar with wireless subwoofer', 449.99, 280.00, 22, 'SKU-AUD-003', 6.800, 8, 'Aisle 3 - Bin B1', 820, 3, 5, TRUE),
(11, 'Vortex Station 5 Console', 'Next-generation 4K 120Hz console with 1TB SSD', 499.99, 390.00, 30, 'SKU-GAM-001', 4.500, 10, 'Aisle 4 - Bin A1', 4100, 4, 7, TRUE),
(12, 'Vortex Pro Wireless Controller', 'Haptic feedback wireless controller with custom triggers', 69.99, 32.00, 95, 'SKU-GAM-002', 0.280, 20, 'Aisle 4 - Bin A2', 1150, 4, 7, TRUE),
(13, 'Vortex Gaming Headset 7.1', 'Surround sound RGB gaming headset with detachable boom mic', 99.99, 45.00, 65, 'SKU-GAM-003', 0.350, 15, 'Aisle 4 - Bin B1', 890, 4, 7, TRUE),
(14, 'Pulse Chrono Smartwatch', 'AMOLED display smartwatch with heart rate, ECG and GPS', 249.99, 130.00, 40, 'SKU-WCH-001', 0.065, 10, 'Aisle 5 - Bin A1', 1600, 5, 8, TRUE),
(15, 'Pulse FitBand 4', 'Waterproof fitness tracker with 14-day battery life and sleep tracking', 79.99, 35.00, 120, 'SKU-WCH-002', 0.030, 25, 'Aisle 5 - Bin A2', 980, 5, 8, TRUE),
(16, 'LumixVision 4K Mirrorless Camera', 'Full-frame 33MP 4K60p video mirrorless camera body', 1799.99, 1250.00, 14, 'SKU-CAM-001', 0.720, 5, 'Aisle 6 - Bin A1', 1350, 6, 6, TRUE),
(17, 'CineLens 24-70mm f/2.8', 'Professional standard zoom lens with optical stabilization', 1099.99, 780.00, 16, 'SKU-CAM-002', 0.890, 5, 'Aisle 6 - Bin A2', 740, 6, 6, TRUE),
(18, 'ProGimbal 3-Axis Stabilizer', 'Handheld handheld gimbal stabilizer for mirrorless cameras and phones', 299.99, 180.00, 28, 'SKU-CAM-003', 1.100, 8, 'Aisle 6 - Bin B1', 610, 6, 6, TRUE),
(19, 'SmartHub Display 10', '10 inch HD smart display with voice assistant and camera', 149.99, 85.00, 48, 'SKU-IOT-001', 1.150, 10, 'Aisle 7 - Bin A1', 770, 7, 3, TRUE),
(20, 'SmartGlow RGB Bulb 4-Pack', 'Matter compatible smart Wi-Fi LED color changing light bulbs', 44.99, 16.00, 140, 'SKU-IOT-002', 0.320, 20, 'Aisle 7 - Bin A2', 530, 7, 3, TRUE),
(21, 'SmartLock Ultra Pro', 'Biometric fingerprint keyless smart deadbolt lock with Wi-Fi', 219.99, 120.00, 24, 'SKU-IOT-003', 1.450, 8, 'Aisle 7 - Bin B1', 890, 7, 3, TRUE),
(22, 'ErgoClick Wireless Mouse', 'Ergonomic vertical wireless mouse with silent clicks', 59.99, 22.00, 80, 'SKU-ACC-003', 0.130, 15, 'Aisle 1 - Bin C1', 620, 1, 2, TRUE),
(23, 'MechKeys Pro Mechanical Keyboard', 'RGB hot-swappable mechanical keyboard with linear switches', 129.99, 60.00, 50, 'SKU-ACC-004', 0.980, 12, 'Aisle 1 - Bin C2', 1100, 1, 2, TRUE),
(24, 'UltraView 34 Curved Monitor', '34 inch WQHD 165Hz Ultrawide HDR curved productivity and gaming monitor', 549.99, 360.00, 20, 'SKU-LAP-004', 8.200, 6, 'Aisle 1 - Bin B2', 1650, 1, 1, TRUE),
(25, 'USB-C Multiport Hub 7-in-1', 'Aluminum dongle with 4K HDMI, 100W PD, SD card reader and USB 3.0', 39.99, 12.00, 210, 'SKU-ACC-005', 0.095, 35, 'Aisle 1 - Bin C3', 420, 1, 2, TRUE),
(26, 'Vintage Film Camera Strap', 'Handmade genuine leather camera neck strap', 24.99, 7.00, 4, 'SKU-CAM-004', 0.110, 15, 'Aisle 6 - Bin C1', 95, 6, 6, TRUE),
(27, 'Micro USB Legacy Cable 2m', 'Braided high durability 2 meter micro-USB charging cable', 9.99, 2.10, 3, 'SKU-ACC-006', 0.050, 20, 'Aisle 2 - Bin D1', 60, 2, 3, TRUE),
(28, 'Stylus Pen Active Touch', 'Universal precision active stylus pen for touchscreens', 34.99, 11.00, 5, 'SKU-ACC-007', 0.025, 15, 'Aisle 2 - Bin D2', 110, 2, 3, TRUE),
(29, 'Retro Handheld Mini Console', '8-bit retro gaming console with 500 built-in games', 29.99, 9.50, 2, 'SKU-GAM-004', 0.200, 10, 'Aisle 4 - Bin C1', 85, 4, 7, TRUE),
(30, 'Wireless Charging Stand 15W', 'Fast wireless qi charging pad stand for phone and earbuds', 29.99, 9.00, 130, 'SKU-ACC-008', 0.160, 20, 'Aisle 2 - Bin C3', 840, 2, 4, TRUE);

UPDATE categories c
SET products_count = (SELECT COUNT(*) FROM products p WHERE p.category_id = c.category_id);

INSERT INTO customers (customer_id, first_name, last_name, email, password_hash, shipping_address, city, birth_date, total_spent, last_order_date, loyalty_tier, referred_by_id, is_active, created_at) VALUES
(1, 'Alexander', 'Wright', 'alex.wright@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '124 West 79th St, Apt 4B', 'New York', '1988-04-12', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-01-10 10:15:00'),
(2, 'Sophia', 'Martinez', 'sophia.m@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '452 Ocean Drive, Unit 12', 'Miami', '1992-09-28', 0.00, NULL, 'Bronze', 1, TRUE, '2025-01-18 14:22:00'),
(3, 'Marcus', 'Chen', 'marcus.chen@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '789 Sunset Blvd, Suite 200', 'Los Angeles', '1985-11-03', 0.00, NULL, 'Bronze', 1, TRUE, '2025-02-05 09:30:00'),
(4, 'Emily', 'Johnson', 'emily.johnson@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '312 Michigan Ave, Apt 18A', 'Chicago', '1995-03-15', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-02-14 16:45:00'),
(5, 'David', 'Miller', 'david.miller@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '540 Post Oak Blvd', 'Houston', '1980-07-22', 0.00, NULL, 'Bronze', 3, TRUE, '2025-03-01 11:10:00'),
(6, 'Olivia', 'Davis', 'olivia.d@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '654 Broadway St, Apt 9C', 'New York', '1998-05-19', 0.00, NULL, 'Bronze', 2, TRUE, '2025-03-20 13:05:00'),
(7, 'Lucas', 'Taylor', 'lucas.taylor@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '210 Wilshire Blvd', 'Los Angeles', '1990-12-11', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-04-12 18:20:00'),
(8, 'Isabella', 'Anderson', 'isabella.a@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '88 Biscayne Blvd, Penthouse 3', 'Miami', '1994-08-08', 0.00, NULL, 'Bronze', 4, TRUE, '2025-04-28 10:40:00'),
(9, 'Benjamin', 'Thomas', 'benjamin.t@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '1020 State St, Floor 4', 'Chicago', '1983-02-17', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-05-15 15:55:00'),
(10, 'Mia', 'Jackson', 'mia.jackson@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '770 Westheimer Rd, Apt 14', 'Houston', '1996-10-30', 0.00, NULL, 'Bronze', 5, TRUE, '2025-06-02 12:15:00'),
(11, 'Ethan', 'White', 'ethan.white@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '350 Fifth Ave, Floor 22', 'New York', '1991-01-25', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-07-09 09:40:00'),
(12, 'Charlotte', 'Harris', 'charlotte.h@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '920 Santa Monica Blvd', 'Los Angeles', '1993-06-14', 0.00, NULL, 'Bronze', 7, TRUE, '2025-08-14 17:30:00'),
(13, 'Daniel', 'Martin', 'daniel.martin@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '401 N Michigan Ave', 'Chicago', '1987-03-09', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-09-01 11:25:00'),
(14, 'Amelia', 'Thompson', 'amelia.t@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '1500 Collins Ave, Apt 5', 'Miami', '1999-12-05', 0.00, NULL, 'Bronze', 8, TRUE, '2025-10-10 14:50:00'),
(15, 'Henry', 'Garcia', 'henry.garcia@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '2300 Main St, Suite 100', 'Houston', '1982-08-20', 0.00, NULL, 'Bronze', NULL, TRUE, '2025-11-05 08:20:00'),
(16, 'Harper', 'Robinson', 'harper.r@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '48 Wall St, Apt 11', 'New York', '1997-04-02', 0.00, NULL, 'Bronze', 11, TRUE, '2025-12-01 16:10:00'),
(17, 'Sebastian', 'Clark', 'sebastian.c@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '1100 Westwood Blvd', 'Los Angeles', '1989-10-18', 0.00, NULL, 'Bronze', NULL, TRUE, '2026-01-12 10:00:00'),
(18, 'Evelyn', 'Rodriguez', 'evelyn.rod@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '300 S Wacker Dr', 'Chicago', '1994-07-04', 0.00, NULL, 'Bronze', 13, TRUE, '2026-02-01 13:45:00'),
(19, 'James', 'Lewis', 'james.lewis@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '600 Washington Ave', 'Miami', '1986-05-23', 0.00, NULL, 'Bronze', NULL, TRUE, '2026-03-01 09:15:00'),
(20, 'Luna', 'Walker', 'luna.walker@email.com', '$2b$12$e8Y5N89.2k3A1B2C3D4E5uF6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U', '1800 Post Oak Blvd', 'Houston', '2001-09-12', 0.00, NULL, 'Bronze', 15, TRUE, '2026-03-15 15:30:00');

INSERT INTO orders (order_id, customer_id, branch_id, order_date, status, total_amount, shipping_cost) VALUES
(1,  1, 1, '2025-01-15 10:30:00', 'Delivered', 1949.98, 0.00),
(2,  2, 4, '2025-01-25 14:15:00', 'Delivered', 1149.98, 0.00),
(3,  3, 2, '2025-02-10 18:45:00', 'Delivered', 2749.98, 0.00),
(4,  1, 1, '2025-02-20 09:15:00', 'Delivered',  359.97, 9.99),
(5,  4, 3, '2025-03-05 12:20:00', 'Delivered',  849.97, 0.00),
(6,  5, 5, '2025-03-18 20:10:00', 'Delivered',  569.98, 0.00),
(7,  2, 4, '2025-04-02 11:35:00', 'Delivered',  389.98, 0.00),
(8,  6, 1, '2025-04-15 16:50:00', 'Delivered', 1239.98, 0.00),
(9,  7, 2, '2025-05-01 14:05:00', 'Delivered',  499.99, 0.00),
(10, 3, 2, '2025-05-18 19:25:00', 'Delivered', 1399.97, 0.00),
(11, 8, 4, '2025-06-04 10:40:00', 'Delivered', 2899.98, 0.00),
(12, 1, 1, '2025-06-22 17:15:00', 'Delivered',  189.98, 0.00),
(13, 9, 3, '2025-07-08 13:50:00', 'Delivered',  929.98, 0.00),
(14, 4, 3, '2025-07-25 15:30:00', 'Delivered',  249.99, 0.00),
(15, 10, 5, '2025-08-10 21:05:00', 'Delivered',  369.98, 0.00),
(16, 5, 5, '2025-08-28 11:15:00', 'Delivered', 1899.99, 0.00),
(17, 11, 1, '2025-09-05 14:40:00', 'Delivered', 1139.98, 0.00),
(18, 2, 4, '2025-09-20 18:10:00', 'Delivered',  449.99, 0.00),
(19, 12, 2, '2025-10-02 10:20:00', 'Delivered',  569.98, 0.00),
(20, 3, 2, '2025-10-18 16:35:00', 'Delivered',  679.98, 0.00),
(21, 13, 3, '2025-11-04 12:05:00', 'Delivered', 1949.98, 0.00),
(22, 6, 1, '2025-11-20 20:45:00', 'Delivered',  229.98, 0.00),
(23, 14, 4, '2025-12-02 15:10:00', 'Delivered', 1179.98, 0.00),
(24, 7, 2, '2025-12-15 19:00:00', 'Delivered',  169.98, 0.00),
(25, 15, 5, '2025-12-28 11:50:00', 'Delivered',  769.98, 0.00),
(26, 1, 1, '2026-01-08 14:25:00', 'Delivered', 2699.99, 0.00),
(27, 8, 4, '2026-01-20 18:30:00', 'Delivered',  349.98, 0.00),
(28, 16, 1, '2026-02-05 10:15:00', 'Delivered',  839.98, 0.00),
(29, 9, 3, '2026-02-18 13:40:00', 'Delivered',  549.99, 0.00),
(30, 2, 4, '2026-02-27 16:05:00', 'Delivered', 1099.99, 0.00),
(31, 17, 2, '2026-03-05 09:30:00', 'Shipped',   1899.99, 0.00),
(32, 10, 5, '2026-03-12 11:20:00', 'Shipped',    249.99, 0.00),
(33, 4, 3, '2026-03-18 15:45:00', 'Processing',  189.98, 0.00),
(34, 18, 3, '2026-03-22 17:10:00', 'Processing', 1139.98, 0.00),
(35, 19, 4, '2026-03-25 12:50:00', 'Pending Payment', 514.98, 14.99),
(36, 11, 1, '2026-03-26 14:35:00', 'Processing',  299.99, 0.00),
(37, 5, 5, '2026-03-26 19:15:00', 'Pending Payment', 679.98, 0.00),
(38, 12, 2, '2026-03-27 10:00:00', 'Delivered',   54.98, 4.99),
(39, 3, 2, '2026-03-27 13:20:00', 'Cancelled',   849.98, 0.00),
(40, 20, 5, '2026-03-27 18:00:00', 'Delivered',   179.99, 0.00);

INSERT INTO order_details (order_id, product_id, quantity, frozen_unit_price) VALUES
(1, 1, 1, 1899.99),
(1, 22, 1, 49.99),

(2, 4, 1, 1099.99),
(2, 7, 1, 49.99),

(3, 3, 1, 2699.99),
(3, 22, 1, 49.99),

(4, 8, 1, 299.99),
(4, 7, 1, 49.99),

(5, 5, 1, 759.99),
(5, 6, 1, 39.99),
(5, 7, 1, 49.99),

(6, 11, 1, 499.99),
(6, 12, 1, 69.99),

(7, 14, 1, 249.99),
(7, 23, 1, 139.99),

(8, 2, 1, 1199.99),
(8, 25, 1, 39.99),

(9, 11, 1, 499.99),

(10, 16, 1, 1354.98),
(10, 20, 1, 44.99),

(11, 16, 1, 1799.99),
(11, 17, 1, 1099.99),

(12, 23, 1, 129.99),
(12, 22, 1, 59.99),

(13, 5, 1, 799.99),
(13, 23, 1, 129.99),

(14, 14, 1, 249.99),

(15, 8, 1, 299.99),
(15, 12, 1, 69.99),

(16, 1, 1, 1899.99),

(17, 4, 1, 1099.99),
(17, 6, 1, 39.99),

(18, 10, 1, 449.99),

(19, 11, 1, 499.99),
(19, 12, 1, 69.99),

(20, 24, 1, 549.99),
(20, 23, 1, 129.99),

(21, 1, 1, 1899.99),
(21, 7, 1, 49.99),

(22, 21, 1, 219.99),
(22, 27, 1, 9.99),

(23, 4, 1, 1099.99),
(23, 15, 1, 79.99),

(24, 13, 1, 99.99),
(24, 12, 1, 69.99),

(25, 11, 1, 519.99),
(25, 14, 1, 249.99),

(26, 3, 1, 2699.99),

(27, 8, 1, 299.99),
(27, 7, 1, 49.99),

(28, 5, 1, 799.99),
(28, 6, 1, 39.99),

(29, 24, 1, 549.99),

(30, 4, 1, 1099.99),

(31, 1, 1, 1899.99),

(32, 14, 1, 249.99),

(33, 23, 1, 129.99),
(33, 22, 1, 59.99),

(34, 4, 1, 1099.99),
(34, 6, 1, 39.99),

(35, 11, 1, 499.99),

(36, 8, 1, 299.99),

(37, 24, 1, 549.99),
(37, 23, 1, 129.99),

(38, 7, 1, 49.99),

(39, 5, 1, 799.99),
(39, 7, 1, 49.99),

(40, 9, 1, 179.99);

UPDATE customers c
SET total_spent = COALESCE((
    SELECT SUM(o.total_amount)
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status NOT IN ('Cancelled')
), 0.00),
last_order_date = (
    SELECT MAX(o.order_date)
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status NOT IN ('Cancelled')
);

UPDATE customers
SET loyalty_tier = CASE
    WHEN total_spent >= 5000.00 THEN 'Platinum'
    WHEN total_spent >= 2500.00 THEN 'Gold'
    WHEN total_spent >= 1000.00 THEN 'Silver'
    ELSE 'Bronze'
END;

INSERT INTO promotions (promotion_id, code, name, discount_percentage, start_date, end_date, is_active) VALUES
(1, 'SUMMER2025', 'Summer Super Tech Savings', 15.00, '2025-06-01 00:00:00', '2025-08-31 23:59:59', FALSE),
(2, 'BLACKFRIDAY25', 'Black Friday Massive Discounts', 25.00, '2025-11-20 00:00:00', '2025-11-30 23:59:59', FALSE),
(3, 'NEWYEAR2026', 'New Year New Gadgets', 10.00, '2026-01-01 00:00:00', '2026-01-15 23:59:59', FALSE),
(4, 'SPRING2026', 'Spring Electronic Renewal', 12.00, '2026-03-01 00:00:00', '2026-04-30 23:59:59', TRUE),
(5, 'VIPEXCLUSIVE', 'Exclusive VIP Members Perks', 20.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE);

INSERT INTO shopping_carts (cart_id, customer_id, created_at, updated_at, is_abandoned) VALUES
(1, 1, '2026-03-27 10:00:00', '2026-03-27 10:15:00', FALSE),
(2, 6, '2026-03-20 11:00:00', '2026-03-20 11:30:00', TRUE),
(3, 8, '2026-03-18 14:00:00', '2026-03-18 14:45:00', TRUE),
(4, 15, '2026-03-15 09:30:00', '2026-03-15 10:00:00', TRUE),
(5, 19, '2026-03-27 15:00:00', '2026-03-27 15:20:00', FALSE);

INSERT INTO cart_items (cart_item_id, cart_id, product_id, quantity, added_at) VALUES
(1, 1, 24, 1, '2026-03-27 10:05:00'),
(2, 1, 23, 1, '2026-03-27 10:10:00'),
(3, 2, 11, 1, '2026-03-20 11:05:00'),
(4, 2, 12, 2, '2026-03-20 11:15:00'),
(5, 3, 4, 1, '2026-03-18 14:10:00'),
(6, 4, 16, 1, '2026-03-15 09:35:00'),
(7, 4, 17, 1, '2026-03-15 09:40:00'),
(8, 5, 8, 1, '2026-03-27 15:05:00');

INSERT INTO product_reviews (review_id, product_id, customer_id, rating, comment, created_at) VALUES
(1, 1, 1, 5, 'Unbelievable performance. The screen is gorgeous and battery easily lasts all day.', '2025-01-20 14:00:00'),
(2, 4, 2, 5, 'Best smartphone camera I have ever owned. Lightning fast and premium titanium feel.', '2025-02-01 11:30:00'),
(3, 3, 3, 5, 'Absolute beast of a machine. Plays every 4K title at maximum FPS without breaking a sweat.', '2025-02-15 19:10:00'),
(4, 8, 1, 4, 'Great noise cancellation, very comfortable for long flights. Audio is crisp.', '2025-03-01 09:45:00'),
(5, 11, 7, 5, 'The console is fast, silent, and the new controller haptics are game-changing.', '2025-05-10 16:20:00'),
(6, 16, 8, 5, 'Professional grade camera. Color science and dynamic range are stunning.', '2025-06-12 12:00:00'),
(7, 23, 2, 4, 'Tactile click feel is superb. Software could use a slight UI polish.', '2025-09-25 10:15:00'),
(8, 27, 6, 2, 'Cable works fine but feels a bit stiff compared to newer silicone cables.', '2025-11-25 17:00:00');

INSERT INTO stock_alerts (alert_id, product_id, current_stock, min_threshold, alert_message, alert_date, is_resolved) VALUES
(1, 26, 4, 15, 'CRITICAL: Stock for Vintage Film Camera Strap (4) is below safety threshold (15).', '2026-03-25 08:00:00', FALSE),
(2, 27, 3, 20, 'CRITICAL: Stock for Micro USB Legacy Cable 2m (3) is below safety threshold (20).', '2026-03-25 08:00:00', FALSE),
(3, 28, 5, 15, 'CRITICAL: Stock for Stylus Pen Active Touch (5) is below safety threshold (15).', '2026-03-25 08:00:00', FALSE),
(4, 29, 2, 10, 'CRITICAL: Stock for Retro Handheld Mini Console (2) is below safety threshold (10).', '2026-03-25 08:00:00', FALSE);
