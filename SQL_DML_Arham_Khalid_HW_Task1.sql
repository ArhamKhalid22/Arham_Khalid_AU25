/*Choose your real top-3 favorite movies and add them to the 'film' table (films with the title Film1, Film2, etc - will not be taken into account and grade will be reduced by 20%)
Fill in rental rates with 4.99, 9.99 and 19.99 and rental durations with 1, 2 and 3 weeks respectively.
*/
INSERT INTO film (
    film_id, title, description, release_year, language_id, original_language_id,
    rental_duration, rental_rate, length, replacement_cost, rating, last_update,
    special_features
)
VALUES
-- ROW 1: 'Inception' 
(
    1001,
    'Inception',
    'A thief who steals corporate secrets through use of dream-sharing technology.',
    2010,
    1,
    NULL,
    1, -- rental_duration (1 week)
    4.99, -- rental_rate
    148,
    19.99,
    'PG-13',
    CURRENT_TIMESTAMP,
    '{Trailers, Deleted Scenes, Behind the Scenes}'
),
-- ROW 2: 'Pulp Fiction' 
(
    1002,
    'Pulp Fiction',
    'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine.',
    1994,
    1,
    NULL,
    2, -- rental_duration (2 weeks)
    9.99, -- rental_rate
    154,
    19.99,
    'R',
    CURRENT_TIMESTAMP,
    '{Trailers, Commentary, Behind the Scenes}'
),
-- ROW 3: 'The Matrix' 
(
    1003,
    'The Matrix',
    'A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.',
    1999,
    1,
    NULL,
    3, -- rental_duration (3 weeks)
    19.99, -- rental_rate
    136,
    14.99,
    'R',
    CURRENT_TIMESTAMP,
    '{Deleted Scenes, Behind the Scenes, Making Of}'
)
RETURNING film_id, title;

COMMIT; 
--select * from film where film_id in (1001,1002,1003);
--------------------------------------------------------------------
INSERT INTO actor (
    actor_id, first_name, last_name, last_update
)
VALUES
    (201, 'LEONARDO', 'DICAPRIO', CURRENT_TIMESTAMP), -- Inception
    (202, 'JOSEPH', 'GORDON-LEVITT', CURRENT_TIMESTAMP), -- Inception
    (203, 'ELLEN', 'PAGE', CURRENT_TIMESTAMP), -- Inception (as credited in 2010)
    (204, 'JOHN', 'TRAVOLTA', CURRENT_TIMESTAMP), -- Pulp Fiction
    (205, 'SAMUEL', 'L JACKSON', CURRENT_TIMESTAMP), -- Pulp Fiction
    (206, 'UMA', 'THURMAN', CURRENT_TIMESTAMP), -- Pulp Fiction
    (207, 'KEANU', 'REEVES', CURRENT_TIMESTAMP) -- The Matrix
RETURNING actor_id, first_name, last_name;

COMMIT; 
-- Map the 7 newly created actors to the 3 films (1001, 1002, 1003)
INSERT INTO film_actor (
    actor_id, film_id, last_update
)
VALUES
    -- INCEPTION (Film ID 1111)
    (201, 1001, CURRENT_TIMESTAMP), -- Leonardo DiCaprio
    (202, 1001, CURRENT_TIMESTAMP), -- Joseph Gordon-Levitt
    (203, 1001, CURRENT_TIMESTAMP), -- Ellen Page

    -- PULP FICTION (Film ID 1112)
    (204, 1002, CURRENT_TIMESTAMP), -- John Travolta
    (205, 1002, CURRENT_TIMESTAMP), -- Samuel L Jackson
    (206, 1002, CURRENT_TIMESTAMP), -- Uma Thurman

    -- THE MATRIX (Film ID 1113)
    (207, 1003, CURRENT_TIMESTAMP); -- Keanu Reeves

COMMIT;

--quick join query to confirm all insertions were mapped correctly
SELECT
    f.title AS film_title,
    a.first_name || ' ' || a.last_name AS actor_name
FROM
    film f
JOIN
    film_actor fa ON f.film_id = fa.film_id
JOIN
    actor a ON fa.actor_id = a.actor_id
WHERE
    f.film_id IN (1001, 1002, 1003)
ORDER BY
    f.title, a.last_name; 
----------------------------------------------------------------
--Add your favorite movies to any store's inventory.
--select * from inventory;
INSERT INTO inventory (
    film_id, store_id, last_update
)
SELECT
    f.film_id,
    s.store_id,
    CURRENT_DATE
FROM
    film f -- Get IDs for the new films
CROSS JOIN
    store s -- Cross join to every store
WHERE
    f.title IN ('Inception', 'Pulp Fiction', 'The Matrix')
    -- Rerunnability check: Skip insertion if the film/store combination already exists.
    AND NOT EXISTS (
        SELECT 1
        FROM inventory i
        WHERE i.film_id = f.film_id AND i.store_id = s.store_id
    )
RETURNING inventory_id, film_id, store_id;

COMMIT;

/*Alter any existing customer in the database with at least 
43 rental and 43 payment records. Change their personal data to yours
(first name, last name, address, etc.). You can use any existing address from the 
"address" table. Please do not perform any updates on the "address" table, 
as this can impact multiple records with the same addres*/

