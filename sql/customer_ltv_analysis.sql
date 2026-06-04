-- customer_ltv_analysis.sql
-- SQL-запросы для вкладки "Клиенты и LTV" дашборда Metabase.
-- Период анализа: 2023 год.
-- В запросах используется Metabase Field Filter: {{date_filter}}.

-- 1. DAU и скользящее среднее за 7 дней
WITH daily_activity AS (
    SELECT
        purchase_date::date AS date,
        COUNT(DISTINCT client_id) AS dau
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY purchase_date::date
)
SELECT
    date AS "Дата",
    dau AS "DAU",
    ROUND(AVG(dau) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS "DAU, скользящее среднее 7 дней"
FROM daily_activity
ORDER BY date;

-- 2. WAU и скользящее среднее за 4 недели
WITH weekly_activity AS (
    SELECT
        DATE_TRUNC('week', purchase_date)::date AS week,
        COUNT(DISTINCT client_id) AS wau
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY 1
)
SELECT
    week AS "Неделя",
    wau AS "WAU",
    ROUND(AVG(wau) OVER (ORDER BY week ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS "WAU, скользящее среднее 4 недели"
FROM weekly_activity
ORDER BY week;

-- 3. MAU
WITH filter_date AS (
    SELECT DISTINCT
        DATE_TRUNC('month', purchase_date)::date AS month
    FROM purchases
    WHERE {{month}}
      AND EXTRACT(YEAR FROM purchase_date) = 2023
)
SELECT
    DATE_TRUNC('month', purchase_date)::date AS month,
    COUNT(DISTINCT client_id) AS mau
FROM purchases
CROSS JOIN filter_date
WHERE DATE_TRUNC('month', purchase_date) = filter_date.month
   OR DATE_TRUNC('month', purchase_date) = filter_date.month - INTERVAL '1 month'
GROUP BY 1
ORDER BY 1;

-- 4. Sticky Factor
WITH daily_activity AS (
    SELECT
        purchase_date,
        COUNT(DISTINCT client_id) AS dau
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY purchase_date
),

monthly_activity AS (
    SELECT
        DATE_TRUNC('month', purchase_date)::date AS month_date,
        COUNT(DISTINCT client_id) AS mau
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY 1
)

SELECT
    ROUND(
        AVG(d.dau)::numeric / AVG(m.mau) * 100, 2) AS "Sticky Factor, %"
FROM daily_activity d
JOIN monthly_activity m
    ON DATE_TRUNC('month', d.purchase_date)::date = m.month_date;


-- 5. Repeat Rate
WITH client_purchases AS (
    SELECT
        client_id,
        COUNT(*) AS purchases_count
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY client_id
)
SELECT
    ROUND(COUNT(*) FILTER (WHERE purchases_count > 1)::numeric / COUNT(*) * 100, 2) AS "Repeat Rate, %"
FROM client_purchases;


-- 6. Распределение клиентов по полу
SELECT
    CASE 
        WHEN gender = 'F' THEN 'Женский'
        WHEN gender = 'M' THEN 'Мужской'
        ELSE 'Не указан'
    END AS "Пол",
    
    COUNT(DISTINCT client_id) AS "Количество клиентов",
    ROUND(COUNT(DISTINCT client_id) * 1.0 / SUM(COUNT(DISTINCT client_id)) OVER () * 100, 2) AS "Доля, %"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1;


-- 7. Сравнение выручки мужской и женской аудитории, млрд ₽
SELECT
    CASE
        WHEN gender = 'F' THEN 'Женщины'
        WHEN gender = 'M' THEN 'Мужчины'
        ELSE 'Не указан'
    END AS "Пол",
    ROUND(SUM(total_price) / 1000000000.0, 2) AS "Выручка, млрд ₽"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1
ORDER BY 2 DESC;

-- 8. Динамика среднего чека
SELECT
    DATE_TRUNC('month', purchase_date)::date AS "Месяц",
    ROUND(AVG(total_price), 2) AS "Средний чек, ₽"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1
ORDER BY 1;

-- 9. Среднее количество заказов на клиента
SELECT
    DATE_TRUNC('month', purchase_date)::date AS "Месяц",
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT client_id), 2) AS "Средняя частота покупок"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01'
GROUP BY 1
ORDER BY 1;


-- 10. LTV за период
SELECT
    ROUND(SUM(total_price) / COUNT(DISTINCT client_id), 2) AS "LTV, ₽"
FROM purchases
WHERE {{date_filter}}
  AND purchase_date >= '2023-01-01'
  AND purchase_date < '2024-01-01';


-- 11. RFM-анализ клиентской базы
WITH client_metrics AS (
    SELECT
        client_id,
        MAX(purchase_date) AS last_purchase_date,
        COUNT(*) AS frequency,
        SUM(total_price) AS monetary
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY client_id
),

rfm_scores AS (
    SELECT
        client_id,
        '2023-12-31'::date - last_purchase_date AS recency_days,
        frequency,
        monetary,
        CASE
            WHEN '2023-12-31'::date - last_purchase_date > 60 THEN 1
            WHEN '2023-12-31'::date - last_purchase_date > 30 THEN 2
            ELSE 3
        END AS r_score,
        CASE
            WHEN frequency <= 1 THEN 1
            WHEN frequency <= 4 THEN 2
            ELSE 3
        END AS f_score,
        CASE
            WHEN monetary < 700000 THEN 1
            WHEN monetary <= 2100000 THEN 2
            ELSE 3
        END AS m_score
    FROM client_metrics
),
rfm_codes AS (
    SELECT
        client_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        r_score::text || f_score::text || m_score::text AS rfm_code
    FROM rfm_scores
),
rfm_segments AS (
    SELECT
        client_id,
        recency_days,
        frequency,
        monetary,
        rfm_code,

        CASE
            WHEN rfm_code IN ('333', '332', '331') THEN 'Идеальные'
            WHEN rfm_code IN ('323', '322', '321') THEN 'Лояльные'
            WHEN rfm_code IN ('233', '232', '231', '213', '212', '211') THEN 'Спящие'
            WHEN rfm_code IN ('223', '222', '221', '313', '312', '311') THEN 'Бывшие лояльные'
            WHEN rfm_code IN ('123', '122', '121', '133', '132', '131') THEN 'Редкие'
            WHEN rfm_code IN ('113', '112', '111') THEN 'Потерянные'
        END AS segment
    FROM rfm_codes
)
SELECT
    segment AS "RFM-сегмент",
    COUNT(*) AS "Количество клиентов",
    ROUND(SUM(monetary), 2) AS "Выручка сегмента",
    ROUND(AVG(monetary), 2) AS "Средняя выручка на клиента",
    ROUND(AVG(frequency), 2) AS "Среднее количество покупок",
    ROUND(AVG(recency_days), 2) AS "Средняя давность покупки, дней"
FROM rfm_segments
GROUP BY segment
ORDER BY "Количество клиентов" DESC;


-- 12. Средний lifetime клиента
SELECT
    ROUND(AVG(client_lifetime_days), 2) AS "Средний lifetime, дней"
FROM (
    SELECT
        client_id,
        MAX(purchase_date) - MIN(purchase_date) AS client_lifetime_days
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY client_id
) t;


-- 13. Распределение клиентов по количеству покупок
WITH client_orders AS (
    SELECT
        client_id,
        COUNT(*) AS orders_count
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY client_id
),

grouped AS (
    SELECT
        CASE
            WHEN orders_count = 1 THEN '1 заказ'
            WHEN orders_count BETWEEN 2 AND 3 THEN '2–3 заказа'
            WHEN orders_count BETWEEN 4 AND 5 THEN '4–5 заказов'
            WHEN orders_count BETWEEN 6 AND 10 THEN '6–10 заказов'
            ELSE 'Более 10 заказов'
        END AS order_group,
        CASE
            WHEN orders_count = 1 THEN 1
            WHEN orders_count BETWEEN 2 AND 3 THEN 2
            WHEN orders_count BETWEEN 4 AND 5 THEN 3
            WHEN orders_count BETWEEN 6 AND 10 THEN 4
            ELSE 5
        END AS sort_order
    FROM client_orders
)
SELECT
    order_group AS "Количество заказов",
    COUNT(*) AS "Количество клиентов"
FROM grouped
GROUP BY order_group, sort_order
ORDER BY sort_order;


-- 14. Динамика новых клиентов по месяцам
SELECT
    DATE_TRUNC('month', first_purchase)::date AS "Месяц",
    COUNT(DISTINCT client_id) AS "Новые клиенты"
FROM (
    SELECT
        client_id,
        MIN(purchase_date) AS first_purchase
    FROM purchases
    WHERE {{date_filter}}
      AND purchase_date >= '2023-01-01'
      AND purchase_date < '2024-01-01'
    GROUP BY client_id
) t
GROUP BY 1
ORDER BY 1;

