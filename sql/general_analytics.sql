-- general_analytics.sql
-- SQL-запросы для вкладки "Общая аналитика" дашборда Metabase.
-- Период анализа: 2023 год.
-- В запросах используется Metabase Field Filter: {{date_filter}}.

-- 1. KPI-карточка тренд по Выручке
WITH filter_date AS (
    SELECT DISTINCT
        DATE_TRUNC('month', purchase_date)::date AS month
    FROM purchases
    WHERE {{month}}
)

SELECT
    DATE_TRUNC('month', purchase_date)::date AS month,
    SUM(total_price) AS revenue
FROM purchases
CROSS JOIN filter_date
WHERE DATE_TRUNC('month', purchase_date) = filter_date.month
   OR DATE_TRUNC('month', purchase_date) = filter_date.month - INTERVAL '1 month'
GROUP BY 1
ORDER BY 1;

WITH filter_date AS (
    SELECT DISTINCT
        DATE_TRUNC('month', purchase_date)::date AS month
    FROM purchases
    WHERE {{month}}
)

-- 2. KPI-карточка тренд Продажи на клиента
SELECT
    DATE_TRUNC('month', purchase_date)::date AS month,
    ROUND(
        SUM(total_price) / COUNT(DISTINCT client_id),
        2
    ) AS revenue_per_client
FROM purchases
CROSS JOIN filter_date
WHERE DATE_TRUNC('month', purchase_date) = filter_date.month
   OR DATE_TRUNC('month', purchase_date) = filter_date.month - INTERVAL '1 month'
GROUP BY 1
ORDER BY 1;

-- 3. KPI-карточка тренд Количество заказов
WITH filter_date AS (
    SELECT DISTINCT
        DATE_TRUNC('month', purchase_date)::date AS month
    FROM purchases
    WHERE {{month}}
)

SELECT
    DATE_TRUNC('month', purchase_date)::date AS month,
    COUNT(*) AS orders
FROM purchases
CROSS JOIN filter_date
WHERE DATE_TRUNC('month', purchase_date) = filter_date.month
   OR DATE_TRUNC('month', purchase_date) = filter_date.month - INTERVAL '1 month'
GROUP BY 1
ORDER BY 1;

-- 4. KPI-карточка тренд Средний чек
WITH filter_date AS (
    SELECT DISTINCT
        DATE_TRUNC('month', purchase_date)::date AS month
    FROM purchases
    WHERE {{month}}
)

SELECT
    DATE_TRUNC('month', purchase_date)::date AS month,
    ROUND(
        AVG(total_price),
        2
    ) AS avg_order_value
FROM purchases
CROSS JOIN filter_date
WHERE DATE_TRUNC('month', purchase_date) = filter_date.month
   OR DATE_TRUNC('month', purchase_date) = filter_date.month - INTERVAL '1 month'
GROUP BY 1
ORDER BY 1;

-- 5. Накопительная динамика выручки за 2023 г.
WITH revenue_by_month AS (
    SELECT
        date_trunc('month', purchase_date)::date as month,
        SUM(total_price) AS revenue
    FROM purchases
    WHERE EXTRACT(YEAR FROM purchase_date) = 2023
    GROUP BY 1
)
SELECT
    month,
    ROUND(
        SUM(revenue) OVER (ORDER BY month) / 1000000000.0,
        2
    ) AS "Накопительная выручка, млрд ₽"
FROM revenue_by_month
ORDER BY MONTH

-- 6. Динамика скидок по месяцам
SELECT
    DATE_TRUNC('month', purchase_date)::date AS "Месяц",
    ROUND(
        SUM(discount_per_item * quantity) / 1000000000.0,
        2
    ) AS "Сумма скидок"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1
ORDER BY 1;


-- 7. Средний процент скидки
SELECT
    ROUND(
        AVG(
            discount_per_item
            / NULLIF(price_per_item, 0)
        ) * 100,
        2
    ) AS "Средний процент скидки"
FROM purchases
WHERE {{date_filter}}
  AND discount_per_item > 0

  
-- 8. Доля заказов со скидкой, %
SELECT
    ROUND(
        COUNT(*) FILTER (WHERE discount_per_item > 0)::numeric
        / COUNT(*) * 100,
        2
    ) AS "Доля заказов со скидкой, %"
FROM purchases
WHERE {{date_filter}}


-- 9. Динамика выручки и количества заказов
SELECT
    DATE_TRUNC('week', purchase_date)::date AS "Неделя",
    ROUND(SUM(total_price) / 1000000000, 2) AS "Выручка, млрд ₽",
    COUNT(*) AS "Количество заказов"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1
ORDER BY 1;


-- 10. Топ-10 товаров по выручке
SELECT
    product_id AS "ID товара",
    ROUND(SUM(total_price) / 1000000, 2) AS "Выручка, млн ₽"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY product_id
ORDER BY "Выручка, млн ₽" DESC
LIMIT 10;


-- 11. Топ-10 товаров по количеству продаж
SELECT
    product_id AS "ID товара",
    SUM(quantity) AS "Продано, шт"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY product_id
ORDER BY "Продано, шт" DESC
LIMIT 10;


-- 12. Антитоп-10 товаров по выручке
SELECT
    product_id AS "ID товара",
    SUM(total_price)  AS "Выручка, ₽"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY product_id
ORDER BY "Выручка, ₽" ASC
LIMIT 10;


-- 13. Антитоп-10 товаров по количеству продаж
SELECT
    product_id AS "ID товара",
    SUM(quantity) AS "Продано, шт"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY product_id
ORDER BY "Продано, шт" ASC
LIMIT 10;


-- 14. Динамика активного ассортимента 
WITH total_products AS (
    SELECT
        COUNT(DISTINCT product_id) AS total_products
    FROM purchases
    WHERE purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
),

monthly_active AS (
    SELECT
        DATE_TRUNC('month', purchase_date)::date AS month,
        COUNT(DISTINCT product_id) AS active_products
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY 1
)

SELECT
    month AS "Месяц",
    active_products AS "Активные товары",
    total_products AS "Всего товаров"
FROM monthly_active
CROSS JOIN total_products
ORDER BY month;