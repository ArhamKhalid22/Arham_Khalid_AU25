/* TASK 1 STRATEGY: 
   1. Use a Common Table Expression (CTE) 'sales_summary' to pre-calculate all aggregations.
      This separates the complex math from the final filtering, making the code readable.
   2. Use Window Functions (SUM() OVER) to get the channel total without a self-join.
   3. Use ROW_NUMBER() to handle the "Top 5" requirement. This is safer than LIMIT
      because it works correctly per-group (channel), whereas LIMIT is global.
*/

WITH sales_summary AS (
    SELECT 
        s.channel_id,
        c.channel_desc,
        cu.cust_id,
        cu.cust_last_name,
        cu.cust_first_name,
        
        -- Aggregation: Total sales per customer
        SUM(s.amount_sold) AS customer_sales,

        -- WINDOW FUNCTION: Calculate the total for the WHOLE channel in the same row.
        -- PARTITION BY channel_id resets the sum for every new channel.
        -- Default frame (unbounded) is used implicitly here to sum everything in the partition.
        SUM(SUM(s.amount_sold)) OVER (PARTITION BY s.channel_id) AS total_channel_sales,

        -- RANKING: Assign a rank (1, 2, 3...) to customers based on their sales.
        -- We do this here so we can filter by "rn <= 5" in the final SELECT.
        ROW_NUMBER() OVER (
            PARTITION BY s.channel_id 
            ORDER BY SUM(s.amount_sold) DESC
        ) AS rn

    FROM sh.sales s
    JOIN sh.channels c ON s.channel_id = c.channel_id
    JOIN sh.customers cu ON s.cust_id = cu.cust_id
    GROUP BY 
        s.channel_id, c.channel_desc, cu.cust_id, cu.cust_last_name, cu.cust_first_name
)
SELECT
    channel_desc,
    cust_last_name,
    cust_first_name,
    ROUND(customer_sales, 2) AS total_sales,
    
    -- KPI CALCULATION: Now simple arithmetic because both values exist in the row.
    CONCAT(ROUND((customer_sales / total_channel_sales) * 100, 4), '%') AS sales_percentage
FROM sales_summary
WHERE rn <= 5 -- Filter for Top 5 ONLY after the ranking is calculated
ORDER BY 
    channel_desc,
    customer_sales DESC;

	
	/* TASK 2 STRATEGY:
   1. The 'crosstab' function requires two queries:
      - Source SQL: The raw data (must return 3 columns: RowID, Category, Value).
      - Category SQL: The list of columns to create (Q1, Q2, Q3, Q4).
   2. Explicitly cast columns to NUMERIC in the final definition list to match data types.
   3. NULL Handling: The crosstab function returns NULL if a quarter has no sales.
      We must use COALESCE(..., 0) inside the YEAR_SUM calculation, otherwise
      (100 + NULL) results in NULL, destroying the total.
*/

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT
    ct.prod_name,
    ROUND(COALESCE(ct.q1, 0), 2) AS q1,
    ROUND(COALESCE(ct.q2, 0), 2) AS q2,
    ROUND(COALESCE(ct.q3, 0), 2) AS q3,
    ROUND(COALESCE(ct.q4, 0), 2) AS q4,
    ROUND(
        COALESCE(ct.q1, 0) +
        COALESCE(ct.q2, 0) +
        COALESCE(ct.q3, 0) +
        COALESCE(ct.q4, 0),
        2
    ) AS year_sum
