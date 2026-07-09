#!/usr/bin/env bash
# Snapshot a table before DML runs: CREATE TABLE bak_<table>_<run> AS TABLE <table>
# Keeps only the most recent N backups per table (default 5).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/db_exec.sh"

TABLE=$(echo "${1:?usage: backup_table.sh <table> <run-number>}" | tr '[:upper:]' '[:lower:]')
RUN_NO="${2:?usage: backup_table.sh <table> <run-number>}"
KEEP="${BACKUP_KEEP:-5}"

BAK="bak_${TABLE}_${RUN_NO}"

echo ">> Creating backup snapshot: $BAK (copy of $TABLE)"
run_stmt "CREATE TABLE ${BAK} AS TABLE ${TABLE};"

ROWS=$(run_scalar "SELECT COUNT(*) FROM ${BAK};")
echo ">> Backup created: $BAK ($ROWS rows)"

# Prune old backups, keep the newest $KEEP (run number embedded in the name)
OLD=$(run_scalar "SELECT COALESCE(string_agg(table_name, ','), '')
  FROM (
    SELECT table_name,
           ROW_NUMBER() OVER (
             ORDER BY (regexp_match(table_name, '([0-9]+)\$'))[1]::int DESC
           ) AS rn
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name ~ ('^bak_${TABLE}_[0-9]+\$')
  ) x WHERE rn > ${KEEP};")

if [[ -n "$OLD" ]]; then
  IFS=',' read -ra OLD_TABLES <<< "$OLD"
  for OT in "${OLD_TABLES[@]}"; do
    echo ">> Pruning old backup: $OT"
    run_stmt "DROP TABLE ${OT};"
  done
fi

echo "backup_name=$BAK"
