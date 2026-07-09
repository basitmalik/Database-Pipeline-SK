#!/usr/bin/env bash
# Guard: fail if the DML file contains DELETE or TRUNCATE statements.
# Comments (-- and /* */) and string literals are stripped first, so a
# column named "deleted_at" or the word DELETE inside a comment will NOT
# trigger a false positive.
set -euo pipefail

FILE="${1:?usage: check_forbidden.sh <sql-file>}"

if [[ ! -f "$FILE" ]]; then
  echo "::error::SQL file not found: $FILE"
  exit 1
fi

# Strip /* */ block comments, -- line comments and '...' string literals
CLEANED=$(perl -0777 -pe "s{/\*.*?\*/}{}gs; s/--[^\n]*//g; s/'[^']*'//g" "$FILE")

FORBIDDEN='\b(DELETE|TRUNCATE)\b'

if echo "$CLEANED" | grep -Eiq "$FORBIDDEN"; then
  echo "=================================================================="
  echo " ERROR: DELETE/TRUNCATE DETECTED in $FILE"
  echo "=================================================================="
  echo "Offending lines:"
  grep -Ein "$FORBIDDEN" "$FILE" || true
  echo "::error file=$FILE::DELETE/TRUNCATE detected - pipeline blocked. Destructive DML is not allowed."
  exit 1
fi

echo "OK: no DELETE/TRUNCATE statements found in $FILE"
