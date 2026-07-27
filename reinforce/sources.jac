"""Where events come from: the demo generator and the Google Calendar importer.

Both produce `RawEvent`s and hand them to `upsert_events`, which is the only
thing that touches the graph. Adding a third source (Outlook, an .ics upload)
means writing one function that returns `list[RawEvent]` -- nothing else in the
feature changes.

**Google access is read-only.** The requested scope is
`calendar.events.readonly`; this feature never writes to anyone's calendar.

Configure a real connection with three environment variables:

    GOOGLE_CLIENT_ID=...
    GOOGLE_CLIENT_SECRET=...
    GOOGLE_REDIRECT_URI=http://localhost:8000/oauth/google/callback

Without them the Connect button falls back to the demo source, so the whole
flow -- intention, priming, reminders, reflection -- is exercisable before any
credentials exist.
"""

import json;
import os;
import from urllib.parse { urlencode }
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError, URLError }

import from reinforce.clock { now_utc, to_iso, shift, now_iso, parse_iso }
import from reinforce.store {
    ConnectionView, EventView, RawEvent, CalendarLink,
    Links, upsert_events
}


glob GOOGLE_AUTH_ENDPOINT: str = "https://accounts.google.com/o/oauth2/v2/auth";
glob GOOGLE_TOKEN_ENDPOINT: str = "https://oauth2.googleapis.com/token";
glob GOOGLE_EVENTS_ENDPOINT: str =
    "https://www.googleapis.com/calendar/v3/calendars/primary/events";
glob GOOGLE_SCOPE: str = "https://www.googleapis.com/auth/calendar.events.readonly";


# ─── Credentials ─────────────────────────────────────────────────────────────

obj GoogleCredentials {
    has client_id: str,
        client_secret: str,
        redirect_uri: str;
}


"""Read Google OAuth credentials from the environment.

Returns None when they are not configured, which is the signal every caller
uses to fall back to the demo source rather than failing.
"""
def _credentials -> GoogleCredentials | None {
    client_id = os.environ.get("GOOGLE_CLIENT_ID", "");
    client_secret = os.environ.get("GOOGLE_CLIENT_SECRET", "");
    redirect_uri = os.environ.get(
        "GOOGLE_REDIRECT_URI", "http://localhost:8000/oauth/google/callback"
    );
    if not client_id or not client_secret {
        return None;
    }
    return GoogleCredentials(
        client_id=client_id, client_secret=client_secret, redirect_uri=redirect_uri
    );
}


def google_configured -> bool {
    return _credentials() is not None;
}


# ─── The demo source ─────────────────────────────────────────────────────────

"""Sample events positioned relative to *now*.

Timed so that every state in the feature is reachable the moment someone opens
the app: one event inside its priming window, one already running, one that has
just ended (so the reflection prompt appears), plus a few genuinely upcoming
ones and an all-day entry.
"""
def _demo_events -> list[RawEvent] {
    base = now_utc();
    return [
        RawEvent(
            source_id="demo-standup",
            title="Design Review",
            starts_at=to_iso(shift(base, 8.0)),
            ends_at=to_iso(shift(base, 53.0)),
            location="Studio B",
            calendar_name="Work"
        ),
        RawEvent(
            source_id="demo-inprogress",
            title="Deep Work Block",
            starts_at=to_iso(shift(base, -25.0)),
            ends_at=to_iso(shift(base, 65.0)),
            location="Library, 3rd floor",
            calendar_name="Personal"
        ),
        RawEvent(
            source_id="demo-justended",
            title="Coffee with Priya",
            starts_at=to_iso(shift(base, -80.0)),
            ends_at=to_iso(shift(base, -20.0)),
            location="Blue Bottle",
            calendar_name="Personal"
        ),
        RawEvent(
            source_id="demo-mixer",
            title="AI Founders Mixer",
            starts_at=to_iso(shift(base, 1710.0)),
            ends_at=to_iso(shift(base, 1890.0)),
            location="Mission Bay Pavilion",
            calendar_name="Work"
        ),
        RawEvent(
            source_id="demo-mentor",
            title="1:1 with Mentor",
            starts_at=to_iso(shift(base, 2880.0)),
            ends_at=to_iso(shift(base, 2910.0)),
            location="Zoom",
            calendar_name="Work"
        ),
        RawEvent(
            source_id="demo-demoday",
            title="Hackathon Demo Day",
            starts_at=to_iso(shift(base, 4320.0)),
            ends_at=to_iso(shift(base, 4440.0)),
            location="Main Auditorium",
            calendar_name="Work"
        ),
        RawEvent(
            source_id="demo-retreat",
            title="Team Offsite",
            starts_at=to_iso(shift(base, 7200.0)),
            ends_at=to_iso(shift(base, 8640.0)),
            location="Point Reyes",
            calendar_name="Work",
            all_day=True
        )
    ];
}


