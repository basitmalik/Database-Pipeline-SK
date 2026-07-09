#!/usr/bin/env bash
# Restore a table from a backup snapshot created by backup_table.sh.
#   rollback_table.sh <table> [backup_name|latest]
# DELETE + INSERT inside one transaction: if the restore fails midway,
# everything rolls back and the table is left untouched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/db_exec.sh"

TABLE=$(echo "${1:?usage: rollback_table.sh <table> [backup|latest]}" | tr '[:upper:]' '[:lower:]')
CHOICE=$(echo "${2:-latest}" | tr '[:upper:]' '[:lower:]')

if [[ "$CHOICE" == "latest" ]]; then
  BAK=$(run_scalar "SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name ~ ('^bak_${TABLE}_[0-9]+\$')
    ORDER BY (regexp_match(table_name, '([0-9]+)\$'))[1]::int DESC
    LIMIT 1;")
else
  BAK="$CHOICE"
fi

if [[ -z "$BAK" ]]; then
  echo "::error::No backup snapshot found for table $TABLE"
  exit 1
fi

if [[ "$(table_exists "$BAK")" != "1" ]]; then
  echo "::error::Backup table $BAK does not exist"
  exit 1
fi

BEFORE=$(run_scalar "SELECT COUNT(*) FROM ${TABLE};")
BAK_ROWS=$(run_scalar "SELECT COUNT(*) FROM ${BAK};")

echo "=================================================================="
echo " ROLLBACK: restoring $TABLE from $BAK"
echo "   current rows : $BEFORE"
echo "   snapshot rows: $BAK_ROWS"
echo "=================================================================="

run_stmt "DELETE FROM ${TABLE};
INSERT INTO ${TABLE} SELECT * FROM ${BAK};"

AFTER=$(run_scalar "SELECT COUNT(*) FROM ${TABLE};")
echo ">> Rollback complete: $TABLE now has $AFTER rows (restored from $BAK)"
