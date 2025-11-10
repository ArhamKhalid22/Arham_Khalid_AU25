--PART 1
--task 1
SELECT
    f.title
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN
    public.category AS c ON fc.category_id = c.category_id
WHERE
    LOWER(c.name) = 'animation'
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;

	
SELECT
    f.title
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
WHERE
    fc.category_id = (
        SELECT category_id
        FROM public.category
        WHERE LOWER(name) = 'animation'
    )
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;

	WITH animation_category AS (
    SELECT category_id
    FROM public.category
    WHERE LOWER(name) = 'animation'
)

SELECT
    f.title
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN
    animation_category AS ac ON fc.category_id = ac.category_id
WHERE
    f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;


-- TASK 2

SELECT
    st.store_id,
    CONCAT_WS(', ', a.address, a.address2) AS store_address,
    SUM(p.amount) AS revenue
FROM public.payment   AS p
JOIN public.rental    AS r ON p.rental_id = r.rental_id
JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
JOIN public.store     AS st ON i.store_id = st.store_id
JOIN public.address   AS a ON st.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'    -- explicit: since April 2017
GROUP BY st.store_id, a.address, a.address2
ORDER BY revenue DESC;
WITH store_revenue AS (
    SELECT
        i.store_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment   AS p
    JOIN public.rental    AS r ON p.rental_id = r.rental_id
    JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
)
SELECT
    sr.store_id,
    CONCAT_WS(', ', a.address, a.address2) AS store_address,
    sr.total_revenue AS revenue
FROM store_revenue AS sr
JOIN public.store   AS st ON sr.store_id = st.store_id
JOIN public.address AS a ON st.address_id = a.address_id
ORDER BY revenue DESC;

--TASK 3

SELECT
    a.first_name,
    a.last_name,
    COUNT(f.film_id) AS number_of_movies
FROM
    public.actor AS a
INNER JOIN
    public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN
    public.film AS f ON fa.film_id = f.film_id
WHERE
    f.release_year > 2015 -- Films released *after* 2015
GROUP BY
    a.actor_id,  -- Group by ID for accuracy
    a.first_name,
    a.last_name
ORDER BY
    number_of_movies DESC
-- Use the SQL-standard FETCH clause as requested
FETCH FIRST 5 ROWS ONLY; 

--TASK 4


-- Solution 1.4.1: JOIN (with Conditional Aggregation)
-- This is the most efficient and standard way to pivot data in SQL.
-- We join all tables and use a single GROUP BY.

SELECT
    f.release_year,
    COUNT(CASE WHEN LOWER(c.name) = 'drama' THEN f.film_id ELSE NULL END) AS number_of_drama_movies,
    COUNT(CASE WHEN LOWER(c.name) = 'travel' THEN f.film_id ELSE NULL END) AS number_of_travel_movies,
    COUNT(CASE WHEN LOWER(c.name) = 'documentary' THEN f.film_id ELSE NULL END) AS number_of_documentary_movies
FROM
    public.film AS f
LEFT JOIN -- Use LEFT JOIN to include years that might not have these categories
    public.film_category AS fc ON f.film_id = fc.film_id
LEFT JOIN
    public.category AS c ON fc.category_id = c.category_id
GROUP BY
    f.release_year
ORDER BY
    f.release_year DESC;

/*
Advantages/Disadvantages (JOIN):
* Readability: High, once you understand the conditional aggregation pattern.
* Performance: Excellent. The database scans the tables once and performs
    a single aggregation.
* Complexity: Medium. The `CASE` statements can look complex to a beginner.
*/

-- Solution 1.4.2: Subquery (Correlated)
-- This solution groups by release year from the `film` table, and then uses
-- three separate correlated subqueries to count films for each category.

SELECT
    f_main.release_year,
    (SELECT COUNT(f.film_id)
     FROM public.film AS f
     JOIN public.film_category AS fc ON f.film_id = fc.film_id
     JOIN public.category AS c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'drama' AND f.release_year = f_main.release_year
    ) AS number_of_drama_movies,
    (SELECT COUNT(f.film_id)
     FROM public.film AS f
     JOIN public.film_category AS fc ON f.film_id = fc.film_id
     JOIN public.category AS c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'travel' AND f.release_year = f_main.release_year
    ) AS number_of_travel_movies,
    (SELECT COUNT(f.film_id)
     FROM public.film AS f
     JOIN public.film_category AS fc ON f.film_id = fc.film_id
     JOIN public.category AS c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'documentary' AND f.release_year = f_main.release_year
    ) AS number_of_documentary_movies
