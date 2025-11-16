------------------------------------------------------------------
-- 0. CREATE DATABASE (run once from a superuser connection)
------------------------------------------------------------------
-- CREATE DATABASE metro_project;
-- \c metro_project;

------------------------------------------------------------------
-- 1. CREATE SCHEMA AND SET SEARCH PATH
------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS metro;
SET search_path TO metro;

------------------------------------------------------------------
-- 2. CLEANUP (RERUNNABLE)
------------------------------------------------------------------
DROP TABLE IF EXISTS ticket_type_promotions      CASCADE;
DROP TABLE IF EXISTS promotions                  CASCADE;
DROP TABLE IF EXISTS ticket_types                CASCADE;
DROP TABLE IF EXISTS maintenance_logs            CASCADE;
DROP TABLE IF EXISTS stop_times                  CASCADE;
DROP TABLE IF EXISTS trips                       CASCADE;
DROP TABLE IF EXISTS schedules                   CASCADE;
DROP TABLE IF EXISTS line_stations               CASCADE;
DROP TABLE IF EXISTS employees                   CASCADE;
DROP TABLE IF EXISTS roles                       CASCADE;
DROP TABLE IF EXISTS trains                      CASCADE;
DROP TABLE IF EXISTS stations                    CASCADE;
DROP TABLE IF EXISTS lines                       CASCADE;

------------------------------------------------------------------
-- 3. CREATE TABLES (NO record_ts YET)
--    DDL ORDER: PARENTS -> CHILDREN (AVOID FK ERRORS)
------------------------------------------------------------------

---------------------------------------------------
-- Table 1: lines
---------------------------------------------------
CREATE TABLE lines (
    line_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    line_name   VARCHAR(100) NOT NULL UNIQUE,
    line_color  VARCHAR(50)  NOT NULL,
    -- Check: line name must not be empty
    CONSTRAINT chk_lines_name_nonempty CHECK (line_name <> '')
);

---------------------------------------------------
-- Table 2: stations
---------------------------------------------------
CREATE TABLE stations (
    station_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_name       VARCHAR(100) NOT NULL UNIQUE,
    location_desc      VARCHAR(255),
    has_disabled_access BOOLEAN NOT NULL,
    open_date          DATE NOT NULL,
    -- Check: station open date >= 2000-01-01 (assignment requirement)
    CONSTRAINT chk_stations_open_date CHECK (open_date >= DATE '2000-01-01')
);

---------------------------------------------------
-- Table 4: trains
---------------------------------------------------
CREATE TABLE trains (
    train_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name     VARCHAR(100),
    capacity       INT NOT NULL,
    purchase_date  DATE,
    status         VARCHAR(50) NOT NULL,
    -- Check: capacity cannot be negative (measured value)
    CONSTRAINT chk_trains_capacity_nonneg CHECK (capacity >= 0),
    -- Check: purchase date, if provided, must be >= 2000-01-01
    CONSTRAINT chk_trains_purchase_date CHECK (purchase_date IS NULL OR purchase_date >= DATE '2000-01-01'),
    -- Check: status can only be one of these values (gender-like example)
    CONSTRAINT chk_trains_status CHECK (status IN ('Active', 'In Repair', 'Retired'))
);

---------------------------------------------------
-- Table 5: roles
---------------------------------------------------
CREATE TABLE roles (
    role_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name  VARCHAR(100) NOT NULL UNIQUE
);

---------------------------------------------------
-- Table 6: employees
---------------------------------------------------
CREATE TABLE employees (
    employee_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    hire_date    DATE NOT NULL,
    role_id      INT  NOT NULL,
    manager_id   INT,
    FOREIGN KEY (role_id)    REFERENCES roles(role_id),
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id),
    -- Check: hire date must be >= 2000-01-01
    CONSTRAINT chk_employees_hire_date CHECK (hire_date >= DATE '2000-01-01')
);

---------------------------------------------------
-- Table 11: ticket_types
---------------------------------------------------
CREATE TABLE ticket_types (
    ticket_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name      VARCHAR(100) NOT NULL UNIQUE,
    base_price     DECIMAL(10, 2) NOT NULL,
    validity_days  INT,
    -- Check: ticket price cannot be negative (measured value)
    CONSTRAINT chk_ticket_types_price_nonneg CHECK (base_price >= 0)
);

