"""Calendar tab - month grid on top, the selected day's events below.

The month is the whole point of this screen: a dot under a square is the only
signal that a day carries something, so the grid is sized to be tappable at
phone width rather than shrunk to fit more chrome around it.

Selecting a day filters the list underneath. Selecting nothing (the default on
open) shows everything upcoming, so the tab is useful before you touch it.
"""

sv import from ..reinforce.api { EventView }

# Only functions are imported from calgrid. An `obj` or a `glob` is not
# exported as a runtime value across a client module boundary -- naming
# `DayCell` or a shared weekday table here fails at import time even though
# the types check. So cells are read field-by-field, `DayButton` takes
# primitives, and the weekday row is a local below.
import from ..reinforce.calgrid {
    month_cells, month_label, day_key, day_heading
}
import from ..reinforce.timefmt { time_label, duration_label, has_ended, is_live }


glob WEEKDAYS: list[str] = ["S", "M", "T", "W", "T", "F", "S"];


"""One row in the day list."""
def:pub CalRow(
    item: EventView,
    onOpen: Callable[[str], None]
) -> JsxElement {
    def open(_e: MouseEvent) {
        onOpen(item.id);
    }

    live = is_live(item.starts_at, item.ends_at);
    done = has_ended(item.ends_at);

    meta = duration_label(item.duration_minutes);
    if item.location {
        meta = (meta + " · " + item.location) if meta else item.location;
    }

    cls = "cal-row";
    if live {
        cls = "cal-row live";
    } elif done {
        cls = "cal-row done";
    }

    return <button className={cls} onClick={open}>
        <span className="cal-row-time">
            {"All day" if item.all_day else time_label(item.starts_at)}
        </span>
        <span className="cal-row-body">
            <span className="cal-row-title">{item.title}</span>
            {if meta {
                <span key="meta" className="cal-row-meta">{meta}</span>
            }}
            {if item.intention_title {
                <span key="int" className="cal-row-intent">{item.intention_title}</span>
            }}
        </span>
        {if live {
            <span key="live" className="cal-live-dot" aria-label="Happening now"></span>
        }}
    </button>;
}


def:pub CalendarScreen(
    events: list[EventView],
    connected: bool,
    busy: bool,
    selectedDay: str,
    onSelectDay: Callable[[str], None],
    onOpen: Callable[[str], None],
    onConnect: Callable[[], None]
) -> JsxElement {
    # The visible month, held as an offset from the current one so the initial
    # render needs no effect to land on today.
    has monthShift: int = 0;

    today = new(Date);
    base = new(Date, today.getFullYear(), (today.getMonth() as int) + monthShift, 1);
    year = base.getFullYear() as int;
    month = base.getMonth() as int;

    def prev_month(_e: MouseEvent) {
        monthShift = monthShift - 1;
    }

    def next_month(_e: MouseEvent) {
        monthShift = monthShift + 1;
    }

    if not connected {
        return <div className="scroll cal-screen">
            <header className="cal-head">
                <h1 className="cal-title">Calendar</h1>
            </header>
            <div className="cal-connect">
                <div className="cal-connect-art" aria-hidden="true">
                    <span className="cal-connect-grid">
                        {for i in range(12) {
                            <span key={"g" + str(i)}></span>
                        }}
                    </span>
                </div>
                <h2>Bring in your calendar</h2>
                <p>
                    {"Pick one behavior to reinforce before each experience, "
                     + "then get a nudge while it is happening."}
                </p>
                <button className="primary-btn" onClick={onConnect} disabled={busy}>
                    {"Connecting…" if busy else "Connect calendar"}
                </button>
                <p className="cal-connect-note">Demo events, no account needed.</p>
            </div>
        </div>;
    }

    # Which days carry something. A set would be tidier, but membership on a
    # dict key is what compiles cleanly to JS here.
    marked: dict[str, bool] = {};
    for e in events {
        k = day_key(e.starts_at);
        if k {
            marked[k] = True;
        }
    }

    cells = month_cells(year, month);

    # The list under the grid: one day when a square is selected, otherwise
    # everything still ahead.
    shown: list[EventView] = [];
    if selectedDay {
        shown = [e for e in events if day_key(e.starts_at) == selectedDay];
    } else {
        shown = [e for e in events if not has_ended(e.ends_at)];
    }

    heading = day_heading(selectedDay) if selectedDay else "Upcoming";

    def clear_day(_e: MouseEvent) {
        onSelectDay("");
    }

    return <div className="scroll cal-screen">
        <header className="cal-head">
            <h1 className="cal-title">Calendar</h1>
            <p className="cal-sub">One intention per experience.</p>
        </header>

        <section className="cal-card">
            <div className="cal-month-bar">
                <button className="cal-arrow" onClick={prev_month} aria-label="Previous month">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                        stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"
                        strokeLinejoin="round">
                        <polyline points="15 18 9 12 15 6"/>
                    </svg>
                </button>
                <span className="cal-month-label">{month_label(year, month)}</span>
                <button className="cal-arrow" onClick={next_month} aria-label="Next month">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                        stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"
                        strokeLinejoin="round">
                        <polyline points="9 18 15 12 9 6"/>
                    </svg>
                </button>
            </div>

            <div className="cal-weekdays" aria-hidden="true">
                {for (i, w) in enumerate(WEEKDAYS) {
                    <span key={"w" + str(i)}>{w}</span>
                }}
            </div>

            <div className="cal-grid" role="grid">
                {for cell in cells {
                    <DayButton
                        key={cell.key}
                        dayKey={cell.key}
                        day={cell.day}
                        inMonth={cell.in_month}
                        isToday={cell.is_today}
                        marked={cell.key in marked}
                        selected={cell.key == selectedDay}
                        onSelectDay={onSelectDay}
                    />
                }}
            </div>
        </section>

        <div className="cal-list-head">
            <h2 className="section-label">{heading}</h2>
            {if selectedDay {
                <button key="clear" className="text-btn sm" onClick={clear_day}>
                    Show all
                </button>
            }}
        </div>

        {if len(shown) == 0 {
            <p className="empty-inline">
                {"Nothing on this day." if selectedDay else "Nothing coming up."}
            </p>
            skip;
        }}

        <div className="cal-list">
            {for item in shown {
                <CalRow key={item.id} item={item} onOpen={onOpen}/>
            }}
        </div>
    </div>;
}


"""One square. Its own component so the tap closes over its day key."""
def:pub DayButton(
    dayKey: str,
    day: int,
    inMonth: bool,
    isToday: bool,
    marked: bool,
    selected: bool,
    onSelectDay: Callable[[str], None]
) -> JsxElement {
    def tap(_e: MouseEvent) {
        onSelectDay("" if selected else dayKey);
    }

    cls = "cal-day";
    if not inMonth {
        cls = cls + " out";
    }
    if isToday {
        cls = cls + " today";
    }
    if selected {
        cls = cls + " sel";
    }

    return <button className={cls} onClick={tap}>
        <span className="cal-day-num">{str(day)}</span>
        {if marked {
            <span key="dot" className="cal-day-dot" aria-label="Has events"></span>
        }}
    </button>;
}
