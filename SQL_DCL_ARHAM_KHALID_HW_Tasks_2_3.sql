/********************************************************************************************
  TASK 1 ─ Create rentaluser (base user) with minimal rights
*********************************************************************************************/

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rentaluser'
    ) THEN
        CREATE ROLE rentaluser LOGIN PASSWORD 'rentalpassword';
    ELSE
        ALTER ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';
    END IF;
END $$;

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM rentaluser;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM rentaluser;


/********************************************************************************************
  TASK 2 ─ Create rental role, assign privileges, and grant to rentaluser
*********************************************************************************************/

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rental'
    ) THEN
        CREATE ROLE rental;
    END IF;
END $$;

GRANT rental TO rentaluser;

-- rental role permissions
GRANT SELECT ON public.customer TO rental;
GRANT SELECT ON public.payment  TO rental;
GRANT SELECT, INSERT, UPDATE ON public.rental TO rental;

GRANT USAGE ON SEQUENCE public.rental_rental_id_seq TO rental;


/********************************************************************************************
  TASK 3–4 ─ Test INSERT / UPDATE as rentaluser (no hardcoded IDs, no duplicates)
*********************************************************************************************/

SET ROLE rentaluser;

DO $$
DECLARE
    v_customer_id  INTEGER;
    v_inventory_id INTEGER;
BEGIN
    -- STEP 1: Dynamic eligible customer
    SELECT c.customer_id
    INTO v_customer_id
    FROM public.customer c
    JOIN public.rental  r ON r.customer_id = c.customer_id
    JOIN public.payment p ON p.customer_id = c.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(r.rental_id) > 0
       AND COUNT(p.payment_id) > 0
    ORDER BY c.customer_id
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RAISE NOTICE 'No eligible customer found.';
        RETURN;
    END IF;

    -- STEP 2: Choose an inventory previously rented by that customer
    SELECT r.inventory_id
    INTO v_inventory_id
    FROM public.rental r
    WHERE r.customer_id = v_customer_id
    ORDER BY r.rental_id
    LIMIT 1;

    IF v_inventory_id IS NULL THEN
        RAISE NOTICE 'No inventory found for customer %.', v_customer_id;
        RETURN;
    END IF;

    -- STEP 3: Insert rental only if one doesn't already exist today
    INSERT INTO public.rental (
        rental_date,
        inventory_id,
        customer_id,
        return_date,
        staff_id,
        last_update
    )
    SELECT
        CURRENT_TIMESTAMP,
        v_inventory_id,
        v_customer_id,
        CURRENT_TIMESTAMP + INTERVAL '2 days',
        1,
        CURRENT_TIMESTAMP
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.rental r
        WHERE r.customer_id  = v_customer_id
          AND r.inventory_id = v_inventory_id
          AND r.rental_date::date = CURRENT_DATE
    );

END $$;

RESET ROLE;


/********************************************************************************************
  TASK 5 ─ Create client_mary_smith + grant base SELECT rights
*********************************************************************************************/

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'client_mary_smith'
    ) THEN
        CREATE ROLE client_mary_smith LOGIN PASSWORD 'role';
    ELSE
        ALTER ROLE client_mary_smith WITH LOGIN PASSWORD 'role';
    END IF;
END $$;

GRANT CONNECT ON DATABASE dvdrental TO client_mary_smith;
GRANT USAGE  ON SCHEMA public TO client_mary_smith;
GRANT SELECT ON public.customer TO client_mary_smith;
GRANT SELECT ON public.rental   TO client_mary_smith;
GRANT SELECT ON public.payment  TO client_mary_smith;


/********************************************************************************************
  TASK 6 ─ Implement Row-Level Security (dynamic for Mary Smith)
*********************************************************************************************/

ALTER TABLE public.rental  FORCE ROW LEVEL SECURITY;
ALTER TABLE public.payment FORCE ROW LEVEL SECURITY;

DO $$
DECLARE
    v_mary_customer_id INTEGER;
BEGIN
    -- Identify the correct Mary Smith in your DB
    SELECT customer_id
    INTO v_mary_customer_id
    FROM public.customer
    WHERE first_name = 'MARY'
      AND last_name  = 'SMITH'
    ORDER BY customer_id
    LIMIT 1;

    IF v_mary_customer_id IS NULL THEN
        RAISE EXCEPTION 'Customer Mary Smith not found in database.';
    END IF;

    -- Drop old policies if any
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname='rental_customer_policy'
          AND tablename='rental'
          AND schemaname='public'
    ) THEN
        EXECUTE 'DROP POLICY rental_customer_policy ON public.rental';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname='payment_customer_policy'
          AND tablename='payment'
          AND schemaname='public'
    ) THEN
        EXECUTE 'DROP POLICY payment_customer_policy ON public.payment';
    END IF;

    -- Create row-level security policies dynamically
    EXECUTE format(
        'CREATE POLICY rental_customer_policy ON public.rental
         FOR SELECT TO client_mary_smith
         USING (customer_id = %s)',
        v_mary_customer_id
    );

    EXECUTE format(
        'CREATE POLICY payment_customer_policy ON public.payment
         FOR SELECT TO client_mary_smith
         USING (customer_id = %s)',
        v_mary_customer_id
    );
END $$;


/********************************************************************************************
  TASK 7 ─ Verification queries for Mary Smith (actual RLS check)
*********************************************************************************************/

SET ROLE client_mary_smith;

-- Should return only Mary Smith's rows
SELECT * FROM public.rental  LIMIT 10;
SELECT * FROM public.payment LIMIT 10;

RESET ROLE;

-- Check privilege grants
SELECT
    'public.rental'  AS object,
    has_table_privilege('client_mary_smith', 'public.rental',  'SELECT') AS can_select
UNION ALL
SELECT
    'public.payment',
    has_table_privilege('client_mary_smith', 'public.payment', 'SELECT');


/********************************************************************************************
  TASK 8 ─ Rewards Report Function (rerunnable)
*********************************************************************************************/

DROP FUNCTION IF EXISTS public.rewards_report(integer, numeric);

CREATE OR REPLACE FUNCTION public.rewards_report(
    min_monthly_purchases INTEGER,
    min_dollar_amount_earned NUMERIC
)
RETURNS TABLE (
    customer_id INTEGER,
    email TEXT,
    total_spent NUMERIC,
    avg_monthly_rentals NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.customer_id,
        c.email,
        SUM(p.amount)::NUMERIC AS total_spent,
        ROUND(AVG(m.count_rentals), 2)::NUMERIC AS avg_monthly_rentals
    FROM public.customer c
    JOIN public.payment p
      ON p.customer_id = c.customer_id
    JOIN LATERAL (
        SELECT COUNT(*)::INT AS count_rentals
        FROM public.rental r
        WHERE r.customer_id = c.customer_id
        GROUP BY date_trunc('month', r.rental_date)
    ) m ON TRUE
    GROUP BY c.customer_id, c.email
    HAVING SUM(p.amount) >= min_dollar_amount_earned
       AND MIN(m.count_rentals) >= min_monthly_purchases;
END;
$$;

-- Example test:
--SELECT * FROM public.rewards_report(2, 20.00);
--SELECT rolname FROM pg_roles WHERE rolname IN ('rentaluser', 'rental', 'client_mary_smith');

