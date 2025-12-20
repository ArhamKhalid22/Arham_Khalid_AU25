-- =========================================================
-- TASK 1: Create View 'sales_revenue_by_category_qtr'
-- =========================================================

DROP VIEW IF EXISTS public.sales_revenue_by_category_qtr;

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales_revenue
FROM public.payment p
JOIN public.rental r ON p.rental_id = r.rental_id
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film_category fc ON i.film_id = fc.film_id
JOIN public.category c ON fc.category_id = c.category_id
WHERE 
    -- Condition: Check if Quarter and Year match the current date
    EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
    AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC;

-- =========================================================
-- TASK 2: SQL Function 'get_sales_revenue_by_category_qtr'
-- =========================================================

DROP FUNCTION IF EXISTS public.get_sales_revenue_by_category_qtr(date);

CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_choose_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    category TEXT,
    total_sales_revenue NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
        c.name AS category,
        SUM(p.amount) AS total_sales_revenue
    FROM public.payment p
    JOIN public.rental r        ON p.rental_id = r.rental_id
    JOIN public.inventory i     ON r.inventory_id = i.inventory_id
    JOIN public.film_category fc ON i.film_id = fc.film_id
    JOIN public.category c      ON fc.category_id = c.category_id
    WHERE 
        EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM p_choose_date)
        AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM p_choose_date)
    GROUP BY c.name
    HAVING SUM(p.amount) > 0
    ORDER BY total_sales_revenue DESC;
$$;

-- =========================================================
-- TASK 3: Function 'most_popular_film_by_country'
-- =========================================================

DROP FUNCTION IF EXISTS public.most_popular_film_by_country(TEXT);

CREATE OR REPLACE FUNCTION public.most_popular_film_by_country(
    p_country TEXT
)
RETURNS TABLE(
    country TEXT,
    film TEXT,
    rating TEXT,
    language TEXT,
    length INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country_exists BOOLEAN;
BEGIN
    -- Validate input
    IF p_country IS NULL OR TRIM(p_country) = '' THEN
        RAISE EXCEPTION 'Country name cannot be NULL or empty.';
    END IF;

    -- Check if country exists
    SELECT EXISTS (
        SELECT 1 FROM public.country WHERE country ILIKE p_country
    ) INTO v_country_exists;

    IF NOT v_country_exists THEN
        RAISE NOTICE 'Country "%" does not exist in the database.', p_country;
        RAISE EXCEPTION 'Invalid country: "%".', p_country;
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            co.country AS country_col,
            f.title AS film_col,
            f.rating::TEXT AS rating_col,
            l.name::TEXT AS language_col,    
            f.length AS length_col,
            f.release_year AS release_year_col,
            COUNT(*) AS rental_count,
            ROW_NUMBER() OVER (
                PARTITION BY co.country
                ORDER BY COUNT(*) DESC
            ) AS rn
        FROM public.rental r
        JOIN public.inventory i ON r.inventory_id = i.inventory_id
        JOIN public.film f ON f.film_id = i.film_id
        JOIN public.language l ON l.language_id = f.language_id
        JOIN public.customer cu ON cu.customer_id = r.customer_id
        JOIN public.address a ON a.address_id = cu.address_id
        JOIN public.city ci ON ci.city_id = a.city_id
        JOIN public.country co ON co.country_id = ci.country_id
        WHERE co.country ILIKE p_country     
        GROUP BY co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT
        country_col,
        film_col,
        rating_col,
        language_col,
        length_col,
        release_year_col
    FROM ranked
    WHERE rn = 1
    ORDER BY country_col;

    IF NOT FOUND THEN
        RAISE NOTICE 'Country "%" exists but has no rental records.', p_country;
        RAISE EXCEPTION 'No rental information found for country "%".', p_country;
    END IF;
END;
$$;

-- =========================================================
-- TASK 4: Function 'films_in_stock_by_title' (CORRECTED)
-- =========================================================
-- 1. Uses DISTINCT ON to return one row per film.
-- 2. Sorts by rental_date DESC to get the latest rental.
-- 3. Explicit public schemas.

DROP FUNCTION IF EXISTS public.films_in_stock_by_title(TEXT);

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(
    p_pattern TEXT
)
RETURNS TABLE(
    row_num BIGINT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    rec RECORD;
    has_results BOOLEAN := FALSE;
BEGIN
    IF p_pattern IS NULL OR TRIM(p_pattern) = '' THEN
        RAISE EXCEPTION 'Search pattern cannot be NULL or empty.';
    END IF;

    FOR rec IN
        SELECT DISTINCT ON (f.title)
            ROW_NUMBER() OVER (ORDER BY f.title) AS rn,
            f.title AS film_title,
            l.name::TEXT AS lang_name,
            CONCAT(cu.first_name, ' ', cu.last_name) AS cust_name,
            r.rental_date
        FROM public.film f
        JOIN public.language l ON l.language_id = f.language_id
        JOIN public.inventory i ON i.film_id = f.film_id
        LEFT JOIN public.rental r ON r.inventory_id = i.inventory_id 
        LEFT JOIN public.customer cu ON cu.customer_id = r.customer_id
        WHERE f.title ILIKE p_pattern
          -- Check: Total Inventory > Active Rentals
          AND (
              SELECT COUNT(i2.inventory_id)
              FROM public.inventory i2
              WHERE i2.film_id = f.film_id
          ) > (
              SELECT COUNT(r2.rental_id)
              FROM public.rental r2
              JOIN public.inventory i2 ON r2.inventory_id = i2.inventory_id
              WHERE i2.film_id = f.film_id
                AND r2.return_date IS NULL
          )
        -- Order by title (for DISTINCT) and rental_date DESC (for latest rental)
        ORDER BY f.title, r.rental_date DESC
    LOOP
        row_num       := rec.rn;
        film_title    := rec.film_title;
        language      := rec.lang_name;
        customer_name := rec.cust_name;
        rental_date   := rec.rental_date;

        has_results := TRUE;
        RETURN NEXT;
    END LOOP;

    IF NOT FOUND THEN
        row_num       := 1;
        film_title    := 'No films in stock matching pattern: ' || p_pattern;
        language      := NULL;
        customer_name := NULL;
        rental_date   := NULL;
        RETURN NEXT;
    END IF;
END;
$$;

-- =========================================================
-- TASK 5: Procedure 'new_movie'
-- =========================================================

-- 1. Helper block to ensure language exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.language WHERE TRIM(name) ILIKE 'Klingon') THEN
        INSERT INTO public.language (name, last_update) VALUES ('Klingon', NOW());
    END IF;
END $$;

DROP FUNCTION IF EXISTS public.new_movie(TEXT, INT, TEXT);

CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_lang_id INT;
    v_film_id INT;
BEGIN
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be empty.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.film WHERE title ILIKE p_title) THEN
        RAISE NOTICE 'Movie "%" already exists. Skipping insertion.', p_title;
        RETURN;
    END IF;

    SELECT language_id INTO v_lang_id 
    FROM public.language 
    WHERE TRIM(name) ILIKE TRIM(p_language_name)
    LIMIT 1;
    
    IF v_lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in the language table.', p_language_name;
    END IF;

    SELECT COALESCE(MAX(film_id), 0) + 1 INTO v_film_id FROM public.film;

    INSERT INTO public.film (
        film_id, title, description, release_year, language_id, original_language_id, 
        rental_duration, rental_rate, length, replacement_cost, rating, last_update, 
        special_features, fulltext
    )
    VALUES (
        v_film_id, p_title, NULL, p_release_year, v_lang_id, NULL, 
        3, 4.99, NULL, 19.99, 'G'::mpaa_rating, NOW(), NULL, to_tsvector(p_title)
    );

    RAISE NOTICE 'Success: New movie "%" inserted with ID %.', p_title, v_film_id;
