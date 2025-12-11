
BEGIN;

CREATE SCHEMA IF NOT EXISTS metro;
SET search_path TO metro;


-- 1. Table: lines
CREATE TABLE IF NOT EXISTS lines (
    line_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    line_name   VARCHAR(100) NOT NULL UNIQUE,
    line_color  VARCHAR(50)  NOT NULL,
    CONSTRAINT chk_lines_name_nonempty CHECK (line_name <> '')
);

-- 2. Table: stations
CREATE TABLE IF NOT EXISTS stations (
    station_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_name        VARCHAR(100) NOT NULL UNIQUE,
    location_desc       VARCHAR(255),
    has_disabled_access BOOLEAN NOT NULL DEFAULT FALSE,
    open_date           DATE NOT NULL,
    CONSTRAINT chk_stations_open_date CHECK (open_date >= DATE '2000-01-01')
);

-- 3. Table: trains
CREATE TABLE IF NOT EXISTS trains (
    train_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name    VARCHAR(100),
    capacity      INT NOT NULL,
    purchase_date DATE,
    status        VARCHAR(50) NOT NULL,
    CONSTRAINT chk_trains_capacity_nonneg CHECK (capacity >= 0),
    CONSTRAINT chk_trains_purchase_date CHECK (purchase_date IS NULL OR purchase_date >= DATE '2000-01-01'),
    CONSTRAINT chk_trains_status CHECK (status IN ('Active', 'In Repair', 'Retired'))
);

-- 4. Table: roles
CREATE TABLE IF NOT EXISTS roles (
    role_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name VARCHAR(100) NOT NULL UNIQUE
);

-- 5. Table: employees
CREATE TABLE IF NOT EXISTS employees (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    hire_date   DATE NOT NULL DEFAULT CURRENT_DATE, 
    role_id     INT  NOT NULL,
    manager_id  INT,
    FOREIGN KEY (role_id)    REFERENCES roles(role_id),
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id),
    CONSTRAINT chk_employees_hire_date CHECK (hire_date >= DATE '2000-01-01')
);

-- 6. Table: ticket_types
CREATE TABLE IF NOT EXISTS ticket_types (
    ticket_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name      VARCHAR(100) NOT NULL UNIQUE,
    base_price     DECIMAL(10, 2) NOT NULL,
    validity_days  INT,
    CONSTRAINT chk_ticket_types_price_nonneg CHECK (base_price >= 0)
);

-- 7. Table: promotions
CREATE TABLE IF NOT EXISTS promotions (
    promotion_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_name   VARCHAR(100) NOT NULL UNIQUE,
    discount_percent DECIMAL(5, 2) NOT NULL,
    start_date       DATE NOT NULL,
    end_date         DATE NOT NULL,
    CONSTRAINT chk_promotions_start_date CHECK (start_date >= DATE '2000-01-01'),
    CONSTRAINT chk_promotions_date_range CHECK (end_date >= start_date)
);

-- 8. Table: schedules
CREATE TABLE IF NOT EXISTS schedules (
    schedule_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schedule_name  VARCHAR(100) NOT NULL,
    line_id        INT NOT NULL,
    direction      VARCHAR(50) NOT NULL,
    frequency_mins INT NOT NULL,
    FOREIGN KEY (line_id) REFERENCES lines(line_id),
    CONSTRAINT chk_schedules_frequency CHECK (frequency_mins > 0)
);

-- 9. Table: line_stations (Junction)
CREATE TABLE IF NOT EXISTS line_stations (
    line_id       INT NOT NULL,
    station_id    INT NOT NULL,
    stop_sequence INT NOT NULL,
    PRIMARY KEY (line_id, station_id),
    FOREIGN KEY (line_id)    REFERENCES lines(line_id),
    FOREIGN KEY (station_id) REFERENCES stations(station_id),
    CONSTRAINT chk_line_stations_sequence CHECK (stop_sequence > 0)
);

-- 10. Table: trips
CREATE TABLE IF NOT EXISTS trips (
    trip_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_date   DATE NOT NULL,
    schedule_id INT NOT NULL,
    train_id    INT NOT NULL,
    driver_id   INT NOT NULL,
    FOREIGN KEY (schedule_id) REFERENCES schedules(schedule_id),
    FOREIGN KEY (train_id)    REFERENCES trains(train_id),
    FOREIGN KEY (driver_id)   REFERENCES employees(employee_id),
    CONSTRAINT chk_trips_date CHECK (trip_date >= DATE '2000-01-01')
);

