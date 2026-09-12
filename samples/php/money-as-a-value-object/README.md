# money as a value object

## What it shows

An amount that cannot be stored as a float, cannot be added to a different currency, and cannot be
divided without saying where the remainder went.

## Why it is shaped this way

`0.1 + 0.2` is not `0.3`, and a price that is out by a hundredth of a krone survives every test that
checks it "looks right" and fails an accountant. Minor units as an integer removes the whole class:
1499 is 1499, and addition is addition.

Currency in the type removes the second class. `$dkk->plus($eur)` is a mistake somebody will make
under deadline, and the only place it can be caught reliably is at the point of the operation, by
something that knows both sides. A float with a currency column on another table cannot do that.

The allocation method is the part usually left out. Splitting 100 across three people gives 33.33
three times and loses a hundredth. `allocate` distributes the remainder deterministically, one minor
unit at a time from the start, so the parts always sum to the whole. Which party gets the extra unit
is arbitrary, and stating the rule is the difference between an arbitrary choice and an accident.

## What it costs

More ceremony at every boundary: the database stores an integer and a code, the API serialises them,
and somebody has to write the mapping. In exchange, no float ever touches an amount.

See `Money.php`.
