#!/bin/bash

run_dir() {
  local dir="$1"
  for f in "$dir"/*.sql; do
    [ -e "$f" ] || continue                       # папка порожня
    echo ">>> applying $f"
    psql -v ON_ERROR_STOP=1 \
         --username "$POSTGRES_USER" \
         --dbname "$POSTGRES_DB" \
         -f "$f" || exit 1
  done
}

run_dir /etc/sql/shared
run_dir /etc/sql/node