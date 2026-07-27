"""The application shell.

Holds the two things that must persist across every route: the header, and the
neural field behind it.

The field lives here rather than on individual pages so its breathing cycles
are continuous -- remounting it per navigation would restart every animation
and turn ambient texture into a visible flicker. Pages that want to fire a
reactivation pulse dispatch a `neuro-pulse` window event, which is the one
piece of cross-route state worth a bus rather than prop-drilling through the
router.
"""

import from "@jac/runtime" { Outlet, Link, useLocation }
import from react { useEffect }
import from ..reinforce.NeuralField { NeuralField }


def:pub Shell() -> JsxLayout {
    has pulseKey: int = 0;

    location = useLocation();
    on_event_screen = "/calendar/" in location.pathname;

    # Single manual effect so the listener and its removal share one closure.
    useEffect(lambda {
        handler = lambda (e: any) { pulseKey = pulseKey + 1; };
        window.addEventListener("neuro-pulse", handler);
        return lambda { window.removeEventListener("neuro-pulse", handler); };
    }, []);

    return <div className="relative min-h-screen">
        <NeuralField active={on_event_screen} pulseKey={pulseKey} />

        <header className="sticky top-0 z-30 border-b border-border/50 bg-background/70 backdrop-blur-xl">
            <div className="mx-auto flex h-16 max-w-2xl items-center justify-between px-5">
                <Link
                    to="/calendar"
                    className="text-sm font-semibold tracking-tight transition-opacity hover:opacity-70"
                >
                    {"neurotech_"}
                </Link>
                <nav aria-label="Main">
                    <Link
                        to="/calendar"
                        className={
                            "text-sm transition-colors "
                            + ("text-foreground" if location.pathname.startswith("/calendar")
                               else "text-muted-foreground hover:text-foreground")
                        }
                    >
                        {"Calendar"}
                    </Link>
                </nav>
            </div>
        </header>

        <main className="mx-auto max-w-2xl px-5 pb-24 pt-8">
            <Outlet />
        </main>
    </div>;
}
