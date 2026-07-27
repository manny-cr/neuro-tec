"""The onboarding state, shown when no calendar is connected yet.

This is the first thing a new user sees, so it states the purpose of the
feature in one line rather than describing the mechanics of OAuth.

When real Google credentials are configured the button starts the consent
flow. When they are not, it connects the built-in demo calendar instead and
says so plainly -- an honest fallback is better than a Connect button that
fails silently.
"""

def:pub CalendarConnectionCard(
    googleConfigured: bool,
    busy: bool,
    onConnect: Callable[[], None]
) -> JsxElement {

    def handle_connect(e: MouseEvent) {
        if not busy {
            onConnect();
        }
    }

    label = "Connect Google Calendar" if googleConfigured else "Use the demo calendar";

    return <section className="animate-rise rounded-3xl border border-border bg-card/60 p-8 sm:p-10">
        <div className="mx-auto max-w-md space-y-6 text-center">

            <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full border border-primary/30 text-primary">
                <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.4"
                    strokeLinecap="round"
                    className="h-6 w-6"
                >
                    <rect x="3" y="5" width="18" height="16" rx="3" />
                    <line x1="3" y1="10" x2="21" y2="10" />
                    <line x1="8" y1="3" x2="8" y2="7" />
                    <line x1="16" y1="3" x2="16" y2="7" />
                </svg>
            </span>

            <h2 className="text-balance text-2xl font-semibold leading-snug tracking-tight sm:text-3xl">
                {"Connect your calendar to prepare your mind before meaningful experiences."}
            </h2>

            <p className="text-sm leading-relaxed text-muted-foreground">
                {"Read-only access. Your events are never modified, and nothing is shared."}
            </p>

            <button
                type="button"
                onClick={handle_connect}
                disabled={busy}
                className={
                    "mx-auto flex h-12 items-center justify-center rounded-full px-8 "
                    + "text-sm font-semibold transition-all duration-300 "
                    + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
                    + "focus-visible:ring-offset-2 focus-visible:ring-offset-background "
                    + ("cursor-wait bg-primary/60 text-primary-foreground" if busy
                       else "bg-primary text-primary-foreground hover:brightness-110")
                }
            >
                {"Connecting…" if busy else label}
            </button>

            {if not googleConfigured {
                <p className="text-xs leading-relaxed text-muted-foreground/70">
                    {"Google credentials aren't configured on this server, so the demo "}
                    {"calendar will be used. Every part of the experience works the same way."}
                </p>
            }}
        </div>
    </section>;
}
