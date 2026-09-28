USE ecommerce_db;

-- 1. Top 10 Best-Selling Products by Revenue
SELECT 
    p.product_id,
    p.name AS product_name,
    c.name AS category_name,
    p.price AS current_price,
    SUM(od.quantity) AS total_units_sold,
    ROUND(SUM(od.quantity * od.frozen_unit_price), 2) AS total_revenue_generated
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN order_details od ON p.product_id = od.product_id
JOIN orders o ON od.order_id = o.order_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY p.product_id, p.name, c.name, p.price
ORDER BY total_revenue_generated DESC
LIMIT 10;

-- 2. Products with Low Sales (Bottom 10% of Sales)
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.name AS product_name,
        c.name AS category_name,
        p.stock AS current_stock,
        COALESCE(SUM(od.quantity), 0) AS total_units_sold,
        COALESCE(SUM(od.quantity * od.frozen_unit_price), 0.00) AS total_revenue
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN order_details od ON p.product_id = od.product_id
    LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
    GROUP BY p.product_id, p.name, c.name, p.stock
),
ranked_products AS (
    SELECT 
        product_id,
        product_name,
        category_name,
        current_stock,
        total_units_sold,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue ASC) AS sales_decile
    FROM product_sales
)
SELECT 
    product_id,
    product_name,
    category_name,
    current_stock,
    total_units_sold,
    ROUND(total_revenue, 2) AS total_revenue,
    sales_decile AS decile_rank_bottom_10_percent
FROM ranked_products
WHERE sales_decile = 1
ORDER BY total_revenue ASC;

-- 3. VIP Customers (Top 5 by Lifetime Value - LTV)
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.city,
    c.loyalty_tier,
    COUNT(DISTINCT o.order_id) AS total_completed_orders,
    ROUND(SUM(o.total_amount), 2) AS lifetime_value_ltv,
    ROUND(AVG(o.total_amount), 2) AS average_order_value_aov
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city, c.loyalty_tier
ORDER BY lifetime_value_ltv DESC
LIMIT 5;

-- 4. Monthly Sales Analysis
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(od.quantity) AS total_items_sold,
    ROUND(SUM(od.quantity * od.frozen_unit_price), 2) AS gross_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_order_value
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY sales_month ASC;

-- 5. Customer Growth (New Customers Registered by Quarter)
WITH quarterly_acquisitions AS (
    SELECT 
        YEAR(c.created_at) AS registration_year,
        QUARTER(c.created_at) AS registration_quarter,
        COUNT(c.customer_id) AS new_customers_count
    FROM customers c
    GROUP BY YEAR(c.created_at), QUARTER(c.created_at)
)
SELECT 
    registration_year,
    registration_quarter,
    CONCAT('Q', registration_quarter, ' ', registration_year) AS quarter_label,
    new_customers_count,
    SUM(new_customers_count) OVER (ORDER BY registration_year, registration_quarter) AS cumulative_customers
FROM quarterly_acquisitions
ORDER BY registration_year, registration_quarter;

-- 6. Repeat Purchase Rate
WITH customer_order_counts AS (
    SELECT 
        c.customer_id,
        COUNT(o.order_id) AS orders_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status NOT IN ('Cancelled')
    GROUP BY c.customer_id
)
SELECT 
    COUNT(*) AS total_purchasing_customers,
    COUNT(CASE WHEN orders_count > 1 THEN 1 END) AS repeat_customers_count,
    COUNT(CASE WHEN orders_count = 1 THEN 1 END) AS one_time_buyers_count,
    ROUND((COUNT(CASE WHEN orders_count > 1 THEN 1 END) / COUNT(*)) * 100.0, 2) AS repeat_purchase_rate_percentage
FROM customer_order_counts;

-- 7. Products Bought Together Frequently (Market Basket Analysis)
SELECT 
    p1.name AS product_a,
    p2.name AS product_b,
    COUNT(*) AS frequency_bought_together
FROM order_details d1
JOIN order_details d2 
    ON d1.order_id = d2.order_id 
   AND d1.product_id < d2.product_id
JOIN products p1 ON d1.product_id = p1.product_id
JOIN products p2 ON d2.product_id = p2.product_id
JOIN orders o ON d1.order_id = o.order_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY p1.product_id, p2.product_id, p1.name, p2.name
ORDER BY frequency_bought_together DESC, product_a ASC
LIMIT 10;

