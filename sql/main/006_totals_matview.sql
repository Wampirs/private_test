CREATE MATERIALIZED VIEW mv_t1_totals AS
SELECT
    msg ->> 'client_id' AS client_id,
    msg ->> 'op_type' AS op_type,
    sum(sum) AS total_sum
FROM t1
WHERE state = 1
GROUP BY
    msg ->> 'client_id',
    msg ->> 'op_type';

CREATE UNIQUE INDEX ux_mv_t1_totals ON mv_t1_totals (client_id, op_type);


CREATE OR REPLACE FUNCTION t1_refresh_totals()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM old_rows o
        JOIN new_rows n ON n.id = o.id AND n.t_date = o.t_date
        WHERE 
            o.state = 0
            AND n.state = 1
    ) 
    THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_t1_totals;
    END IF;

    RETURN NULL;
END;
$$;


CREATE TRIGGER trg_t1_refresh_totals
AFTER UPDATE ON t1
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION t1_refresh_totals();