FROM
    public.film AS f_main
GROUP BY
    f_main.release_year
ORDER BY
    f_main.release_year DESC;

/*
Advantages/Disadvantages (Correlated Subquery):
* Readability: Low. The query is very repetitive and hard to read.
* Performance: Extremely poor. This will run 3 full subqueries *for every
    distinct release year*.
* Resource Usage: Very high. Do not use this in production.
*/

-- Solution 1.4.3: CTE
-- This solution uses a CTE to pre-join films and categories, then
-- performs the conditional aggregation on the CTE.

WITH film_with_category AS (
    SELECT
        f.film_id,
        f.release_year,
        c.name AS category_name
    FROM
        public.film AS f
    LEFT JOIN
        public.film_category AS fc ON f.film_id = fc.film_id
    LEFT JOIN
        public.category AS c ON fc.category_id = c.category_id
)
SELECT
    fwc.release_year,
    COUNT(CASE WHEN LOWER(fwc.category_name) = 'drama' THEN fwc.film_id ELSE NULL END) AS number_of_drama_movies,
    COUNT(CASE WHEN LOWER(fwc.category_name) = 'travel' THEN fwc.film_id ELSE NULL END) AS number_of_travel_movies,
    COUNT(CASE WHEN LOWER(fwc.category_name) = 'documentary' THEN fwc.film_id ELSE NULL END) AS number_of_documentary_movies
FROM
    film_with_category AS fwc
GROUP BY
    fwc.release_year
ORDER BY
    fwc.release_year DESC;


/*Advantages/Disadvantages (CTE):
* Readability: Good. It separates the "data prep" (joining) from the
    "analysis" (pivoting/aggregation).
* Performance: Good. The optimizer will likely "inline" the CTE and
    execute a plan identical to the simple JOIN (Solution 1.4.1).
* Complexity: Medium. Slightly more verbose than the JOIN solution.
*/ 

/************************************************************************************************/
/* PART 2                                             */
/************************************************************************************************/

--------------------------------------------------------------------------------------------------
-- TASK 2.1: The HR department aims to reward top-performing employees in 2017.
-- Show which three employees generated the most revenue in 2017?


-- Solution 2.1.1: JOIN
-- Joins all tables first, filters by date, then groups by employee and store.

SELECT
    s.first_name,
    s.last_name,
    SUM(p.amount) AS total_revenue_2017,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM
    public.payment AS p
INNER JOIN
    public.staff AS s ON p.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
WHERE
    EXTRACT(YEAR FROM p.payment_date) = 2017
GROUP BY
    s.staff_id, s.first_name, s.last_name, st.store_id, a.address, a.address2
ORDER BY
    total_revenue_2017 DESC,
    s.last_name ASC,
    s.first_name ASC
FETCH FIRST 3 ROWS ONLY;

/*
Advantages/Disadvantages (JOIN):
* Readability: Good. Clear logic flow.
* Performance: Good, but the WHERE clause with EXTRACT() is not sargable,
    meaning it may not use an index on payment_date as efficiently as a
    date range check.
* Complexity: Low.
*/

-- Solution 2.1.2: Subquery (in FROM clause)
-- Uses a subquery to first calculate 2017 revenue for each `staff_id`,
-- then joins this result to get names and addresses.

SELECT
    s.first_name,
    s.last_name,
    staff_revenue.total_revenue AS total_revenue_2017,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM
    (SELECT
         p.staff_id,
         SUM(p.amount) AS total_revenue
     FROM
         public.payment AS p
     WHERE
         EXTRACT(YEAR FROM p.payment_date) = 2017
     GROUP BY
         p.staff_id
    ) AS staff_revenue
INNER JOIN
    public.staff AS s ON staff_revenue.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    total_revenue_2017 DESC,
    s.last_name ASC,
    s.first_name ASC
