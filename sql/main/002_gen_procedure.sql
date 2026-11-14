CREATE OR REPLACE PROCEDURE generate_t1_data
(
    date_from timestamptz,
    date_to timestamptz,
    need_rows int,
    batch_size int DEFAULT 10000
)
LANGUAGE plpgsql
AS $$
DECLARE
    gen_count int := 0;
    cur_batch_size int;
BEGIN
    IF date_to <= date_from THEN
        RAISE EXCEPTION 'date_to (%) must be greater than date_from (%)', date_to, date_from;
    END IF;

    WHILE gen_count < need_rows LOOP
        cur_batch_size := LEAST(batch_size, need_rows - gen_count);

        WITH gen AS MATERIALIZED 
        (
            SELECT uuidv7() AS t_guid,
                date_from + random() * (date_to - date_from) AS t_dt,
                round((random() * 9990 + 10)::numeric, 2) AS t_amount,
                (1 + floor(random() * 2))::int AS t_state,
                (1 + floor(random() * 2))::int AS op_type,
                (floor(random() * 5000) + 1)::int AS op_client_id
            FROM generate_series(1, cur_batch_size)
        )
        INSERT INTO t1 (t_date, sum, state, op_guid, msg)
        SELECT 
            t_dt,
            t_amount,
            t_state,
            t_guid,
            jsonb_build_object
            (
                'acc_num', 'UA' || lpad((op_client_id * 10 + floor(random() * 3)::int)::text, 12, '0'),
                'client_id', op_client_id,
                'op_type', op_type
            )
        FROM gen;

        gen_count := gen_count + cur_batch_size;
        COMMIT;
        RAISE NOTICE 'Generated % / % rows', gen_count, need_rows;
    END LOOP;
END;
$$;