FROM crosstab(
    $$
        SELECT 
            p.prod_id,
            p.prod_name,
            'Q' || t.calendar_quarter_number AS quarter_label,
            SUM(s.amount_sold) AS quarter_sales
        FROM sh.sales s
        JOIN sh.products  p  ON s.prod_id = p.prod_id
        JOIN sh.times     t  ON s.time_id = t.time_id
        JOIN sh.customers cu ON s.cust_id = cu.cust_id
        JOIN sh.countries co ON cu.country_id = co.country_id
        WHERE LOWER(p.prod_category) = LOWER('Photo')
          AND t.calendar_year = 2000
          AND UPPER(co.country_region) = UPPER('Asia')
        GROUP BY
            p.prod_id,
            p.prod_name,
            t.calendar_quarter_number
        ORDER BY
            p.prod_id,
            t.calendar_quarter_number
    $$,
    $$ VALUES ('Q1'), ('Q2'), ('Q3'), ('Q4') $$
) AS ct(
    prod_id   INTEGER,
    prod_name TEXT,
    q1 NUMERIC,
    q2 NUMERIC,
    q3 NUMERIC,
    q4 NUMERIC
)
ORDER BY year_sum DESC;

/* TASK 3 STRATEGY:
   1. Optimization: Isolate the "Top 300 Customers" first using a CTE. 
      This prevents us from carrying heavy text data (names, channel desc) 
      through the sorting process.
   2. The main query then acts as a report generator, simply looking up details 
      for the IDs found in the CTE.
*/
WITH total_pool AS (
    -- Step 1: Calculate total sales for the pool of years
    SELECT 
        s.cust_id,
        SUM(s.amount_sold) as total_combined_sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY s.cust_id
),
top_300_ids AS (
    -- Step 2: Rank them and pick the top 300
    SELECT cust_id
    FROM (
        SELECT cust_id, 
               ROW_NUMBER() OVER (ORDER BY total_combined_sales DESC) as rn
        FROM total_pool
    )
    WHERE rn <= 300
)
-- Step 3: Final Report
SELECT 
    ch.channel_desc,
    c.cust_id,
    c.cust_last_name,
    c.cust_first_name,
    ROUND(SUM(s.amount_sold), 2) AS amount_sold
FROM sh.sales s
JOIN sh.customers c  ON s.cust_id = c.cust_id
JOIN sh.channels ch  ON s.channel_id = ch.channel_id
JOIN sh.times t      ON s.time_id = t.time_id
WHERE s.cust_id IN (SELECT cust_id FROM top_300_ids) -- Filter by our Top 300 list
  AND t.calendar_year IN (1998, 1999, 2001)         -- Only report these years
GROUP BY 
    ch.channel_desc,
    c.cust_id,
    c.cust_last_name,
    c.cust_first_name
ORDER BY 
    amount_sold DESC;

/* TASK 4 STRATEGY:
   1. Use Conditional Aggregation ("Pivoting with CASE").
      Instead of grouping by region (which puts regions in rows), we group by 
      Month and Category, and "manually" place the sales into columns based on region.
   2. This avoids the complexity of 'crosstab' when you only have 2 static columns.
   3. Use TO_CHAR for the formatting requirement (commas in numbers).
*/

SELECT
    t.calendar_month_desc,
    p.prod_category,
    -- Column 1: If region is Americas, add amount, else add 0.
    TO_CHAR(SUM(CASE WHEN co.country_region = 'Americas' THEN s.amount_sold ELSE 0 END), '999,999,999') AS "Americas SALES",
    -- Column 2: If region is Europe, add amount, else add 0.
    TO_CHAR(SUM(CASE WHEN co.country_region = 'Europe' THEN s.amount_sold ELSE 0 END), '999,999,999') AS "Europe SALES"
FROM sh.sales s
JOIN sh.products p ON s.prod_id = p.prod_id
JOIN sh.times t ON s.time_id = t.time_id
JOIN sh.customers c ON s.cust_id = c.cust_id
JOIN sh.countries co ON c.country_id = co.country_id
WHERE t.calendar_year = 2000
  AND t.calendar_month_number IN (1, 2, 3)
  -- Optimization: Filter source rows early so we don't process Asia/Africa data unnecessarily
  AND co.country_region IN ('Americas', 'Europe')
GROUP BY 
    t.calendar_month_desc, 
    p.prod_category
ORDER BY 
    t.calendar_month_desc, 

    p.prod_category;

