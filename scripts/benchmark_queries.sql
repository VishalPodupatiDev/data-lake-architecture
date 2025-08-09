-- AWS Data Lake Analytics Queries
-- Benchmark queries for Athena vs Redshift performance comparison

-- ============================================
-- ATHENA QUERIES (Serverless, pay-per-query)
-- ============================================

-- 1. Basic Sales Analysis
SELECT 
    sale_date,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_sales,
    AVG(total_amount) as avg_order_value
FROM sales_fact
WHERE sale_date >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY sale_date
ORDER BY sale_date DESC;

-- 2. Product Performance Analysis
SELECT 
    product_name,
    COUNT(*) as units_sold,
    SUM(total_amount) as revenue,
    AVG(unit_price) as avg_unit_price,
    SUM(profit_margin) as total_profit
FROM sales_fact
GROUP BY product_name
ORDER BY revenue DESC;

-- 3. Regional Sales Analysis
SELECT 
    region,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_id) as unique_customers
FROM sales_fact
GROUP BY region
ORDER BY revenue DESC;

-- 4. Customer Segment Analysis
SELECT 
    customer_segment,
    COUNT(*) as orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_id) as customer_count
FROM sales_fact
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- 5. Time-based Analysis (Partitioned by date)
SELECT 
    year,
    month,
    month_name,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value
FROM sales_fact
WHERE year = 2024
GROUP BY year, month, month_name
ORDER BY year, month;

-- 6. Payment Method Analysis
SELECT 
    payment_method,
    COUNT(*) as orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM sales_fact
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- 7. Daily Sales Trend (Last 7 days)
SELECT 
    sale_date,
    day_of_week,
    COUNT(*) as orders,
    SUM(total_amount) as daily_revenue,
    AVG(total_amount) as avg_order_value
FROM sales_fact
WHERE sale_date >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY sale_date, day_of_week
ORDER BY sale_date DESC;

-- 8. High-Value Orders Analysis
SELECT 
    sale_id,
    customer_id,
    product_name,
    total_amount,
    region,
    sale_date
FROM sales_fact
WHERE total_amount >= 1000
ORDER BY total_amount DESC
LIMIT 20;

-- ============================================
-- REDSHIFT QUERIES (Optimized for Analytics)
-- ============================================

-- 1. Create optimized table structure
CREATE TABLE IF NOT EXISTS sales_fact_redshift (
    sale_id VARCHAR(50),
    customer_id VARCHAR(50),
    product_name VARCHAR(100),
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    region VARCHAR(50),
    payment_method VARCHAR(50),
    sale_date DATE,
    sale_timestamp TIMESTAMP,
    processing_timestamp TIMESTAMP,
    profit_margin DECIMAL(10,2),
    customer_segment VARCHAR(20),
    month_name VARCHAR(20),
    quarter INTEGER,
    day_of_week VARCHAR(20),
    year INTEGER,
    month INTEGER,
    day INTEGER
)
DISTSTYLE KEY
DISTKEY (sale_date)
SORTKEY (sale_date, region);

-- 2. Load data from S3 (COPY command)
-- COPY sales_fact_redshift FROM 's3://your-processed-bucket/processed/sales/'
-- IAM_ROLE 'arn:aws:iam::account:role/redshift-s3-role'
-- FORMAT AS PARQUET;

-- 3. Advanced Analytics Queries

-- Customer Lifetime Value Analysis
SELECT 
    customer_id,
    COUNT(*) as total_orders,
    SUM(total_amount) as lifetime_value,
    AVG(total_amount) as avg_order_value,
    MAX(sale_date) as last_order_date,
    MIN(sale_date) as first_order_date
FROM sales_fact_redshift
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY lifetime_value DESC
LIMIT 20;

-- Product Cross-Selling Analysis
WITH product_pairs AS (
    SELECT 
        a.customer_id,
        a.product_name as product1,
        b.product_name as product2
    FROM sales_fact_redshift a
    JOIN sales_fact_redshift b ON a.customer_id = b.customer_id
    WHERE a.sale_id < b.sale_id
)
SELECT 
    product1,
    product2,
    COUNT(*) as co_occurrences
FROM product_pairs
GROUP BY product1, product2
ORDER BY co_occurrences DESC
LIMIT 10;