-- 8. Inventory Turnover by Product Category
SELECT 
    c.category_id,
    c.name AS category_name,
    SUM(p.stock) AS total_units_in_stock,
    ROUND(SUM(p.stock * p.cost), 2) AS current_inventory_cost_value,
    COALESCE(ROUND(SUM(od.quantity * p.cost), 2), 0.00) AS total_cogs_sold,
    ROUND(
        COALESCE(SUM(od.quantity * p.cost), 0.00) / 
        NULLIF(SUM(p.stock * p.cost), 0), 
        3
    ) AS inventory_turnover_ratio
FROM categories c
JOIN products p ON c.category_id = p.category_id
LEFT JOIN order_details od ON p.product_id = od.product_id
LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
GROUP BY c.category_id, c.name
ORDER BY inventory_turnover_ratio DESC;

-- 9. Products Needing Reorder (Below Safety Threshold)
SELECT 
    p.product_id,
    p.name AS product_name,
    p.sku,
    c.name AS category_name,
    s.company_name AS supplier_name,
    s.contact_email AS supplier_email,
    p.stock AS current_stock,
    p.min_threshold,
    ((p.min_threshold * 2) - p.stock) AS suggested_reorder_quantity,
    p.cost AS unit_cost,
    ROUND(((p.min_threshold * 2) - p.stock) * p.cost, 2) AS estimated_reorder_cost
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE p.stock <= p.min_threshold
  AND p.is_active = TRUE
ORDER BY p.stock ASC;

-- 10. Simulated Abandoned Cart Analysis
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    sc.cart_id,
    sc.updated_at AS cart_last_activity,
    COUNT(ci.cart_item_id) AS items_in_cart,
    SUM(ci.quantity) AS total_units_pending,
    ROUND(SUM(ci.quantity * p.price), 2) AS estimated_abandoned_value
FROM shopping_carts sc
JOIN customers c ON sc.customer_id = c.customer_id
JOIN cart_items ci ON sc.cart_id = ci.cart_id
JOIN products p ON ci.product_id = p.product_id
WHERE sc.is_abandoned = TRUE 
   OR sc.updated_at < (NOW() - INTERVAL 72 HOUR)
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, sc.cart_id, sc.updated_at
ORDER BY estimated_abandoned_value DESC;

-- 11. Supplier Performance Ranking
SELECT 
    s.supplier_id,
    s.company_name,
    COUNT(DISTINCT p.product_id) AS products_supplied,
    COALESCE(SUM(od.quantity), 0) AS total_units_sold,
    COALESCE(ROUND(SUM(od.quantity * od.frozen_unit_price), 2), 0.00) AS total_sales_volume,
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(od.quantity * od.frozen_unit_price), 0) DESC) AS performance_rank
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
LEFT JOIN order_details od ON p.product_id = od.product_id
LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
GROUP BY s.supplier_id, s.company_name
ORDER BY performance_rank ASC;

-- 12. Geographic Sales Analysis
WITH city_totals AS (
    SELECT 
        c.city,
        COUNT(DISTINCT c.customer_id) AS registered_customers,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(od.quantity) AS total_products_sold,
        ROUND(SUM(od.quantity * od.frozen_unit_price), 2) AS total_city_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    WHERE o.status NOT IN ('Cancelled')
    GROUP BY c.city
)
SELECT 
    city,
    registered_customers,
    total_orders,
    total_products_sold,
    total_city_revenue,
    ROUND((total_city_revenue / SUM(total_city_revenue) OVER ()) * 100.0, 2) AS revenue_contribution_pct
FROM city_totals
ORDER BY total_city_revenue DESC;

-- 13. Sales by Hour of the Day (Peak Shopping Hours)
SELECT 
    HOUR(o.order_date) AS hour_of_day,
    CASE 
        WHEN HOUR(o.order_date) BETWEEN 6 AND 11 THEN 'Morning (06:00 - 11:59)'
        WHEN HOUR(o.order_date) BETWEEN 12 AND 17 THEN 'Afternoon (12:00 - 17:59)'
        WHEN HOUR(o.order_date) BETWEEN 18 AND 23 THEN 'Evening (18:00 - 23:59)'
        ELSE 'Night / Early Morning (00:00 - 05:59)'
    END AS time_window,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(od.quantity) AS total_items_sold,
    ROUND(SUM(od.quantity * od.frozen_unit_price), 2) AS total_hourly_revenue
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY HOUR(o.order_date), time_window
ORDER BY hour_of_day ASC;

