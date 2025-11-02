/************************************************************************************************/
/* PART 1                                             */
/************************************************************************************************/

--------------------------------------------------------------------------------------------------
-- TASK 1.1: The marketing team needs a list of animation movies between 2017 and 2019
-- to promote family-friendly content. Show all animation movies released during this
-- period with rate more than 1, sorted alphabetically.
--------------------------------------------------------------------------------------------------

-- Business Logic: To find "animation movies", we must join the `film` table with the
-- `category` table via the `film_category` mapping table. We then filter this joined
-- result based on three criteria:
-- 1. The category name is 'Animation'.
-- 2. The film's release year is between 2017 and 2019 (inclusive).
-- 3. The film's rental rate is greater than 1.
-- Finally, we sort the results alphabetically by the film's title.

-- Solution 1.1.1: JOIN
-- This is the most direct and common solution, joining all three tables
-- and applying all filters in the WHERE clause.

SELECT
    f.title,
    f.release_year,
    f.rental_rate,
    c.name AS category_name
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN
    public.category AS c ON fc.category_id = c.category_id
WHERE
    c.name = 'Animation'
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;

/*
Advantages/Disadvantages (JOIN):
* Readability: High for anyone familiar with SQL JOINs. It's a very standard pattern.
* Performance: Generally very good. The query optimizer can easily create an
    efficient execution plan, likely starting from the small 'category' table.
* Complexity: Low. It's a straightforward query.
*/

-- Solution 1.1.2: Subquery
-- This solution uses a subquery in the WHERE clause to find the `category_id`
-- for 'Animation' first, then joins `film` and `film_category`.

SELECT
    f.title,
    f.release_year,
    f.rental_rate
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
WHERE
    fc.category_id = (SELECT category_id FROM public.category WHERE name = 'Animation')
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;

/*
Advantages/Disadvantages (Subquery):
* Readability: Can be slightly less readable than a direct JOIN, as the logic
    is split between the main query and the subquery.
* Performance: For a simple lookup like this, the optimizer will likely
    rewrite it as an INNER JOIN, resulting in identical performance.
* Limitations: Less flexible if you needed to select data *from* the category table
    (like the category_name) without joining it again.
*/

-- Solution 1.1.3: CTE (Common Table Expression)
-- This solution uses a CTE to first define the 'Animation' category,
-- and then joins it in the main query.

WITH animation_category AS (
    SELECT category_id
    FROM public.category
    WHERE name = 'Animation'
)
SELECT
    f.title,
    f.release_year,
    f.rental_rate,
    'Animation' AS category_name -- We can hardcode this as we filtered in the CTE
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

/*
Advantages/Disadvantages (CTE):
* Readability: High, arguably the highest for complex queries. It breaks
    the logic into named, sequential steps ("first, find the category, then find the films").
* Performance: Good. Modern query planners optimize CTEs well, often
    inlining them like a subquery or join.
* Complexity: Slightly more verbose for a simple query, but invaluable for
    multi-step logic.
*/

--------------------------------------------------------------------------------------------------
-- TASK 1.2: The finance department requires a report on store performance.
-- Calculate the revenue earned by each rental store after March 2017 (since April)
-- (include columns: address and address2 – as one column, revenue).
--------------------------------------------------------------------------------------------------

-- Business Logic: To calculate revenue per store, we must sum the `amount` from the
-- `payment` table. We link a payment to a store via the `staff` table
-- (`payment.staff_id` -> `staff.staff_id` -> `staff.store_id`).
-- We then join to the `store` and `address` tables to get the store's address.
-- We filter payments to include only those *after* '2017-03-31'.
-- Finally, we group by the store's concatenated address and sum the payments.

-- Solution 1.2.1: JOIN
-- This solution joins all required tables and performs a GROUP BY
-- on the final concatenated address string.

SELECT
    CONCAT(a.address, ', ', a.address2) AS store_address,
    SUM(p.amount) AS revenue
FROM
    public.payment AS p
INNER JOIN
    public.staff AS s ON p.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
