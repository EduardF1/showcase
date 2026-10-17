#!/usr/bin/env bash
# Runs 001_add_currency.sql against a real PostgreSQL and checks the claims in the README:
# safe to run twice, a backfill that resumes in bounded batches, no invented currency, and a
# constraint that applies to new writes before the existing rows are validated.
#
# Connection comes from the usual PG* environment variables. Each test gets a fresh database.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
migration="$here/../001_add_currency.sql"
db="idempotent_migration_test"
failures=0

# The file is written to be run step by step; these slices follow its own numbered headings.
step() { awk -v from="$1" -v to="$2" 'index($0, from) == 1 {on=1} to != "" && index($0, to) == 1 {on=0} on' "$migration"; }
step1="$(step '-- 1.' '-- 2.')"
step2="$(step '-- 2.' '-- 3.')"
step4="$(step '-- 4.' '')"
# Step 4 goes through stdin, not -c: -c would wrap both statements in one transaction, and a
# failing VALIDATE would then roll back the NOT VALID constraint it is meant to leave in place.
# Step 4 goes through stdin, not -c: -c would wrap both statements in one transaction, and a
# failing VALIDATE would then roll back the NOT VALID constraint it is meant to leave in place.

sql() { psql -X -q -v ON_ERROR_STOP=1 -d "$db" -tA "$@"; }
updated() { psql -X -v ON_ERROR_STOP=1 -d "$db" -c "$1" | sed -n 's/^UPDATE \([0-9]*\)$/\1/p'; }

fresh() {
  psql -X -q -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS $db" -c "CREATE DATABASE $db"
  sql <<'SQL'
CREATE TABLE accounts (id bigint PRIMARY KEY, currency char(3));
CREATE TABLE payments (id bigint PRIMARY KEY, account_id bigint NOT NULL REFERENCES accounts (id));
INSERT INTO accounts VALUES (1, 'DKK'), (2, 'EUR'), (3, NULL);
SQL
}

expect() {
  local name="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected [$want], got [$got]"
    failures=$((failures + 1))
  fi
}

echo "# the whole file, run twice"
fresh
sql -c "INSERT INTO payments SELECT g, 1 + g % 2 FROM generate_series(1, 300) g"
first=0; sql -f "$migration" >/dev/null 2>&1 || first=$?
second=0; sql -f "$migration" >/dev/null 2>&1 || second=$?
expect "first run succeeds" 0 "$first"
expect "second run succeeds" 0 "$second"
expect "every row has a currency" 0 "$(sql -c "SELECT count(*) FROM payments WHERE currency IS NULL")"
expect "currency comes from the account" 0 \
  "$(sql -c "SELECT count(*) FROM payments p JOIN accounts a ON a.id = p.account_id WHERE p.currency <> a.currency")"
expect "one currency column" 1 \
  "$(sql -c "SELECT count(*) FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'currency'")"
expect "partial index exists" 1 "$(sql -c "SELECT count(*) FROM pg_indexes WHERE indexname = 'payments_currency_idx'")"
expect "constraint exists once and is validated" "1|t" \
  "$(sql -c "SELECT count(*), bool_and(convalidated) FROM pg_constraint WHERE conname = 'payments_currency_present'")"

echo "# the backfill resumes in bounded batches"
fresh
sql -c "INSERT INTO payments SELECT g, 1 + g % 2 FROM generate_series(1, 12000) g"
sql -c "$step1" >/dev/null
sql -c "$step1" >/dev/null
batches="$(updated "$step2") $(updated "$step2") $(updated "$step2") $(updated "$step2")"
expect "each batch is bounded and a rerun picks up where the last stopped" "5000 5000 2000 0" "$batches"
expect "nothing left to backfill" 0 "$(sql -c "SELECT count(*) FROM payments WHERE currency IS NULL")"

echo "# a row with no derivable currency is not defaulted"
fresh
sql -c "INSERT INTO payments SELECT g, 1 + g % 3 FROM generate_series(1, 30) g"
sql -c "$step1" >/dev/null
updated "$step2" >/dev/null
expect "rows of a currencyless account stay NULL" 10 "$(sql -c "SELECT count(*) FROM payments WHERE currency IS NULL")"
validate=0; sql <<< "$step4" >/dev/null 2>&1 || validate=$?
expect "VALIDATE refuses while such rows exist" 1 "$((validate != 0))"
expect "the NOT VALID constraint was still added" "f" \
  "$(sql -c "SELECT convalidated FROM pg_constraint WHERE conname = 'payments_currency_present'")"
insert=0; sql -c "INSERT INTO payments VALUES (9999, 1, NULL)" >/dev/null 2>&1 || insert=$?
expect "the constraint already applies to new writes" 1 "$((insert != 0))"
rerun="$(sql <<< "$step4" 2>&1 || true)"
expect "re-adding the constraint is skipped, not an error" 1 \
  "$(grep -c 'payments_currency_present already exists, skipping' <<< "$rerun")"
sql -c "UPDATE accounts SET currency = 'SEK' WHERE id = 3" >/dev/null
updated "$step2" >/dev/null
after=0; sql <<< "$step4" >/dev/null 2>&1 || after=$?
expect "once someone decides, a rerun of step 4 validates" 0 "$after"

psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $db"

if (( failures > 0 )); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
