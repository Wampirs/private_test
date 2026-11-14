CREATE TABLE t1_op_guid_reg 
(
    op_guid uuid PRIMARY KEY
);


CREATE OR REPLACE FUNCTION t1_register_op_guid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO t1_op_guid_reg (op_guid) VALUES (NEW.op_guid);
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_t1_op_guid
BEFORE INSERT ON t1
FOR EACH ROW EXECUTE FUNCTION t1_register_op_guid();