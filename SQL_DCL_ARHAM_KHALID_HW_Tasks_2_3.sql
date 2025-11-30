--Task 2. Implement role-based authentication model for dvd_rental database
--task 1
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM rentaluser;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM rentaluser;

--task 2
GRANT SELECT ON customer TO rentaluser;

--task 3-4
-- Run as a superuser or admin
CREATE ROLE rental;
CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rental';
GRANT rental TO rentaluser;
GRANT INSERT, UPDATE ON rental TO rental;

-- Switch to the user role
SET ROLE rentaluser;

-- Insert and update data
INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (1004, CURRENT_TIMESTAMP, 1588, 565, CURRENT_TIMESTAMP + INTERVAL '2 days', 1, CURRENT_TIMESTAMP)
ON CONFLICT (rental_id)
DO UPDATE SET
  return_date = EXCLUDED.return_date,
  last_update = CURRENT_TIMESTAMP;


--task 5

REVOKE INSERT ON rental FROM rental;
SET ROLE rentaluser;
--task 6
-- 1. Find an eligible customer
SELECT c.first_name, c.last_name
FROM customer c
JOIN rental r ON r.customer_id = c.customer_id
JOIN payment p ON p.customer_id = c.customer_id
GROUP BY c.first_name, c.last_name
HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
LIMIT 1;

CREATE ROLE client_mary_smith LOGIN PASSWORD 'role';

GRANT CONNECT ON DATABASE dvdrental TO client_mary_smith;
GRANT USAGE ON SCHEMA public TO client_mary_smith;
GRANT SELECT ON rental, payment, customer TO client_mary_smith;

select * from customer




--Task 3. Implement row-level securit

ALTER TABLE rental FORCE ROW LEVEL SECURITY;
ALTER TABLE payment FORCE ROW LEVEL SECURITY;


CREATE POLICY rental_customer_policy ON rental
FOR SELECT
TO client_mary_smith
USING (customer_id = 5);


CREATE POLICY payment_customer_policy ON payment
FOR SELECT
TO client_mary_smith
USING (customer_id = 5); 

GRANT SELECT ON rental, payment TO client_mary_smith;