-- 14. Promotion Campaign Impact
SELECT 
    pr.name AS campaign_name,
    pr.discount_percentage,
    pr.start_date,
    pr.end_date,
    COUNT(DISTINCT CASE 
        WHEN o.order_date BETWEEN (pr.start_date - INTERVAL DATEDIFF(pr.end_date, pr.start_date) DAY) AND pr.start_date 
        THEN o.order_id END) AS orders_before_promo,
    COALESCE(ROUND(SUM(CASE 
        WHEN o.order_date BETWEEN (pr.start_date - INTERVAL DATEDIFF(pr.end_date, pr.start_date) DAY) AND pr.start_date 
        THEN od.quantity * od.frozen_unit_price END), 2), 0.00) AS revenue_before_promo,
    COUNT(DISTINCT CASE 
        WHEN o.order_date BETWEEN pr.start_date AND pr.end_date 
        THEN o.order_id END) AS orders_during_promo,
    COALESCE(ROUND(SUM(CASE 
        WHEN o.order_date BETWEEN pr.start_date AND pr.end_date 
        THEN od.quantity * od.frozen_unit_price END), 2), 0.00) AS revenue_during_promo,
    COUNT(DISTINCT CASE 
        WHEN o.order_date BETWEEN pr.end_date AND (pr.end_date + INTERVAL DATEDIFF(pr.end_date, pr.start_date) DAY) 
        THEN o.order_id END) AS orders_after_promo,
    COALESCE(ROUND(SUM(CASE 
        WHEN o.order_date BETWEEN pr.end_date AND (pr.end_date + INTERVAL DATEDIFF(pr.end_date, pr.start_date) DAY) 
        THEN od.quantity * od.frozen_unit_price END), 2), 0.00) AS revenue_after_promo
FROM promotions pr
CROSS JOIN orders o
JOIN order_details od ON o.order_id = od.order_id
WHERE o.status NOT IN ('Cancelled')
GROUP BY pr.promotion_id, pr.name, pr.discount_percentage, pr.start_date, pr.end_date;

-- 15. Customer Cohort Analysis (Monthly Retention)
WITH customer_first_purchase AS (
    SELECT 
        customer_id,
        DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM orders
    WHERE status NOT IN ('Cancelled')
    GROUP BY customer_id
),
customer_activities AS (
    SELECT 
        o.customer_id,
        cfp.cohort_month,
        TIMESTAMPDIFF(MONTH, cfp.cohort_month, DATE_FORMAT(o.order_date, '%Y-%m-01')) AS month_number
    FROM orders o
    JOIN customer_first_purchase cfp ON o.customer_id = cfp.customer_id
    WHERE o.status NOT IN ('Cancelled')
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_cohort_customers
    FROM customer_first_purchase
    GROUP BY cohort_month
)
SELECT 
    ca.cohort_month,
    cs.total_cohort_customers,
    ca.month_number AS months_elapsed_since_first_order,
    COUNT(DISTINCT ca.customer_id) AS active_retained_customers,
    ROUND((COUNT(DISTINCT ca.customer_id) / cs.total_cohort_customers) * 100.0, 2) AS retention_rate_percentage
FROM customer_activities ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.total_cohort_customers, ca.month_number
ORDER BY ca.cohort_month ASC, ca.month_number ASC;

-- 16. Profit Margin per Product
SELECT 
    p.product_id,
    p.name AS product_name,
    c.name AS category_name,
    p.cost AS unit_cost,
    p.price AS current_selling_price,
    ROUND(p.price - p.cost, 2) AS unit_gross_profit,
    ROUND(((p.price - p.cost) / p.price) * 100.0, 2) AS profit_margin_percentage,
    COALESCE(SUM(od.quantity), 0) AS total_units_sold,
    COALESCE(ROUND(SUM(od.quantity * (od.frozen_unit_price - p.cost)), 2), 0.00) AS total_lifetime_gross_profit
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_details od ON p.product_id = od.product_id
LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
GROUP BY p.product_id, p.name, c.name, p.cost, p.price
ORDER BY total_lifetime_gross_profit DESC;

