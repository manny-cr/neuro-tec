"""Time helpers shared by every server module in this feature.

One rule holds everywhere: **instants are stored as ISO-8601 strings in UTC**
with an explicit `+00:00` offset. Nothing in the graph is ever a naive local
time. The client converts to the viewer's zone at render, so a user who flies
across timezones mid-event still sees a correct countdown against the same
stored instant.
"""

import from datetime { datetime, timedelta, UTC }


"""Current instant, timezone-aware, in UTC."""
def now_utc -> datetime {
    return datetime.now(UTC);
}


"""Serialize an instant for the graph / the wire."""
def to_iso(moment: datetime) -> str {
    return moment.astimezone(UTC).isoformat();
}


def now_iso -> str {
    return to_iso(now_utc());
}


"""Parse a stored instant back into an aware datetime.

Returns None rather than raising: a malformed or empty timestamp should
degrade one event to "unknown time", never fail the whole request. Naive
inputs are assumed UTC, and a trailing `Z` is normalized because
`fromisoformat` did not accept it before Python 3.11.
"""
def parse_iso(value: str) -> datetime | None {
    if not value {
        return None;
    }
    text = value.strip();
    if text.endswith("Z") {
        text = text[:-1] + "+00:00";
    }
    try {
        parsed = datetime.fromisoformat(text);
    } except ValueError {
        return None;
    }
    if parsed.tzinfo is None {
        return parsed.replace(tzinfo=UTC);
    }
    return parsed.astimezone(UTC);
}


def shift(moment: datetime, minutes: float) -> datetime {
    return moment + timedelta(minutes=minutes);
}


"""Whole minutes from `start` to `end`; 0 if either is unparseable."""
def minutes_between(start: str, end: str) -> int {
    a = parse_iso(start);
    b = parse_iso(end);
    if a is None or b is None {
        return 0;
    }
    return int((b - a).total_seconds() // 60);
}