---------------------------------------------------
-- Table 12: promotions
---------------------------------------------------
CREATE TABLE promotions (
    promotion_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_name    VARCHAR(100) NOT NULL UNIQUE,
    discount_percent  DECIMAL(5, 2) NOT NULL,
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    -- Check: start date >= 2000-01-01
    CONSTRAINT chk_promotions_start_date CHECK (start_date >= DATE '2000-01-01'),
    -- Check: end date must be >= start date
    CONSTRAINT chk_promotions_date_range CHECK (end_date >= start_date)
);

---------------------------------------------------
-- Table 7: schedules
---------------------------------------------------
CREATE TABLE schedules (
    schedule_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schedule_name  VARCHAR(100) NOT NULL,
    line_id        INT NOT NULL,
    direction      VARCHAR(50) NOT NULL,
    frequency_mins INT NOT NULL,
    FOREIGN KEY (line_id) REFERENCES lines(line_id),
    -- Check: frequency must be positive
    CONSTRAINT chk_schedules_frequency CHECK (frequency_mins > 0)
);

---------------------------------------------------
-- Table 3: line_stations (junction)
---------------------------------------------------
CREATE TABLE line_stations (
    line_id       INT NOT NULL,
    station_id    INT NOT NULL,
    stop_sequence INT NOT NULL,
    PRIMARY KEY (line_id, station_id),
    FOREIGN KEY (line_id)    REFERENCES lines(line_id),
    FOREIGN KEY (station_id) REFERENCES stations(station_id),
    -- Check: stop sequence must be positive
    CONSTRAINT chk_line_stations_sequence CHECK (stop_sequence > 0)
);

---------------------------------------------------
-- Table 8: trips
---------------------------------------------------
CREATE TABLE trips (
    trip_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_date   DATE NOT NULL,
    schedule_id INT NOT NULL,
    train_id    INT NOT NULL,
    driver_id   INT NOT NULL,
    FOREIGN KEY (schedule_id) REFERENCES schedules(schedule_id),
    FOREIGN KEY (train_id)    REFERENCES trains(train_id),
    FOREIGN KEY (driver_id)   REFERENCES employees(employee_id),
    -- Check: trip date >= 2000-01-01
    CONSTRAINT chk_trips_date CHECK (trip_date >= DATE '2000-01-01')
);

---------------------------------------------------
-- Table 9: stop_times
---------------------------------------------------
CREATE TABLE stop_times (
    stop_time_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_id        INT NOT NULL,
    station_id     INT NOT NULL,
    arrival_time   TIME,
    departure_time TIME,
    FOREIGN KEY (trip_id)    REFERENCES trips(trip_id),
    FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

---------------------------------------------------
-- Table 10: maintenance_logs
---------------------------------------------------
CREATE TABLE maintenance_logs (
    log_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_type       VARCHAR(50) NOT NULL,
    asset_id         INT NOT NULL,
    maintenance_date DATE NOT NULL,
    description      TEXT NOT NULL,
    technician_id    INT NOT NULL,
    FOREIGN KEY (technician_id) REFERENCES employees(employee_id),
    -- Check: maintenance date >= 2000-01-01
    CONSTRAINT chk_maint_date CHECK (maintenance_date >= DATE '2000-01-01'),
    -- Check: asset_type limited to specific values
    CONSTRAINT chk_maint_asset_type CHECK (asset_type IN ('Train','Station','Track'))
);

---------------------------------------------------
-- Table 13: ticket_type_promotions (junction)
---------------------------------------------------
CREATE TABLE ticket_type_promotions (
    ticket_type_id INT NOT NULL,
    promotion_id   INT NOT NULL,
    PRIMARY KEY (ticket_type_id, promotion_id),
    FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(ticket_type_id),
    FOREIGN KEY (promotion_id)   REFERENCES promotions(promotion_id)
);

------------------------------------------------------------------
-- 4. POPULATE TABLES WITH SAMPLE DATA (2+ ROWS EACH, 20+ TOTAL)
--    USE WHERE NOT EXISTS OR ON CONFLICT TO AVOID DUPLICATES
------------------------------------------------------------------

-----------------------------
-- lines
-----------------------------
INSERT INTO lines (line_name, line_color)
SELECT 'Central Line','Red'
WHERE NOT EXISTS (SELECT 1 FROM lines WHERE line_name = 'Central Line');

INSERT INTO lines (line_name, line_color)
SELECT 'Circle Line','Yellow'
WHERE NOT EXISTS (SELECT 1 FROM lines WHERE line_name = 'Circle Line');

-----------------------------
-- stations
-----------------------------
INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'Downtown Central','123 Main St',TRUE,'2005-05-01'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'Downtown Central');

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'North Park','800 North Ave',TRUE,'2002-10-11'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'North Park');

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'West End','450 Sunset Blvd',FALSE,'2008-02-20'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'West End');

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'City Hall','1 Government Plaza',TRUE,'2005-06-01'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'City Hall');