-- 17. Average Time Between Purchases
WITH customer_order_timeline AS (
    SELECT 
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM orders
    WHERE status NOT IN ('Cancelled')
),
customer_intervals AS (
    SELECT 
        customer_id,
        DATEDIFF(order_date, previous_order_date) AS days_between_orders
    FROM customer_order_timeline
    WHERE previous_order_date IS NOT NULL
)
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(ci.days_between_orders) AS repeat_purchase_events,
    ROUND(AVG(ci.days_between_orders), 1) AS avg_days_between_purchases,
    MIN(ci.days_between_orders) AS shortest_gap_days,
    MAX(ci.days_between_orders) AS longest_gap_days
FROM customer_intervals ci
JOIN customers c ON ci.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY avg_days_between_purchases ASC;

-- 18. Most Viewed vs. Most Purchased Products (Conversion Rate)
SELECT 
    p.product_id,
    p.name AS product_name,
    c.name AS category_name,
    p.views_count AS product_page_views,
    COALESCE(SUM(od.quantity), 0) AS units_purchased,
    ROUND(
        (COALESCE(SUM(od.quantity), 0) / NULLIF(p.views_count, 0)) * 100.0, 
        2
    ) AS conversion_rate_percentage,
    ROUND(COALESCE(SUM(od.quantity * od.frozen_unit_price), 0), 2) AS total_revenue
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_details od ON p.product_id = od.product_id
LEFT JOIN orders o ON od.order_id = o.order_id AND o.status NOT IN ('Cancelled')
GROUP BY p.product_id, p.name, c.name, p.views_count
ORDER BY units_purchased DESC, product_page_views DESC;

-- 19. RFM Customer Segmentation (Recency, Frequency, Monetary)
WITH rfm_raw AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        DATEDIFF('2026-03-31', MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        ROUND(SUM(o.total_amount), 2) AS monetary_total
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status NOT IN ('Cancelled')
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
),
rfm_scores AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        recency_days,
        frequency_orders,
        monetary_total,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary_total ASC) AS m_score
    FROM rfm_raw
)
SELECT 
    customer_id,
    customer_name,
    email,
    recency_days,
    frequency_orders,
    monetary_total,
    CONCAT(r_score, f_score, m_score) AS rfm_combined_score,
    CASE 
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions (High Value & Recent)'
        WHEN r_score >= 2 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising / Recent Buyers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk (High Past Value, Inactive)'
        ELSE 'Hibernating / Needs Attention'
    END AS customer_segment
FROM rfm_scores
ORDER BY monetary_total DESC, recency_days ASC;

-- 20. Simple Demand Forecast (Next Month Projected Sales for Categories)
WITH monthly_category_sales AS (
    SELECT 
        c.category_id,
        c.name AS category_name,
        DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,
        SUM(od.quantity) AS monthly_units_sold,
        ROUND(SUM(od.quantity * od.frozen_unit_price), 2) AS monthly_revenue
    FROM categories c
    JOIN products p ON c.category_id = p.category_id
    JOIN order_details od ON p.product_id = od.product_id
    JOIN orders o ON od.order_id = o.order_id
    WHERE o.status NOT IN ('Cancelled')
    GROUP BY c.category_id, c.name, DATE_FORMAT(o.order_date, '%Y-%m')
),
rolling_averages AS (
    SELECT 
        category_id,
        category_name,
        sales_month,
        monthly_units_sold,
        monthly_revenue,
        ROUND(AVG(monthly_revenue) OVER (
            PARTITION BY category_id 
            ORDER BY sales_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS rolling_3_month_avg_revenue,
        ROUND(AVG(monthly_units_sold) OVER (
            PARTITION BY category_id 
            ORDER BY sales_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 0) AS rolling_3_month_avg_units
    FROM monthly_category_sales
)
SELECT 
    category_id,
    category_name,
    sales_month AS latest_recorded_month,
    monthly_revenue AS latest_month_revenue,
    rolling_3_month_avg_units AS projected_next_month_units,
    rolling_3_month_avg_revenue AS projected_next_month_revenue
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY sales_month DESC) AS rn
    FROM rolling_averages
) sub
WHERE rn = 1
ORDER BY projected_next_month_revenue DESC;
