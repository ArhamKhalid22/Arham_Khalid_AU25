--TASK 2
/*1. Create table ‘table_to_delete’ and fill it with the following query*/
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

/*2. Lookup how much space this table consumes with the following query:*/

  	SELECT *, pg_size_pretty(total_bytes) AS total,
                                    pg_size_pretty(index_bytes) AS INDEX,
                                    pg_size_pretty(toast_bytes) AS toast,
                                    pg_size_pretty(table_bytes) AS TABLE
               FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                               FROM (SELECT c.oid,nspname AS table_schema,
                                                               relname AS TABLE_NAME,
                                                              c.reltuples AS row_estimate,
                                                              pg_total_relation_size(c.oid) AS total_bytes,
                                                              pg_indexes_size(c.oid) AS index_bytes,
                                                              pg_total_relation_size(reltoastrelid) AS toast_bytes
                                              FROM pg_class c
                                              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                              WHERE relkind = 'r'
                                              ) a
                                    ) a
               WHERE table_name LIKE '%table_to_delete%';

--3. Issue the following DELETE operation on ‘table_to_delete’:
               DELETE FROM table_to_delete
               WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; -- removes 1/3 of all rows


--      a) Note how much time it takes to perform this DELETE statement;
-- Query returned successfully in 22 secs 113 msec.
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;
--      b) Lookup how much space this table consumes after previous DELETE;
SELECT *, pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS INDEX,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS "TABLE"
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name = 'table_to_delete';
--      c) Perform the following command (if you're using DBeaver, press Ctrl+Shift+O to observe server output (VACUUM results)):
  VACUUM FULL VERBOSE table_to_delete;
--      d) Check space consumption of the table once again and make conclusions;
SELECT *, pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS INDEX,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS "TABLE"
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name = 'table_to_delete';
--      e) Recreate ‘table_to_delete’ table;
DROP TABLE IF EXISTS table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;
--4. Issue the following TRUNCATE operation: 
TRUNCATE table_to_delete;
     -- a) Note how much time it takes to perform this:
	 --Query returned successfully in 104 msec.

      --b) Compare with previous results and make conclusion.
	  -- SQL Script for Comparison and Conclusion

SELECT
    '1. AFTER TRUNCATE' AS operation,
    'INSTANTLY MINIMAL' AS space_reclamation_result,
    pg_size_pretty(pg_total_relation_size('table_to_delete')) AS current_total_size,
    'TRUNCATE is DDL: drops all data blocks immediately, reclaiming space without VACUUM.' AS conclusion_point;


SELECT
    '2. AFTER DELETE (Before VACUUM)' AS operation,
    'UNCHANGED (BLOAT)' AS space_reclamation_result,
    'You must re-run the size query immediately after the DELETE operation to see this result.' AS current_total_size,
    'DELETE is DML: marks rows as dead (creating bloat). Space is not reclaimed instantly.' AS conclusion_point;


SELECT
    '3. AFTER VACUUM FULL' AS operation,
    'REDUCED (PHYSICAL RECLAIM)' AS space_reclamation_result,
    'You must re-run the size query after VACUUM FULL to see this result.' AS current_total_size,
    'VACUUM FULL is slow maintenance: required to physically rewrite the table and reclaim space from DELETE.' AS conclusion_point;



/*FINAL CONCLUSION: TRUNCATE vs. DELETE/VACUUM FULL
-------------------------------------------------
TRUNCATE is the superior operation for removing ALL data from a table when space reclamation is critical.

1. SPEED: TRUNCATE is dramatically faster than DELETE because it operates on metadata, not on individual rows.
2. SPACE RECLAMATION: TRUNCATE reclaims disk space instantly and automatically. DELETE requires a separate, slow, resource-intensive VACUUM FULL command to remove bloat and reclaim space.
*/
      --c) Check space consumption of the table once again and make conclusions;

SELECT *, pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS INDEX,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS "TABLE"
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name = 'table_to_delete';
--5. Hand over your investigation's results to your trainer. The results must include:
     -- a) Space consumption of ‘table_to_delete’ table before and after each operation;
	 --b) Duration of each operation (DELETE, TRUNCATE)*/
	  SELECT
    'Space Check' AS operation,
    c.reltuples AS row_estimate,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_total_relation_size(reltoastrelid)) AS toast_size
FROM pg_class c
WHERE relname = 'table_to_delete';

	 