-----------------------------
-- roles
-----------------------------
INSERT INTO roles (role_name)
SELECT 'Manager'
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Manager');

INSERT INTO roles (role_name)
SELECT 'Train Driver'
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Train Driver');

INSERT INTO roles (role_name)
SELECT 'Station Agent'
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Station Agent');

INSERT INTO roles (role_name)
SELECT 'Technician'
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Technician');

-----------------------------
-- employees
-----------------------------
INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Ada','Lovelace','2010-01-15',
       (SELECT role_id FROM roles WHERE role_name='Manager'),
       NULL
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE first_name='Ada' AND last_name='Lovelace');

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Grace','Hopper','2012-07-22',
       (SELECT role_id FROM roles WHERE role_name='Train Driver'),
       (SELECT employee_id FROM employees WHERE first_name='Ada' AND last_name='Lovelace')
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE first_name='Grace' AND last_name='Hopper');

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Charles','Babbage','2018-11-01',
       (SELECT role_id FROM roles WHERE role_name='Technician'),
       (SELECT employee_id FROM employees WHERE first_name='Ada' AND last_name='Lovelace')
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE first_name='Charles' AND last_name='Babbage');

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Tim','Berners-Lee','2022-02-10',
       (SELECT role_id FROM roles WHERE role_name='Station Agent'),
       (SELECT employee_id FROM employees WHERE first_name='Ada' AND last_name='Lovelace')
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE first_name='Tim' AND last_name='Berners-Lee');

-----------------------------
-- trains
-----------------------------
INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Siemens Velaro',850,'2015-01-20','Active'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE model_name='Siemens Velaro' AND status='Active');

INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Bombardier Movia',820,'2018-06-15','Active'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE model_name='Bombardier Movia' AND status='Active');

INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Siemens Velaro',850,'2015-01-20','In Repair'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE model_name='Siemens Velaro' AND status='In Repair');

-----------------------------
-- ticket_types
-----------------------------
INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Single Trip',2.75,NULL
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE type_name='Single Trip');

INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Daily Pass',10.50,1
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE type_name='Daily Pass');

INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Monthly Pass',127.00,30
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE type_name='Monthly Pass');

-----------------------------
-- promotions
-----------------------------
INSERT INTO promotions (promotion_name, discount_percent, start_date, end_date)
SELECT 'Weekend Saver',20.00,'2025-01-01','2025-12-31'
WHERE NOT EXISTS (SELECT 1 FROM promotions WHERE promotion_name='Weekend Saver');

INSERT INTO promotions (promotion_name, discount_percent, start_date, end_date)
SELECT 'Student Discount',15.00,'2025-08-01','2025-08-30'
WHERE NOT EXISTS (SELECT 1 FROM promotions WHERE promotion_name='Student Discount');

-----------------------------
-- schedules
-----------------------------
INSERT INTO schedules (schedule_name, line_id, direction, frequency_mins)
SELECT 'Weekday Peak',
       (SELECT line_id FROM lines WHERE line_name='Central Line'),
       'Northbound',5
WHERE NOT EXISTS (SELECT 1 FROM schedules WHERE schedule_name='Weekday Peak');

INSERT INTO schedules (schedule_name, line_id, direction, frequency_mins)
SELECT 'Weekend All Day',
       (SELECT line_id FROM lines WHERE line_name='Circle Line'),
       'Clockwise',8
WHERE NOT EXISTS (SELECT 1 FROM schedules WHERE schedule_name='Weekend All Day');

-----------------------------
-- line_stations
-----------------------------
INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE line_name='Central Line'),
       (SELECT station_id FROM stations WHERE station_name='Downtown Central'),
       1
