-- Add a currency to payments, backfill it, then enforce it.
--
-- Safe to run twice: every statement is guarded, and the backfill's predicate excludes the rows it
-- has already done, so a rerun after an interrupted run resumes rather than restarts.
--
-- PostgreSQL. Run each numbered step as its own transaction; step 2 deliberately commits per batch.

-- 1. Schema. Nullable to begin with: a NOT NULL column with no default would fail on the first
--    existing row, and a NOT NULL with a default rewrites the whole table under a lock.
ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS currency char(3);

CREATE INDEX IF NOT EXISTS payments_currency_idx
    ON payments (currency)
    WHERE currency IS NOT NULL;

-- 2. Backfill, in batches.
--
--    The WHERE clause is what makes this resumable: finished rows no longer match, so a second run
--    starts from wherever the first one stopped. LIMIT bounds the lock and the WAL each batch
--    produces. Run this block until it reports zero rows.
--
--    The currency is derived from the account rather than defaulted to a guess: a hardcoded 'DKK'
--    would be right for most rows and silently wrong for the rest, and nothing downstream could
--    tell which was which afterwards.
WITH batch AS (
    SELECT p.id
    FROM payments p
    WHERE p.currency IS NULL
    ORDER BY p.id
    LIMIT 5000
    FOR UPDATE SKIP LOCKED
)
UPDATE payments p
SET currency = a.currency
FROM batch b,
     accounts a
WHERE p.id = b.id
  AND a.id = p.account_id;

-- 3. Rows whose account has no currency either. They are NOT defaulted; they are listed, so someone
--    can decide. A migration that invents values to satisfy its own constraint has moved the
--    problem to a place nobody will look.
--
-- SELECT p.id, p.account_id FROM payments p WHERE p.currency IS NULL;

-- 4. Enforce, in two steps.
--
--    NOT VALID takes a brief lock and applies to every new write immediately. VALIDATE then scans
--    the existing rows WITHOUT blocking writers. Adding a valid constraint in one statement instead
--    holds ACCESS EXCLUSIVE for the length of that scan, which on a large table is an outage.
DO $$
    BEGIN
        ALTER TABLE payments
            ADD CONSTRAINT payments_currency_present
                CHECK (currency IS NOT NULL) NOT VALID;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'payments_currency_present already exists, skipping';
    END
$$;

ALTER TABLE payments
    VALIDATE CONSTRAINT payments_currency_present;