SELECT
    c.customer_id,
    c.first_name AS old_first_name,
    c.last_name AS old_last_name
FROM
    customer c
WHERE
    (SELECT count(*) FROM rental r WHERE r.customer_id = c.customer_id) >= 43
    AND (SELECT count(*) FROM payment p WHERE p.customer_id = c.customer_id) >= 43
ORDER BY (SELECT count(*) FROM rental r WHERE r.customer_id = c.customer_id) DESC
LIMIT 1;

-- --- (Verification SELECT complete. Now proceed with the UPDATE.) ---

UPDATE customer c
SET
    first_name = 'MARVIN',
    last_name = 'HENDERS',
    email = 'marvin.henders@mydomain.com',
    -- Safely link to an existing address_id (e.g., ID 100) to avoid updating the 'address' table.
    address_id = (SELECT address_id FROM address WHERE address_id = 100 LIMIT 1),
    last_update = CURRENT_DATE
WHERE
    c.customer_id = (
        -- Subquery finds the ID of the single, highest-activity customer meeting the criteria
        SELECT customer_id
        FROM customer
        WHERE
            (SELECT count(*) FROM rental r WHERE r.customer_id = customer.customer_id) >= 43
            AND (SELECT count(*) FROM payment p WHERE p.customer_id = customer.customer_id) >= 43
        ORDER BY
            (SELECT count(*) FROM rental r WHERE r.customer_id = customer.customer_id) DESC,
            (SELECT count(*) FROM payment p WHERE p.customer_id = customer.customer_id) DESC
        LIMIT 1
    )
RETURNING customer_id, first_name, last_name, email, address_id, last_update;

COMMIT; 
------------------------------------------------------------------------
/*Remove any records related to you (as a customer) from
all tables except 'Customer' and 'Inventory'
Rent you favorite movies from the store they are in and
pay for them (add corresponding records to the database to represent this activity)
(Note: to insert the payment_date into the table payment, you can create 
a new partition (see the scripts to install the training database ) or add records for the
first half of 2017)
*/

DELETE FROM payment
WHERE customer_id = (
    SELECT customer_id FROM customer WHERE first_name = 'MARVIN' AND last_name = 'HENDERS'
);

-- 2. DELETE Rental records
-- This must be done after payment records are deleted (or cascaded) to satisfy foreign key constraints.
DELETE FROM rental
WHERE customer_id = (
    SELECT customer_id FROM customer WHERE first_name = 'MARVIN' AND last_name = 'HENDERS'
);

COMMIT;

-- Verification SELECT: Check that no payment or rental records exist for the customer
SELECT
    (SELECT COUNT(*) FROM rental r WHERE r.customer_id = c.customer_id) AS total_rentals,
    (SELECT COUNT(*) FROM payment p WHERE p.customer_id = c.customer_id) AS total_payments
FROM customer c
WHERE first_name = 'MARVIN' AND last_name = 'HENDERS';


WITH customer_data AS (
    SELECT customer_id, store_id FROM customer WHERE first_name = 'MARVIN' AND last_name = 'HENDERS'
),
staff_data AS (
    SELECT staff_id FROM staff LIMIT 1 -- Dynamically gets one staff ID
),
film_rental_data AS (
    -- Get film details and calculate the return date
    SELECT
        film_id,
        title,
        rental_rate, -- Unique reference for rental rate
        (CURRENT_DATE + interval '1 day') AS rental_date,
        (CURRENT_DATE + interval '1 day' + (rental_duration || ' days')::interval) AS return_date
    FROM film
    WHERE title IN ('Inception', 'Pulp Fiction', 'The Matrix')
),
-- Insert the RENTAL records first
inserted_rentals AS (
    INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date, last_update)
    SELECT
        frd.rental_date,
        (SELECT inventory_id FROM inventory i WHERE i.film_id = frd.film_id AND i.store_id = cd.store_id LIMIT 1) AS inventory_id,
        cd.customer_id,
        sd.staff_id,
        frd.return_date,
        CURRENT_DATE -- last_update is correctly used in the 'rental' table
    FROM film_rental_data frd
    CROSS JOIN customer_data cd
    CROSS JOIN staff_data sd
    -- Rerunnability check: Do not insert if a rental record for this film, customer, and rental date already exists.
    WHERE NOT EXISTS (
        SELECT 1 FROM rental r
        WHERE r.customer_id = cd.customer_id
        AND r.rental_date = frd.rental_date
    )
    RETURNING rental_id, customer_id, rental_date, inventory_id
)
-- Now insert the PAYMENT records using the new rental_ids
-- NOTE: 'last_update' IS EXCLUDED from this insert.
INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT
    ir.customer_id,
    sd.staff_id,
    ir.rental_id,
    frd.rental_rate,
    '2017-01-01'::date 
FROM inserted_rentals ir
JOIN film_rental_data frd ON frd.film_id = (
    SELECT film_id FROM inventory i WHERE i.inventory_id = ir.inventory_id
)
CROSS JOIN staff_data sd
RETURNING payment_id, rental_id, amount, payment_date;

COMMIT

--------------------------------------------------------------------------------
