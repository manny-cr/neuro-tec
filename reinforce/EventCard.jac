"""One event in the calendar list.

Carries just enough to decide whether to open it: when, where, how long, and
whether an intention is already committed. A card whose event is running now
gets a live marker; one that has ended and still has no reflection says so,
because that is the only remaining action on it.
"""

import from .timefmt { time_label, duration_label, is_live, has_ended }


def:pub EventCard(
    eventId: str,
    title: str,
    startsAt: str,
    endsAt: str,
    location: str,
    durationMinutes: int,
    allDay: bool,
    intentionTitle: str,
    reflection: str,
    onOpen: Callable[[str], None]
) -> JsxElement {

    def handle_open(e: MouseEvent) {
        onOpen(eventId);
    }

    live = is_live(startsAt, endsAt);
    ended = has_ended(endsAt);

    shell = "group w-full rounded-2xl border p-5 text-left transition-all duration-300 "
        + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
        + "focus-visible:ring-offset-2 focus-visible:ring-offset-background ";
    if live {
        shell = shell + "border-primary/40 bg-card shadow-lg shadow-primary/5";
    } elif ended {
        shell = shell + "border-border/50 bg-card/30 hover:bg-card/50";
    } else {
        shell = shell + "border-border bg-card/60 hover:border-muted-foreground/40 hover:bg-card";
    }

    when = "All day" if allDay else time_label(startsAt);
    length = duration_label(durationMinutes);

    return <button type="button" onClick={handle_open} className={shell}>
        <div className="flex items-start gap-4">

            {#* A single quiet time-marker, not an icon set. *#}
            <span className={
                "mt-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-full border "
                + ("border-primary/50 text-primary" if live
                   else "border-border text-muted-foreground")
            }>
                <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.6"
                    strokeLinecap="round"
                    className="h-4 w-4"
                >
                    <circle cx="12" cy="12" r="9" />
                    <polyline points="12 7 12 12 15.5 14" />
                </svg>
            </span>

            <div className="min-w-0 flex-1 space-y-2">
                <div className="flex items-baseline justify-between gap-3">
                    <h3 className={
                        "truncate text-base font-semibold "
                        + ("text-muted-foreground" if ended else "text-foreground")
                    }>
                        {title}
                    </h3>
                    <span className="tabular shrink-0 text-sm text-muted-foreground">
                        {when}
                    </span>
                </div>

                <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs text-muted-foreground">
                    {if live {
                        <span
                            key="live"
                            className="flex items-center gap-1.5 font-medium text-primary"
                        >
                            <span className="h-1.5 w-1.5 rounded-full bg-primary animate-breathe" />
                            {"Happening now"}
                        </span>
                    }}
                    {if length {
                        <span key="len">{length}</span>
                    }}
                    {if location {
                        <span key="loc" className="truncate">{"· " + location}</span>
                    }}
                </div>

                {if intentionTitle {
                    <div
                        key="intent"
                        className="flex items-center gap-2 pt-0.5 text-xs font-medium text-primary"
                    >
                        <span className="h-1 w-1 rounded-full bg-primary" />
                        <span className="truncate">{intentionTitle}</span>
                    </div>
                }}

                {#* Only an event someone actually prepared for has a
                    reflection worth prompting. *#}
                {if ended and intentionTitle and not reflection {
                    <p key="reflect" className="pt-0.5 text-xs text-muted-foreground/80">
                        {"Reflect for a moment"}
                    </p>
                }}
            </div>
        </div>
    </button>;
}
