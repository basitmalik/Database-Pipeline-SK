#!/usr/bin/env bash
# Extract target table names from SQL files.
#   extract_tables.sh ddl <file>  -> table name from CREATE TABLE
#   extract_tables.sh dml <file>  -> unique tables targeted by INSERT/UPDATE/MERGE
set -euo pipefail

MODE="${1:?usage: extract_tables.sh <ddl|dml> <sql-file>}"
FILE="${2:?usage: extract_tables.sh <ddl|dml> <sql-file>}"

# Strip comments so commented-out statements are ignored
CLEANED=$(perl -0777 -pe 's{/\*.*?\*/}{}gs; s/--[^\n]*//g' "$FILE")

case "$MODE" in
  ddl)
    echo "$CLEANED" \
      | grep -Eio 'CREATE[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+)?"?[A-Za-z0-9_.]+"?' \
      | sed -E 's/.*[[:space:]]"?([A-Za-z0-9_.]+)"?$/\1/' \
      | sed -E 's/^[A-Za-z0-9_]+\.//' \
      | tr '[:upper:]' '[:lower:]' \
      | sort -u
    ;;
  dml)
    echo "$CLEANED" \
      | grep -Eio '(INSERT[[:space:]]+INTO|UPDATE|MERGE[[:space:]]+INTO)[[:space:]]+"?[A-Za-z0-9_.]+"?' \
      | sed -E 's/.*[[:space:]]"?([A-Za-z0-9_.]+)"?$/\1/' \
      | sed -E 's/^[A-Za-z0-9_]+\.//' \
      | tr '[:upper:]' '[:lower:]' \
      | grep -Evx 'set' \
      | sort -u
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac
