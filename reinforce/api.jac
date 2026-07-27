"""The one client-facing module: every endpoint the browser can call.

**Why this file exists.** `jac start` runs each server module the client
`sv import`s as its own service, with its own graph. Splitting endpoints
across `store` and `sources` therefore split the *data*: `connect_demo` wrote
events into the sources service's graph while `list_events` read the store
service's, and the calendar came back empty even though both calls succeeded.

Collapsing the public surface into a single module puts every endpoint in one
service, against one graph. `store` and `sources` keep their own files and
their own responsibilities -- they are simply internal now, reached through
here rather than over the wire.

So: one rule. **If the browser calls it, it is declared in this file.**
"""

import from reinforce.store {
    ConnectionView, EventView, IntentionPreset,
    list_intentions as _list_intentions,
    list_events as _list_events,
    get_event as _get_event,
    list_pings as _list_pings,
    set_intention as _set_intention,
    set_interval as _set_interval,
    mark_primed as _mark_primed,
    record_ping as _record_ping,
    record_reflection as _record_reflection,
    disconnect_calendar as _disconnect_calendar
}
import from reinforce.sources {
    google_auth_url as _google_auth_url,
    get_connection as _get_connection,
    connect_demo as _connect_demo,
    complete_google_connect as _complete_google_connect,
    sync_events as _sync_events
}


# ─── Calendar connection ─────────────────────────────────────────────────────

def:pub get_connection -> ConnectionView {
    return _get_connection();
}


def:pub connect_demo -> ConnectionView {
    return _connect_demo();
}


def:pub google_auth_url -> str {
    return _google_auth_url();
}


def:pub complete_google_connect(code: str) -> ConnectionView {
    return _complete_google_connect(code);
}


def:pub sync_events -> list[EventView] {
    return _sync_events();
}


def:pub disconnect_calendar -> ConnectionView {
    return _disconnect_calendar();
}


# ─── Events and preparation ──────────────────────────────────────────────────

def:pub list_intentions -> list[IntentionPreset] {
    return _list_intentions();
}


def:pub list_events -> list[EventView] {
    return _list_events();
}


def:pub get_event(event_id: str) -> EventView | None {
    return _get_event(event_id);
}


def:pub list_pings(event_id: str) -> list[dict[str, str]] {
    return _list_pings(event_id);
}


def:pub set_intention(event_id: str, intention_key: str) -> EventView | None {
    return _set_intention(event_id, intention_key);
}


def:pub set_interval(event_id: str, interval_minutes: int) -> EventView | None {
    return _set_interval(event_id, interval_minutes);
}


def:pub mark_primed(event_id: str) -> EventView | None {
    return _mark_primed(event_id);
}


def:pub record_ping(event_id: str, scheduled_for: str, response: str) -> EventView | None {
    return _record_ping(event_id, scheduled_for, response);
}


def:pub record_reflection(event_id: str, rating: str) -> EventView | None {
    return _record_reflection(event_id, rating);
}