END;
$$;

-- =========================================================
-- TASK 6.2: Fix 'rewards_report'
-- =========================================================
-- Question: Why does ‘rewards_report’ return 0 rows?
-- Answer: The default function uses 'CURRENT_DATE' to calculate the reporting period. 
-- Since the Sakila database contains sample data from 2005-2006, running the function 
-- in the current year looks for data that doesn't exist.
-- Fix: Hardcode the date to '2006-06-01' (or similar) to capture the historical data.

CREATE OR REPLACE FUNCTION public.rewards_report(
    min_monthly_purchases INTEGER, 
    min_dollar_amount_purchased NUMERIC
)
RETURNS SETOF public.customer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
    rr RECORD;
    tmpSQL TEXT;
BEGIN
    -- FIXED: Anchor date to historical data
    last_month_start := DATE '2006-05-01';
    last_month_start := last_month_start - '3 month'::INTERVAL;
    last_month_end := DATE '2006-05-01';

    tmpSQL := 'SELECT c.*
               FROM public.payment p
               INNER JOIN public.customer c ON p.customer_id = c.customer_id
               WHERE p.payment_date >= '''|| last_month_start ||'''
               AND p.payment_date < '''|| last_month_end ||'''
               GROUP BY c.customer_id
               HAVING COUNT(p.payment_id) > '|| min_monthly_purchases ||'
               AND SUM(p.amount) > '|| min_dollar_amount_purchased;

    FOR rr IN EXECUTE tmpSQL LOOP
        RETURN NEXT rr;
    END LOOP;

    RETURN;
END;
$$;

-- =========================================================
-- TASK 6.4: Update 'get_customer_balance'
-- =========================================================
-- Added logic: If film is more than RENTAL_DURATION * 2 overdue, charge REPLACEMENT_COST.

CREATE OR REPLACE FUNCTION public.get_customer_balance(
    p_customer_id INT, 
    p_effective_date TIMESTAMP
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_rentfees NUMERIC;
    v_overfees INTEGER;
    v_payments NUMERIC;
BEGIN
    -- 1. Calculate Rent Fees
    SELECT COALESCE(SUM(f.rental_rate),0) INTO v_rentfees
    FROM public.film f
    JOIN public.inventory i ON f.film_id = i.film_id
    JOIN public.rental r ON i.inventory_id = r.inventory_id
    WHERE r.rental_date <= p_effective_date
      AND r.customer_id = p_customer_id;

    -- 2. Calculate Overdue Fees (UPDATED LOGIC HERE)
    SELECT COALESCE(SUM(
        CASE 
            WHEN (r.return_date - r.rental_date) > (f.rental_duration * '1 day'::interval) THEN
                EXTRACT(DAY FROM (r.return_date - r.rental_date) - (f.rental_duration * '1 day'::interval))
            ELSE 0 
        END 
        + 
        -- NEW CONDITION: Charge Replacement Cost if Overdue > Rental Duration * 2
        CASE
            WHEN (EXTRACT(DAY FROM (COALESCE(r.return_date, p_effective_date) - r.rental_date)) > f.rental_duration * 2) 
            THEN f.replacement_cost 
            ELSE 0 
        END
    ),0) INTO v_overfees
    FROM public.rental r
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    WHERE r.rental_date <= p_effective_date
      AND r.customer_id = p_customer_id;

    -- 3. Calculate Payments
    SELECT COALESCE(SUM(amount),0) INTO v_payments
    FROM public.payment
    WHERE payment_date <= p_effective_date
      AND customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END;
$$;