WHERE NOT EXISTS (
    SELECT 1 FROM line_stations
    WHERE line_id=(SELECT line_id FROM lines WHERE line_name='Central Line')
      AND station_id=(SELECT station_id FROM stations WHERE station_name='Downtown Central')
);

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE line_name='Central Line'),
       (SELECT station_id FROM stations WHERE station_name='North Park'),
       2
WHERE NOT EXISTS (
    SELECT 1 FROM line_stations
    WHERE line_id=(SELECT line_id FROM lines WHERE line_name='Central Line')
      AND station_id=(SELECT station_id FROM stations WHERE station_name='North Park')
);

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE line_name='Circle Line'),
       (SELECT station_id FROM stations WHERE station_name='West End'),
       1
WHERE NOT EXISTS (
    SELECT 1 FROM line_stations
    WHERE line_id=(SELECT line_id FROM lines WHERE line_name='Circle Line')
      AND station_id=(SELECT station_id FROM stations WHERE station_name='West End')
);

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE line_name='Circle Line'),
       (SELECT station_id FROM stations WHERE station_name='City Hall'),
       2
WHERE NOT EXISTS (
    SELECT 1 FROM line_stations
    WHERE line_id=(SELECT line_id FROM lines WHERE line_name='Circle Line')
      AND station_id=(SELECT station_id FROM stations WHERE station_name='City Hall')
);

-----------------------------
-- trips
-----------------------------
INSERT INTO trips (trip_date, schedule_id, train_id, driver_id)
SELECT '2025-01-24',
       (SELECT schedule_id FROM schedules WHERE schedule_name='Weekday Peak'),
       (SELECT train_id    FROM trains    WHERE model_name='Siemens Velaro' AND status='Active'),
       (SELECT employee_id FROM employees WHERE first_name='Grace' AND last_name='Hopper')
WHERE NOT EXISTS (
    SELECT 1 FROM trips
    WHERE trip_date = '2025-01-24'
      AND schedule_id = (SELECT schedule_id FROM schedules WHERE schedule_name='Weekday Peak')
);

INSERT INTO trips (trip_date, schedule_id, train_id, driver_id)
SELECT '2025-01-25',
       (SELECT schedule_id FROM schedules WHERE schedule_name='Weekend All Day'),
       (SELECT train_id    FROM trains    WHERE model_name='Bombardier Movia' AND status='Active'),
       (SELECT employee_id FROM employees WHERE first_name='Grace' AND last_name='Hopper')
WHERE NOT EXISTS (
    SELECT 1 FROM trips
    WHERE trip_date = '2025-01-25'
      AND schedule_id = (SELECT schedule_id FROM schedules WHERE schedule_name='Weekend All Day')
);

-----------------------------
-- stop_times
-----------------------------
INSERT INTO stop_times (trip_id, station_id, arrival_time, departure_time)
SELECT (SELECT MIN(trip_id) FROM trips),
       (SELECT station_id FROM stations WHERE station_name='Downtown Central'),
       NULL,'08:00'
WHERE NOT EXISTS (
    SELECT 1 FROM stop_times
    WHERE trip_id    = (SELECT MIN(trip_id) FROM trips)
      AND station_id = (SELECT station_id FROM stations WHERE station_name='Downtown Central')
);

INSERT INTO stop_times (trip_id, station_id, arrival_time, departure_time)
SELECT (SELECT MIN(trip_id) FROM trips),
       (SELECT station_id FROM stations WHERE station_name='North Park'),
       '08:05','08:06'
WHERE NOT EXISTS (
    SELECT 1 FROM stop_times
    WHERE trip_id    = (SELECT MIN(trip_id) FROM trips)
      AND station_id = (SELECT station_id FROM stations WHERE station_name='North Park')
);

INSERT INTO stop_times (trip_id, station_id, arrival_time, departure_time)
SELECT (SELECT MIN(trip_id) FROM trips),
       (SELECT station_id FROM stations WHERE station_name='West End'),
       '08:11',NULL
WHERE NOT EXISTS (
    SELECT 1 FROM stop_times
    WHERE trip_id    = (SELECT MIN(trip_id) FROM trips)
      AND station_id = (SELECT station_id FROM stations WHERE station_name='West End')
);

-----------------------------
-- maintenance_logs
-----------------------------
INSERT INTO maintenance_logs (asset_type, asset_id, maintenance_date, description, technician_id)
SELECT 'Train',503,'2025-10-22','Replaced faulty brake pads',
       (SELECT employee_id FROM employees WHERE first_name='Charles' AND last_name='Babbage')
