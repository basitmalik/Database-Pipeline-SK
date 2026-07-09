#!/usr/bin/env bash
# Helper library: run SQL against PostgreSQL inside the Docker container.
# Connects over TCP with password auth (not the trust socket) so credentials
# are actually exercised.
# Required environment variables:
#   PG_CONTAINER - docker container name (e.g. pg-db)
#   DB_USER      - application user (NOT the postgres superuser)
#   DB_PASSWORD  - password for DB_USER
#   DB_NAME      - database name (e.g. appdb)
set -euo pipefail

: "${PG_CONTAINER:?PG_CONTAINER not set}"
: "${DB_USER:?DB_USER not set}"
: "${DB_PASSWORD:?DB_PASSWORD not set}"
: "${DB_NAME:?DB_NAME not set}"

PSQL="docker exec -i -e PGPASSWORD=${DB_PASSWORD} ${PG_CONTAINER} psql -h 127.0.0.1 -U ${DB_USER} -d ${DB_NAME} -v ON_ERROR_STOP=1"

# run_scalar "<select ...;>" -> prints single value (empty if NULL)
run_scalar() {
  $PSQL -tA -c "$1"
}

# run_file "<path-on-runner>" -> executes the whole file in ONE transaction;
# any error rolls everything back and exits non-zero.
run_file() {
  $PSQL --single-transaction --echo-all -f - < "$1"
}

# run_stmt "<statements;>" -> executes in one implicit transaction
run_stmt() {
  $PSQL --echo-all -c "$1"
}

# table_exists "<table_name>" -> echoes 1 or 0
table_exists() {
  local T
  T=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  run_scalar "SELECT COUNT(*) FROM information_schema.tables
              WHERE table_schema = 'public' AND table_name = '${T}';"
}
