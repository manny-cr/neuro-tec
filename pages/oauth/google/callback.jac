"""Google OAuth return leg.

Google redirects here with `?code=...` after the user grants consent. The code
is exchanged for tokens server-side -- it never lives anywhere but a single
request body -- and the first import runs before the user is sent back to the
calendar.

Set `GOOGLE_REDIRECT_URI` to this path (default
`http://localhost:8000/oauth/google/callback`) and register the same value in
the Google Cloud console, or Google refuses the exchange.

The user may also arrive here with `?error=access_denied` by declining consent,
which is a normal outcome and is reported as such rather than as a failure.
"""

import from "@jac/runtime" { useLocation, useNavigate }

sv import from ....reinforce.api { complete_google_connect }


def:pub GoogleCallbackPage() -> JsxPage {
    has message: str = "Connecting your calendar…";
    has failed: bool = False;

    location = useLocation();
    nav = useNavigate();

    async can with entry {
        # Untyped hop: `jac check` ships no stubs for browser constructors, so
        # URLSearchParams and its result are held as `any`.
        browser: any = window;
        params: any = new(browser.URLSearchParams, location.search);
        code = params.get("code");
        denied = params.get("error");

        if denied {
            message = "Calendar access wasn't granted.";
            failed = True;
            return;
        }
        if not code {
            message = "That sign-in link was incomplete.";
            failed = True;
            return;
        }

        result = await complete_google_connect(str(code));
        if result and result.connected {
            nav("/calendar", {"replace": True});
            return;
        }
        message = "We couldn't finish connecting. Please try again.";
        failed = True;
    }

    return <div className="flex min-h-[60vh] flex-col items-center justify-center gap-5 text-center">
        {if not failed {
            <span
                className="h-2.5 w-2.5 rounded-full bg-primary animate-breathe"
                aria-hidden="true"
            />
        }}
        <p className="text-base text-muted-foreground" aria-live="polite">{message}</p>
        {if failed {
            <button
                type="button"
                onClick={lambda (e: MouseEvent) { nav("/calendar", {"replace": True}); }}
                className="h-10 rounded-full border border-border px-5 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
                {"Back to calendar"}
            </button>
        }}
    </div>;
}
