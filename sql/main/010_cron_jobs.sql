CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('task4_add_row', '5 seconds', 'CALL add_t1_row()');