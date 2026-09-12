# result, not exception

## What it shows

An operation whose expected failures are part of its return type, so the caller cannot forget them,
and whose unexpected failures still throw, because those are not the caller's business.

## Why it is shaped this way

The distinction that matters is not "exceptions are slow" or "exceptions are ugly". It is that a
validation failure and a dropped database connection are different kinds of event, and a single
`catch` treats them identically.

A rejected booking because the vehicle is already reserved is an ordinary outcome of asking. The
caller has something sensible to do with it, and it should not need a comment to discover that the
call can end that way. Putting it in the return type makes the compiler tell them.

A dropped connection is not an outcome of asking. Nobody at the call site can fix it, every handler
would write the same `catch`, and the honest response is to let it reach the boundary where it can
be logged once and turned into a 500. So it throws.

The endpoint below maps one to 409 and the other to 500 without a single `catch` in the handler,
because the shape of the return value already carries the difference.

## What it costs

Two failure channels instead of one, and a judgment call at every new operation about which channel
a given failure belongs to. Get that wrong and you either bury an infrastructure fault in a 400, or
you throw for something the caller could have handled. The rule I use: if the caller can do
something other than log it, it goes in the result.

See `Result.cs` and `BookingEndpoint.cs`.
