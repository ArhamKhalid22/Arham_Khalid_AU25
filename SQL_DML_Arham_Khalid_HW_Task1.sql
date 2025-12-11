/*
   PART 1.1 – ADD 3 FAVORITE MOVIES TO public.film
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
    special_features,
    fulltext
)

-- Inception
SELECT
    'Inception',
    'A thief who steals corporate secrets through use of dream-sharing technology.',
    2010,
    (
        SELECT l.language_id
        FROM public."language" l
        WHERE LOWER(l.name) = 'english'
        ORDER BY l.language_id
        LIMIT 1
    ),
    NULL::smallint,
    7,
    4.99,
    148,
    19.99,
    'PG-13'::mpaa_rating,
    CURRENT_DATE,
    ARRAY['Trailers','Deleted Scenes','Behind the Scenes']::text[],
    NULL::tsvector
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE LOWER(f.title) = 'inception'
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
        ORDER BY l.language_id
        LIMIT 1
    ),
    NULL::smallint,
    14,
    9.99,
    154,
    19.99,
    'R'::mpaa_rating,
    CURRENT_DATE,
    ARRAY['Trailers','Commentary','Behind the Scenes']::text[],
    NULL::tsvector
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE LOWER(f.title) = 'pulp fiction'
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
        ORDER BY l.language_id
        LIMIT 1
    ),
    NULL::smallint,
    21,
    19.99,
    136,
    14.99,
    'R'::mpaa_rating,
    CURRENT_DATE,
    ARRAY['Deleted Scenes','Behind the Scenes','Making Of']::text[],
    NULL::tsvector
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE LOWER(f.title) = 'the matrix'
);

-- Verification
SELECT film_id, title, rental_duration, rental_rate
FROM public.film
WHERE LOWER(title) IN ('inception','pulp fiction','the matrix')
ORDER BY title;



/*
   PART 1.2 – ADD ACTORS
*/
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 'LEONARDO','DICAPRIO',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='leonardo' AND LOWER(last_name)='dicaprio'
)
UNION ALL
SELECT 'JOSEPH','GORDON-LEVITT',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='joseph' AND LOWER(last_name)='gordon-levitt'
)
UNION ALL
SELECT 'ELLEN','PAGE',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(last_name)='page' AND LOWER(first_name) IN ('ellen','elliot')
)
UNION ALL
SELECT 'JOHN','TRAVOLTA',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='john' AND LOWER(last_name)='travolta'
)
UNION ALL
SELECT 'SAMUEL','L JACKSON',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='samuel' AND LOWER(last_name)='l jackson'
)
UNION ALL
SELECT 'UMA','THURMAN',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='uma' AND LOWER(last_name)='thurman'
)
UNION ALL
SELECT 'KEANU','REEVES',CURRENT_DATE WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE LOWER(first_name)='keanu' AND LOWER(last_name)='reeves'
);

-- Verification
SELECT actor_id, first_name, last_name
FROM public.actor
WHERE LOWER(last_name) IN ('dicaprio','gordon-levitt','page','travolta','l jackson','thurman','reeves')
ORDER BY last_name, first_name;



/*
   MAP ACTORS TO FILMS
*/
WITH fav_films AS (
    SELECT film_id, title
    FROM public.film
    WHERE LOWER(title) IN ('inception','pulp fiction','the matrix')
),
film_actor_mapping AS (
    SELECT f.film_id, f.title, a.actor_id
    FROM fav_films f
    JOIN public.actor a ON
        (
            LOWER(f.title)='inception' AND (
                (LOWER(a.first_name)='leonardo' AND LOWER(a.last_name)='dicaprio')
                OR (LOWER(a.first_name)='joseph' AND LOWER(a.last_name)='gordon-levitt')
                OR (LOWER(a.last_name)='page' AND LOWER(a.first_name) IN ('ellen','elliot'))
            )
        )
        OR (
            LOWER(f.title)='pulp fiction' AND (
                (LOWER(a.first_name)='john' AND LOWER(a.last_name)='travolta')
                OR (LOWER(a.first_name)='samuel' AND LOWER(a.last_name)='l jackson')
                OR (LOWER(a.first_name)='uma' AND LOWER(a.last_name)='thurman')
            )
        )
        OR (
            LOWER(f.title)='the matrix' AND LOWER(a.first_name)='keanu' AND LOWER(a.last_name)='reeves'
        )
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT actor_id, film_id, CURRENT_DATE
FROM film_actor_mapping fam
WHERE NOT EXISTS (
    SELECT 1 FROM public.film_actor fa WHERE fa.actor_id=fam.actor_id AND fa.film_id=fam.film_id
);

-- Verification
SELECT f.title, a.first_name || ' ' || a.last_name AS actor_name
FROM public.film f
JOIN public.film_actor fa ON fa.film_id=f.film_id
JOIN public.actor a ON a.actor_id=fa.actor_id
WHERE LOWER(f.title) IN ('inception','pulp fiction','the matrix')
ORDER BY f.title, actor_name;



/*
   PART 1.3 – ADD MOVIES TO INVENTORY FOR ALL STORES
*/
WITH fav_films AS (
    SELECT film_id FROM public.film WHERE LOWER(title) IN ('inception','pulp fiction','the matrix')
),
all_stores AS (
    SELECT store_id FROM public.store
)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT ff.film_id, s.store_id, CURRENT_DATE
FROM fav_films ff
CROSS JOIN all_stores s
WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory i WHERE i.film_id=ff.film_id AND i.store_id=s.store_id
);

