

USE santiblinds;

-- 1. Create application database user
CREATE USER IF NOT EXISTS 'santiblinds_app'@'localhost'
IDENTIFIED BY 'santiblinds2026';

-- 2. Create read-only database user
CREATE USER IF NOT EXISTS 'santiblinds_readonly'@'localhost'
IDENTIFIED BY 'santiblinds_readonly2026';

-- 3. Create database administrator user
CREATE USER IF NOT EXISTS 'santiblinds_admin'@'localhost'
IDENTIFIED BY 'santiblinds_admin2026';



-- APPLICATION USER


GRANT SELECT, INSERT, UPDATE, DELETE
ON santiblinds.*
TO 'santiblinds_app'@'localhost';

-- 
GRANT EXECUTE
ON PROCEDURE santiblinds.sp_process_order_and_sale
TO 'santiblinds_app'@'localhost';


-- READ-ONLY USER


GRANT SELECT
ON santiblinds.*
TO 'santiblinds_readonly'@'localhost';



-- DATABASE ADMINISTRATOR


GRANT ALL PRIVILEGES
ON santiblinds.*
TO 'santiblinds_admin'@'localhost';


FLUSH PRIVILEGES;



SHOW GRANTS FOR 'santiblinds_app'@'localhost';

SHOW GRANTS FOR 'santiblinds_readonly'@'localhost';

SHOW GRANTS FOR 'santiblinds_admin'@'localhost';