CREATE DATABASE retail_db;
CREATE SCHEMA IF NOT EXISTS  sales AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS sales.customer (
    customer_id      SERIAL PRIMARY KEY,
    first_name       VARCHAR(60) NOT NULL,
    last_name        VARCHAR(60) NOT NULL,
    email            VARCHAR(120) UNIQUE NOT NULL,
    created_on       DATE DEFAULT CURRENT_DATE NOT NULL,
    full_name        VARCHAR(150)
        GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED
);


-- 2. Create Employee Table
CREATE TABLE IF NOT EXISTS sales.employee (
    employee_id      SERIAL PRIMARY KEY,
    emp_name         VARCHAR(120) NOT NULL,
    hire_date        DATE DEFAULT CURRENT_DATE NOT NULL,
    
    -- FIX: Removed hire_date (because DATE conversion is not immutable) 
    -- and added COLLATE "C" to UPPER
    employee_code    VARCHAR(200)
        GENERATED ALWAYS AS (UPPER(emp_name COLLATE "C")) STORED
);

-- 3. Create Category Table
CREATE TABLE IF NOT EXISTS sales.category (
    category_id      SERIAL PRIMARY KEY,
    category_name    VARCHAR(100) UNIQUE NOT NULL
);

-- 4. Create Supplier Table
CREATE TABLE IF NOT EXISTS sales.supplier (
    supplier_id      SERIAL PRIMARY KEY,
    supplier_name    VARCHAR(120) UNIQUE NOT NULL,
    contact_email    VARCHAR(120) UNIQUE
);

-- 5. Create Product Table (Links to Category & Supplier)
CREATE TABLE IF NOT EXISTS  sales.product (
    product_id       SERIAL PRIMARY KEY,
    category_id      INT NOT NULL,
    supplier_id      INT NOT NULL,
    product_name     VARCHAR(120) NOT NULL,
    unit_price       NUMERIC(10,2) DEFAULT 0 NOT NULL,

    FOREIGN KEY (category_id) REFERENCES sales.category(category_id),
    FOREIGN KEY (supplier_id) REFERENCES sales.supplier(supplier_id)
);

-- 6. Create Orders Table (Links to Customer & Employee)
CREATE TABLE IF NOT EXISTS sales.orders (
    order_id         SERIAL PRIMARY KEY,
    customer_id      INT NOT NULL,
    employee_id      INT NOT NULL,
    order_date       DATE DEFAULT CURRENT_DATE NOT NULL,
    order_status     VARCHAR(20) DEFAULT 'Pending' NOT NULL,

    FOREIGN KEY (customer_id) REFERENCES sales.customer(customer_id),
    FOREIGN KEY (employee_id) REFERENCES sales.employee(employee_id)
);

-- 7. Create Order Detail Table (Links to Orders & Product)
CREATE TABLE IF NOT EXISTS sales.order_detail (
    order_detail_id  SERIAL PRIMARY KEY,
    order_id         INT NOT NULL,
    product_id       INT NOT NULL,
    quantity         INT NOT NULL,
    unit_price       NUMERIC(10,2) NOT NULL,

    -- This calculation IS immutable and safe
    line_total       NUMERIC(12,2)
        GENERATED ALWAYS AS (quantity * unit_price) STORED,

    FOREIGN KEY (order_id) REFERENCES sales.orders(order_id),
    FOREIGN KEY (product_id) REFERENCES sales.product(product_id)
);

ALTER TABLE sales.orders
    ADD CONSTRAINT chk_order_date_after_2024
    CHECK (order_date >= '2024-01-01');

ALTER TABLE sales.order_detail
    ADD CONSTRAINT chk_quantity_positive
    CHECK (quantity > 0);

ALTER TABLE sales.product
    ADD CONSTRAINT chk_unit_price_not_negative
    CHECK (unit_price >= 0);

ALTER TABLE sales.orders
    ADD CONSTRAINT chk_status_valid
    CHECK (order_status IN ('Pending','Shipped','Completed','Cancelled'));

ALTER TABLE sales.employee
    ADD CONSTRAINT chk_emp_name_not_blank
    CHECK (TRIM(emp_name) <> '');


INSERT INTO sales.customer (first_name, last_name, email)
VALUES
('Aisha','Khan','aisha.khan@example.com'),
('David','Green','david.green@example.com'),
('Maria','Lopez','maria.lopez@example.com'),
('John','Carter','john.carter@example.com'),
('Fatima','Riaz','fatima.riaz@example.com'),
('Bruce','Wayne','bruce.wayne@example.com');


-- 1. Insert Employees (Note: We use DISTINCT to avoid duplicate employees if run twice)
INSERT INTO sales.employee (emp_name)
SELECT t.emp_name 
FROM (VALUES
    ('Samuel Peters'),
    ('Jane Foster'),
    ('Linda Price'),
    ('Omar Siddiqui'),
    ('Henry Wells'),
    ('Clark Kent')
) AS t(emp_name)
WHERE NOT EXISTS (SELECT 1 FROM sales.employee WHERE emp_name = t.emp_name);

