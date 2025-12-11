
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

-- SOLUTION 1.1.2: SUBQUERY (IN Clause)
-- Pros: Decouples category filtering from film logic.
-- Cons: Performance can vary if subquery returns a massive list.
SELECT
    f.title
FROM
    public.film AS f
INNER JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
WHERE
    fc.category_id IN (
        SELECT category_id
        FROM public.category
        WHERE LOWER(name) = 'animation'
    )
    AND f.release_year BETWEEN 2017 AND 2019
    AND f.rental_rate > 1
ORDER BY
    f.title;

-- SOLUTION 1.1.3: CTE
-- Pros: Very readable, defines the specific category subset first.
-- Cons: Slightly more code for a simple filter.
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


----------------------------------------------------------------------------------------
-- TASK 1.2: Store Revenue after March 2017
-- Logic: Calculate sum of payments per store for payments made >= '2017-04-01'.
----------------------------------------------------------------------------------------

-- SOLUTION 1.2.1: INNER JOIN
-- Pros: Single pass aggregation.
-- Cons: Complex join chain.
SELECT
    st.store_id,
    CONCAT_WS(', ', a.address, a.address2) AS store_address,
    SUM(p.amount) AS revenue
FROM
    public.payment AS p
INNER JOIN
    public.rental AS r ON p.rental_id = r.rental_id
INNER JOIN
    public.inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN
    public.store AS st ON i.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
WHERE
    p.payment_date >= '2017-04-01'
GROUP BY
    st.store_id, a.address, a.address2
ORDER BY
    revenue DESC;

-- SOLUTION 1.2.2: SUBQUERY (FROM Clause)
-- Pros: Pre-aggregates payment data (reducing rows) before joining metadata.
-- Cons: Nested logic logic.
SELECT
    st.store_id,
    CONCAT_WS(', ', a.address, a.address2) AS store_address,
    sub.revenue
FROM
    (SELECT
        i.store_id,
        SUM(p.amount) AS revenue
     FROM
        public.payment AS p
     INNER JOIN
        public.rental AS r ON p.rental_id = r.rental_id
     INNER JOIN
        public.inventory AS i ON r.inventory_id = i.inventory_id
     WHERE
        p.payment_date >= '2017-04-01'
     GROUP BY
        i.store_id
    ) AS sub
INNER JOIN
    public.store AS st ON sub.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    sub.revenue DESC;

-- SOLUTION 1.2.3: CTE
-- Pros: Cleanest separation of calculation vs formatting.
-- Cons: None.
WITH store_revenue AS (
    SELECT
        i.store_id,
        SUM(p.amount) AS total_revenue
    FROM
        public.payment AS p
    INNER JOIN
        public.rental AS r ON p.rental_id = r.rental_id
    INNER JOIN
        public.inventory AS i ON r.inventory_id = i.inventory_id
    WHERE
        p.payment_date >= '2017-04-01'
    GROUP BY
        i.store_id
)
SELECT
    sr.store_id,
    CONCAT_WS(', ', a.address, a.address2) AS store_address,
    sr.total_revenue AS revenue
FROM
    store_revenue AS sr
INNER JOIN
    public.store AS st ON sr.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    revenue DESC;


----------------------------------------------------------------------------------------
-- TASK 1.3: Top 5 Actors by Movies (Released > 2015)
-- Logic: Count films per actor where release_year > 2015, show top 5.
----------------------------------------------------------------------------------------

-- SOLUTION 1.3.1: INNER JOIN
-- Pros: Simple, combines filtering and aggregation.
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
FETCH FIRST 5 ROWS ONLY;

-- SOLUTION 1.3.2: SUBQUERY (FROM Clause)
-- Pros: Counts on ID level first (faster), then joins details.
SELECT
    a.first_name,
    a.last_name,
    sub.movie_count AS number_of_movies
FROM
    (SELECT
        fa.actor_id,
        COUNT(f.film_id) AS movie_count
     FROM
        public.film_actor AS fa
     INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
     WHERE
        f.release_year > 2015
     GROUP BY
        fa.actor_id
    ) AS sub
INNER JOIN
    public.actor AS a ON sub.actor_id = a.actor_id
ORDER BY
    number_of_movies DESC
