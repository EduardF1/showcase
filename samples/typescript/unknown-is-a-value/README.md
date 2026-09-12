# unknown is a value

## What it shows

A derived figure that cannot be justified returns `unknown` with the reason, and the type system
makes the caller deal with it.

## Why it is shaped this way

This came out of a salary tracker. Three paid figures sat on three different bases: one was recorded
at 40 hours with no pension, one included pension, and for the third the source never said. Drawing
a line through all three would have asserted a rise nobody measured. Every half of that claim is
true, which is exactly why per fact checking misses it: the lie is in the join.

The tempting fix is a number with a footnote. It does not work, because the number gets copied into
a chart, a CV bullet and a conversation, and the footnote does not travel with it.

So the model does not return a number it cannot justify. `Maybe<T>` is a union, not an optional, so
there is no `undefined` to skip past and no `0` to mistake for a measurement. The `reason` is
mandatory, which forces the author of the refusal to say what is missing at the point they know it.

## What it costs

Every caller has to branch. A UI that wanted to print a figure now has to decide what to render when
there is none, and that decision has to be made in the design rather than defaulted to a dash. That
is more work, and it is the work, because the alternative is a dash that looks like a small number.

See `maybe.ts` for the type and `salary.ts` for a real refusal.