-- 2. Insert Categories (Safe Mode)
INSERT INTO sales.category (category_name)
VALUES
    ('Electronics'),
    ('Home Appliances'),
    ('Clothing'),
    ('Sports'),
    ('Books'),
    ('Furniture')
ON CONFLICT (category_name) DO NOTHING;

-- 3. Insert Suppliers (Safe Mode)
INSERT INTO sales.supplier (supplier_name, contact_email)
VALUES
    ('Global Tech Supplies','support@globaltech.com'),
    ('FreshHome Distributors','hello@freshhome.com'),
    ('Peak Apparel Co','info@peakapparel.com'),
    ('Sportify International','sales@sportify.com'),
    ('BookVerse Publishers','contact@bookverse.com'),
    ('UrbanLiving Furnishings','hello@urbanliving.com')
ON CONFLICT (supplier_name) DO NOTHING;

-- 4. Insert Products
INSERT INTO sales.product (category_id, supplier_id, product_name, unit_price)
VALUES
((SELECT category_id FROM sales.category WHERE category_name='Electronics'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='Global Tech Supplies'),
 'Smartphone X200', 599.99),

((SELECT category_id FROM sales.category WHERE category_name='Electronics'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='Global Tech Supplies'),
 'Wireless Headphones', 129.50),

((SELECT category_id FROM sales.category WHERE category_name='Clothing'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='Peak Apparel Co'),
 'Winter Jacket', 89.90),

((SELECT category_id FROM sales.category WHERE category_name='Sports'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='Sportify International'),
 'Yoga Mat Premium', 39.99),

((SELECT category_id FROM sales.category WHERE category_name='Books'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='BookVerse Publishers'),
 'Data Science Handbook', 45.00),

((SELECT category_id FROM sales.category WHERE category_name='Furniture'),
 (SELECT supplier_id FROM sales.supplier WHERE supplier_name='UrbanLiving Furnishings'),
 'Office Chair Deluxe', 199.99);

 
INSERT INTO sales.orders (customer_id, employee_id, order_date, order_status)
VALUES
((SELECT customer_id FROM sales.customer WHERE email='aisha.khan@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Samuel Peters'),
 CURRENT_DATE - INTERVAL '20 days','Completed'),

((SELECT customer_id FROM sales.customer WHERE email='david.green@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Jane Foster'),
 CURRENT_DATE - INTERVAL '12 days','Shipped'),

((SELECT customer_id FROM sales.customer WHERE email='maria.lopez@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Linda Price'),
 CURRENT_DATE - INTERVAL '35 days','Pending'),

((SELECT customer_id FROM sales.customer WHERE email='john.carter@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Omar Siddiqui'),
 CURRENT_DATE - INTERVAL '50 days','Completed'),

((SELECT customer_id FROM sales.customer WHERE email='fatima.riaz@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Henry Wells'),
 CURRENT_DATE - INTERVAL '25 days','Pending'),

((SELECT customer_id FROM sales.customer WHERE email='bruce.wayne@example.com'),
 (SELECT employee_id FROM sales.employee WHERE emp_name='Clark Kent'),
 CURRENT_DATE - INTERVAL '5 days','Shipped');


INSERT INTO sales.order_detail (order_id, product_id, quantity, unit_price)
VALUES
-- Order 1
((SELECT order_id FROM sales.orders ORDER BY order_id LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Smartphone X200'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Smartphone X200')),

