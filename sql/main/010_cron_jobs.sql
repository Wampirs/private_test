CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('task4_add_row', '5 seconds', 'CALL add_t1_row()');
SELECT cron.schedule('task5_update_state', '3 seconds', 'CALL update_t1_state()');