"""The browser notification surface.

Two things happen when a reminder comes due, and they are deliberately
separate:

  1. An OS notification, if the user granted permission. Its only job is to
     bring them back to the tab. It carries no buttons.
  2. The in-app banner, which is where the actual YES / NOT YET answer is
     given.

That split is forced by the platform: action buttons on a web notification
require a Service Worker registration and a push subscription. Rather than
half-implement that, the notification stays a nudge and the answer stays in the
app -- which also means the answer is always recorded against a live session
rather than a background context that may not have one.

**Known limitation:** a browser tab that is fully closed cannot run timers, so
reminders fire while the app is open (including in a background tab) but not
after the tab is gone. Nothing is lost when that happens -- the schedule is
derived and the answered slots are on the server, so reopening the app
reconstructs exactly where things stood.
"""

glob NOTIFY_TITLE: str = "Stay on track?";
glob NOTIFY_BODY: str = "Are we still following today's intention?";


"""The browser's Notification constructor, or None where unsupported.

Reached through `globalThis` and held as `any` deliberately: `jac check`
ships no type stubs for browser globals, so naming `Notification` directly
yields an Unknown type and a cascade of false attribute errors. One typed
escape hatch here keeps the rest of the module honestly typed.
"""
def _api -> any {
    root_scope: any = globalThis;
    return root_scope.Notification;
}


"""Whether this browser can show notifications at all."""
def:pub notifications_supported -> bool {
    return bool(_api());
}


"""Current permission: "granted", "denied", "default", or "unsupported"."""
def:pub permission_state -> str {
    api = _api();
    if not api {
        return "unsupported";
    }
    return str(api.permission);
}


"""Ask for notification permission.

Only ever called from a click handler -- browsers reject (and some
permanently penalize) permission prompts that are not tied to a user
gesture. Resolves to the resulting permission string.
"""
async def:pub request_permission -> str {
    api = _api();
    if not api {
        return "unsupported";
    }
    if str(api.permission) != "default" {
        return str(api.permission);
    }
    try {
        result = await api.requestPermission();
        return str(result);
    } except Exception {
        return "denied";
    }
}


"""Show one reminder notification.

`tag` collapses repeats: re-firing with the same tag replaces the existing
notification rather than stacking a new one, so returning to a long-idle
tab never produces a pile of them. `requireInteraction` is deliberately
left off -- a notification that refuses to dismiss itself is pressure, and
this feature does not apply pressure.
"""
def:pub fire_reminder(tag: str) -> bool {
    return _show(NOTIFY_TITLE, NOTIFY_BODY, tag);
}


"""Show the single post-event reflection notification."""
def:pub fire_reflection(tag: str) -> bool {
    return _show("Reflect for a moment", "How did today go?", tag);
}


def _show(title: str, body: str, tag: str) -> bool {
    api = _api();
    if not api or str(api.permission) != "granted" {
        return False;
    }
    try {
        _ = new(api, title, {"body": body, "tag": tag, "silent": True});
        return True;
    } except Exception {
        return False;
    }
}
