"""Neurotech - frontend handler implementations.

Each handler spawns the `LoadBrain` walker or calls a `def:pub` endpoint and
folds the result back into client state. No fetch, no client SDK, no
serializers - the same call shape the server uses.

State is rebound rather than mutated (`nodes = view.nodes`, never
`nodes.append(...)`), because `has` fields are React state and in-place
mutation would not re-render.

Every handler that talks to the server is wrapped in try/except: a dead
server surfaces as a dismissible toast, never a white screen.
"""

impl app.refresh -> None {
    try {
        result = root spawn LoadBrain();
        if result.reports {
            view = result.reports[0];
            nodes = view.nodes;
            links = view.links;
            skills = view.skills;
        }
        error = "";
    } except Exception {
        error = "Could not reach your brain. Check the server and try again.";
    }
    loaded = True;
}

impl app.submit(text: str, cat: str) -> None {
    if not text.strip() {
        return;
    }

    # Optimistic: the node appears immediately, the composer closes, and the
    # server reconciles in the background. `base` snapshots the pre-append
    # list so a failure can roll back cleanly (reads after `await` are the
    # render-time snapshot anyway - see jac-cl-components).
    # A plain object cast to GraphNode: `sv import` brings the *type*, not a
    # client-side constructor, so GraphNode(...) is a ReferenceError here.
    base = nodes;
    words = text.strip().split();
    short = " ".join(words[:4]);
    temp = {
        "id": "pending",
        "kind": "thought",
        "label": short,
        "detail": text.strip(),
        "category": cat if cat else "idea",
        "strength": 1,
        "created_at": "",
        "x": 500.0,
        "y": 850.0
    } as GraphNode;
    nodes = base + [temp];
    composing = False;
    busy = True;

    try {
        _ = await create_thought(text, cat);

        reloaded = root spawn LoadBrain();
        if reloaded.reports {
            view = reloaded.reports[0];
            nodes = view.nodes;
            links = view.links;
            skills = view.skills;
        }
        error = "";
    } except Exception {
        nodes = base;
        error = "Couldn't save that thought. It has not been added.";
    }
    busy = False;
}

impl app.confirmDelete -> None {
    id = pendingDelete;
    busy = True;
    try {
        _ = await delete_thought(id);

        reloaded = root spawn LoadBrain();
        if reloaded.reports {
            view = reloaded.reports[0];
            nodes = view.nodes;
            links = view.links;
            skills = view.skills;
        }
        error = "";
        focus = "";
    } except Exception {
        error = "Couldn't delete that thought. Nothing was changed.";
    }
    busy = False;
    pendingDelete = "";
}

impl app.loadDemo -> None {
    busy = True;
    try {
        _ = await seed_demo();

        reloaded = root spawn LoadBrain();
        if reloaded.reports {
            view = reloaded.reports[0];
            nodes = view.nodes;
            links = view.links;
            skills = view.skills;
        }
        error = "";
    } except Exception {
        error = "Couldn't load the demo brain.";
    }
    busy = False;
}

impl app.loadCalendar -> None {
    # Every intermediate value is held in a LOCAL. Reading a `has` field back
    # after an `await` returns the render-time snapshot, not the value just
    # assigned -- so `calConnected` would still read False here and the whole
    # branch below would be skipped.
    try {
        link = await get_connection();
        connected = bool(link and link.connected);
        calConnected = connected;

        if connected {
            # Stored events first -- instant paint from the graph.
            stored = await list_events();
            events = stored;

            # Then refresh from the source. A failure here leaves the list
            # above untouched: offline should look like slightly stale data,
            # never an empty calendar.
            synced = await sync_events();
            if synced and len(synced) > 0 {
                events = synced;
            }
        }
    } except Exception {
        # A dead calendar service must not blank the brain tabs, so this one
        # stays quiet: the tab shows its connect state instead of a toast.
        calConnected = False;
    }
}

impl app.connectCalendar -> None {
    calConnecting = True;
    try {
        linked = await connect_demo();
        calConnected = bool(linked and linked.connected);
        # Not `loaded` -- the shell already has a `loaded: bool` for the brain,
        # and shadowing it here types the whole assignment as bool.
        fetched = await list_events();
        events = fetched;
        error = "";
    } except Exception {
        error = "Couldn't connect the calendar. Nothing was changed.";
    }
    calConnecting = False;
}

impl app.wipe -> None {
    busy = True;
    try {
        _ = await reset_brain();

        reloaded = root spawn LoadBrain();
        if reloaded.reports {
            view = reloaded.reports[0];
            nodes = view.nodes;
            links = view.links;
            skills = view.skills;
        }
        error = "";
        focus = "";
        tab = "brain";
    } except Exception {
        error = "Couldn't erase the brain. Everything is still intact.";
    }
    busy = False;
    confirmWipe = False;
}
