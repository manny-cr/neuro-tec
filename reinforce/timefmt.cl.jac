"""Browser-side time formatting.

The server stores every instant as ISO-8601 UTC. This module is the only place
that turns one into something a person reads, and it always renders in the
*viewer's* zone via the platform's own locale APIs -- so a user who changes
timezone mid-trip sees correct local times against unchanged stored data.

Wrapped in `cl` because it calls `Date`: this code must compile to JavaScript,
never to Python.
"""

"""Milliseconds since epoch for a stored instant; 0.0 when unparseable.

`Date.parse` returns NaN for malformed input, and NaN propagates silently
through every comparison downstream -- so it is collapsed to 0.0 here,
once, rather than guarded at each call site.
"""
def:pub to_ms(iso: str) -> float {
    if not iso {
        return 0.0;
    }
    parsed = Date.parse(iso);
    if Number.isNaN(parsed) {
        return 0.0;
    }
    return parsed as float;
}


def:pub now_ms -> float {
    return Date.now() as float;
}


"""Local clock time, e.g. "6:30 PM"."""
def:pub time_label(iso: str) -> str {
    ms = to_ms(iso);
    if ms == 0.0 {
        return "";
    }
    return new(Date, ms).toLocaleTimeString(
        [], {"hour": "numeric", "minute": "2-digit"}
    ) as str;
}


"""Local calendar date, e.g. "Thu, Jul 30"."""
def:pub date_label(iso: str) -> str {
    ms = to_ms(iso);
    if ms == 0.0 {
        return "";
    }
    return new(Date, ms).toLocaleDateString(
        [], {"weekday": "short", "month": "short", "day": "numeric"}
    ) as str;
}


"""Day bucket for grouping: "Today", "Tomorrow", or a date label.

Compared on local calendar days rather than elapsed hours, so an event at
11pm tonight and one at 1am tomorrow land in different groups the way a
person would expect.
"""
def:pub day_group(iso: str) -> str {
    ms = to_ms(iso);
    if ms == 0.0 {
        return "Scheduled";
    }
    moment = new(Date, ms);
    today = new(Date);
    if moment.toDateString() == today.toDateString() {
        return "Today";
    }
    tomorrow = new(Date, Date.now() + 86400000.0);
    if moment.toDateString() == tomorrow.toDateString() {
        return "Tomorrow";
    }
    yesterday = new(Date, Date.now() - 86400000.0);
    if moment.toDateString() == yesterday.toDateString() {
        return "Yesterday";
    }
    return date_label(iso);
}


"""A duration in minutes as compact text: "45 min", "1h 30m", "2h"."""
def:pub duration_label(minutes: int) -> str {
    if minutes <= 0 {
        return "";
    }
    if minutes < 60 {
        return str(minutes) + " min";
    }
    hours = minutes // 60;
    rest = minutes % 60;
    if rest == 0 {
        return str(hours) + "h";
    }
    return str(hours) + "h " + str(rest) + "m";
}


"""Human phrasing for the gap between now and an event's start.

Deliberately unhurried: no seconds, no live-ticking digits under a minute.
A countdown that races is the opposite of what this screen is for.
"""
def:pub countdown_label(starts_at: str, ends_at: str) -> str {
    start_ms = to_ms(starts_at);
    end_ms = to_ms(ends_at);
    if start_ms == 0.0 {
        return "";
    }
    current = now_ms();

    if end_ms > 0.0 and current >= end_ms {
        return "Ended";
    }
    if current >= start_ms {
        return "Happening now";
    }

    minutes = int((start_ms - current) / 60000.0);
    if minutes < 1 {
        return "Starting now";
    }
    if minutes == 1 {
        return "In 1 minute";
    }
    if minutes < 60 {
        return "In " + str(minutes) + " minutes";
    }

    hours = minutes // 60;
    rest = minutes % 60;
    if hours < 24 {
        if rest == 0 {
            return "In " + str(hours) + (" hour" if hours == 1 else " hours");
        }
        return "In " + str(hours) + "h " + str(rest) + "m";
    }

    days = hours // 24;
    return "In " + str(days) + (" day" if days == 1 else " days");
}


"""True while an event is running."""
def:pub is_live(starts_at: str, ends_at: str) -> bool {
    current = now_ms();
    start_ms = to_ms(starts_at);
    end_ms = to_ms(ends_at);
    if start_ms == 0.0 or end_ms == 0.0 {
        return False;
    }
    return current >= start_ms and current < end_ms;
}


def:pub has_ended(ends_at: str) -> bool {
    end_ms = to_ms(ends_at);
    return end_ms > 0.0 and now_ms() >= end_ms;
}


"""Minutes until an event starts; negative once it has started."""
def:pub minutes_until(starts_at: str) -> float {
    start_ms = to_ms(starts_at);
    if start_ms == 0.0 {
        return 0.0;
    }
    return (start_ms - now_ms()) / 60000.0;
}
