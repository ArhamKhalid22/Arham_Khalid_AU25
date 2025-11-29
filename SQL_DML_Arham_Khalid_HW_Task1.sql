/*
   PART 1.1 – ADD 3 FAVORITE MOVIES TO public.film
   Movies:
     - Inception
     - Pulp Fiction
     - The Matrix
  
 */

INSERT INTO public.film (
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
    special_features
)
-- Inception
SELECT
    'Inception' AS title,
    'A thief who steals corporate secrets through use of dream-sharing technology.' AS description,
    2010 AS release_year,
    (
        SELECT l.language_id
        FROM public."language" l
        WHERE LOWER(l.name) = 'english'
        FETCH FIRST 1 ROW ONLY
    ) AS language_id,
    NULL AS original_language_id,
    7 AS rental_duration,        -- 1 week => 7 days
    4.99 AS rental_rate,
    148 AS length,
    19.99 AS replacement_cost,
    'PG-13' AS rating,
    CURRENT_DATE AS last_update,
    ARRAY['Trailers', 'Deleted Scenes', 'Behind the Scenes']::text[] AS special_features
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film f
    WHERE LOWER(f.title) = 'inception'
)
UNION ALL
-- Pulp Fiction
SELECT
    'Pulp Fiction',
    'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine.',
    1994,
    (
        SELECT l.language_id
        FROM public."language" l
        WHERE LOWER(l.name) = 'english'
        FETCH FIRST 1 ROW ONLY
    ),
    NULL,
    14,           -- 2 weeks => 14 days
    9.99,
    154,
    19.99,
    'R',
    CURRENT_DATE,
    ARRAY['Trailers', 'Commentary', 'Behind the Scenes']::text[]
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film f
    WHERE LOWER(f.title) = 'pulp fiction'
)
UNION ALL
-- The Matrix
SELECT
    'The Matrix',
    'A computer hacker learns about the true nature of his reality and his role in the war against its controllers.',
    1999,
    (
        SELECT l.language_id
        FROM public."language" l
        WHERE LOWER(l.name) = 'english'
        FETCH FIRST 1 ROW ONLY
    ),
    NULL,
    21,           -- 3 weeks => 21 days
    19.99,
    136,
    14.99,
    'R',
    CURRENT_DATE,
    ARRAY['Deleted Scenes', 'Behind the Scenes', 'Making Of']::text[]
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film f
    WHERE LOWER(f.title) = 'the matrix'
)
RETURNING film_id, title, rental_duration, rental_rate;

-- Verification (read-only)
SELECT
    f.film_id,
    f.title,
    f.rental_duration,
    f.rental_rate
FROM public.film f
WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
ORDER BY f.title;

COMMIT;


/* 
   PART 1.2 – ADD REAL ACTORS & MAP THEM TO FILMS
   Actors:
     Inception: Leonardo DiCaprio, Joseph Gordon-Levitt,
                Ellen/Elliot Page (handle both)
     Pulp Fiction: John Travolta, Samuel L Jackson, Uma Thurman
     The Matrix: Keanu Reeves
  */

-- 1. Insert actors (if not already present)
INSERT INTO public.actor (
    first_name,
    last_name,
    last_update
)
-- Leonardo DiCaprio
SELECT 'LEONARDO', 'DICAPRIO', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'leonardo'
      AND LOWER(a.last_name)  = 'dicaprio'
)
UNION ALL
-- Joseph Gordon-Levitt
SELECT 'JOSEPH', 'GORDON-LEVITT', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'joseph'
      AND LOWER(a.last_name)  = 'gordon-levitt'
)
UNION ALL

SELECT 'ELLEN', 'PAGE', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.last_name)  = 'page'
      AND LOWER(a.first_name) IN ('ellen', 'elliot')
)
UNION ALL
-- John Travolta
SELECT 'JOHN', 'TRAVOLTA', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'john'
      AND LOWER(a.last_name)  = 'travolta'
)
UNION ALL
-- Samuel L Jackson
SELECT 'SAMUEL', 'L JACKSON', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'samuel'
      AND LOWER(a.last_name)  = 'l jackson'
)
UNION ALL
-- Uma Thurman
SELECT 'UMA', 'THURMAN', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'uma'
      AND LOWER(a.last_name)  = 'thurman'
)
UNION ALL
-- Keanu Reeves
SELECT 'KEANU', 'REEVES', CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE LOWER(a.first_name) = 'keanu'
      AND LOWER(a.last_name)  = 'reeves'
)
RETURNING actor_id, first_name, last_name;

-- Verification
SELECT
    a.actor_id,
    a.first_name,
    a.last_name
FROM public.actor a
WHERE LOWER(a.last_name) IN ('dicaprio', 'gordon-levitt', 'page', 'travolta', 'l jackson', 'thurman', 'reeves')
ORDER BY a.last_name, a.first_name;

COMMIT;


