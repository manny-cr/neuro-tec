"""The Calendar page: connect, then everything upcoming.

Three states, in order of how often they are seen:

  - **not connected**  the onboarding card
  - **connected, events**  a chronological list grouped by day
  - **connected, no events**  a quiet empty state, not an error

On mount the page reads the stored events first and re-syncs from the source
second, so a returning user sees their calendar immediately rather than a
spinner while the network decides. If the sync fails, the already-rendered list
simply stays -- offline should look like slightly stale data, never an empty
calendar.
"""

import from "@jac/runtime" { useNavigate }
import from ...reinforce.EventCard { EventCard }
import from ...reinforce.CalendarConnectionCard { CalendarConnectionCard }
import from ...reinforce.timefmt { day_group, has_ended }

sv import from ...reinforce.api {
    EventView, ConnectionView, list_events,
    get_connection, connect_demo, sync_events, google_auth_url
}


def:pub CalendarPage() -> JsxPage {
    has events: list[EventView] = [];
    has connection: ConnectionView | None = None;
    has loading: bool = True;
    has connecting: bool = False;

    nav = useNavigate();

    async can with entry {
        # Every intermediate value is held in a LOCAL. Reading a `has` field
        # back after an `await` returns the render-time snapshot, not the value
        # just assigned -- so `connection` would still read None here and the
        # whole branch below would be skipped.
        link = await get_connection();
        connection = link;

        if link and link.connected {
            # Stored events first -- instant paint from the graph.
            stored = await list_events();
            events = stored;

            # Then refresh from the source. A failure here leaves the list
            # above untouched: offline should look like stale data, not an
            # empty calendar.
            synced = await sync_events();
            if synced and len(synced) > 0 {
                events = synced;
            }
        }
        loading = False;
    }

    async def handle_connect -> None {
        connecting = True;
        # A real Google connection leaves the app entirely for the consent
        # screen and returns through the OAuth callback route.
        if connection and connection.google_configured {
            url = await google_auth_url();
            if url {
                browser: any = window;
                browser.location.href = url;
                return;
            }
        }
        linked = await connect_demo();
        connection = linked;
        loaded = await list_events();
        events = loaded;
        connecting = False;
    }

    def open_event(eventId: str) {
        nav("/calendar/" + eventId);
    }

    connected = bool(connection and connection.connected);
    google_ready = bool(connection and connection.google_configured);

    if loading {
        return <div className="space-y-3 pt-6" aria-busy="true">
            {for i in range(3) {
                <div
                    key={"skeleton-" + str(i)}
                    className="h-24 animate-pulse rounded-2xl border border-border/50 bg-card/30"
                />
            }}
        </div>;
    }

    if not connected {
        return <div className="pt-4">
            <CalendarConnectionCard
                googleConfigured={google_ready}
                busy={connecting}
                onConnect={handle_connect}
            />
        </div>;
    }

    upcoming = [e for e in events if not has_ended(e.ends_at)];
    past = [e for e in events if has_ended(e.ends_at)];
    # A finished event still needing a reflection stays actionable, so it is
    # surfaced above the archive rather than buried in it.
    needs_reflection = [e for e in past if e.intention_key and not e.reflection];
    archive = [e for e in past if not (e.intention_key and not e.reflection)];

    # Distinct day labels in chronological order. Computed up front because a
    # running "did the day change?" flag cannot work inside a render slot --
    # the slot body re-executes every render, so the flag would never persist.
    day_labels: list[str] = [];
    for item in upcoming {
        label = day_group(item.starts_at);
        if label not in day_labels {
            day_labels.append(label);
        }
    }

    return <div className="space-y-10">

        <header className="animate-rise space-y-2">
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
                {"Calendar"}
            </h1>
            <p className="text-sm leading-relaxed text-muted-foreground">
                {"Choose one behavior to reinforce before each experience."}
            </p>
        </header>

        {if len(events) == 0 {
            <section className="animate-rise rounded-2xl border border-border bg-card/40 p-10 text-center">
                <p className="text-base font-medium">{"Nothing scheduled."}</p>
                <p className="pt-1.5 text-sm text-muted-foreground">
                    {"Events from the next two weeks will appear here."}
                </p>
            </section>
            skip;
        }}

        {if len(needs_reflection) > 0 {
            <section key="needs-reflection" className="space-y-3">
                <h2 className="px-1 text-xs font-medium uppercase tracking-[0.16em] text-primary">
                    {"Reflect"}
                </h2>
                {for item in needs_reflection {
                    <EventCard
                        key={item.id}
                        eventId={item.id}
                        title={item.title}
                        startsAt={item.starts_at}
                        endsAt={item.ends_at}
                        location={item.location}
                        durationMinutes={item.duration_minutes}
                        allDay={item.all_day}
                        intentionTitle={item.intention_title}
                        reflection={item.reflection}
                        onOpen={open_event}
                    />
                }}
            </section>
        }}

        {for label in day_labels {
            <section key={"day-" + label} className="space-y-3">
                <h2 className="px-1 text-xs font-medium uppercase tracking-[0.16em] text-muted-foreground">
                    {label}
                </h2>
                {for item in upcoming {
                    if day_group(item.starts_at) == label {
                        <EventCard
                            key={item.id}
                            eventId={item.id}
                            title={item.title}
                            startsAt={item.starts_at}
                            endsAt={item.ends_at}
                            location={item.location}
                            durationMinutes={item.duration_minutes}
                            allDay={item.all_day}
                            intentionTitle={item.intention_title}
                            reflection={item.reflection}
                            onOpen={open_event}
                        />
                    }
                }}
            </section>
        }}

        {if len(archive) > 0 {
            <section key="archive" className="space-y-3">
                <h2 className="px-1 text-xs font-medium uppercase tracking-[0.16em] text-muted-foreground">
                    {"Earlier"}
                </h2>
                {for item in archive {
                    <EventCard
                        key={item.id}
                        eventId={item.id}
                        title={item.title}
                        startsAt={item.starts_at}
                        endsAt={item.ends_at}
                        location={item.location}
                        durationMinutes={item.duration_minutes}
                        allDay={item.all_day}
                        intentionTitle={item.intention_title}
                        reflection={item.reflection}
                        onOpen={open_event}
                    />
                }}
            </section>
        }}
    </div>;
}