FETCH FIRST 5 ROWS ONLY;

-- SOLUTION 1.3.3: CTE
-- Pros: Highly readable, separates "Target Film Logic" from "Actor Details".
WITH recent_actor_counts AS (
    SELECT
        fa.actor_id,
        COUNT(fa.film_id) AS number_of_movies
    FROM
        public.film_actor AS fa
    INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
    WHERE
        f.release_year > 2015
    GROUP BY
        fa.actor_id
)
SELECT
    a.first_name,
    a.last_name,
    rac.number_of_movies
FROM
    public.actor AS a
INNER JOIN
    recent_actor_counts AS rac ON a.actor_id = rac.actor_id
ORDER BY
    rac.number_of_movies DESC
FETCH FIRST 5 ROWS ONLY;


-- TASK 1.4: Genre Production Trends (Pivot)
-- Logic: Count Drama, Travel, Documentary movies per year (columns).

-- SOLUTION 1.4.1: JOIN (Conditional Aggregation)
-- Pros: Most efficient standard way to pivot.
SELECT
    f.release_year,
    COUNT(CASE WHEN LOWER(c.name) = 'drama' THEN f.film_id END) AS number_of_drama_movies,
    COUNT(CASE WHEN LOWER(c.name) = 'travel' THEN f.film_id END) AS number_of_travel_movies,
    COUNT(CASE WHEN LOWER(c.name) = 'documentary' THEN f.film_id END) AS number_of_documentary_movies
FROM
    public.film AS f
LEFT JOIN
    public.film_category AS fc ON f.film_id = fc.film_id
LEFT JOIN
    public.category AS c ON fc.category_id = c.category_id
GROUP BY
    f.release_year
ORDER BY
    f.release_year DESC;

