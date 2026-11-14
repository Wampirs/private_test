CREATE OR REPLACE PROCEDURE add_t1_row()
LANGUAGE plpgsql
AS $$
DECLARE
    op_client_id int := (floor(random() * 5000) + 1)::int;
    op_type int := (1 + floor(random() * 2))::int;
BEGIN
    INSERT INTO t1 (sum, state, msg)
    VALUES
    (
        round((random() * 9990 + 10)::numeric, 2),
        0,
        jsonb_build_object
        (
            'acc_num', 'UA' || lpad((op_client_id * 10 + floor(random() * 3)::int)::text, 12, '0'),
            'client_id', op_client_id,
            'op_type', op_type
        )
    );
END;
$$;