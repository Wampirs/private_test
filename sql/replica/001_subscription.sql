SELECT format
(
    'host=postgres_main port=5432 dbname=priv_main_db user=%s password=%s',
    :'repl_user',
    :'repl_password'
) AS repl_conninfo \gset

CREATE SUBSCRIPTION sub_t1
CONNECTION :'repl_conninfo'
PUBLICATION pub_t1;