# ─── Google import ───────────────────────────────────────────────────────────

"""Build the Google consent URL.

`access_type=offline` + `prompt=consent` are what cause Google to return a
refresh token, without which the connection would silently stop working after
about an hour.
"""
def google_auth_url -> str {
    creds = _credentials();
    if creds is None {
        return "";
    }
    params = {
        "client_id": creds.client_id,
        "redirect_uri": creds.redirect_uri,
        "response_type": "code",
        "scope": GOOGLE_SCOPE,
        "access_type": "offline",
        "include_granted_scopes": "true",
        "prompt": "consent"
    };
    return GOOGLE_AUTH_ENDPOINT + "?" + urlencode(params);
}


"""POST to Google and decode the JSON reply.

Network and HTTP failures come back as None; no caller should crash a page
render because Google is having a bad minute.
"""
def _post_form(url: str, fields: dict[str, str]) -> dict[str, any] | None {
    body = urlencode(fields).encode("utf-8");
    request = Request(url, data=body, method="POST");
    request.add_header("Content-Type", "application/x-www-form-urlencoded");
    return _send(request);
}


def _get_json(url: str, token: str) -> dict[str, any] | None {
    request = Request(url, method="GET");
    request.add_header("Authorization", "Bearer " + token);
    return _send(request);
}


"""Execute a prepared request and decode its JSON body.

Every failure mode -- HTTP error, unreachable host, malformed body -- collapses
to None. Google being unavailable degrades one screen to stale data; it never
raises through a page render.
"""
def _send(request: any) -> dict[str, any] | None {
    response = None;
    try {
        response = urlopen(request, timeout=20);
        return json.loads(response.read().decode("utf-8"));
    } except HTTPError {
        return None;
    } except URLError {
        return None;
    } except ValueError {
        return None;
    } finally {
        if response is not None {
            response.close();
        }
    }
}


"""Store or refresh the OAuth material on the caller's CalendarLink."""
def _save_tokens(payload: dict[str, any], account_label: str) -> None {
    found = [root-->[?:CalendarLink]];
    link = found[0] if found else (
        root +>: Links() :+> CalendarLink(connected_at=now_iso())
    ) as CalendarLink;

    link.provider = "google";
    if account_label {
        link.account_label = account_label;
    }
    link.access_token = str(payload.get("access_token", ""));
    # Google omits refresh_token on a re-consent; keeping the stored one is
    # what prevents a refresh from silently un-connecting the account.
    fresh_refresh = str(payload.get("refresh_token", ""));
    if fresh_refresh {
        link.refresh_token = fresh_refresh;
    }
    expires_in = payload.get("expires_in", 0);
    if expires_in {
        link.token_expires_at = to_iso(shift(now_utc(), float(expires_in) / 60.0 - 2.0));
    }
}


"""Return a usable access token, refreshing it first if it has expired.

Returns "" when the account is not connected or the refresh fails, which the
caller surfaces as "reconnect your calendar" rather than an error.
"""
def _access_token -> str {
    found = [root-->[?:CalendarLink]];
    if not found {
        return "";
    }
    link = found[0];
    if link.provider != "google" {
        return "";
    }

    expiry = parse_iso(link.token_expires_at);
    still_valid = link.access_token and (expiry is None or expiry > now_utc());
    if still_valid {
        return link.access_token;
    }

    creds = _credentials();
    if creds is None or not link.refresh_token {
        return "";
    }
    payload = _post_form(GOOGLE_TOKEN_ENDPOINT, {
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "refresh_token": link.refresh_token,
        "grant_type": "refresh_token"
    });
    if payload is None {
        return "";
    }
    _save_tokens(payload, "");
    return str(payload.get("access_token", ""));
}