-- 11. Table: stop_times
CREATE TABLE IF NOT EXISTS stop_times (
    stop_time_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_id        INT NOT NULL,
    station_id     INT NOT NULL,
    arrival_time   TIME,
    departure_time TIME,
    FOREIGN KEY (trip_id)    REFERENCES trips(trip_id),
    FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- 12. Table: maintenance_logs
CREATE TABLE IF NOT EXISTS maintenance_logs (
    log_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    maintenance_date DATE NOT NULL,
    description      TEXT NOT NULL,
    technician_id    INT NOT NULL,
    train_id         INT,
    station_id       INT,
    FOREIGN KEY (technician_id) REFERENCES employees(employee_id),
    FOREIGN KEY (train_id)      REFERENCES trains(train_id),
    FOREIGN KEY (station_id)    REFERENCES stations(station_id),
    CONSTRAINT chk_maint_date CHECK (maintenance_date >= DATE '2000-01-01'),
    CONSTRAINT chk_maint_exclusive_asset CHECK (
        (train_id IS NOT NULL AND station_id IS NULL) OR 
        (train_id IS NULL AND station_id IS NOT NULL)
    )
);

-- 13. Table: ticket_type_promotions (Junction)
CREATE TABLE IF NOT EXISTS ticket_type_promotions (
    ticket_type_id INT NOT NULL,
    promotion_id   INT NOT NULL,
    PRIMARY KEY (ticket_type_id, promotion_id),
    FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(ticket_type_id),
    FOREIGN KEY (promotion_id)   REFERENCES promotions(promotion_id)
);

COMMIT;

-- DATA POPULATION
BEGIN;

-- Lines
INSERT INTO lines (line_name, line_color)
SELECT 'Central Line', 'Red'
WHERE NOT EXISTS (SELECT 1 FROM lines WHERE UPPER(line_name) = UPPER('Central Line'));

INSERT INTO lines (line_name, line_color)
SELECT 'Circle Line', 'Yellow'
WHERE NOT EXISTS (SELECT 1 FROM lines WHERE UPPER(line_name) = UPPER('Circle Line'));

-- Stations
INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'Downtown Central', '123 Main St', TRUE, '2005-05-01'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE UPPER(station_name) = UPPER('Downtown Central'));

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'North Park', '800 North Ave', TRUE, '2002-10-11'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE UPPER(station_name) = UPPER('North Park'));

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'West End', '450 Sunset Blvd', FALSE, '2008-02-20'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE UPPER(station_name) = UPPER('West End'));

INSERT INTO stations (station_name, location_desc, has_disabled_access, open_date)
SELECT 'City Hall', '1 Government Plaza', TRUE, '2005-06-01'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE UPPER(station_name) = UPPER('City Hall'));

-- Roles
INSERT INTO roles (role_name) SELECT 'Manager' WHERE NOT EXISTS (SELECT 1 FROM roles WHERE UPPER(role_name) = UPPER('Manager'));
INSERT INTO roles (role_name) SELECT 'Train Driver' WHERE NOT EXISTS (SELECT 1 FROM roles WHERE UPPER(role_name) = UPPER('Train Driver'));
INSERT INTO roles (role_name) SELECT 'Station Agent' WHERE NOT EXISTS (SELECT 1 FROM roles WHERE UPPER(role_name) = UPPER('Station Agent'));
INSERT INTO roles (role_name) SELECT 'Technician' WHERE NOT EXISTS (SELECT 1 FROM roles WHERE UPPER(role_name) = UPPER('Technician'));

-- Employees
-- Note: Using LIMIT 1 in subqueries ensures we handle cases where duplicates might already exist gracefully.
INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Ada','Lovelace','2010-01-15', (SELECT role_id FROM roles WHERE UPPER(role_name)=UPPER('Manager') LIMIT 1), NULL
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE UPPER(first_name)=UPPER('Ada') AND UPPER(last_name)=UPPER('Lovelace'));

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Grace','Hopper','2012-07-22', (SELECT role_id FROM roles WHERE UPPER(role_name)=UPPER('Train Driver') LIMIT 1), (SELECT employee_id FROM employees WHERE UPPER(first_name)=UPPER('Ada') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE UPPER(first_name)=UPPER('Grace') AND UPPER(last_name)=UPPER('Hopper'));

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Charles','Babbage','2018-11-01', (SELECT role_id FROM roles WHERE UPPER(role_name)=UPPER('Technician') LIMIT 1), (SELECT employee_id FROM employees WHERE UPPER(first_name)=UPPER('Ada') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE UPPER(first_name)=UPPER('Charles') AND UPPER(last_name)=UPPER('Babbage'));

