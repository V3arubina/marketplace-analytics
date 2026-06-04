-- abc_xyz_analysis.sql
-- SQL-запросы для вкладки "ABC-XYZ" дашборда Metabase.
-- Период анализа: 2023 год.
-- В запросах используется Metabase Field Filter: {{date_filter}}.

-- 1. Pareto-анализ ассортимента
WITH product_revenue AS (
    SELECT
        product_id,
        SUM(total_price) AS revenue
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY product_id
),

ranked AS (
    SELECT
        product_id,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS product_rank,
        COUNT(*) OVER () AS total_products
    FROM product_revenue
),

grouped AS (
    SELECT
        CEIL(product_rank::numeric / total_products * 100) AS pct_group,
        SUM(revenue) AS revenue
    FROM ranked
    GROUP BY 1
),

cumulative AS (
    SELECT
        pct_group,
        revenue,
        SUM(revenue) OVER (ORDER BY pct_group) AS cumulative_revenue,
        SUM(revenue) OVER () AS total_revenue
    FROM grouped
)

SELECT
    pct_group AS "Доля ассортимента, %",
    ROUND(revenue / 1000000000.0, 2) AS "Выручка, млрд ₽",
    ROUND(cumulative_revenue / total_revenue * 100, 2) AS "Накопленная доля выручки, %"
FROM cumulative
ORDER BY pct_group;


-- 2. ABC-XYZ анализ
WITH filtered_purchases AS (
    SELECT *
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
),

sales_by_product AS (
    SELECT
        product_id,
        SUM(quantity) AS qty_sold,
        SUM(total_price) AS revenue
    FROM filtered_purchases
    GROUP BY product_id
),

abc_calc AS (
    SELECT
        product_id,
        qty_sold,
        revenue,
        SUM(qty_sold) OVER (ORDER BY qty_sold DESC)::numeric
            / SUM(qty_sold) OVER () AS qty_share,

        SUM(revenue) OVER (ORDER BY revenue DESC)::numeric
            / SUM(revenue) OVER () AS revenue_share
    FROM sales_by_product
),

abc AS (
    SELECT
        product_id,
        qty_sold,
        revenue,
        CASE
            WHEN qty_share <= 0.8 THEN 'A'
            WHEN qty_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_qty,

        CASE
            WHEN revenue_share <= 0.8 THEN 'A'
            WHEN revenue_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_revenue
    FROM abc_calc
),

months AS (
    SELECT generate_series(
        DATE '2023-01-01',
        DATE '2023-12-01',
        INTERVAL '1 month'
    )::date AS month
),

product_months AS (
    SELECT
        p.product_id,
        m.month
    FROM sales_by_product p
    CROSS JOIN months m
),

monthly_qty AS (
    SELECT
        pm.product_id,
        pm.month,
        COALESCE(SUM(fp.quantity), 0) AS month_qty
    FROM product_months pm
    LEFT JOIN filtered_purchases fp
        ON pm.product_id = fp.product_id
       AND DATE_TRUNC('month', fp.purchase_date)::date = pm.month
    GROUP BY pm.product_id, pm.month
),

xyz_calc AS (
    SELECT
        product_id,
        STDDEV_SAMP(month_qty) / NULLIF(AVG(month_qty), 0) AS variation
    FROM monthly_qty
    GROUP BY product_id
),

xyz AS (
    SELECT
        product_id,
        CASE
            WHEN variation <= 0.10 THEN 'X'
            WHEN variation <= 0.25 THEN 'Y'
            ELSE 'Z'
        END AS xyz
    FROM xyz_calc
)

SELECT
    a.product_id AS "ID товара",
    a.qty_sold AS "Продано, шт",
    ROUND(a.revenue, 2) AS "Выручка",
    a.abc_qty AS "ABC шт",
    a.abc_revenue AS "ABC выручка",
    x.xyz AS "XYZ",
    a.abc_qty || a.abc_revenue || x.xyz AS "ABC-XYZ"
FROM abc a
LEFT JOIN xyz x
    ON a.product_id = x.product_id
ORDER BY a.revenue DESC;


