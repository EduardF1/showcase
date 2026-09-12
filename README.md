# showcase

A catalogue, not an application.

Each entry below is a small, self contained sample that demonstrates one decision: what it is, why
it is shaped that way, and what the shape costs. They are meant to be read in a couple of minutes
rather than cloned and run, so every sample is short enough to fit on a screen and carries a README
that argues for itself.

Most of my work lives in employer repositories or in private ones, which is the honest reason this
exists. Rather than link to repositories a visitor cannot open, the patterns are extracted or, where
there was nothing to extract, written here as a reference implementation.

## The catalogue

| Sample | Language | The decision it shows |
| --- | --- | --- |
| [unknown is a value](samples/typescript/unknown-is-a-value) | TypeScript | A figure that cannot be derived returns `unknown` with a reason, not a plausible number |
| [result, not exception](samples/csharp/result-not-exception) | C# | Failure in the signature, so a caller cannot forget it |
| [read model apart from write](samples/java/read-model-apart-from-write) | Java | A read path that can change without touching the write path |
| [fixed window rate limit](samples/javascript/fixed-window-rate-limit) | JavaScript | A limiter that fails open, and says so out loud |
| [money as a value object](samples/php/money-as-a-value-object) | PHP | Money in minor units, with currency in the type |
| [a pipeline that refuses](samples/python/pipeline-that-refuses) | Python | A step that declines rather than guessing a coordinate |
| [an idempotent migration](samples/sql/idempotent-migration) | SQL | A migration that is safe to run twice |
| [a ratchet gate](samples/powershell/ratchet-gate) | PowerShell | A gate that blocks new violations without demanding a clean sheet |

## The thread running through them

Every sample here is the same idea from a different angle: making the absence of an answer visible.

A salary model I wrote returns `unknown` for two of three figures, because their sources never
recorded whether pension was included and a tidier chart would have invented the difference. A
diagram renderer throws rather than draw an arrow it cannot route, because an arrow touching a box
it has no relationship with is a false claim about the system while a missing arrow is only a gap. A
rate limiter fails open and logs, because a limiter that fails closed takes the whole form down to
protect a counter.

The pattern underneath all of them: a check that cannot fail proves nothing, so I would rather ship
a visible gap than an invisible guess.

## How to read a sample

Each folder has a `README.md` with three sections and then the code:

- **What it shows** in one line.
- **Why it is shaped this way**, which is the part worth your time.
- **What it costs**, because every one of these trades something away.

## Elsewhere

[eduardfischer.dev](https://eduardfischer.dev) for case studies and writing.