-- SOLUTION 1.4.2: CTE
-- Pros: Separates data preparation (Join) from pivoting (Aggregation).
WITH film_data AS (
    SELECT
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
    fd.release_year,
    COUNT(CASE WHEN LOWER(fd.category_name) = 'drama' THEN 1 END) AS number_of_drama_movies,
    COUNT(CASE WHEN LOWER(fd.category_name) = 'travel' THEN 1 END) AS number_of_travel_movies,
    COUNT(CASE WHEN LOWER(fd.category_name) = 'documentary' THEN 1 END) AS number_of_documentary_movies
FROM
    film_data AS fd
GROUP BY
    fd.release_year
ORDER BY
    fd.release_year DESC;

-- SOLUTION 1.4.3: CORRELATED SUBQUERY
-- Pros: Valid alternative syntax.
-- Cons: VERY Poor performance (N+1 query problem). Not recommended for production.
SELECT
    f_outer.release_year,
    (SELECT COUNT(*) FROM public.film f
     JOIN public.film_category fc ON f.film_id = fc.film_id
     JOIN public.category c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'drama' AND f.release_year = f_outer.release_year) AS number_of_drama_movies,
    (SELECT COUNT(*) FROM public.film f
     JOIN public.film_category fc ON f.film_id = fc.film_id
     JOIN public.category c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'travel' AND f.release_year = f_outer.release_year) AS number_of_travel_movies,
    (SELECT COUNT(*) FROM public.film f
     JOIN public.film_category fc ON f.film_id = fc.film_id
     JOIN public.category c ON fc.category_id = c.category_id
     WHERE LOWER(c.name) = 'documentary' AND f.release_year = f_outer.release_year) AS number_of_documentary_movies
FROM
    (SELECT DISTINCT release_year FROM public.film) AS f_outer
ORDER BY
    f_outer.release_year DESC;


 -- PART 2: HR & MANAGEMENT

----------------------------------------------------------------------------------------
-- TASK 2.1: Top 3 Employees by Revenue (2017)
-- Logic: Sum payment amount by staff_id for 2017. Link to store table for "last store".
----------------------------------------------------------------------------------------

-- SOLUTION 2.1.1: INNER JOIN
-- Pros: Straightforward.
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
    total_revenue_2017 DESC
FETCH FIRST 3 ROWS ONLY;

-- SOLUTION 2.1.2: SUBQUERY
-- Pros: Aggregates first (efficient on large transaction tables).
SELECT
    s.first_name,
    s.last_name,
    staff_rev.total_revenue AS total_revenue_2017,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM
    (SELECT
        staff_id,
        SUM(amount) AS total_revenue
     FROM
        public.payment
     WHERE
        EXTRACT(YEAR FROM payment_date) = 2017
     GROUP BY
        staff_id
    ) AS staff_rev
INNER JOIN
    public.staff AS s ON staff_rev.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    total_revenue_2017 DESC
FETCH FIRST 3 ROWS ONLY;

-- SOLUTION 2.1.3: CTE
-- Pros: Best readability.
WITH revenue_per_staff AS (
    SELECT
        staff_id,
        SUM(amount) AS total_revenue
    FROM
        public.payment
    WHERE
        EXTRACT(YEAR FROM payment_date) = 2017
    GROUP BY
        staff_id
)
SELECT
    s.first_name,
    s.last_name,
    rps.total_revenue AS total_revenue_2017,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM
    revenue_per_staff AS rps
INNER JOIN
    public.staff AS s ON rps.staff_id = s.staff_id
INNER JOIN
    public.store AS st ON s.store_id = st.store_id
INNER JOIN
    public.address AS a ON st.address_id = a.address_id
ORDER BY
    rps.total_revenue DESC
FETCH FIRST 3 ROWS ONLY;


-- TASK 2.2: Top 5 Movies by Rentals & Audience Age
-- Logic: Count rentals per film. Map MPAA rating to Age description.


-- SOLUTION 2.2.1: JOIN
-- Pros: Standard approach.
SELECT
    f.title,
    COUNT(r.rental_id) AS number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (<13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only'
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
FETCH FIRST 5 ROWS ONLY;

-- SOLUTION 2.2.2: SUBQUERY
-- Pros: Counts rentals on inventory side first.
SELECT
    f.title,
    sub.rental_count AS number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (<13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only'
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
    ) AS sub
INNER JOIN
    public.film AS f ON sub.film_id = f.film_id
ORDER BY
    number_of_rentals DESC
FETCH FIRST 5 ROWS ONLY;

-- SOLUTION 2.2.3: CTE
-- Pros: Separates counting logic from display logic (CASE statement).
WITH film_rentals AS (
    SELECT
        i.film_id,
        COUNT(r.rental_id) AS cnt
    FROM
        public.rental AS r
    INNER JOIN
        public.inventory AS i ON r.inventory_id = i.inventory_id
    GROUP BY
        i.film_id
)
SELECT
    f.title,
    fr.cnt AS number_of_rentals,
    CASE f.rating
        WHEN 'G' THEN 'G – General Audiences (All ages admitted)'
        WHEN 'PG' THEN 'PG – Parental Guidance Suggested'
        WHEN 'PG-13' THEN 'PG-13 – Parents Strongly Cautioned (<13)'
        WHEN 'R' THEN 'R – Restricted (Under 17 requires parent)'
        WHEN 'NC-17' THEN 'NC-17 – Adults Only'
        ELSE 'Not Rated'
    END AS expected_audience
FROM
    film_rentals AS fr
INNER JOIN
    public.film AS f ON fr.film_id = f.film_id
ORDER BY
    number_of_rentals DESC
FETCH FIRST 5 ROWS ONLY;


-- PART 3: COMPLEX ANALYSIS (ACTOR INACTIVITY)


-- TASK 3 (V1): Gap (Current Date - Last Release)
-- Logic: Current Year - MAX(release_year) per actor.

-- SOLUTION 3.V1.1: JOIN
-- Pros: Concise.
SELECT
    a.first_name,
    a.last_name,
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

-- SOLUTION 3.V1.2: SUBQUERY
-- Pros: Separates max date calculation.
SELECT
    a.first_name,
    a.last_name,
    EXTRACT(YEAR FROM CURRENT_DATE) - sub.max_year AS inactivity_gap_years
FROM
    public.actor AS a
INNER JOIN
    (SELECT
        fa.actor_id,
        MAX(f.release_year) AS max_year
     FROM
        public.film_actor AS fa
     INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
     GROUP BY
        fa.actor_id
    ) AS sub ON a.actor_id = sub.actor_id
ORDER BY
    inactivity_gap_years DESC;

-- SOLUTION 3.V1.3: CTE
-- Pros: Cleanest structure.
WITH actor_last_year AS (
    SELECT
        fa.actor_id,
        MAX(f.release_year) AS last_release
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
    EXTRACT(YEAR FROM CURRENT_DATE) - aly.last_release AS inactivity_gap_years
FROM
    public.actor AS a
INNER JOIN
    actor_last_year AS aly ON a.actor_id = aly.actor_id
ORDER BY
    inactivity_gap_years DESC;


-- TASK 3 (V2): Max Gap Between Sequential Films
-- Logic: Find the sequential difference between movie years without Window Functions.
-- Method: For every year X, find MIN(Year) where Year > X.

-- SOLUTION 3.V2.1: CTE (Simulating LEAD)
-- Pros: Breaks down complex "Next Value" logic into steps. Readable.
WITH actor_film_years AS (
    -- Step 1: Distinct Actor/Year pairs
    SELECT DISTINCT
        fa.actor_id,
        f.release_year
    FROM
        public.film_actor AS fa
    INNER JOIN
        public.film AS f ON fa.film_id = f.film_id
),
year_pairs AS (
    -- Step 2: Find the "Next" year for every current year using correlated logic
    SELECT
        t1.actor_id,
        t1.release_year AS current_year,
        (SELECT MIN(t2.release_year)
         FROM actor_film_years AS t2
         WHERE t2.actor_id = t1.actor_id
           AND t2.release_year > t1.release_year
        ) AS next_year
    FROM
        actor_film_years AS t1
)
SELECT
    a.first_name,
    a.last_name,
    MAX(yp.next_year - yp.current_year) AS max_gap
FROM
    year_pairs AS yp
INNER JOIN
    public.actor AS a ON yp.actor_id = a.actor_id
WHERE
    yp.next_year IS NOT NULL
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap DESC;

-- SOLUTION 3.V2.2: SELF-JOIN
-- Pros: Uses standard Join logic (theta join).
-- Cons: Heavy performance cost on large datasets due to inequalities in join conditions.
SELECT
    a.first_name,
    a.last_name,
    MAX(t2.release_year - t1.release_year) AS max_gap
FROM
    (SELECT DISTINCT actor_id, release_year FROM public.film_actor JOIN public.film USING(film_id)) AS t1
INNER JOIN
    (SELECT DISTINCT actor_id, release_year FROM public.film_actor JOIN public.film USING(film_id)) AS t2
    ON t1.actor_id = t2.actor_id
    AND t1.release_year < t2.release_year
-- Ensure t2 is the IMMEDIATE next film (no t3 in between)
WHERE NOT EXISTS (
    SELECT 1
    FROM (SELECT DISTINCT actor_id, release_year FROM public.film_actor JOIN public.film USING(film_id)) AS t3
    WHERE t3.actor_id = t1.actor_id
      AND t3.release_year > t1.release_year
      AND t3.release_year < t2.release_year
)
INNER JOIN
    public.actor AS a ON t1.actor_id = a.actor_id
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap DESC;

-- SOLUTION 3.V2.3: NESTED SUBQUERIES
-- Pros: Works on very old SQL versions (pre-CTE).
-- Cons: Extremely hard to read/debug.
SELECT
    a.first_name,
    a.last_name,
    MAX(pairs.next_year - pairs.curr_year) AS max_gap
FROM
    public.actor AS a
INNER JOIN
    (SELECT
        main.actor_id,
        main.release_year AS curr_year,
        (SELECT MIN(sub.release_year)
         FROM (SELECT DISTINCT fa.actor_id, f.release_year
               FROM public.film_actor fa JOIN public.film f ON fa.film_id = f.film_id) sub
         WHERE sub.actor_id = main.actor_id AND sub.release_year > main.release_year
        ) AS next_year
     FROM
        (SELECT DISTINCT fa.actor_id, f.release_year
         FROM public.film_actor fa JOIN public.film f ON fa.film_id = f.film_id) main
    ) AS pairs ON a.actor_id = pairs.actor_id
WHERE
    pairs.next_year IS NOT NULL
GROUP BY
    a.actor_id, a.first_name, a.last_name
ORDER BY
    max_gap DESC;