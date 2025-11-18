DROP VIEW IF EXISTS public.sales_revenue_by_category_qtr;

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales_revenue
FROM payment p
JOIN rental r      ON p.rental_id = r.rental_id
JOIN inventory i   ON r.inventory_id = i.inventory_id
JOIN film f        ON f.film_id = i.film_id
JOIN film_category fc ON fc.film_id = f.film_id
JOIN category c    ON c.category_id = fc.category_id
WHERE DATE_TRUNC('quarter', p.payment_date) = DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC;
SELECT * FROM public.sales_revenue_by_category_qtr;

--task 2
DROP FUNCTION IF EXISTS public.get_sales_revenue_by_category_qtr(INT, INT);

CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_quarter INT DEFAULT EXTRACT(QUARTER FROM CURRENT_DATE)
)
RETURNS TABLE(category TEXT, total_sales_revenue NUMERIC)
LANGUAGE sql STABLE
AS $$
    SELECT 
        c.name,
        SUM(p.amount)
    FROM payment p
    JOIN rental r ON r.rental_id = p.rental_id
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = p_year
      AND EXTRACT(QUARTER FROM p.payment_date) = p_quarter
    GROUP BY c.name
    HAVING SUM(p.amount) > 0
    ORDER BY SUM(p.amount) DESC;
$$;
SELECT * FROM public.get_sales_revenue_by_category_qtr(2005, 2);
SELECT * FROM public.get_sales_revenue_by_category_qtr();
CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_pattern TEXT)
RETURNS TABLE(
    row_num       BIGINT,
    film_title    TEXT,
    language      TEXT,
    customer_name TEXT,
    rental_date   TIMESTAMP
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    rec           RECORD;
    has_results   BOOLEAN := FALSE;
BEGIN
    -- Return every copy that belongs to a film that has at least one copy in stock
    FOR rec IN
        SELECT
            ROW_NUMBER() OVER (ORDER BY f.title, i.inventory_id) AS rn,
            f.title,
            l.name AS lang_name,
            CONCAT(cu.first_name, ' ', cu.last_name) AS cust_name,
            r.rental_date
        FROM public.film f
        JOIN public.language l ON l.language_id = f.language_id
        JOIN public.inventory i ON i.film_id = f.film_id
        LEFT JOIN public.rental r  ON r.inventory_id = i.inventory_id AND r.return_date IS NULL
        LEFT JOIN public.customer cu ON cu.customer_id = r.customer_id
        WHERE f.title ILIKE p_pattern
          AND EXISTS (
              SELECT 1
              FROM public.inventory i2
              LEFT JOIN public.rental r2 ON r2.inventory_id = i2.inventory_id AND r2.return_date IS NULL
              WHERE i2.film_id = f.film_id
              GROUP BY i2.film_id
              HAVING COUNT(r2.inventory_id) < COUNT(i2.inventory_id)   -- at least 1 free copy
          )
        ORDER BY f.title, i.inventory_id
    LOOP
        row_num       := rec.rn;
        film_title    := rec.title;
        language      := rec.lang_name;
        customer_name := rec.cust_name;
        rental_date   := rec.rental_date;
        has_results   := TRUE;
        RETURN NEXT;
    END LOOP;

    -- No results → return message row
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

--task3

DROP FUNCTION IF EXISTS public.most_popular_films_by_countries(TEXT[]);

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(
    p_countries TEXT[]
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
BEGIN
    IF p_countries IS NULL OR array_length(p_countries,1) IS NULL THEN
        RAISE EXCEPTION 'Country list cannot be NULL or empty';
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            co.country AS country_col,
            f.title AS film_col,
            f.rating AS rating_col,        -- ENUM type
            l.name AS language_col,
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
        WHERE co.country = ANY(p_countries)
        GROUP BY co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT 
        country_col,
        film_col,
        rating_col::TEXT,      -- FIXED HERE
        language_col,
        length_col,
        release_year_col
    FROM ranked
    WHERE rn = 1
    ORDER BY country_col;

END;
$$;
SELECT *
FROM public.most_popular_films_by_countries(
    ARRAY['Japan','Brazil','United States']
); 
--task 4
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
AS $$
BEGIN
    IF p_pattern IS NULL THEN
        RAISE EXCEPTION 'Search pattern cannot be NULL';
    END IF;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY f.title) AS row_num,
        f.title AS film_title,
        l.name AS language,
        cu.first_name || ' ' || cu.last_name AS customer_name,
        r.rental_date
    FROM film f
    JOIN language l ON l.language_id = f.language_id
    JOIN inventory i ON i.film_id = f.film_id
    LEFT JOIN rental r ON r.inventory_id = i.inventory_id AND r.return_date IS NULL
    LEFT JOIN customer cu ON cu.customer_id = r.customer_id
    WHERE f.title ILIKE p_pattern;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No films found matching pattern %', p_pattern;
    END IF;
END;
$$;

--task5
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.language WHERE name ILIKE 'Klingon') THEN
        INSERT INTO public.language (name, last_update)
        VALUES ('Klingon', NOW());
    END IF;
END $$;
CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_lang_id INT;
    v_new_film_id INT;
BEGIN
    -- Validate title
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be empty';
    END IF;

    -- Validate language exists
    SELECT language_id INTO v_lang_id
    FROM public.language
    WHERE name ILIKE p_language_name;

    IF v_lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in language table', p_language_name;
    END IF;

    -- Generate a new unique film ID using sequence (NO hardcoding)
    SELECT nextval('film_film_id_seq') INTO v_new_film_id;

    -- Insert the movie
    INSERT INTO public.film (
        film_id,
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost,
        last_update
    )
    VALUES (
        v_new_film_id,
        p_title,
        p_release_year,
        v_lang_id,
        3,         -- rental_duration
        4.99,      -- rental_rate
        19.99,     -- replacement_cost
        NOW()
    );

    RAISE NOTICE 'New movie inserted: % (ID %)', p_title, v_new_film_id;
END;
$$;
