"""The persistent graph behind the Calendar feature, and the endpoints over it.

Shape:

    root
     +--(Links)-->    CalendarLink            one per connected calendar source
     +--(Scheduled)-> CalEvent                one per imported event
                       +--(Prepares)--> Preparation      the user's commitment
                                          +--(Pinged)--> ReminderPing   one per answered reminder
                                          +--(Reflected)-> Reflection   one, after the event

Everything the feature remembers lives here, hanging off the caller's own
`root` -- so closing the tab, restarting the server, or coming back tomorrow
restores the same state. Nothing important is kept in browser storage.

A `Preparation` is created lazily, the first time a user commits to an
intention for an event. An event with no `Preparation` is simply one the user
has not prepared for yet, which is the honest default.
"""

import from reinforce.clock { now_iso, minutes_between }
import from reinforce.intentions { INTENTIONS, IntentionPreset, is_valid_intention, preset_for }


# ─── Edges ───────────────────────────────────────────────────────────────────
# Endpoint types are declared wherever both ends are our own nodes, so
# traversals infer the destination type without a filter at every read site.

edge Links {}                                  # root -> CalendarLink
edge Scheduled {}                              # root -> CalEvent
edge Prepares: CalEvent --> Preparation {}
edge Pinged: Preparation --> ReminderPing {}
edge Reflected: Preparation --> Reflection {}
edge Surveyed: Preparation --> Survey {}


# ─── Nodes ───────────────────────────────────────────────────────────────────

"""A connected calendar source.

`provider` is "google" for a real OAuth connection and "demo" for the built-in
sample source, which exists so the feature is fully demonstrable before Google
credentials are configured.

The OAuth material lives here, server-side on the caller's own root. It is
never copied into a view model, so it is not reachable from the browser.
"""
node CalendarLink {
    has provider: str = "demo",
        account_label: str = "",
        connected_at: str = "",
        last_synced_at: str = "",
        access_token: str = "",
        refresh_token: str = "",
        token_expires_at: str = "";
}


"""One imported calendar event.

`source_id` is the provider's own id. It is what makes a re-sync idempotent:
an event already present is updated in place rather than duplicated, so a
user's Preparation survives every refresh.
"""
node CalEvent {
    has source_id: str = "",
        title: str = "",
        starts_at: str = "",
        ends_at: str = "",
        location: str = "",
        calendar_name: str = "",
        all_day: bool = False;
}


"""The user's commitment for one event: what to reinforce, and how often.

Exactly one intention is active at a time -- `intention_key` is a single
field, so choosing a new one replaces the old by construction rather than by a
rule someone has to remember to enforce.

`primed_at` records the pre-event rehearsal, so it is offered once rather than
every time the page mounts.
"""
node Preparation {
    has intention_key: str = "",
        interval_minutes: int = 15,
        created_at: str = "",
        updated_at: str = "",
        primed_at: str = "";
}


"""One reminder the user actually answered.

Only answered reminders are recorded. An unanswered reminder is not a failure
to store -- it is a moment that passed, and the feature takes no position on
it.
"""
node ReminderPing {
    has scheduled_for: str = "",
        answered_at: str = "",
        response: str = "";                    # "yes" | "not_yet"
}


node Reflection {
    has rating: str = "",                      # "better" | "expected" | "needs_work"
        created_at: str = "";
}


"""The post-event survey: three 0-100 readings taken once, after the fact.

Stored as integers on a 0-100 scale rather than a 1-5 rating because the input
is a slider -- collapsing to five buckets at write time would throw away
resolution the user actually expressed, and nothing downstream needs buckets.

Each axis is signed so that higher is better, which is the only way an average
across axes means anything later:

  comfort   uneasy      -> at ease
  mood      drained     -> energized
  presence  distracted  -> fully present
"""
node Survey {
    has comfort: int = 50,
        mood: int = 50,
        presence: int = 50,
        created_at: str = "";
}


# ─── View models ─────────────────────────────────────────────────────────────
# The client gets flat, already-joined objects. It never walks the graph, and
# never recomputes anything the server already knows.

obj EventView {
    has id: str,
        title: str,
        starts_at: str,
        ends_at: str,
        location: str,
        calendar_name: str,
        all_day: bool,
        duration_minutes: int,
        intention_key: str,                    # "" when nothing is committed yet
        # The preset's display title, resolved here so the browser never needs
        # the preset table to render a committed intention.
        intention_title: str,
        interval_minutes: int,
        primed: bool,
        answered_count: int,
        yes_count: int,
        reflection: str,
        # The survey, flattened. `surveyed` is what the client branches on --
        # the three values are 50 when nothing has been recorded, and 50 is
        # also a legitimate answer, so they cannot stand in for "done".
        surveyed: bool,
        comfort: int,
        mood: int,
        presence: int;
}


obj ConnectionView {
    has connected: bool,
        provider: str,
        account_label: str,
        last_synced_at: str,
        google_configured: bool;               # real credentials present server-side
}