-- Regional Growth Analysis
SELECT 
    region,
    year,
    month,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    LAG(SUM(total_amount)) OVER (PARTITION BY region ORDER BY year, month) as prev_month_revenue,
    ((SUM(total_amount) - LAG(SUM(total_amount)) OVER (PARTITION BY region ORDER BY year, month)) / 
     LAG(SUM(total_amount)) OVER (PARTITION BY region ORDER BY year, month) * 100) as growth_percentage
FROM sales_fact_redshift
GROUP BY region, year, month
ORDER BY region, year, month;

-- Time-based Cohort Analysis
SELECT 
    DATE_TRUNC('month', sale_date) as cohort_month,
    customer_segment,
    COUNT(DISTINCT customer_id) as new_customers,
    SUM(total_amount) as cohort_revenue
FROM sales_fact_redshift
WHERE customer_id IN (
    SELECT customer_id 
    FROM sales_fact_redshift 
    GROUP BY customer_id 
    HAVING MIN(sale_date) = DATE_TRUNC('month', MIN(sale_date))
)
GROUP BY DATE_TRUNC('month', sale_date), customer_segment
ORDER BY cohort_month DESC;

-- Performance Benchmarking Queries

-- Query 1: Simple aggregation (should be fast on both)
SELECT 
    region,
    COUNT(*) as orders,
    SUM(total_amount) as revenue
FROM sales_fact_redshift
WHERE sale_date >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY region
ORDER BY revenue DESC;

-- Query 2: Complex join with window functions (Redshift should be faster)
SELECT 
    product_name,
    region,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    RANK() OVER (PARTITION BY region ORDER BY SUM(total_amount) DESC) as regional_rank
FROM sales_fact_redshift
WHERE year = 2024
GROUP BY product_name, region
ORDER BY region, regional_rank;

-- Query 3: Date range analysis with multiple aggregations
SELECT 
    DATE_TRUNC('week', sale_date) as week_start,
    COUNT(*) as total_orders,
    SUM(total_amount) as weekly_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT product_name) as products_sold
FROM sales_fact_redshift
WHERE sale_date >= CURRENT_DATE - INTERVAL '90' DAY
GROUP BY DATE_TRUNC('week', sale_date)
ORDER BY week_start DESC;

-- Query 4: Subquery with complex filtering
SELECT 
    customer_segment,
    COUNT(*) as orders,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value
FROM sales_fact_redshift
WHERE customer_id IN (
    SELECT customer_id 
    FROM sales_fact_redshift 
    GROUP BY customer_id 
    HAVING COUNT(*) >= 3
)
AND sale_date >= CURRENT_DATE - INTERVAL '60' DAY
GROUP BY customer_segment
ORDER BY revenue DESC;

-- ============================================
-- COST OPTIMIZATION QUERIES
-- ============================================

-- 1. Storage cost analysis by partition
SELECT 
    year,
    month,
    COUNT(*) as records,
    SUM(total_amount) as revenue,
    COUNT(*) * 100 as estimated_storage_kb  -- Rough estimate
FROM sales_fact_redshift
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- 2. Query performance analysis
-- This would typically be done via system tables in Redshift
-- SELECT * FROM STL_QUERY WHERE starttime >= CURRENT_DATE - INTERVAL '1' DAY;

-- 3. Compression analysis
-- SELECT * FROM SVV_TABLE_INFO WHERE table_name = 'sales_fact_redshift';

-- ============================================
-- DATA QUALITY QUERIES
-- ============================================

-- 1. Data completeness check
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN sale_id IS NOT NULL THEN 1 END) as records_with_sale_id,
    COUNT(CASE WHEN total_amount > 0 THEN 1 END) as records_with_positive_amount,
    COUNT(CASE WHEN sale_date IS NOT NULL THEN 1 END) as records_with_date
FROM sales_fact_redshift;

-- 2. Duplicate detection
SELECT 
    sale_id,
    COUNT(*) as duplicate_count
FROM sales_fact_redshift
GROUP BY sale_id
HAVING COUNT(*) > 1;

-- 3. Data consistency check
SELECT 
    'Invalid amounts' as check_type,
    COUNT(*) as issue_count
FROM sales_fact_redshift
WHERE total_amount != (quantity * unit_price)
UNION ALL
SELECT 
    'Future dates' as check_type,
    COUNT(*) as issue_count
FROM sales_fact_redshift
WHERE sale_date > CURRENT_DATE;