WHERE
    p.payment_date > '2017-03-31'
GROUP BY
    store_address
ORDER BY
    revenue DESC;

/*
Advantages/Disadvantages (JOIN):
* Readability: Good. It's a clear chain of joins from payment to address.
* Performance: Efficient. The database can filter payments by date first,
    then perform the joins and aggregation on a smaller dataset.
* Complexity: Low.
*/

-- Solution 1.2.2: Subquery (Correlated)
-- This solution selects from the `store` and `address` tables, and then uses a
-- correlated subquery in the SELECT list to calculate the revenue for each store.

SELECT
    CONCAT(a.address, ', ', a.address2) AS store_address,
    (SELECT SUM(p.amount)
     FROM public.payment AS p
     INNER JOIN public.staff AS s ON p.staff_id = s.staff_id
     WHERE s.store_id = st.store_id
       AND p.payment_date > '2017-03-31'
    ) AS revenue
FROM
    public.store AS st
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    revenue DESC;

/*
Advantages/Disadvantages (Correlated Subquery):
* Readability: Can be less readable, as the core logic (summing revenue)
    is "hidden" inside the SELECT list.
* Performance: Often very poor. The subquery is executed *for each row*
    in the outer query (for each store). This is much less efficient than the JOIN.
* Complexity: High.
*/

-- Solution 1.2.3: CTE
-- This solution uses a CTE to first calculate the revenue for each `store_id`.
-- The main query then joins this aggregated data to the `store` and `address`
-- tables to get the address details.

WITH store_revenue AS (
    SELECT
        s.store_id,
        SUM(p.amount) AS total_revenue
    FROM
        public.payment AS p
    INNER JOIN
        public.staff AS s ON p.staff_id = s.staff_id
    WHERE
        p.payment_date > '2017-03-31'
    GROUP BY
        s.store_id
)
SELECT
    CONCAT(a.address, ', ', a.address2) AS store_address,
    sr.total_revenue AS revenue
FROM
    store_revenue AS sr
INNER JOIN
    public.store AS st ON sr.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    revenue DESC;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. It clearly separates the two main steps:
    1. Calculate revenue per store ID.
    2. Get address details for those stores.
* Performance: Very good. The optimizer will aggregate in the CTE first,
    creating a small result set to join against.
* Complexity: Low-to-Medium. More verbose than the JOIN, but much clearer.
*/

--------------------------------------------------------------------------------------------------
-- TASK 1.3: The marketing department aims to identify the most successful actors
-- since 2015. Show top-5 actors by number of movies (released after 2015) they
-- took part in (columns: first_name, last_name, number_of_movies,
-- sorted by number_of_movies in descending order).
--------------------------------------------------------------------------------------------------

-- Business Logic: We need to count films for each actor.
-- 1. Join `actor` -> `film_actor` -> `film`.
-- 2. Filter the `film` table for `release_year > 2015` *before* counting.
-- 3. Group by actor (`actor_id`, `first_name`, `last_name`) and count the films.
-- 4. Order by the count in descending order.
-- 5. Take the top 5 results using `LIMIT 5`.

-- Solution 1.3.1: JOIN
-- The standard approach: join all three tables, filter by year,
-- then group, count, order, and limit.

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
    f.release_year > 2015
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    number_of_movies DESC
LIMIT 5;

/*
Advantages/Disadvantages (JOIN):
* Readability: High. This is a very standard "top N" query.
* Performance: Good. The `WHERE` clause reduces the number of films
    to be considered before the `GROUP BY` operation.
* Complexity: Low.
*/

-- Solution 1.3.2: Subquery (in FROM clause)
-- This solution uses a subquery in the `FROM` clause to first create a
-- temporary table of "recent films", then joins it.

SELECT
    a.first_name,
    a.last_name,
    COUNT(recent_films.film_id) AS number_of_movies
FROM
    public.actor AS a
INNER JOIN
    public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN
    (SELECT film_id
     FROM public.film
     WHERE release_year > 2015
    ) AS recent_films ON fa.film_id = recent_films.film_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    number_of_movies DESC