"""One event as a calendar source hands it over, before it reaches the graph.

Every source -- the demo generator, the Google importer, any future one --
produces these. It is the single boundary type between "where events come
from" and "how events are stored", which is what keeps `upsert_events` from
having to know which provider it is talking to.
"""
obj RawEvent {
    has source_id: str,
        title: str,
        starts_at: str,
        ends_at: str,
        location: str = "",
        calendar_name: str = "",
        all_day: bool = False;
}


# ─── Internal helpers (underscore-prefixed: never routed) ────────────────────

def _find_event(event_id: str) -> CalEvent | None {
    for candidate in [root-->[?:CalEvent]] {
        if jid(candidate) == event_id {
            return candidate;
        }
    }
    return None;
}


def _preparation_of(event: CalEvent) -> Preparation | None {
    existing = [event ->:Prepares:->];
    return existing[0] if existing else None;
}


"""Get this event's Preparation, creating it on first commitment."""
def _ensure_preparation(event: CalEvent) -> Preparation {
    found = _preparation_of(event);
    if found is not None {
        return found;
    }
    stamp = now_iso();
    return (event +>: Prepares() :+> Preparation(
        created_at=stamp, updated_at=stamp
    )) as Preparation;
}


def _view_of(event: CalEvent) -> EventView {
    prep = _preparation_of(event);
    intention = "";
    interval = 15;
    primed = False;
    answered = 0;
    yeses = 0;
    rating = "";
    surveyed = False;
    comfort = 50;
    mood = 50;
    presence = 50;

    if prep is not None {
        intention = prep.intention_key;
        interval = prep.interval_minutes;
        primed = bool(prep.primed_at);
        for ping in [prep ->:Pinged:->] {
            answered += 1;
            if ping.response == "yes" {
                yeses += 1;
            }
        }
        reflections = [prep ->:Reflected:->];
        if reflections {
            rating = reflections[0].rating;
        }
        surveys = [prep ->:Surveyed:->];
        if surveys {
            surveyed = True;
            comfort = surveys[0].comfort;
            mood = surveys[0].mood;
            presence = surveys[0].presence;
        }
    }

    chosen = preset_for(intention);

    return EventView(
        id=jid(event),
        title=event.title,
        starts_at=event.starts_at,
        ends_at=event.ends_at,
        location=event.location,
        calendar_name=event.calendar_name,
        all_day=event.all_day,
        duration_minutes=minutes_between(event.starts_at, event.ends_at),
        intention_key=intention,
        intention_title=chosen.title if chosen is not None else "",
        interval_minutes=interval,
        primed=primed,
        answered_count=answered,
        yes_count=yeses,
        reflection=rating,
        surveyed=surveyed,
        comfort=comfort,
        mood=mood,
        presence=presence
    );
}


"""Chronological sort key.

ISO-8601 UTC strings sort correctly as text, which is the main reason the
storage format is pinned to it.
"""
def _sort_key(view: EventView) -> str {
    return view.starts_at;
}


def _ping_key(row: dict[str, str]) -> str {
    return row["answered_at"];
}


# ─── Read endpoints ──────────────────────────────────────────────────────────

"""The five preset intentions, in display order.

Served from the server rather than duplicated into the bundle so the preset
table has exactly one definition. `IntentionPreset` is a plain `obj`, so the
client receives hydrated, typed instances.
"""
def list_intentions -> list[IntentionPreset] {
    return INTENTIONS;
}

"""Every imported event, earliest first.

Past events are included rather than hidden: an event that has just ended is
exactly the one whose reflection is still worth capturing. The client decides
how to group them.
"""
def list_events -> list[EventView] {
    views = [_view_of(event) for event in [root-->[?:CalEvent]]];
    return sorted(views, key=_sort_key);
}


def get_event(event_id: str) -> EventView | None {
    event = _find_event(event_id);
    return _view_of(event) if event is not None else None;
}


"""Answered reminders for one event, oldest first.

Returned as plain dicts because the client only tallies and timestamps them;
there is no behavior to carry across the wire.
"""
def list_pings(event_id: str) -> list[dict[str, str]] {
    event = _find_event(event_id);
    if event is None {
        return [];
    }
    prep = _preparation_of(event);
    if prep is None {
        return [];
    }
    rows: list[dict[str, str]] = [
        {
            "scheduled_for": ping.scheduled_for,
            "answered_at": ping.answered_at,
            "response": ping.response
        }
        for ping in [prep ->:Pinged:->]
    ];
    return sorted(rows, key=_ping_key);
}


# ─── Write endpoints ─────────────────────────────────────────────────────────

"""Commit to one intention for one event.

Passing the currently-selected key clears it, so the same tap both selects and
deselects. An unknown key is rejected outright.
"""
def set_intention(event_id: str, intention_key: str) -> EventView | None {
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    if intention_key and not is_valid_intention(intention_key) {
        return None;
    }

    prep = _ensure_preparation(event);
    prep.intention_key = "" if prep.intention_key == intention_key else intention_key;
    prep.updated_at = now_iso();
    # Changing the commitment invalidates a rehearsal done against the old one
    # -- the user should prime on whatever they are actually committed to.
    if not prep.intention_key {
        prep.primed_at = "";
    }
    return _view_of(event);
}


