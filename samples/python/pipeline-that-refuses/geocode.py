"""Turn photo metadata into placed points, and refuse the ones that cannot be placed.

The refusal is the feature. A photo with no coordinate could borrow one from the photo taken a
minute earlier and would often be right, but a borrowed pin and a measured pin render as the same
dot and nothing downstream can tell them apart afterwards.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable, Protocol

# Roughly 100 m at European latitudes. Reverse geocoding is rate limited and slow, and two photos
# from the same street corner do not need two lookups. The precision is named here rather than
# inlined as a magic 3 at the call site.
CACHE_PRECISION_DP = 3


@dataclass(frozen=True)
class Photo:
    path: str
    lat: float | None
    lon: float | None


@dataclass(frozen=True)
class Place:
    city: str
    country: str


@dataclass(frozen=True)
class PlacedPhoto:
    photo: Photo
    place: Place


@dataclass(frozen=True)
class Skipped:
    photo: Photo
    reason: str


class Geocoder(Protocol):
    def __call__(self, lat: float, lon: float) -> Place | None: ...


def _cache_key(lat: float, lon: float) -> tuple[float, float]:
    return (round(lat, CACHE_PRECISION_DP), round(lon, CACHE_PRECISION_DP))


def locate(
    photos: Iterable[Photo],
    geocoder: Geocoder,
    on_progress: Callable[[int], None] | None = None,
) -> tuple[list[PlacedPhoto], list[Skipped]]:
    """Place what can be placed and return the rest as skips, with a reason each.

    Two return values rather than one list with optional fields: a caller that wants only the placed
    photos cannot then iterate the happy list and never notice the skips exist. Making the second
    list something they have to name is the point.
    """
    placed: list[PlacedPhoto] = []
    skipped: list[Skipped] = []
    cache: dict[tuple[float, float], Place | None] = {}

    for index, photo in enumerate(photos):
        if photo.lat is None or photo.lon is None:
            skipped.append(Skipped(photo, "no GPS in the file, and a neighbour's coordinate is a guess"))
            continue
        if not (-90.0 <= photo.lat <= 90.0 and -180.0 <= photo.lon <= 180.0):
            # Out of range means the extractor misread the EXIF, not that the photo was taken there.
            skipped.append(Skipped(photo, f"coordinate out of range: {photo.lat}, {photo.lon}"))
            continue

        key = _cache_key(photo.lat, photo.lon)
        if key not in cache:
            cache[key] = geocoder(photo.lat, photo.lon)
        place = cache[key]

        if place is None:
            skipped.append(Skipped(photo, "the geocoder returned nothing for this coordinate"))
        else:
            placed.append(PlacedPhoto(photo, place))

        if on_progress is not None:
            on_progress(index + 1)

    return placed, skipped


def summarise(placed: list[PlacedPhoto], skipped: list[Skipped]) -> str:
    """One line a human will actually read, with the skips in it rather than under a debug flag."""
    total = len(placed) + len(skipped)
    if total == 0:
        return "no photos given"
    share = len(skipped) / total * 100
    return f"placed {len(placed)} of {total} photos; {len(skipped)} skipped ({share:.1f}%)"
