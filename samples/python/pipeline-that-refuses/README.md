# a pipeline that refuses

## What it shows

A photo geocoding step that declines to place a picture it cannot place, instead of reaching for the
nearest plausible coordinate.

## Why it is shaped this way

This is from a travel map built out of photo metadata. The temptation at every stage is to fill a
gap: a photo with no GPS could borrow the coordinate of the photo taken a minute earlier, and most
of the time that would even be right.

It is still the wrong move, because the map has no way to show the difference afterwards. A borrowed
pin and a measured pin are the same dot. One of them is a record of where someone stood and the
other is an inference, and the person reading the map six months later cannot tell which they are
looking at, including when that person is you.

So `locate` returns nothing for a photo with no coordinate, the caller counts the refusals, and the
count is reported rather than swallowed. If half the trip is missing from the map, that is a fact
about the corpus worth seeing.

The cache is the other decision. Reverse geocoding is rate limited and slow, and the same lat/lon to
three decimal places is the same place: rounding the cache key to roughly a hundred metres turns a
thousand lookups into a few dozen. The rounding is in one function with its precision named, rather
than inlined at the call site where nobody would find it.

## What it costs

A map with holes in it, and a caller that has to decide what to do about them. The alternative is a
map with no holes and no way to know which pins were real.

See `geocode.py`.