-- 2. Map actors to films in public.film_actor
WITH fav_films AS (
    SELECT
        f.film_id,
        f.title
    FROM public.film f
    WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
),
film_actor_mapping AS (
    SELECT
        f.film_id,
        f.title,
        a.actor_id
    FROM fav_films f
    INNER JOIN public.actor a
        ON (
            -- Inception actors
            LOWER(f.title) = 'inception'
            AND (
                (LOWER(a.first_name) = 'leonardo' AND LOWER(a.last_name) = 'dicaprio')
                OR (LOWER(a.first_name) = 'joseph'  AND LOWER(a.last_name) = 'gordon-levitt')
                OR (LOWER(a.last_name)  = 'page'
                    AND LOWER(a.first_name) IN ('ellen', 'elliot'))
            )
        )
        OR (
            -- Pulp Fiction actors
            LOWER(f.title) = 'pulp fiction'
            AND (
                (LOWER(a.first_name) = 'john'   AND LOWER(a.last_name) = 'travolta')
                OR (LOWER(a.first_name) = 'samuel' AND LOWER(a.last_name) = 'l jackson')
                OR (LOWER(a.first_name) = 'uma'    AND LOWER(a.last_name) = 'thurman')
            )
        )
        OR (
            -- The Matrix actors
            LOWER(f.title) = 'the matrix'
            AND LOWER(a.first_name) = 'keanu'
            AND LOWER(a.last_name)  = 'reeves'
        )
)
INSERT INTO public.film_actor (
    actor_id,
    film_id,
    last_update
)
SELECT
    fam.actor_id,
    fam.film_id,
    CURRENT_DATE AS last_update
FROM film_actor_mapping fam
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor fa
    WHERE fa.actor_id = fam.actor_id
      AND fa.film_id  = fam.film_id
)
RETURNING actor_id, film_id;

-- Verification join
SELECT
    f.title AS film_title,
    a.first_name || ' ' || a.last_name AS actor_name
FROM public.film f
INNER JOIN public.film_actor fa
    ON f.film_id = fa.film_id
INNER JOIN public.actor a
    ON fa.actor_id = a.actor_id
WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
ORDER BY f.title, actor_name;

COMMIT;


/* 
   PART 1.3 – ADD FAVORITE MOVIES TO ANY STORE'S INVENTORY
 */

WITH fav_films AS (
    SELECT
        f.film_id,
        f.title
    FROM public.film f
    WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
),
all_stores AS (
    SELECT s.store_id
    FROM public.store s
)
INSERT INTO public.inventory (
    film_id,
    store_id,
    last_update
)
SELECT
    ff.film_id,
    s.store_id,
    CURRENT_DATE AS last_update
FROM fav_films ff
CROSS JOIN all_stores s
WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = ff.film_id
      AND i.store_id = s.store_id
)
RETURNING inventory_id, film_id, store_id;

-- Verification
SELECT
    i.inventory_id,
    f.title,
    i.store_id
FROM public.inventory i
INNER JOIN public.film f
    ON f.film_id = i.film_id
WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
ORDER BY f.title, i.store_id;

COMMIT;


/*
   PART 2 – UPDATE A HIGH-ACTIVITY CUSTOMER TO YOUR DATA
  */

SELECT
    c.customer_id,
    c.store_id,
    c.first_name,
    c.last_name,
    (SELECT COUNT(*) FROM public.rental r  WHERE r.customer_id = c.customer_id) AS rental_count,
    (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) AS payment_count
FROM public.customer c
WHERE (SELECT COUNT(*) FROM public.rental r  WHERE r.customer_id = c.customer_id) >= 43
  AND (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) >= 43
ORDER BY rental_count DESC, payment_count DESC
FETCH FIRST 1 ROW ONLY;

WITH high_activity_customer AS (
    SELECT
        c.customer_id,
        c.store_id
    FROM public.customer c
    WHERE (SELECT COUNT(*) FROM public.rental r  WHERE r.customer_id = c.customer_id) >= 43
      AND (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) >= 43
    ORDER BY
        (SELECT COUNT(*) FROM public.rental r  WHERE r.customer_id = c.customer_id) DESC,
        (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) DESC
    FETCH FIRST 1 ROW ONLY
),
any_address AS (
    SELECT a.address_id
    FROM public.address a
    ORDER BY a.address_id
    FETCH FIRST 1 ROW ONLY
)
UPDATE public.customer c
SET
    first_name  = 'ARHAM',
    last_name   = 'KHALID',
    email       = 'arhamkhalid2207@gmail.com',
    address_id  = (SELECT address_id FROM any_address),
    last_update = CURRENT_DATE
FROM high_activity_customer hac
WHERE c.customer_id = hac.customer_id
RETURNING c.customer_id, c.store_id, c.first_name, c.last_name, c.email, c.address_id, c.last_update;

-- Verification
SELECT
    c.customer_id,
    c.store_id,
    c.first_name,
    c.last_name,
    c.email,
    c.address_id
FROM public.customer c
WHERE LOWER(c.first_name) = 'arham'
  AND LOWER(c.last_name)  = 'khalid';

