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
GRANT SELECT, UPDATE ON public.rental TO rental; -- Removed INSERT from the grant list

-- Explicitly Revoke INSERT (as requested)
REVOKE INSERT ON public.rental FROM rental;

GRANT USAGE ON SEQUENCE public.rental_rental_id_seq TO rental;


/********************************************************************************************
  TASK 3–4 ─ Verification: Test INSERT Denial as rentaluser
*********************************************************************************************/

SET ROLE rentaluser;

DO $$
BEGIN
    -- Attempting an insert to prove it is denied
    BEGIN
        INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id)
        VALUES (CURRENT_TIMESTAMP, 1, 1, 1);
        
        RAISE NOTICE 'Error: Insert should have been denied, but it succeeded.';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Success: INSERT permission was correctly denied for rentaluser.';
    END;
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