((SELECT order_id FROM sales.orders ORDER BY order_id LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Wireless Headphones'), 2,
 (SELECT unit_price FROM sales.product WHERE product_name='Wireless Headphones')),

-- Order 2
((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 1 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Winter Jacket'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Winter Jacket')),

((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 1 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Yoga Mat Premium'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Yoga Mat Premium')),

-- Order 3
((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 2 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Data Science Handbook'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Data Science Handbook')),

((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 2 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Office Chair Deluxe'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Office Chair Deluxe')),

-- Order 4
((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 3 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Smartphone X200'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Smartphone X200')),

((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 3 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Data Science Handbook'), 2,
 (SELECT unit_price FROM sales.product WHERE product_name='Data Science Handbook')),

-- Order 5
((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 4 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Wireless Headphones'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Wireless Headphones')),

((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 4 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Office Chair Deluxe'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Office Chair Deluxe')),

-- Order 6
((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 5 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Yoga Mat Premium'), 3,
 (SELECT unit_price FROM sales.product WHERE product_name='Yoga Mat Premium')),

((SELECT order_id FROM sales.orders ORDER BY order_id OFFSET 5 LIMIT 1),
 (SELECT product_id FROM sales.product WHERE product_name='Winter Jacket'), 1,
 (SELECT unit_price FROM sales.product WHERE product_name='Winter Jacket'));

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--task 5.1
CREATE OR REPLACE FUNCTION sales.update_order_field(
    p_order_id INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID
AS $$
BEGIN
    EXECUTE format(
        'UPDATE sales.orders SET %I = %L WHERE order_id = %L',
        p_column_name, p_new_value, p_order_id
    );
END;
$$ LANGUAGE plpgsql;
SELECT sales.update_order_field(2, 'order_status', 'Shipped');

--task 5.2

CREATE OR REPLACE FUNCTION sales.add_transaction(
    p_customer_email   TEXT,                -- natural key for customer
    p_employee_name    TEXT,                -- natural key for employee
    p_product_name     TEXT,                -- natural key for product
    p_quantity         INT,                 -- must be > 0 (constraint on order_detail)
    p_order_date       DATE DEFAULT CURRENT_DATE,  -- must be >= 2024-01-01 (constraint)
    p_order_status     TEXT DEFAULT 'Pending',     -- must be in allowed set
    p_unit_price       NUMERIC(10,2) DEFAULT NULL  -- optional override; if NULL uses product price
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id  INT;
    v_employee_id  INT;
    v_product_id   INT;
    v_unit_price   NUMERIC(10,2);
    v_order_id     INT;
BEGIN
    -- Look up natural keys and fail fast if not found to avoid silent errors.
    SELECT customer_id INTO v_customer_id
    FROM sales.customer
    WHERE email = p_customer_email;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Customer with email % not found', p_customer_email;
    END IF;

    SELECT employee_id INTO v_employee_id
    FROM sales.employee
    WHERE emp_name = p_employee_name;

    IF v_employee_id IS NULL THEN
        RAISE EXCEPTION 'Employee with name % not found', p_employee_name;
    END IF;

    SELECT product_id, unit_price INTO v_product_id, v_unit_price
    FROM sales.product
    WHERE product_name = p_product_name;

    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Product with name % not found', p_product_name;
    END IF;

    -- If caller did not provide unit_price, use the product's current unit_price.
    IF p_unit_price IS NOT NULL THEN
        v_unit_price := p_unit_price;
    END IF;

    -- Insert into orders (transaction header).
    INSERT INTO sales.orders (customer_id, employee_id, order_date, order_status)
    VALUES (v_customer_id, v_employee_id, p_order_date, p_order_status)
    RETURNING order_id INTO v_order_id;

    -- Insert into order_detail (transaction line).
    INSERT INTO sales.order_detail (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, v_product_id, p_quantity, v_unit_price);

    -- Confirmation (no return value, but visible in messages).
    RAISE NOTICE 'Transaction created: order_id=%, customer_email=%, product=%, quantity=%',
        v_order_id, p_customer_email, p_product_name, p_quantity;
END;
$$;

SELECT sales.add_transaction(
    'aisha.khan@example.com',
    'Samuel Peters',
    'Smartphone X200',
    1,
    (CURRENT_DATE - INTERVAL '3 days')::DATE,
    'Completed',
    NULL
);
-- check
SELECT o.order_id,
       o.order_date,
       o.order_status,
       e.emp_name AS handled_by
FROM sales.orders o
JOIN sales.customer c ON o.customer_id = c.customer_id
JOIN sales.employee e ON o.employee_id = e.employee_id
WHERE c.email = 'aisha.khan@example.com'
ORDER BY o.order_date DESC;
---------------------
--task 6
CREATE OR REPLACE VIEW sales.v_recent_quarter_analytics AS
WITH latest_q AS (
    -- Find the start of the most recent quarter that appears in orders
    SELECT date_trunc('quarter', max(order_date))::date AS q_start
    FROM sales.orders
),
orders_in_q AS (
    SELECT o.order_id,
           o.order_date,
           o.order_status,
           o.customer_id
    FROM sales.orders o
    CROSS JOIN latest_q lq
    WHERE o.order_date >= lq.q_start
      AND o.order_date <  lq.q_start + INTERVAL '3 months'
)
SELECT
    to_char(lq.q_start, 'YYYY-"Q"Q')      AS quarter_label,
    c.full_name                           AS customer_name,
    o.order_date,
    o.order_status,
    SUM(od.line_total)                    AS order_total
FROM orders_in_q o
JOIN sales.customer c
  ON c.customer_id = o.customer_id
JOIN sales.order_detail od
  ON od.order_id = o.order_id
CROSS JOIN latest_q lq
GROUP BY
    lq.q_start,
    c.full_name,
    o.order_date,
    o.order_status;
	
SELECT * FROM sales.v_recent_quarter_analytics;

--task 7
-- Create a read-only role for managers.
CREATE ROLE manager_readonly
    LOGIN
    PASSWORD 'FinalTask!'  
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT;

-- Allow the manager to connect to the retail_db database.
GRANT CONNECT ON DATABASE retail_db TO manager_readonly;

-- Allow the manager to see and query objects in the sales schema.
GRANT USAGE ON SCHEMA sales TO manager_readonly;

-- Allow SELECT on all existing tables in the schema.
GRANT SELECT ON ALL TABLES IN SCHEMA sales TO manager_readonly;

-- Ensure that any future tables created in sales schema are also readable.
ALTER DEFAULT PRIVILEGES IN SCHEMA sales
GRANT SELECT ON TABLES TO manager_readonly;

SET ROLE manager_readonly;
SELECT * FROM sales.v_recent_quarter_analytics;
select * from order_detail