"""Set the reminder cadence, in minutes.

Clamped to 1 minute at the low end and 12 hours at the high end, so a custom
value can never schedule a reminder storm or an interval so long it never
fires inside the event.
"""
def set_interval(event_id: str, interval_minutes: int) -> EventView | None {
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    prep = _ensure_preparation(event);
    prep.interval_minutes = max(1, min(720, interval_minutes));
    prep.updated_at = now_iso();
    return _view_of(event);
}


"""Record that the user completed the pre-event rehearsal."""
def mark_primed(event_id: str) -> EventView | None {
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    prep = _ensure_preparation(event);
    prep.primed_at = now_iso();
    prep.updated_at = prep.primed_at;
    return _view_of(event);
}


"""Record the answer to one reminder.

`scheduled_for` is the reminder's own slot time, which makes this idempotent:
answering the same slot twice (two tabs, a double tap, a replayed
notification) updates that slot rather than inflating the count.
"""
def record_ping(event_id: str, scheduled_for: str, response: str) -> EventView | None {
    if response not in ["yes", "not_yet"] {
        return None;
    }
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    prep = _ensure_preparation(event);

    for existing in [prep ->:Pinged:->] {
        if existing.scheduled_for == scheduled_for {
            existing.response = response;
            existing.answered_at = now_iso();
            return _view_of(event);
        }
    }

    prep +>: Pinged() :+> ReminderPing(
        scheduled_for=scheduled_for, answered_at=now_iso(), response=response
    );
    return _view_of(event);
}


"""Store the one-tap post-event reflection, replacing any earlier answer."""
def record_reflection(event_id: str, rating: str) -> EventView | None {
    if rating not in ["better", "expected", "needs_work"] {
        return None;
    }
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    prep = _ensure_preparation(event);

    existing = [prep ->:Reflected:->];
    if existing {
        existing[0].rating = rating;
        existing[0].created_at = now_iso();
    } else {
        prep +>: Reflected() :+> Reflection(rating=rating, created_at=now_iso());
    }
    return _view_of(event);
}


"""Record the post-event survey. Re-submitting overwrites.

Values are clamped rather than rejected: this is the last screen of a flow the
user has already finished, and failing it over an out-of-range integer would
lose the whole response to protect data nobody is going to audit.
"""
def record_survey(
    event_id: str, comfort: int, mood: int, presence: int
) -> EventView | None {
    event = _find_event(event_id);
    if event is None {
        return None;
    }
    prep = _ensure_preparation(event);

    c = max(0, min(100, comfort));
    m = max(0, min(100, mood));
    p = max(0, min(100, presence));

    existing = [prep ->:Surveyed:->];
    if existing {
        existing[0].comfort = c;
        existing[0].mood = m;
        existing[0].presence = p;
        existing[0].created_at = now_iso();
    } else {
        prep +>: Surveyed() :+> Survey(
            comfort=c, mood=m, presence=p, created_at=now_iso()
        );
    }
    return _view_of(event);
}


# ─── Connection state ────────────────────────────────────────────────────────

def _link -> CalendarLink | None {
    found = [root-->[?:CalendarLink]];
    return found[0] if found else None;
}


"""Import events, keyed on `source_id`.

Called by the sync layer, not the browser. Matching an existing `source_id`
updates that event in place, so re-syncing a changed event (moved, renamed,
relocated) preserves the Preparation attached to it -- the whole point of
storing the provider's id.
"""
def upsert_events(rows: list[RawEvent], provider: str, account_label: str) -> list[EventView] {
    existing = [root-->[?:CalEvent]];
    by_source: dict[str, CalEvent] = {};
    for event in existing {
        by_source[event.source_id] = event;
    }

    touched: list[CalEvent] = [];
    for row in rows {
        if not row.source_id {
            continue;
        }
        target = by_source.get(row.source_id);
        if target is None {
            target = (root +>: Scheduled() :+> CalEvent(source_id=row.source_id)) as CalEvent;
            by_source[row.source_id] = target;
        }
        target.title = row.title or "Untitled event";
        target.starts_at = row.starts_at;
        target.ends_at = row.ends_at;
        target.location = row.location;
        target.calendar_name = row.calendar_name;
        target.all_day = row.all_day;
        touched.append(target);
    }

    link = _link();
    if link is None {
        link = (root +>: Links() :+> CalendarLink(
            provider=provider, account_label=account_label, connected_at=now_iso()
        )) as CalendarLink;
    }
    link.provider = provider;
    link.account_label = account_label;
    link.last_synced_at = now_iso();

    return sorted([_view_of(event) for event in touched], key=_sort_key);
}


"""Forget the connection and every imported event.

Deleting a `CalEvent` cascades to its Preparation, pings and reflection --
which is the correct reading of "disconnect my calendar". This is the only
destructive path in the feature, and it is always user-initiated.
"""
def disconnect_calendar -> ConnectionView {
    for event in [root-->[?:CalEvent]] {
        del event;
    }
    for link in [root-->[?:CalendarLink]] {
        del link;
    }
    return ConnectionView(
        connected=False, provider="", account_label="",
        last_synced_at="", google_configured=False
    );
}
