"""Application entry.

Two jobs, and they look unrelated but are not:

  1. **Register the API surface.** Every `def:pub` this app exposes must be
     named in an import here -- both the brain endpoints and the calendar /
     reinforcement endpoints. Registration tracks the exact name: an endpoint
     missing from this list returns 405 at runtime even though it compiles,
     imports, and type-checks cleanly. When an RPC call 404s or 405s, this
     list is the first place to look.

  2. **Export the client `app`.** Routing is file-based (`pages/`), so `app`
     receives the router tree as `children` and must render it. An `app` that
     ignores `children` silently drops every route with no error anywhere.
     The brain UI is mounted by `pages/index.jac` at `/`; the calendar lives
     under `/calendar`.
"""

import from endpoints { Thought, Link, LoadBrain, create_thought, delete_thought }

import from reinforce.api {
    EventView, ConnectionView, IntentionPreset,
    get_connection, connect_demo, google_auth_url, complete_google_connect,
    sync_events, disconnect_calendar,
    list_intentions, list_events, get_event, list_pings,
    set_intention, set_interval, mark_primed, record_ping, record_reflection
}

import ".styles.global.css";


def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
