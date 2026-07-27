"""Month-grid geometry for the calendar tab.

The grid is always six rows of seven, never five: a month that fits in five
rows would otherwise resize the whole tab as you page through it, and a
calendar that changes height while you scrub months reads as a bug.

Cells outside the month are still rendered, dimmed, so the grid keeps its
shape and the week rows stay aligned with their weekday headers.

`cl` because everything here goes through `Date`.
"""

import from .timefmt { to_ms }


obj DayCell {
    has key: str,           # local calendar key, "2026-07-26"
        day: int,           # day of month
        in_month: bool,
        is_today: bool;
}


"""Local calendar key for a Date. Local, not UTC.

`toISOString` would shift a late-evening event into the next day for anyone
west of UTC, putting its dot on the wrong square -- which is exactly the kind
of off-by-one nobody notices until the demo.
"""
def:pub day_key_of(moment: any) -> str {
    y = moment.getFullYear() as int;
    m = (moment.getMonth() as int) + 1;
    d = moment.getDate() as int;
    mm = ("0" + str(m)) if m < 10 else str(m);
    dd = ("0" + str(d)) if d < 10 else str(d);
    return str(y) + "-" + mm + "-" + dd;
}


"""The local day key for a stored ISO instant; "" when unparseable."""
def:pub day_key(iso: str) -> str {
    ms = to_ms(iso);
    if ms == 0.0 {
        return "";
    }
    return day_key_of(new(Date, ms));
}


"""Six weeks of cells covering `year`/`month` (month is 0-based)."""
def:pub month_cells(year: int, month: int) -> list[DayCell] {
    first = new(Date, year, month, 1);
    # Back up to the Sunday on or before the 1st.
    lead = first.getDay() as int;
    start = new(Date, year, month, 1 - lead);

    today_key = day_key_of(new(Date));

    cells: list[DayCell] = [];
    for i in range(42) {
        moment = new(Date, start.getFullYear(), start.getMonth(), (start.getDate() as int) + i);
        key = day_key_of(moment);
        cells.append(DayCell(
            key=key,
            day=moment.getDate() as int,
            in_month=(moment.getMonth() as int) == month,
            is_today=key == today_key
        ));
    }
    return cells;
}


"""Month heading, e.g. "July 2026"."""
def:pub month_label(year: int, month: int) -> str {
    return new(Date, year, month, 1).toLocaleDateString(
        [], {"month": "long", "year": "numeric"}
    ) as str;
}


"""Full-date heading for a selected day key, e.g. "Sunday, July 26"."""
def:pub day_heading(key: str) -> str {
    if not key {
        return "";
    }
    parts = key.split("-");
    if len(parts) != 3 {
        return "";
    }
    moment = new(Date, int(parts[0]), int(parts[1]) - 1, int(parts[2]));
    return moment.toLocaleDateString(
        [], {"weekday": "long", "month": "long", "day": "numeric"}
    ) as str;
}