WHERE NOT EXISTS (
    SELECT 1 FROM maintenance_logs
    WHERE asset_type='Train' AND asset_id=503 AND maintenance_date='2025-10-22'
);

INSERT INTO maintenance_logs (asset_type, asset_id, maintenance_date, description, technician_id)
SELECT 'Station', (SELECT station_id FROM stations WHERE station_name='West End'),
       '2025-09-15','Repaired escalator motor',
       (SELECT employee_id FROM employees WHERE first_name='Charles' AND last_name='Babbage')
WHERE NOT EXISTS (
    SELECT 1 FROM maintenance_logs
    WHERE asset_type='Station'
      AND asset_id=(SELECT station_id FROM stations WHERE station_name='West End')
      AND maintenance_date='2025-09-15'
);

-----------------------------
-- ticket_type_promotions
-----------------------------
INSERT INTO ticket_type_promotions (ticket_type_id, promotion_id)
SELECT (SELECT ticket_type_id FROM ticket_types WHERE type_name='Daily Pass'),
       (SELECT promotion_id   FROM promotions   WHERE promotion_name='Weekend Saver')
WHERE NOT EXISTS (
    SELECT 1 FROM ticket_type_promotions
    WHERE ticket_type_id = (SELECT ticket_type_id FROM ticket_types WHERE type_name='Daily Pass')
      AND promotion_id   = (SELECT promotion_id   FROM promotions   WHERE promotion_name='Weekend Saver')
);

INSERT INTO ticket_type_promotions (ticket_type_id, promotion_id)
SELECT (SELECT ticket_type_id FROM ticket_types WHERE type_name='Monthly Pass'),
       (SELECT promotion_id   FROM promotions   WHERE promotion_name='Student Discount')
WHERE NOT EXISTS (
    SELECT 1 FROM ticket_type_promotions
    WHERE ticket_type_id = (SELECT ticket_type_id FROM ticket_types WHERE type_name='Monthly Pass')
      AND promotion_id   = (SELECT promotion_id   FROM promotions   WHERE promotion_name='Student Discount')
);

------------------------------------------------------------------
-- 5. ADD record_ts VIA ALTER TABLE (NOT NULL, DEFAULT CURRENT_DATE)
------------------------------------------------------------------
ALTER TABLE lines                 ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE stations              ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE trains                ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE roles                 ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE employees             ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE schedules             ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE line_stations         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE trips                 ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE stop_times            ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE maintenance_logs      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE ticket_types          ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE promotions            ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE ticket_type_promotions ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

------------------------------------------------------------------
-- 6. CHECK THAT record_ts IS POPULATED (SHOULD ALL BE ZERO)
------------------------------------------------------------------
SELECT 'lines'                  AS table_name, COUNT(*) AS missing_record_ts FROM lines                  WHERE record_ts IS NULL
UNION ALL
SELECT 'stations',                            COUNT(*) FROM stations               WHERE record_ts IS NULL
UNION ALL
SELECT 'trains',                              COUNT(*) FROM trains                 WHERE record_ts IS NULL
UNION ALL
SELECT 'roles',                               COUNT(*) FROM roles                  WHERE record_ts IS NULL
UNION ALL
SELECT 'employees',                           COUNT(*) FROM employees              WHERE record_ts IS NULL
UNION ALL
SELECT 'schedules',                           COUNT(*) FROM schedules              WHERE record_ts IS NULL
UNION ALL
SELECT 'line_stations',                       COUNT(*) FROM line_stations          WHERE record_ts IS NULL
UNION ALL
SELECT 'trips',                               COUNT(*) FROM trips                  WHERE record_ts IS NULL
UNION ALL
SELECT 'stop_times',                          COUNT(*) FROM stop_times             WHERE record_ts IS NULL
UNION ALL
SELECT 'maintenance_logs',                    COUNT(*) FROM maintenance_logs       WHERE record_ts IS NULL
UNION ALL
SELECT 'ticket_types',                        COUNT(*) FROM ticket_types           WHERE record_ts IS NULL
UNION ALL
SELECT 'promotions',                          COUNT(*) FROM promotions             WHERE record_ts IS NULL
UNION ALL
SELECT 'ticket_type_promotions',              COUNT(*) FROM ticket_type_promotions WHERE record_ts IS NULL;


SELECT * FROM metro.trips;
