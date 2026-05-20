CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_date DATA,
    product_id VARCHAR(50)
    quantity INTEGER,
    unit_price NUMERIC(10,2),
    status VARCHAR(50),
    country VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 100 seed rows so you have something to query immediately
INSERT INTO orders
SELECT
    'ORD-' || LPAD(gs::text, 5, '0'),
    'CUST-' || LPAD((1 + gs % 8)::text, 3, '0'),
    CURRENT_DATE - (gs % 30),
    'PROD-' || LPAD((1 + gs % 10)::text, 3, '0'),
    (1 + gs % 5),
    ROUND((10 + random() * 490)::numeric, 2),
    CASE WHEN gs % 10 = 0 THEN 'cancelled' ELSE 'completed' END,
    CASE gs % 4 WHEN 0 THEN 'Germany' WHEN 1 THEN 'Austria'
                WHEN 2 THEN 'Netherlands' ELSE 'France' END,
    NOW() - (INTERVAL '1 minute' * gs * 10)
FROM generate_series(1, 100) gs
ON CONFLICT DO NOTHING;