CREATE SCHEMA IF NOT EXISTS partman;
CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;

SELECT partman.create_parent(
    p_parent_table    => 'public.t1',
    p_control         => 'op_date',
    p_interval        => '1 month',
    p_premake         => 4,
    p_start_partition => date_trunc('month', now() - interval '4 months')::text
);