"""Turn one Google API event into a RawEvent.

Google reports a timed event as `{"dateTime": ...}` and an all-day event as
`{"date": ...}`; the latter has no time component, so it is normalized to a
midnight-to-midnight span. Cancelled entries and anything without a start are
dropped by returning None.
"""
def _to_raw_event(item: dict[str, any]) -> RawEvent | None {
    if str(item.get("status", "")) == "cancelled" {
        return None;
    }
    start = item.get("start", {});
    end = item.get("end", {});
    if not start {
        return None;
    }

    all_day = bool(start.get("date"));
    starts_at: str = "";
    ends_at: str = "";
    if all_day {
        starts_at = str(start.get("date", "")) + "T00:00:00+00:00";
        ends_at = str(end.get("date", start.get("date", ""))) + "T00:00:00+00:00";
    } else {
        starts_at = str(start.get("dateTime", ""));
        ends_at = str(end.get("dateTime", starts_at));
    }
    if not starts_at {
        return None;
    }

    return RawEvent(
        source_id=str(item.get("id", "")),
        title=str(item.get("summary", "")) or "Untitled event",
        starts_at=starts_at,
        ends_at=ends_at,
        location=str(item.get("location", "")),
        calendar_name="Google",
        all_day=all_day
    );
}


"""Fetch upcoming events from Google, newest window first.

`singleEvents=true` is what expands a recurring series into its individual
occurrences -- without it a weekly standup arrives as one master entry and the
user could only ever prepare for the series, not for Thursday.
"""
def _fetch_google_events -> list[RawEvent] | None {
    token = _access_token();
    if not token {
        return None;
    }
    params = {
        "timeMin": to_iso(shift(now_utc(), -1440.0)),
        "timeMax": to_iso(shift(now_utc(), 20160.0)),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": "50"
    };
    payload = _get_json(GOOGLE_EVENTS_ENDPOINT + "?" + urlencode(params), token);
    if payload is None {
        return None;
    }

    rows: list[RawEvent] = [];
    for item in payload.get("items", []) {
        converted = _to_raw_event(item);
        if converted is not None {
            rows.append(converted);
        }
    }
    return rows;
}


# ─── Endpoints ───────────────────────────────────────────────────────────────

def _connection_view -> ConnectionView {
    found = [root-->[?:CalendarLink]];
    if not found {
        return ConnectionView(
            connected=False, provider="", account_label="",
            last_synced_at="", google_configured=google_configured()
        );
    }
    link = found[0];
    return ConnectionView(
        connected=True,
        provider=link.provider,
        account_label=link.account_label,
        last_synced_at=link.last_synced_at,
        google_configured=google_configured()
    );
}


def get_connection -> ConnectionView {
    return _connection_view();
}


"""Connect the built-in demo source and import its events.

This is what the Connect button calls when Google credentials are not
configured. It is deliberately a real connection -- it writes a CalendarLink
and real CalEvent nodes -- so every downstream screen behaves identically to
the Google path.
"""
def connect_demo -> ConnectionView {
    upsert_events(_demo_events(), "demo", "Demo calendar");
    return _connection_view();
}


"""Exchange an OAuth authorization code for tokens and do the first import.

Called by the `/oauth/google/callback` route after the user grants consent.
"""
def complete_google_connect(code: str) -> ConnectionView {
    creds = _credentials();
    if creds is None or not code {
        return _connection_view();
    }
    payload = _post_form(GOOGLE_TOKEN_ENDPOINT, {
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": creds.redirect_uri
    });
    if payload is None {
        return _connection_view();
    }
    _save_tokens(payload, "Google Calendar");

    rows = _fetch_google_events();
    if rows is not None {
        upsert_events(rows, "google", "Google Calendar");
    }
    return _connection_view();
}


"""Re-import events from whichever source is connected.

Safe to call on every page load: `upsert_events` matches on the provider's own
id, so nothing duplicates and existing preparations survive. A Google fetch
that fails leaves the previously imported events in place rather than wiping
the list -- offline should look like stale data, not an empty calendar.
"""
def sync_events -> list[EventView] {
    found = [root-->[?:CalendarLink]];
    if not found {
        return [];
    }
    link = found[0];

    if link.provider == "google" {
        rows = _fetch_google_events();
        if rows is None {
            return [];
        }
        return upsert_events(rows, "google", link.account_label or "Google Calendar");
    }

    return upsert_events(_demo_events(), "demo", link.account_label or "Demo calendar");
}