INSERT INTO employees (first_name, last_name, hire_date, role_id, manager_id)
SELECT 'Tim','Berners-Lee','2022-02-10', (SELECT role_id FROM roles WHERE UPPER(role_name)=UPPER('Station Agent') LIMIT 1), (SELECT employee_id FROM employees WHERE UPPER(first_name)=UPPER('Ada') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE UPPER(first_name)=UPPER('Tim') AND UPPER(last_name)=UPPER('Berners-Lee'));

-- Trains
INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Siemens Velaro', 850, '2015-01-20', 'Active'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE UPPER(model_name)=UPPER('Siemens Velaro') AND UPPER(status)=UPPER('Active'));

INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Bombardier Movia', 820, '2018-06-15', 'Active'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE UPPER(model_name)=UPPER('Bombardier Movia') AND UPPER(status)=UPPER('Active'));

INSERT INTO trains (model_name, capacity, purchase_date, status)
SELECT 'Siemens Velaro', 850, '2015-01-20', 'In Repair'
WHERE NOT EXISTS (SELECT 1 FROM trains WHERE UPPER(model_name)=UPPER('Siemens Velaro') AND UPPER(status)=UPPER('In Repair'));

-- Ticket Types
INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Single Trip', 2.75, NULL
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE UPPER(type_name) = UPPER('Single Trip'));

INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Daily Pass', 10.50, 1
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE UPPER(type_name) = UPPER('Daily Pass'));

INSERT INTO ticket_types (type_name, base_price, validity_days)
SELECT 'Monthly Pass', 127.00, 30
WHERE NOT EXISTS (SELECT 1 FROM ticket_types WHERE UPPER(type_name) = UPPER('Monthly Pass'));

-- Promotions
INSERT INTO promotions (promotion_name, discount_percent, start_date, end_date)
SELECT 'Weekend Saver', 20.00, '2025-01-01', '2025-12-31'
WHERE NOT EXISTS (SELECT 1 FROM promotions WHERE UPPER(promotion_name) = UPPER('Weekend Saver'));

INSERT INTO promotions (promotion_name, discount_percent, start_date, end_date)
SELECT 'Student Discount', 15.00, '2025-08-01', '2025-08-30'
WHERE NOT EXISTS (SELECT 1 FROM promotions WHERE UPPER(promotion_name) = UPPER('Student Discount'));

