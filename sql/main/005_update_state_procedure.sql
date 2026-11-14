CREATE OR REPLACE PROCEDURE update_t1_state()
LANGUAGE plpgsql
AS $$
DECLARE
    sec_parity int := floor(extract(second FROM now()))::int % 2;
BEGIN
    UPDATE t1
    SET state = 1
    WHERE 
        state = 0
        AND id % 2 = sec_parity;
END;
$$;
