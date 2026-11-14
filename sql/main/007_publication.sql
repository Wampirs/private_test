CREATE ROLE :"repl_user" WITH LOGIN REPLICATION PASSWORD :'repl_password';
GRANT SELECT ON t1 TO :"repl_user";

CREATE PUBLICATION pub_t1 FOR TABLE t1 WITH (publish_via_partition_root = true);
