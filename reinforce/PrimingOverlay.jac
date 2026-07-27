"""The pre-event priming screen.

Shown in the ten minutes before an event starts, once, and only when an
intention has been committed.

Rather than opening with "are we on track?" -- a question about an experience
that has not begun -- it shows the chosen intention and asks the user to
mentally rehearse the behavior for fifteen seconds while a single pathway
lights up. This is the retrieval-and-rehearsal step: activating an intention
shortly before the experience, so the reminders during it are reactivating
something already primed rather than introducing it cold.

The rehearsal cannot be rushed. The confirm button stays disabled until the
fifteen seconds have actually elapsed, because a screen you can tap through
instantly is a screen that trains you to tap through it.
"""

import from react { useEffect }

glob REHEARSAL_SECONDS: int = 15;


def:pub PrimingOverlay(
    intentionTitle: str,
    rehearsal: str,
    startsInLabel: str,
    onComplete: Callable[[], None],
    onSkip: Callable[[], None]
) -> JsxElement {

    has elapsed: int = 0;

    # One manual effect so the interval handle and its cleanup share a closure
    # -- `can with entry` / `can with exit` compile to separate effects and the
    # clear would silently no-op.
    useEffect(lambda {
        ticker = setInterval(lambda { elapsed = elapsed + 1; }, 1000);
        return lambda { clearInterval(ticker); };
    }, []);

    remaining = max(0, REHEARSAL_SECONDS - elapsed);
    ready = remaining == 0;
    progress = min(1.0, (elapsed as float) / (REHEARSAL_SECONDS as float));

    # Circumference of the r=54 ring below, used to drive the sweep.
    circumference = 339.292;
    offset = circumference * (1.0 - progress);

    def confirm(e: MouseEvent) {
        if ready {
            onComplete();
        }
    }

    def skip(e: MouseEvent) {
        onSkip();
    }

    return <div
        role="dialog"
        aria-modal="true"
        aria-label="Prepare for this experience"
        className={
            "fixed inset-0 z-50 flex items-center justify-center bg-background/95 "
            + "p-6 backdrop-blur-md animate-settle"
        }
    >
        <div className="w-full max-w-md space-y-10 text-center">

            <p className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">
                {startsInLabel}
            </p>

            <div className="space-y-3">
                <h2 className="text-balance text-3xl font-semibold leading-tight tracking-tight text-primary sm:text-4xl">
                    {intentionTitle}
                </h2>
                <p className="text-balance text-base leading-relaxed text-muted-foreground">
                    {rehearsal}
                </p>
            </div>

            <div className="relative mx-auto h-40 w-40">
                <svg viewBox="0 0 120 120" className="h-full w-full -rotate-90">
                    <circle
                        cx="60" cy="60" r="54"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        className="text-border"
                    />
                    <circle
                        cx="60" cy="60" r="54"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2.5"
                        strokeLinecap="round"
                        className="text-primary transition-all duration-1000 ease-linear"
                        style={{
                            "strokeDasharray": str(circumference),
                            "strokeDashoffset": str(offset)
                        }}
                    />
                </svg>

                <div className="absolute inset-0 flex items-center justify-center">
                    <span className="h-3 w-3 rounded-full bg-primary animate-breathe" />
                </div>
            </div>

            <p className="text-sm text-muted-foreground" aria-live="polite">
                {"Hold it in mind." if ready else
                 ("Hold it in mind · " + str(remaining) + "s")}
            </p>

            <div className="space-y-3">
                <button
                    type="button"
                    onClick={confirm}
                    disabled={not ready}
                    className={
                        "h-12 w-full rounded-full text-sm font-semibold transition-all duration-500 "
                        + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
                        + ("bg-primary text-primary-foreground hover:brightness-110" if ready
                           else "cursor-not-allowed bg-muted text-muted-foreground")
                    }
                >
                    {"I'm ready"}
                </button>
                <button
                    type="button"
                    onClick={skip}
                    className="h-9 w-full text-xs text-muted-foreground/70 transition-colors hover:text-muted-foreground"
                >
                    {"Not now"}
                </button>
            </div>
        </div>
    </div>;
}