-- 3. Распределение товаров по сегментам ABC-XYZ
WITH filtered_purchases AS (
    SELECT *
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
),

sales_by_product AS (
    SELECT
        product_id,
        SUM(quantity) AS qty_sold,
        SUM(total_price) AS revenue
    FROM filtered_purchases
    GROUP BY product_id
),

abc_calc AS (
    SELECT
        product_id,
        qty_sold,
        revenue,
        SUM(qty_sold) OVER (ORDER BY qty_sold DESC)::numeric
            / SUM(qty_sold) OVER () AS qty_share,

        SUM(revenue) OVER (ORDER BY revenue DESC)::numeric
            / SUM(revenue) OVER () AS revenue_share
    FROM sales_by_product
),

abc AS (
    SELECT
        product_id,
        CASE
            WHEN qty_share <= 0.80 THEN 'A'
            WHEN qty_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_qty,

        CASE
            WHEN revenue_share <= 0.80 THEN 'A'
            WHEN revenue_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_revenue
    FROM abc_calc
),

months AS (
    SELECT generate_series(
        DATE '2023-01-01',
        DATE '2023-12-01',
        INTERVAL '1 month'
    )::date AS month
),

product_months AS (
    SELECT
        p.product_id,
        m.month
    FROM sales_by_product p
    CROSS JOIN months m
),

monthly_sales AS (
    SELECT
        pm.product_id,
        pm.month,
        COALESCE(SUM(fp.quantity), 0) AS month_qty
    FROM product_months pm
    LEFT JOIN filtered_purchases fp
        ON pm.product_id = fp.product_id
       AND DATE_TRUNC('month', fp.purchase_date)::date = pm.month
    GROUP BY pm.product_id, pm.month
),

xyz AS (
    SELECT
        product_id,
        CASE
            WHEN STDDEV_SAMP(month_qty) / NULLIF(AVG(month_qty), 0) <= 0.10 THEN 'X'
            WHEN STDDEV_SAMP(month_qty) / NULLIF(AVG(month_qty), 0) <= 0.25 THEN 'Y'
            ELSE 'Z'
        END AS xyz
    FROM monthly_sales
    GROUP BY product_id
),

abc_xyz AS (
    SELECT
        a.product_id,
        a.abc_qty || a.abc_revenue || x.xyz AS segment
    FROM abc a
    LEFT JOIN xyz x
        ON a.product_id = x.product_id
)

SELECT
    segment AS "ABC-XYZ группа",
    COUNT(DISTINCT product_id) AS "Количество ID товаров"
FROM abc_xyz
GROUP BY segment
ORDER BY "Количество ID товаров" DESC;


-- 4. Распределение ассортимента по частоте продаж
WITH product_sales AS (
    SELECT
        product_id,
        SUM(quantity) AS sales_count
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY product_id
)

SELECT
    CASE
        WHEN sales_count BETWEEN 1 AND 500 THEN '1–500'
        WHEN sales_count BETWEEN 501 AND 1000 THEN '501–1000'
        WHEN sales_count BETWEEN 1001 AND 1500 THEN '1001–1500'
        WHEN sales_count BETWEEN 1501 AND 2000 THEN '1501–2000'
        WHEN sales_count BETWEEN 2001 AND 2500 THEN '2001–2500'
        WHEN sales_count BETWEEN 2501 AND 3000 THEN '2501–3000'
        ELSE 'Более 3000'
    END AS "Диапазон продаж товаров",

    COUNT(*) AS "Количество товаров"
FROM product_sales
GROUP BY
    CASE
        WHEN sales_count BETWEEN 1 AND 500 THEN '1–500'
        WHEN sales_count BETWEEN 501 AND 1000 THEN '501–1000'
        WHEN sales_count BETWEEN 1001 AND 1500 THEN '1001–1500'
        WHEN sales_count BETWEEN 1501 AND 2000 THEN '1501–2000'
        WHEN sales_count BETWEEN 2001 AND 2500 THEN '2001–2500'
        WHEN sales_count BETWEEN 2501 AND 3000 THEN '2501–3000'
        ELSE 'Более 3000'
    END
ORDER BY
    MIN(sales_count);