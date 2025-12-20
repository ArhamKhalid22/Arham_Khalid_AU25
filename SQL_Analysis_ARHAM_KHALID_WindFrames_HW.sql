--task 1
WITH base AS (
    SELECT
        co.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold,
        100.0 * SUM(s.amount_sold)
            / SUM(SUM(s.amount_sold)) OVER (
                  PARTITION BY co.country_region, t.calendar_year
              ) AS pct_by_channels
    FROM
        sh.sales     s
        JOIN sh.customers cu ON s.cust_id   = cu.cust_id
        JOIN sh.countries co ON cu.country_id = co.country_id
        JOIN sh.times     t  ON s.time_id   = t.time_id
        JOIN sh.channels  ch ON s.channel_id = ch.channel_id
    WHERE
        t.calendar_year BETWEEN 1999 AND 2001
        AND co.country_region IN ('Americas','Asia','Europe')
    GROUP BY
        co.country_region,
        t.calendar_year,
        ch.channel_desc
),
with_prev AS (
    SELECT
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        pct_by_channels,
        LAG(pct_by_channels) OVER (
            PARTITION BY country_region, channel_desc
            ORDER BY calendar_year
        ) AS pct_prev_period
    FROM base
)
SELECT
    country_region,
    calendar_year,
    channel_desc,
    amount_sold,
    ROUND(pct_by_channels, 2)                                AS "% BY CHANNELS",
    ROUND(pct_prev_period, 2)                                AS "% PREVIOUS PERIOD",
    ROUND(pct_by_channels - COALESCE(pct_prev_period, 0), 2) AS "% DIFF"
FROM with_prev
ORDER BY
    country_region,
    calendar_year,
    channel_desc;

--task 2
WITH daily_sales AS (
    SELECT
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        SUM(s.amount_sold) AS sales
    FROM
        sh.sales s
        JOIN sh.times t ON s.time_id = t.time_id
    WHERE
        t.calendar_year = 1999
        AND t.calendar_week_number BETWEEN 49 AND 51
    GROUP BY
        t.calendar_week_number,
        t.time_id,
        t.day_name
),
with_cum AS (
    SELECT
        calendar_week_number,
        time_id,
        day_name,
        sales,
        SUM(sales) OVER (
            PARTITION BY calendar_week_number
            ORDER BY time_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cum_sum
    FROM daily_sales
)
SELECT
    calendar_week_number,
    time_id,
    day_name,
    sales,
    ROUND(cum_sum, 2) AS cum_sum,
    ROUND(
        AVG(sales) OVER (
            ORDER BY time_id
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ),
        2
    ) AS centered_3_day_avg
FROM with_cum
ORDER BY
    calendar_week_number,
    time_id;
-- task 3
-- ROWS frame – last 3 days’ sales per product

SELECT
    s.prod_id,
    t.time_id,
    t.day_name,
    SUM(s.amount_sold) AS daily_sales,
    SUM(SUM(s.amount_sold)) OVER (
        PARTITION BY s.prod_id
        ORDER BY t.time_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS sum_last_3_days
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
GROUP BY
    s.prod_id,
    t.time_id,
    t.day_name
ORDER BY
    s.prod_id,
    t.time_id;
-- 2. RANGE frame – 7‑day calendar sales window
SELECT
    t.time_id,
    t.day_name,
    SUM(s.amount_sold) AS daily_sales,
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.time_id
        RANGE BETWEEN INTERVAL '6 day' PRECEDING AND CURRENT ROW
    ) AS sales_last_7_calendar_days
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
GROUP BY
    t.time_id,
    t.day_name
ORDER BY
    t.time_id;
--3. GROUPS frame – current and previous 2 promotion groups
SELECT
    p.promo_category_id,
    p.promo_category,
    SUM(s.amount_sold) AS promo_sales,
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY p.promo_category_id
        GROUPS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS sales_last_3_promo_groups
FROM sh.sales s
JOIN sh.promotions p ON s.promo_id = p.promo_id
GROUP BY
    p.promo_category_id,
    p.promo_category
ORDER BY
    p.promo_category_id;