LIMIT 5;

/*
Advantages/Disadvantages (Subquery):
* Readability: Good. It logically isolates the "recent films" criteria.
* Performance: Good. The optimizer will treat this very similarly
    to the CTE or simple JOIN solution.
* Complexity: Low-to-Medium. Slightly more complex than the simple JOIN.
*/

-- Solution 1.3.3: CTE
-- This solution uses a CTE to create a named "virtual table" of recent films,
-- which makes the main query very clean.

WITH recent_films AS (
    SELECT film_id
    FROM public.film
    WHERE release_year > 2015
)
SELECT
    a.first_name,
    a.last_name,
    COUNT(rf.film_id) AS number_of_movies
FROM
    public.actor AS a
INNER JOIN
    public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN
    recent_films AS rf ON fa.film_id = rf.film_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    number_of_movies DESC
LIMIT 5;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. The logic is very clear:
    1. Define "recent_films".
    2. Count those films for each actor.
* Performance: Good, effectively identical to the Subquery solution.
* Complexity: Low-to-Medium.
*/

--------------------------------------------------------------------------------------------------
-- TASK 1.4: The marketing team needs to track production trends. Show number of
-- Drama, Travel, and Documentary films per year. (columns: release_year,
-- number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies),
-- sorted by release year in descending order. Dealing with NULL values is encouraged.
--------------------------------------------------------------------------------------------------

-- Business Logic: This requires a "pivot". We need to turn rows of category data
-- into columns.
-- 1. Get all films and their release years from the `film` table.
-- 2. `LEFT JOIN` to `film_category` and `category` to get category names.
-- 3. Group the results by `release_year`.
-- 4. Use "conditional aggregation" (e.g., `COUNT(CASE ...)` or `SUM(CASE ...)`)
--    to count films *only* if their category name matches 'Drama', 'Travel',
--    or 'Documentary'.
-- 5. Using `COUNT(CASE ... ELSE NULL END)` or `SUM(CASE ... ELSE 0 END)`
--    handles the "NULL values" (shows 0 instead of NULL).
-- 6. Sort by `release_year` descending.

-- Solution 1.4.1: JOIN (with Conditional Aggregation)
-- This is the most efficient and standard way to pivot data in SQL.
-- We join all tables and use a single GROUP BY.