FETCH FIRST 3 ROWS ONLY;

/*
Advantages/Disadvantages (Subquery):
* Readability: Good. Clearly separates aggregation from joining metadata.
* Performance: Very good. Aggregates on the large `payment` table first,
    creating a very small result set to join. The non-sargable WHERE clause
    is applied during this initial aggregation.
* Complexity: Medium.
*/

-- Solution 2.1.3: CTE
-- Uses a CTE to calculate 2017 revenue per `staff_id`. This is the most
-- readable version, logically identical to the subquery solution.

WITH staff_revenue_2017 AS (
    SELECT
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM
        public.payment AS p
    WHERE
        EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY
        p.staff_id
)
SELECT
    s.first_name,
    s.last_name,
    sr.total_revenue AS total_revenue_2017,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM
    staff_revenue_2017 AS sr
INNER JOIN
    public.staff AS s ON sr.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    total_revenue_2017 DESC,
    s.last_name ASC,
    s.first_name ASC
FETCH FIRST 3 ROWS ONLY;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. The steps are named and clear.
* Performance: Very good. Same benefits as the `FROM` subquery.
* Complexity: Medium.
*/


--Solution 2.2.1: JOIN
-- Joins all tables, then groups, counts, and maps the rating.

SELECT
    f.title,
    COUNT(r.rental_id) AS number_of_rentals,
    f.rating,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (Inappropriate for <13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only (No one 17 and under)'
        ELSE 'Not Rated'
    END AS expected_audience
FROM
    public.rental AS r
INNER JOIN
    public.inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN
    public.film AS f ON i.film_id = f.film_id
GROUP BY
    f.film_id, f.title, f.rating
ORDER BY
    number_of_rentals DESC
LIMIT 5;

/*
Advantages/Disadvantages (JOIN):
* Readability: Good. It's a standard aggregation query. The `CASE`
    statement is verbose but clear.
* Performance: Good.
* Complexity: Low-to-Medium, only due to the `CASE` statement.
*/

-- Solution 2.2.2: Subquery (in FROM clause)
-- Uses a subquery to first count rentals per `film_id`, then joins to `film`
-- to get the title and rating.

SELECT
    f.title,
    film_rentals.rental_count AS number_of_rentals,
    f.rating,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (Inappropriate for <13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only (No one 17 and under)'
        ELSE 'Not Rated'
    END AS expected_audience
FROM
    (SELECT
         i.film_id,
         COUNT(r.rental_id) AS rental_count
     FROM
         public.rental AS r
     INNER JOIN
         public.inventory AS i ON r.inventory_id = i.inventory_id
     GROUP BY
         i.film_id
    ) AS film_rentals
INNER JOIN
    public.film AS f ON film_rentals.film_id = f.film_id
ORDER BY
    number_of_rentals DESC
LIMIT 5;

/*
Advantages/Disadvantages (Subquery):
* Readability: Good. Separates aggregation (counting rentals) from
    metadata lookup (getting title/rating).
* Performance: Very good. Aggregates on `rental`/`inventory` first,
    then joins the smaller result set to `film`.
* Complexity: Medium.
*/

-- Solution 2.2.3: CTE
-- Uses a CTE to count rentals per `film_id`, making the main query very clean.
-- Logically identical to the subquery solution.

WITH film_rental_counts AS (
    SELECT
        i.film_id,
        COUNT(r.rental_id) AS number_of_rentals
    FROM
        public.rental AS r
    INNER JOIN
        public.inventory AS i ON r.inventory_id = i.inventory_id
    GROUP BY
        i.film_id
)
SELECT
    f.title,
    frc.number_of_rentals,
    f.rating,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (Inappropriate for <13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only (No one 17 and under)'
        ELSE 'Not Rated'
    END AS expected_audience
FROM
    film_rental_counts AS frc
INNER JOIN
    public.film AS f ON frc.film_id = f.film_id
ORDER BY
    frc.number_of_rentals DESC
LIMIT 5;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. The best readability of the three.
* Performance: Very good. Same benefits as the subquery solution.
* Complexity: Medium.
*/

/************************************************************************************************/
/* PART 3                                             */
/************************************************************************************************/

--------------------------------------------------------------------------------------------------
-- TASK 3 (V1): Which actors/actresses didn't act for a longer period of time?
-- V1: gap between the latest release_year and current year per each actor;
--------------------------------------------------------------------------------------------------

-- Business Logic:
-- 1. Join `actor` -> `film_actor` -> `film`.
-- 2. Group by actor (`actor_id`, `first_name`, `last_name`).
-- 3. Find the `MAX(f.release_year)` for each actor.
-- 4. Calculate the gap: `CURRENT_DATE`'s year - `MAX(f.release_year)`.
-- 5. Sort by this gap in descending order.

-- Solution 3.V1.1: JOIN
-- The most straightforward approach.

SELECT
    a.first_name,
    a.last_name,
    MAX(f.release_year) AS latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year) AS inactivity_gap_years
FROM
    public.actor AS a
INNER JOIN
    public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN
    public.film AS f ON fa.film_id = f.film_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    inactivity_gap_years DESC;

/*
Advantages/Disadvantages (JOIN):
* Readability: High.
* Performance: Good. Standard aggregation.
* Complexity: Low.
*/

-- Solution 3.V1.2: Subquery (Correlated)
-- Selects from `actor` and uses a correlated subquery to find the max
-- release year for each actor.

SELECT
    a.first_name,
    a.last_name,
    (SELECT MAX(f.release_year)
     FROM public.film AS f
     INNER JOIN public.film_actor AS fa ON f.film_id = fa.film_id
     WHERE fa.actor_id = a.actor_id
    ) AS latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - (SELECT MAX(f.release_year)
                                       FROM public.film AS f
                                       INNER JOIN public.film_actor AS fa ON f.film_id = fa.film_id
                                       WHERE fa.actor_id = a.actor_id
                                      ) AS inactivity_gap_years
FROM
    public.actor AS a
ORDER BY
    inactivity_gap_years DESC;

/*
Advantages/Disadvantages (Correlated Subquery):
* Readability: Low. Repetitive and inefficient.
* Performance: Poor. Executes the subquery for every actor.
* Complexity: High.
*/

-- Solution 3.V1.3: CTE
-- Uses a CTE to first find the max release year per `actor_id`, then
-- joins to `actor` to get the names.

WITH actor_latest_film AS (
    SELECT
        fa.actor_id,
        MAX(f.release_year) AS latest_release_year
    FROM
        public.film_actor AS fa
    INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
    GROUP BY
        fa.actor_id
)
SELECT
    a.first_name,
    a.last_name,
    alf.latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - alf.latest_release_year AS inactivity_gap_years
FROM
    public.actor AS a
INNER JOIN
    actor_latest_film AS alf ON a.actor_id = alf.actor_id
ORDER BY
    inactivity_gap_years DESC;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. Clearly separates aggregation from metadata lookup.
* Performance: Very good. Aggregates first on the mapping/film tables.
* Complexity: Low-to-Medium.
*/

--------------------------------------------------------------------------------------------------
-- TASK 3 (V2): Which actors/actresses didn't act for a longer period of time?
-- V2: gaps between sequential films per each actor;
-- (Note: This is a complex task without window functions)
--------------------------------------------------------------------------------------------------

-- Business Logic:
-- 1. Find all *distinct* `(actor_id, release_year)` pairs.
-- 2. For each pair (e.g., `(actor_id, year1)`), we must find the *next*
--    sequential release year (e.g., `year2`) for that same actor.
-- 3. `year2` is the `MIN(release_year)` for that actor where `release_year > year1`.
-- 4. Calculate the gap: `year2 - year1`.
-- 5. Find the `MAX(gap)` for each actor.

-- Solution 3.V2.1: CTE
-- This is the most readable solution, breaking the problem into logical steps.

WITH actor_film_years AS (
    -- Step 1: Get distinct years for each actor
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM
        public.film_actor AS fa
    INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
),
actor_year_pairs AS (
    -- Step 2: For each year, find the *next* year using a correlated subquery
    SELECT
        afy1.actor_id,
        afy1.release_year AS current_year,
        (SELECT MIN(afy2.release_year)
         FROM actor_film_years AS afy2
         WHERE afy2.actor_id = afy1.actor_id
           AND afy2.release_year > afy1.release_year
        ) AS next_year
    FROM
        actor_film_years AS afy1
),
actor_gaps AS (
    -- Step 3: Calculate the gap for each pair
    SELECT
        actor_id,
        next_year - current_year AS gap
    FROM
        actor_year_pairs
    WHERE
        next_year IS NOT NULL -- Exclude the last film for each actor
)
-- Step 4: Find the max gap for each actor and get their name
SELECT
    a.first_name,
    a.last_name,
    MAX(ag.gap) AS max_gap_between_films
FROM
    actor_gaps AS ag
INNER JOIN
    public.actor AS a ON ag.actor_id = a.actor_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap_between_films DESC;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. This is the only truly maintainable solution
    for such a complex problem without window functions.
* Performance: Good. The logic is sequential and clear to the optimizer.
* Complexity: High (due to the problem), but the CTE makes it manageable.
*/

-- Solution 3.V2.2: Subquery (Nested)
-- This solution nests the logic from the CTE solution into `FROM` subqueries.
-- It is extremely difficult to read.

SELECT
    a.first_name,
    a.last_name,
    MAX(gaps.gap) AS max_gap_between_films
FROM
    public.actor AS a
INNER JOIN
    ( -- Step 3: Calculate gap
      SELECT
        actor_id,
        next_year - current_year AS gap
      FROM
        ( -- Step 2: Find next year
          SELECT
            afy1.actor_id,
            afy1.release_year AS current_year,
            (SELECT MIN(afy2.release_year)
             FROM (SELECT DISTINCT fa.actor_id, f.release_year
                   FROM public.film_actor AS fa
                   INNER JOIN public.film AS f ON fa.film_id = f.film_id
                  ) AS afy2 -- Step 1 (inside subquery)
             WHERE afy2.actor_id = afy1.actor_id
               AND afy2.release_year > afy1.release_year
            ) AS next_year
          FROM
            (SELECT DISTINCT fa.actor_id, f.release_year
             FROM public.film_actor AS fa
             INNER JOIN public.film AS f ON fa.film_id = f.film_id
            ) AS afy1 -- Step 1 (main)
        ) AS year_pairs
      WHERE
        year_pairs.next_year IS NOT NULL
    ) AS gaps ON a.actor_id = gaps.actor_id -- Step 4: Join to Actor
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap_between_films DESC;

/*
Advantages/Disadvantages (Subquery):
* Readability: Extremely low. This is "write-only" code, very hard to debug.
* Performance: Likely similar to the CTE, but harder for the optimizer
    (and humans) to parse.
* Complexity: Very High.
*/

-- Solution 3.V2.3: JOIN (Self-Join "Gap-and-Islands")
-- This solution uses a classic "find the next row" pattern with a
-- triple self-join on the distinct years list.

WITH actor_film_years AS (
    -- Step 1: Get distinct years for each actor
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM
        public.film_actor AS fa
    INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
)
-- Step 2: Find gaps
SELECT
    a.first_name,
    a.last_name,
    MAX(afy2.release_year - afy1.release_year) AS max_gap_between_films
FROM
    actor_film_years AS afy1
-- Join to all *potential* next years (afy2)
INNER JOIN
    actor_film_years AS afy2 ON afy1.actor_id = afy2.actor_id
                           AND afy1.release_year < afy2.release_year
-- LEFT JOIN to find any year (afy3) *between* afy1 and afy2
LEFT JOIN
    actor_film_years AS afy3 ON afy1.actor_id = afy3.actor_id
                           AND afy3.release_year > afy1.release_year
                           AND afy3.release_year < afy2.release_year
INNER JOIN
    public.actor AS a ON afy1.actor_id = a.actor_id
WHERE
    afy3.actor_id IS NULL -- The magic: keep only afy2 where no "in-between" year (afy3) was found
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap_between_films DESC;

/*
Advantages/Disadvantages (JOIN):
* Readability: Low. This is a very "clever" but non-intuitive SQL pattern.
    Hard to understand without prior knowledge.
* Performance: Can be very poor on large datasets due to the
    complex three-way self-join (a "theta-join").
* Complexity: Very High.
*/