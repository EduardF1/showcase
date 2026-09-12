# a ratchet gate

## What it shows

A lint gate that blocks NEW violations while tolerating the ones already in the tree, so a large
codebase can start enforcing a rule on the day it adopts it rather than on the day it is finally
clean.

## Why it is shaped this way

Turning a rule on in a codebase with two thousand existing violations gives you two options, and
both are bad. Fail the build and nobody can ship until someone spends a week on it. Warn instead of
fail and the count grows, because a warning nobody has to act on is a warning nobody acts on.

The ratchet is the third option. Record today's count per rule, fail only when a rule's count goes
UP, and lower the recorded number whenever it comes down. New code is held to the rule immediately.
Old code gets cleaned when someone is in there anyway, and the gate makes that cleanup permanent.

Two details that matter more than the idea:

**It counts per rule, not in total.** A single total lets somebody fix forty easy violations of one
rule and add three of a rule that matters, and the gate says nothing.

**The baseline only ever goes down automatically.** Raising it is an explicit, visible commit, so
loosening the gate is something a reviewer sees rather than something a script did.

## What it costs

A baseline file in the repository that will show up in diffs, and the discipline not to raise it
casually. It also does not know about moved code: a file rename can look like a new violation and an
old one disappearing. Worth knowing before the first confusing failure.

See `Invoke-RatchetGate.ps1`.
