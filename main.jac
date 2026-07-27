"""Neurotech - Entry Point.

One module wiring the two halves together: the object-spatial brain on the
server and the React UI in the browser. The server imports register the
endpoints; the `cl` block mounts the client shell.

**Registration is by name.** Every `def:pub` the browser calls must appear in
an import here -- the brain endpoints and the calendar/reinforcement ones
alike. An endpoint missing from this list returns 405 at runtime even though
it compiles, imports, and type-checks cleanly. When an RPC call 404s or 405s,
this list is the first place to look.

There is no file-based routing: the calendar is a tab inside the phone shell,
not a separate route tree, so `app` renders the shell directly.
"""

import from endpoints {
    Thought, Link, Goal, LoadBrain,
    create_thought, delete_thought, get_goal, set_goal
}

import from reinforce.api {
    EventView, ConnectionView, IntentionPreset,
    get_connection, connect_demo, google_auth_url, complete_google_connect,
    sync_events, disconnect_calendar,
    list_intentions, list_events, get_event, list_pings,
    set_intention, set_interval, mark_primed, record_ping, record_reflection
}

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
