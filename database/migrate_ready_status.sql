-- Run once on an existing database to merge legacy installation-ready orders
-- into the Completed status used by the current owner workflow.
UPDATE orders
SET status = 'Completed'
WHERE status IN ('Ready', 'Ready for Install');
