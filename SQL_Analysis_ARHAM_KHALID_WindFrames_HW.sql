/* 
Task 1
-------
Purpose:
- Calculate percent contribution of each sales channel per region and year
- Compare it to the previous year using LAG
- Ensure correct rounding and avoid NULLs for 1999 by including 1998 data
*/

WITH base AS (
    /* 
    Base aggregation at country region / year / channel level.
    Percent-of-total is calculated using a window SUM over the same region and year.
    */
    SELECT
        co.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold,
        100.0 * SUM(s.amount_sold)
            / SUM(SUM(s.amount_sold)) OVER (
                PARTITION BY co.country_region, t.calendar_year
            ) AS pct_by_channels
    FROM sh.sales s
    JOIN sh.customers cu ON s.cust_id = cu.cust_id
    JOIN sh.countries co ON cu.country_id = co.country_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    WHERE
        t.calendar_year BETWEEN 1998 AND 2001
        AND LOWER(co.country_region) IN ('americas', 'asia', 'europe')
    GROUP BY
        co.country_region,
        t.calendar_year,
        ch.channel_desc
),
with_prev AS (
    /*
    LAG is applied per region and channel to fetch
    the previous year's percent value.
    Including 1998 ensures that 1999 has a valid previous period.
    */
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
    ROUND(pct_by_channels, 2) AS "% BY CHANNELS",
    ROUND(pct_prev_period, 2) AS "% PREVIOUS PERIOD",
    /* 
    Percent difference is calculated after rounding
    to avoid floating-point precision issues
    (e.g. 11.9 - 10.35 = 1.55)
    */
    ROUND(
        ROUND(pct_by_channels, 2) - ROUND(pct_prev_period, 2),
        2
    ) AS "% DIFF"
FROM with_prev
WHERE calendar_year BETWEEN 1999 AND 2001
ORDER BY
    country_region,
    calendar_year,
    channel_desc;
/*
Task 2
-------
Purpose:
- Calculate cumulative sales per week
- Calculate a centered 3-day moving average
- Include weeks 48 and 52 in calculations but exclude them from final output
*/

WITH daily_sales AS (
    /*
    Sales are aggregated at day level.
    Weeks 48–52 are included so boundary days
    (week 49 Monday and week 51 Sunday)
    have complete centered windows.
    */
    SELECT
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE
        t.calendar_year = 1999
        AND t.calendar_week_number BETWEEN 48 AND 52
    GROUP BY
        t.calendar_week_number,
        t.time_id,
        t.day_name
),
with_cum AS (
    /*
    Cumulative sum is calculated within each calendar week,
    ordered by time_id to preserve daily sequence.
    */
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
    /*
    Centered 3-day moving average:
    - ROWS frame is used because we need exactly
      one previous and one following row (day),
      regardless of date gaps.
    */
    ROUND(
        AVG(sales) OVER (
            ORDER BY time_id
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ),
        2
    ) AS centered_3_day_avg
FROM with_cum
WHERE calendar_week_number BETWEEN 49 AND 51
ORDER BY
    calendar_week_number,
    time_id;
/*
ROWS frame is used because the requirement is based on
a fixed number of rows (last 3 days),
not on calendar intervals.
This ensures consistent results even if dates are missing.
*/

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
/*
RANGE frame is used because the window is defined
by calendar time (7 days), not by row count.
This correctly accounts for missing dates
and uneven data distribution.
*/

SELECT
    t.time_id,
    t.day_name,
    SUM(s.amount_sold) AS daily_sales,
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.time_id
        RANGE BETWEEN INTERVAL '6' DAY PRECEDING AND CURRENT ROW
    ) AS sales_last_7_calendar_days
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
GROUP BY
    t.time_id,
    t.day_name
ORDER BY
    t.time_id;
/*
GROUPS frame is used because calculations must operate
on logical peer groups (promotion categories),
not individual rows.
This guarantees that entire promotion groups
are included in the aggregation.
*/

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
