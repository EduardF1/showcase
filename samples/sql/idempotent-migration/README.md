# an idempotent migration

## What it shows

A migration that can be run twice without failing and without doing the work twice, and a backfill
that can be interrupted halfway and resumed.

## Why it is shaped this way

Migrations get run twice. A deploy retries, two instances start at once, someone reruns the job
after a timeout that had actually succeeded. If the second run throws, the deploy goes red for a
reason that has nothing to do with the change.

`IF NOT EXISTS` covers the schema. The interesting half is the data.

A backfill written as one `UPDATE` over a large table takes a long lock and, if it is killed at 80
percent, leaves you with no way to know that. Batching with a bound and a `WHERE` clause that
excludes already-done rows gives you both: each batch commits, and a rerun picks up where the last
one stopped because the predicate no longer matches the finished rows.

The constraint is added `NOT VALID` and validated separately on purpose. `NOT VALID` takes a brief
lock and applies to new writes immediately; `VALIDATE CONSTRAINT` scans the table without blocking
writers. Doing it in one statement instead takes an ACCESS EXCLUSIVE lock for the length of the
scan, which on a big table is an outage.

## What it costs

More statements, and a backfill that is eventually consistent while it runs: for a window, some rows
have the new column populated and some do not, so anything reading it in that window has to tolerate
nulls. That is the trade for not locking the table.

Written for PostgreSQL. See `001_add_currency.sql`.