SELECT
    f.release_year,
    COUNT(CASE WHEN c.name = 'Drama' THEN f.film_id ELSE NULL END) AS number_of_drama_movies,
    COUNT(CASE WHEN c.name = 'Travel' THEN f.film_id ELSE NULL END) AS number_of_travel_movies,
    COUNT(CASE WHEN c.name = 'Documentary' THEN f.film_id ELSE NULL END) AS number_of_documentary_movies
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
     WHERE c.name = 'Drama' AND f.release_year = f_main.release_year
    ) AS number_of_drama_movies,
    (SELECT COUNT(f.film_id)
     FROM public.film AS f
     JOIN public.film_category AS fc ON f.film_id = fc.film_id
     JOIN public.category AS c ON fc.category_id = c.category_id
     WHERE c.name = 'Travel' AND f.release_year = f_main.release_year
    ) AS number_of_travel_movies,
    (SELECT COUNT(f.film_id)
     FROM public.film AS f
     JOIN public.film_category AS fc ON f.film_id = fc.film_id
     JOIN public.category AS c ON fc.category_id = c.category_id
     WHERE c.name = 'Documentary' AND f.release_year = f_main.release_year
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
    COUNT(CASE WHEN fwc.category_name = 'Drama' THEN fwc.film_id ELSE NULL END) AS number_of_drama_movies,
    COUNT(CASE WHEN fwc.category_name = 'Travel' THEN fwc.film_id ELSE NULL END) AS number_of_travel_movies,
    COUNT(CASE WHEN fwc.category_name = 'Documentary' THEN fwc.film_id ELSE NULL END) AS number_of_documentary_movies
FROM
    film_with_category AS fwc
GROUP BY
    fwc.release_year
ORDER BY
    fwc.release_year DESC;

/*
Advantages/Disadvantages (CTE):
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
-- Assumptions:
--  - staff could work in several stores... indicate... the last one
--  - if staff processed the payment then he works in the same store
--  - take into account only payment_date
--------------------------------------------------------------------------------------------------

-- Business Logic: We interpret "last store" as the `store_id` currently assigned
-- to the employee in the `staff` table (`staff.store_id`).
-- 1. Filter the `payment` table for all payments where `payment_date` is in 2017.
-- 2. Group these payments by `staff_id` to `SUM(amount)` and get total revenue per employee.
-- 3. Join this aggregated data with `staff` (for name), `store` (for `store_id`),
--    and `address` (for store address).
-- 4. Order by the total revenue descending and `LIMIT 3`.

-- Solution 2.1.1: JOIN
-- Joins all tables first, filters by date, then groups by employee and store.

SELECT
    s.first_name,
    s.last_name,
    SUM(p.amount) AS total_revenue_2017,
    CONCAT(a.address, ', ', a.address2) AS last_store_address
FROM
    public.payment AS p
INNER JOIN
    public.staff AS s ON p.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
WHERE
    p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
GROUP BY
    s.staff_id, s.first_name, s.last_name, last_store_address
ORDER BY
    total_revenue_2017 DESC
LIMIT 3;

/*
Advantages/Disadvantages (JOIN):
* Readability: Good. Clear logic flow.
* Performance: Good. The date filter will be applied early.
* Complexity: Low.
*/

-- Solution 2.1.2: Subquery (in FROM clause)
-- Uses a subquery to first calculate 2017 revenue for each `staff_id`,
-- then joins this result to get names and addresses.

SELECT
    s.first_name,
    s.last_name,
    staff_revenue.total_revenue AS total_revenue_2017,
    CONCAT(a.address, ', ', a.address2) AS last_store_address
FROM
    (SELECT
         p.staff_id,
         SUM(p.amount) AS total_revenue
     FROM
         public.payment AS p
     WHERE
         p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
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
    total_revenue_2017 DESC
LIMIT 3;

/*
Advantages/Disadvantages (Subquery):
* Readability: Good. Clearly separates aggregation from joining metadata.
* Performance: Very good. Aggregates on the large `payment` table first,
    creating a very small result set (only a few staff) to join.
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
        p.payment_date >= '2017-01-01' AND p.payment_date < '2018-01-01'
    GROUP BY
        p.staff_id
)
SELECT
    s.first_name,
    s.last_name,
    sr.total_revenue AS total_revenue_2017,
    CONCAT(a.address, ', ', a.address2) AS last_store_address
FROM
    staff_revenue_2017 AS sr
INNER JOIN
    public.staff AS s ON sr.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    total_revenue_2017 DESC
LIMIT 3;

/*
Advantages/Disadvantages (CTE):
* Readability: Excellent. The steps are named and clear.
* Performance: Very good. Same logic as the `FROM` subquery.
* Complexity: Medium.
*/

--------------------------------------------------------------------------------------------------
-- TASK 2.2: The management team wants to identify the most popular movies.
-- Show which 5 movies were rented more than others (number of rentals), and
-- what's the expected age of the audience for these movies?
-- Use 'Motion Picture Association film rating system' descriptions.
--------------------------------------------------------------------------------------------------

-- Business Logic:
-- 1. "Most rented" means we must count rows in the `rental` table.
-- 2. Join `rental` -> `inventory` -> `film` to link rentals to film titles.
-- 3. Group by `film_id`, `title`, and `rating`.
-- 4. Count the rentals (`COUNT(r.rental_id)`).
-- 5. Use a `CASE` statement in the `SELECT` list to map the `film.rating`
--    column ('G', 'PG', etc.) to the long-form descriptions provided.
-- 6. Order by the rental count descending and `LIMIT 5`.

-- Solution 2.2.1: JOIN
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