-- Verification
SELECT i.inventory_id, f.title, i.store_id
FROM public.inventory i
JOIN public.film f ON f.film_id=i.film_id
WHERE LOWER(f.title) IN ('inception','pulp fiction','the matrix')
ORDER BY f.title, store_id;



/*
   PART 2 – UPDATE HIGH-ACTIVITY CUSTOMER TO YOUR DATA
*/
WITH high_activity_customer AS (
    SELECT c.customer_id, c.store_id
    FROM public.customer c
    WHERE (SELECT COUNT(*) FROM public.rental r WHERE r.customer_id=c.customer_id) >= 43
      AND (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id=c.customer_id) >= 43
    ORDER BY
        (SELECT COUNT(*) FROM public.rental r WHERE r.customer_id=c.customer_id) DESC,
        (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id=c.customer_id) DESC,
        c.customer_id
    LIMIT 1
),
any_address AS (
    SELECT address_id
    FROM public.address
    ORDER BY address_id
    LIMIT 1
)
UPDATE public.customer c
SET first_name='ARHAM',
    last_name='KHALID',
    email='arhamkhalid2207@gmail.com',
    address_id=(SELECT address_id FROM any_address),
    last_update=CURRENT_DATE
FROM high_activity_customer hac
WHERE c.customer_id=hac.customer_id;

-- Verification
SELECT customer_id, store_id, first_name, last_name, email, address_id
FROM public.customer
WHERE LOWER(first_name)='arham' AND LOWER(last_name)='khalid';



/*
   PART 3 – REMOVE OLD RENTALS & PAYMENTS FOR YOUR CUSTOMER
   (Always use the LOWEST customer_id for ARHAM KHALID)
*/
DELETE FROM public.payment
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE LOWER(first_name)='arham'
      AND LOWER(last_name)='khalid'
    ORDER BY customer_id
    LIMIT 1
);

DELETE FROM public.rental
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE LOWER(first_name)='arham'
      AND LOWER(last_name)='khalid'
    ORDER BY customer_id
    LIMIT 1
);

-- Verification
SELECT customer_id,
       (SELECT COUNT(*) FROM public.rental  r WHERE r.customer_id=c.customer_id) AS total_rentals,
       (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id=c.customer_id) AS total_payments
FROM public.customer c
WHERE LOWER(first_name)='arham' AND LOWER(last_name)='khalid'
ORDER BY customer_id;



/*
   PART 4 – RENT FAVORITE MOVIES AGAIN & PAY
*/
WITH customer_data AS (
    SELECT customer_id, store_id
    FROM public.customer
    WHERE LOWER(first_name)='arham'
      AND LOWER(last_name)='khalid'
    ORDER BY customer_id
    LIMIT 1
),
store_staff AS (
    SELECT s.staff_id
    FROM public.staff s
    JOIN customer_data cd ON s.store_id = cd.store_id
    ORDER BY s.staff_id
    LIMIT 1
),
fav_films AS (
    SELECT film_id, title, rental_rate, rental_duration
    FROM public.film
    WHERE LOWER(title) IN ('inception','pulp fiction','the matrix')
),
customer_inventory AS (
    SELECT cd.customer_id, cd.store_id, ff.film_id, ff.title,
           ff.rental_rate, ff.rental_duration, i.inventory_id
    FROM customer_data cd
    JOIN fav_films ff ON TRUE
    JOIN public.inventory i ON i.film_id=ff.film_id AND i.store_id=cd.store_id
),
inserted_rentals AS (
    INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
    SELECT CURRENT_DATE,
           ci.inventory_id,
           ci.customer_id,
           CURRENT_DATE + ci.rental_duration,
           (SELECT staff_id FROM store_staff),
           CURRENT_DATE
    FROM customer_inventory ci
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.rental r
        WHERE r.customer_id=ci.customer_id
          AND r.inventory_id=ci.inventory_id
    )
    RETURNING rental_id, customer_id, inventory_id
),
inserted_payments AS (
    INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
    SELECT ir.customer_id,
           (SELECT staff_id FROM store_staff),
           ir.rental_id,
           ff.rental_rate,
           DATE '2017-01-01'
    FROM inserted_rentals ir
    JOIN public.inventory i ON i.inventory_id=ir.inventory_id
    JOIN fav_films ff ON ff.film_id=i.film_id
    WHERE NOT EXISTS (
        SELECT 1 FROM public.payment p WHERE p.rental_id=ir.rental_id
    )
    RETURNING payment_id, customer_id, rental_id, amount, payment_date
)
SELECT * FROM inserted_payments;

-- Verification
SELECT f.title, r.rental_date, r.return_date, p.amount, p.payment_date
FROM public.customer c
JOIN public.rental r ON r.customer_id=c.customer_id
JOIN public.payment p ON p.rental_id=r.rental_id
JOIN public.inventory i ON i.inventory_id=r.inventory_id
JOIN public.film f ON f.film_id=i.film_id
WHERE LOWER(c.first_name)='arham'
  AND LOWER(c.last_name)='khalid'
  AND LOWER(f.title) IN ('inception','pulp fiction','the matrix')
ORDER BY f.title;

