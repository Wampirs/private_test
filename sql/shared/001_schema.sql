CREATE TABLE t1 
(
    id BIGINT GENERATED ALWAYS AS IDENTITY ,
    "date" TIMESTAMPTZ NOT NULL DEFAULT now(),
    sum NUMERIC(18,2) NOT NULL,
    state SMALLINT NOT NULL,
    op_guid UUID NOT NULL DEFAULT uuidv7(),
    msg JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_t1 PRIMARY KEY (id, "date"),
    CONSTRAINT chk_t1_msg CHECK (
        msg ? 'acc_num'
        AND msg ? 'client_id'
        AND msg -> 'op_type' IN ('1'::jsonb, '2'::jsonb)
    )
)
PARTITION BY RANGE (date)