COMMIT;


/* 
   PART 3 – REMOVE YOUR RENTAL/PAYMENT RECORDS
 */

SELECT
    c.customer_id,
    c.store_id,
    c.first_name,
    c.last_name
FROM public.customer c
WHERE LOWER(c.first_name) = 'arham'
  AND LOWER(c.last_name)  = 'khalid';

DELETE FROM public.payment p
WHERE p.customer_id = (
    SELECT c.customer_id
    FROM public.customer c
    WHERE LOWER(c.first_name) = 'arham'
      AND LOWER(c.last_name)  = 'khalid'
    FETCH FIRST 1 ROW ONLY
)
RETURNING p.payment_id, p.customer_id, p.rental_id, p.amount, p.payment_date;

DELETE FROM public.rental r
WHERE r.customer_id = (
    SELECT c.customer_id
    FROM public.customer c
    WHERE LOWER(c.first_name) = 'arham'
      AND LOWER(c.last_name)  = 'khalid'
    FETCH FIRST 1 ROW ONLY
)
RETURNING r.rental_id, r.customer_id, r.inventory_id, r.rental_date, r.return_date;

SELECT
    c.customer_id,
    (SELECT COUNT(*) FROM public.rental  r WHERE r.customer_id = c.customer_id) AS total_rentals,
    (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id) AS total_payments
FROM public.customer c
WHERE LOWER(c.first_name) = 'arham'
  AND LOWER(c.last_name)  = 'khalid';

COMMIT;


/*
   PART 4 – RENT FAVORITE MOVIES AGAIN AND PAY FOR THEM
   Requirements:
  */

WITH customer_data AS (
    SELECT
        c.customer_id,
        c.store_id
    FROM public.customer c
    WHERE LOWER(c.first_name) = 'arham'
      AND LOWER(c.last_name)  = 'khalid'
    FETCH FIRST 1 ROW ONLY
),
store_staff AS (
    SELECT s.staff_id
    FROM public.staff s
    INNER JOIN customer_data cd
        ON s.store_id = cd.store_id
    ORDER BY s.staff_id
    FETCH FIRST 1 ROW ONLY
),
fav_films AS (
    SELECT
        f.film_id,
        f.title,
        f.rental_rate,
        f.rental_duration
    FROM public.film f
    WHERE LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
),
customer_inventory AS (
    -- Inventory for favorite films in your store
    SELECT
        cd.customer_id,
        cd.store_id,
        ff.film_id,
        ff.title,
        ff.rental_rate,
        ff.rental_duration,
        i.inventory_id
    FROM customer_data cd
    INNER JOIN fav_films ff
        ON TRUE
    INNER JOIN public.inventory i
        ON i.film_id = ff.film_id
       AND i.store_id = cd.store_id
),
inserted_rentals AS (
    INSERT INTO public.rental (
        rental_date,
        inventory_id,
        customer_id,
        return_date,
        staff_id,
        last_update
    )
    SELECT
        CURRENT_DATE AS rental_date,
        ci.inventory_id,
        ci.customer_id,
        CURRENT_DATE + (ci.rental_duration) AS return_date,  
        (SELECT staff_id FROM store_staff),
        CURRENT_DATE AS last_update
    FROM customer_inventory ci
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.rental r
        WHERE r.customer_id  = ci.customer_id
          AND r.inventory_id = ci.inventory_id
    )
    RETURNING rental_id, customer_id, inventory_id, rental_date, return_date
),
inserted_payments AS (
    INSERT INTO public.payment (
        customer_id,
        staff_id,
        rental_id,
        amount,
        payment_date,
        last_update
    )
    SELECT
        ir.customer_id,
        (SELECT staff_id FROM store_staff),
        ir.rental_id,
        ff.rental_rate,
        DATE '2017-01-01' AS payment_date,   -- first half of 2017
        CURRENT_DATE AS last_update
    FROM inserted_rentals ir
    INNER JOIN public.inventory i
        ON i.inventory_id = ir.inventory_id
    INNER JOIN fav_films ff
        ON ff.film_id = i.film_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.payment p
        WHERE p.rental_id = ir.rental_id
    )
    RETURNING payment_id, customer_id, rental_id, amount, payment_date
)
SELECT *
FROM inserted_payments;

-- Verification: rentals and payments for you & favorite films
SELECT
    f.title,
    r.rental_date,
    r.return_date,
    p.amount,
    p.payment_date
FROM public.customer c
INNER JOIN public.rental r
    ON r.customer_id = c.customer_id
INNER JOIN public.payment p
    ON p.rental_id = r.rental_id
INNER JOIN public.inventory i
    ON i.inventory_id = r.inventory_id
INNER JOIN public.film f
    ON f.film_id = i.film_id
WHERE LOWER(c.first_name) = 'arham'
  AND LOWER(c.last_name)  = 'khalid'
  AND LOWER(f.title) IN ('inception', 'pulp fiction', 'the matrix')
ORDER BY f.title;

COMMIT;
