
-- =============================================
-- TASK 1: Create View 'sales_revenue_by_category_qtr'
-- =============================================

DROP VIEW IF EXISTS public.sales_revenue_by_category_qtr;

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film_category fc ON i.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE 
    -- Condition 1: Check if the Quarter matches the current quarter
    EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
    -- Condition 2: Explicitly check if the Year matches the current year
    AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC;

-- Verification
SELECT * FROM public.sales_revenue_by_category_qtr;



-- TASK 2: SQL Function

DROP FUNCTION IF EXISTS public.get_sales_revenue_by_category_qtr(date);


CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_choose_date DATE DEFAULT CURRENT_DATE     -- Input date representing year + quarter
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
    FROM payment p
    JOIN rental r       ON p.rental_id = r.rental_id
    JOIN inventory i    ON r.inventory_id = i.inventory_id
    JOIN film_category fc ON i.film_id = fc.film_id
    JOIN category c     ON fc.category_id = c.category_id
    WHERE 
        -- Match YEAR of the payment with the YEAR of the chosen date
        EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM p_choose_date)

        -- Match QUARTER of the payment with the QUARTER of the chosen date
        AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM p_choose_date)

    GROUP BY c.name
    HAVING SUM(p.amount) > 0                     -- Only include categories with sales
    ORDER BY total_sales_revenue DESC;           -- High-to-low revenue
$$;

SELECT * FROM public.get_sales_revenue_by_category_qtr('2005-05-01');

-- task 3

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
    IF p_country IS NULL OR TRIM(p_country) = '' THEN
        RAISE EXCEPTION 'Country name cannot be NULL or empty.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM country
        WHERE country ILIKE p_country
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
        FROM rental r
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON f.film_id = i.film_id
        JOIN language l ON l.language_id = f.language_id
        JOIN customer cu ON cu.customer_id = r.customer_id
        JOIN address a ON a.address_id = cu.address_id
        JOIN city ci ON ci.city_id = a.city_id
        JOIN country co ON co.country_id = ci.country_id
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

    -- If no rentals found but country exists
    IF NOT FOUND THEN
        RAISE NOTICE 'Country "%" exists but has no rental records.', p_country;
        RAISE EXCEPTION 'No rental information found for country "%".', p_country;
    END IF;

END;
$$;

SELECT * FROM core.most_popular_films_by_countries(
    ARRAY['franCe', 'Brazil', 'united states']
);

--task 4

DROP FUNCTION IF EXISTS core.films_in_stock_by_title(TEXT);

CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(
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
    -- Validate input
    IF p_pattern IS NULL OR TRIM(p_pattern) = '' THEN
        RAISE EXCEPTION 'Search pattern cannot be NULL or empty.';
    END IF;

    -- Main loop returning each matching record
    FOR rec IN
        SELECT
            ROW_NUMBER() OVER (ORDER BY f.title, i.inventory_id) AS rn,
            f.title AS film_title,
            l.name::TEXT AS lang_name,    -- FIX: CAST TO TEXT
            CONCAT(cu.first_name, ' ', cu.last_name) AS cust_name,
            r.rental_date
        FROM film f
        JOIN language l ON l.language_id = f.language_id
        JOIN inventory i ON i.film_id = f.film_id
        LEFT JOIN rental r  
               ON r.inventory_id = i.inventory_id 
              AND r.return_date IS NULL
        LEFT JOIN customer cu 
               ON cu.customer_id = r.customer_id
        WHERE f.title ILIKE p_pattern

          -- Stock check: at least one unrented copy available
          AND EXISTS (
                SELECT 1
                FROM inventory i2
                LEFT JOIN rental r2
                       ON r2.inventory_id = i2.inventory_id
                      AND r2.return_date IS NULL
                WHERE i2.film_id = f.film_id
                GROUP BY i2.film_id
                HAVING COUNT(r2.inventory_id) < COUNT(i2.inventory_id)
          )
        ORDER BY f.title, i.inventory_id
    LOOP
        -- Assign results
        row_num       := rec.rn;
        film_title    := rec.film_title;
        language      := rec.lang_name;
        customer_name := rec.cust_name;
        rental_date   := rec.rental_date;

        has_results := TRUE;
        RETURN NEXT;
    END LOOP;

    -- No films returned – return message row
    IF NOT has_results THEN
        row_num       := 1;
        film_title    := 'No films in stock matching pattern: ' || p_pattern;
        language      := NULL;
        customer_name := NULL;
        rental_date   := NULL;
        RETURN NEXT;
    END IF;

END;
$$;
SELECT * FROM core.films_in_stock_by_title('%xyzxyz%');
SELECT * FROM core.films_in_stock_by_title('%love%') LIMIT 5;

-- TASK 5: Procedure to Insert a New Movie
-- =============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.language WHERE TRIM(name) ILIKE 'Klingon') THEN
        INSERT INTO public.language (name, last_update) VALUES ('Klingon', NOW());
    END IF;
END $$;

-- 2. Cleanup
DROP FUNCTION IF EXISTS public.new_movie(TEXT, INT, TEXT);

-- 3. Create Function
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
    -- A. Validate Title
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be empty.';
    END IF;

    -- B. Check for Duplicates
    IF EXISTS (SELECT 1 FROM public.film WHERE title ILIKE p_title) THEN
        RAISE NOTICE 'Movie "%" already exists. Skipping insertion.', p_title;
        RETURN;
    END IF;

    -- C. Validate Language & Get ID (Fixes "Language Not Found" error)
    SELECT language_id INTO v_lang_id 
    FROM public.language 
    WHERE TRIM(name) ILIKE TRIM(p_language_name)
    LIMIT 1;
    
    IF v_lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in the language table.', p_language_name;
    END IF;

    -- D. Generate Safe ID (Fixes "Duplicate Key" error)
    SELECT COALESCE(MAX(film_id), 0) + 1 INTO v_film_id FROM public.film;

    -- E. Insert the Movie (Matches your column list exactly)
    INSERT INTO public.film (
        film_id, 
        title, 
        description, 
        release_year, 
        language_id,
        original_language_id, 
        rental_duration, 
        rental_rate, 
        length,
        replacement_cost, 
        rating, 
        last_update, 
        special_features, 
        fulltext
    )
    VALUES (
        v_film_id,           -- Generated Safe ID
        p_title,             -- Input Title
        NULL,                -- Description (Optional)
        p_release_year,      -- Input Year
        v_lang_id,           -- Found Language ID
        NULL,                -- Original Language (Optional)
        3,                   -- REQUIRED: Rental Duration
        4.99,                -- REQUIRED: Rental Rate
        NULL,                -- Length (Optional)
        19.99,               -- REQUIRED: Replacement Cost
        'G'::mpaa_rating,    -- Rating (Cast to Enum to avoid type errors)
        NOW(),               -- Last Update
        NULL,                -- Special Features
        to_tsvector(p_title) -- REQUIRED: Generates search index data
    );

    RAISE NOTICE 'Success: New movie "%" inserted with ID %.', p_title, v_film_id;
END;
$$;