# fixed window rate limit

## What it shows

A per client throttle that fails OPEN, hashes the identifier before it touches storage, and says in
its own return value whether it actually ran.

## Why it is shaped this way

Three decisions, each of which has bitten someone.

**It fails open.** If the counter store is unreachable, the request is allowed. A limiter protects
against a cost, not against an intruder: the worst case of failing open is a bill, and the worst
case of failing closed is that a dead cache takes the contact form down with it. If you are
throttling something where the worst case is a breach, you want a different component, and you
should say so at the call site rather than hope this one holds.

**The identifier is hashed before storage.** An IP address in a key is an IP address in a backup, in
a log line and in a support screenshot. Hashing it with the endpoint as salt also stops two routes
being correlated by key, which an unsalted hash would allow.

**The result says whether the check ran.** A limiter that returns `allowed: true` for "under the
limit" and for "I could not check" collapses two very different facts. The caller may not care, but
the metric does: without this field a broken store looks exactly like quiet traffic.

**And the window is fixed, not sliding.** A fixed window is cheap and coarse: a caller can send the
whole budget at the end of one window and the whole budget at the start of the next. That burst is
acceptable for a contact form and would not be for an auth endpoint. It is written down here so the
next person does not have to rediscover it by reading the arithmetic.

## What it costs

The burst at the window boundary, and a dependency that is allowed to be down. Both are deliberate,
and neither is free.

See `rateLimit.js`.
