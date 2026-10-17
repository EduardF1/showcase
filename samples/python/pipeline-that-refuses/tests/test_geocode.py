from geocode import CACHE_PRECISION_DP, Photo, Place, locate, summarise

COPENHAGEN = Place("Copenhagen", "Denmark")


class CountingGeocoder:
    def __init__(self, answer: Place | None = COPENHAGEN) -> None:
        self.answer = answer
        self.calls: list[tuple[float, float]] = []

    def __call__(self, lat: float, lon: float) -> Place | None:
        self.calls.append((lat, lon))
        return self.answer


def test_a_photo_without_gps_is_refused_not_borrowed_from_its_neighbour():
    before = Photo("a.jpg", 55.6761, 12.5683)
    missing = Photo("b.jpg", None, None)
    half = Photo("c.jpg", 55.6761, None)

    placed, skipped = locate([before, missing, half], CountingGeocoder())

    assert [p.photo for p in placed] == [before]
    assert [s.photo for s in skipped] == [missing, half]
    assert all("no GPS" in s.reason for s in skipped)


def test_an_out_of_range_coordinate_is_refused_and_never_sent_to_the_geocoder():
    geocoder = CountingGeocoder()
    placed, skipped = locate([Photo("x.jpg", 91.0, 0.0), Photo("y.jpg", 0.0, -180.5)], geocoder)

    assert placed == []
    assert [s.reason.startswith("coordinate out of range") for s in skipped] == [True, True]
    assert geocoder.calls == []


def test_a_geocoder_with_no_answer_is_a_skip_with_a_reason():
    placed, skipped = locate([Photo("sea.jpg", 56.0, 4.0)], CountingGeocoder(answer=None))

    assert placed == []
    assert skipped[0].reason == "the geocoder returned nothing for this coordinate"


def test_the_cache_key_is_rounded_so_one_street_corner_is_one_lookup():
    assert CACHE_PRECISION_DP == 3
    geocoder = CountingGeocoder()
    photos = [
        Photo("1.jpg", 55.67610, 12.56830),
        Photo("2.jpg", 55.67612, 12.56834),  # same corner, a few metres away
        Photo("3.jpg", 55.68000, 12.56830),  # a different street
    ]

    placed, skipped = locate(photos, geocoder)

    assert len(placed) == 3 and skipped == []
    assert len(geocoder.calls) == 2


def test_progress_is_reported_per_geocoded_photo():
    seen: list[int] = []
    locate([Photo("1.jpg", 1.0, 1.0), Photo("2.jpg", 2.0, 2.0)], CountingGeocoder(), on_progress=seen.append)

    assert seen == [1, 2]


def test_the_summary_puts_the_skips_in_the_sentence():
    placed, skipped = locate(
        [Photo("1.jpg", 1.0, 1.0), Photo("2.jpg", None, None), Photo("3.jpg", None, None)],
        CountingGeocoder(),
    )

    assert summarise(placed, skipped) == "placed 1 of 3 photos; 2 skipped (66.7%)"
    assert summarise([], []) == "no photos given"
