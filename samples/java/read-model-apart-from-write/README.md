# a read model apart from the write path

## What it shows

A query side that owns its own shape and its own SQL, so the screen can change without touching the
rules, and the rules can change without breaking the screen.

## Why it is shaped this way

The usual arrangement has one set of entities serving both jobs. It works until the two jobs want
different things, which they always eventually do. The write side wants small aggregates with
invariants it can enforce in one transaction. The read side wants one flat row per screen, joined
across three of those aggregates, ordered by something none of them owns.

Serving both from the same objects means one of them loses. Usually it is the read side, which ends
up fetching three aggregates and assembling the row in Java, in a loop, once per row on the page.

So the read side here is a record and a query. No entities, no lazy loading, no mapper: the query
returns the shape the screen asked for. The write side keeps its aggregate and its invariant and
never learns that the screen exists.

This is the cheap half of CQRS and it is worth having on its own. There is no separate database, no
event bus and no eventual consistency: both sides hit the same tables in the same transaction. Reach
for the expensive half when a measurement says you need it, not because the diagram looked
symmetrical.

## What it costs

Two places to change when a field is added to both, and a read query that will not be caught by the
compiler when a column is renamed. The second is worth a test that runs the query against a real
schema, which is cheaper than the loop it replaces.

See `AccountSummaryQuery.java` and `TransferService.java`.