-- Schedules
INSERT INTO schedules (schedule_name, line_id, direction, frequency_mins)
SELECT 'Weekday Peak', (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Central Line')), 'Northbound', 5
WHERE NOT EXISTS (SELECT 1 FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekday Peak'));

INSERT INTO schedules (schedule_name, line_id, direction, frequency_mins)
SELECT 'Weekend All Day', (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Circle Line')), 'Clockwise', 8
WHERE NOT EXISTS (SELECT 1 FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekend All Day'));

-- Line Stations
INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Central Line')), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('Downtown Central')), 1
WHERE NOT EXISTS (SELECT 1 FROM line_stations WHERE line_id=(SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Central Line')) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('Downtown Central')));

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Central Line')), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('North Park')), 2
WHERE NOT EXISTS (SELECT 1 FROM line_stations WHERE line_id=(SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Central Line')) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('North Park')));

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Circle Line')), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('West End')), 1
WHERE NOT EXISTS (SELECT 1 FROM line_stations WHERE line_id=(SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Circle Line')) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('West End')));

INSERT INTO line_stations (line_id, station_id, stop_sequence)
SELECT (SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Circle Line')), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('City Hall')), 2
WHERE NOT EXISTS (SELECT 1 FROM line_stations WHERE line_id=(SELECT line_id FROM lines WHERE UPPER(line_name)=UPPER('Circle Line')) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('City Hall')));

-- Trips
INSERT INTO trips (trip_date, schedule_id, train_id, driver_id)
SELECT '2025-01-24', 
       (SELECT schedule_id FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekday Peak') LIMIT 1), 
       (SELECT train_id FROM trains WHERE UPPER(model_name)=UPPER('Siemens Velaro') LIMIT 1), 
       (SELECT employee_id FROM employees WHERE UPPER(first_name)=UPPER('Grace') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM trips WHERE trip_date='2025-01-24' AND schedule_id=(SELECT schedule_id FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekday Peak') LIMIT 1));

INSERT INTO trips (trip_date, schedule_id, train_id, driver_id)
SELECT '2025-01-25', 
       (SELECT schedule_id FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekend All Day') LIMIT 1), 
       (SELECT train_id FROM trains WHERE UPPER(model_name)=UPPER('Bombardier Movia') LIMIT 1), 
       (SELECT employee_id FROM employees WHERE UPPER(first_name)=UPPER('Grace') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM trips WHERE trip_date='2025-01-25' AND schedule_id=(SELECT schedule_id FROM schedules WHERE UPPER(schedule_name)=UPPER('Weekend All Day') LIMIT 1));

-- Stop Times
INSERT INTO stop_times (trip_id, station_id, arrival_time, departure_time)
SELECT (SELECT MIN(trip_id) FROM trips), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('Downtown Central') LIMIT 1), NULL, '08:00'
WHERE NOT EXISTS (SELECT 1 FROM stop_times WHERE trip_id=(SELECT MIN(trip_id) FROM trips) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('Downtown Central') LIMIT 1));

INSERT INTO stop_times (trip_id, station_id, arrival_time, departure_time)
SELECT (SELECT MIN(trip_id) FROM trips), (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('North Park') LIMIT 1), '08:05', '08:06'
WHERE NOT EXISTS (SELECT 1 FROM stop_times WHERE trip_id=(SELECT MIN(trip_id) FROM trips) AND station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('North Park') LIMIT 1));
-- Maintenance Logs
INSERT INTO maintenance_logs (train_id, station_id, maintenance_date, description, technician_id)
SELECT 
    (SELECT MAX(train_id) FROM trains), 
    NULL,
    '2025-10-22', 
    'Replaced faulty brake pads', 
    (SELECT employee_id FROM employees WHERE UPPER(last_name)=UPPER('Babbage') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM maintenance_logs WHERE train_id=(SELECT MAX(train_id) FROM trains) AND maintenance_date='2025-10-22');

INSERT INTO maintenance_logs (train_id, station_id, maintenance_date, description, technician_id)
SELECT 
    NULL,
    (SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('West End') LIMIT 1), 
    '2025-09-15', 
    'Repaired escalator motor', 
    (SELECT employee_id FROM employees WHERE UPPER(last_name)=UPPER('Babbage') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM maintenance_logs WHERE station_id=(SELECT station_id FROM stations WHERE UPPER(station_name)=UPPER('West End') LIMIT 1) AND maintenance_date='2025-09-15');

-- Ticket Type Promotions
INSERT INTO ticket_type_promotions (ticket_type_id, promotion_id)
SELECT (SELECT ticket_type_id FROM ticket_types WHERE UPPER(type_name)=UPPER('Daily Pass') LIMIT 1), (SELECT promotion_id FROM promotions WHERE UPPER(promotion_name)=UPPER('Weekend Saver') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM ticket_type_promotions WHERE ticket_type_id=(SELECT ticket_type_id FROM ticket_types WHERE UPPER(type_name)=UPPER('Daily Pass') LIMIT 1));

INSERT INTO ticket_type_promotions (ticket_type_id, promotion_id)
SELECT (SELECT ticket_type_id FROM ticket_types WHERE UPPER(type_name)=UPPER('Monthly Pass') LIMIT 1), (SELECT promotion_id FROM promotions WHERE UPPER(promotion_name)=UPPER('Student Discount') LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM ticket_type_promotions WHERE ticket_type_id=(SELECT ticket_type_id FROM ticket_types WHERE UPPER(type_name)=UPPER('Monthly Pass') LIMIT 1));

COMMIT;

-- ADD AUDIT COLUMN
BEGIN;
ALTER TABLE lines                   ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE stations                ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE trains                  ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE roles                   ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE employees               ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE schedules               ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE line_stations           ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE trips                   ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE stop_times              ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE maintenance_logs        ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE ticket_types            ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE promotions              ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE ticket_type_promotions  ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;
COMMIT;

-- VALIDATION CHECKS
SELECT 'lines' AS table_name, COUNT(*) AS null_count FROM lines WHERE record_ts IS NULL
UNION ALL
SELECT 'stations',            COUNT(*) FROM stations WHERE record_ts IS NULL
UNION ALL
SELECT 'trains',              COUNT(*) FROM trains WHERE record_ts IS NULL
UNION ALL
SELECT 'employees',           COUNT(*) FROM employees WHERE record_ts IS NULL
UNION ALL
SELECT 'trips',               COUNT(*) FROM trips WHERE record_ts IS NULL
UNION ALL
SELECT 'maintenance_logs',    COUNT(*) FROM maintenance_logs WHERE record_ts IS NULL;


