#!/bin/bash

run_dir() {
  local dir="$1"
  echo "Executing init from $dir"
  for f in "$dir"/*.sql; do
    [ -e "$f" ] || continue
    echo ">>> applying $f"
    psql -v ON_ERROR_STOP=1 \
         -v repl_user="$REPL_USER" \
         -v repl_password="$REPL_PASSWORD" \
         --no-psqlrc -P pager=off \
         --username "$POSTGRES_USER" \
         --dbname "$POSTGRES_DB" \
         -f "$f" || exit 1
  done
}

run_dir /etc/sql/shared
run_dir /etc/sql/node