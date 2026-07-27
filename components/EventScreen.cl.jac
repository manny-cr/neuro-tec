"""One event, inside the phone: commit, prime, reinforce, reflect.

This is the calendar's detail view. It is a *screen*, not a route -- the tab
shell swaps it in over the calendar and hands back an `onBack`, so the phone
frame and its tab bar never go away.

**How the reminder engine avoids stale state.** A `setInterval` closure
captures the render that created it, so an engine that both keeps time and
decides what is due inside one interval goes stale within a minute. The work
is split instead:

  - one interval does nothing but increment `tick`, a heartbeat;
  - the *render body* recomputes the due slot as a pure function of the
    current schedule and the answered slots, so it is always fresh;
  - one effect keyed on that computed value fires the notification exactly
    when it changes.

Everything meaningful is derived, not accumulated -- which is why closing the
tab mid-event loses nothing. Reopening recomputes the same schedule and reads
the answered slots back from the graph.
"""

import from react { useEffect }

import from .BigConfetti { BigConfetti }
import from ..reinforce.timefmt {
    countdown_label, time_label, date_label, duration_label, has_ended, now_ms
}
import from ..reinforce.schedule {
    reminder_slots, due_slot, in_priming_window, remaining_slots
}
import from ..reinforce.notify {
    permission_state, request_permission, fire_reminder, fire_reflection
}

sv import from ..reinforce.api {
    EventView, IntentionPreset, get_event, list_intentions, list_pings,
    set_intention, set_interval, mark_primed, record_ping, record_reflection
}


glob REFLECTIONS: list[list[str]] = [
    ["yes", "Yes, I did"],
    ["partly", "Partly"],
    ["no", "Not this time"]
];

glob INTERVALS: list[list[str]] = [
    ["5", "5 min"], ["10", "10 min"], ["15", "15 min"],
    ["30", "30 min"], ["60", "1 hour"]
];


def:pub EventScreen(
    eventId: str,
    onBack: Callable[[], None]
) -> JsxElement {
    has event: EventView | None = None;
    has presets: list[IntentionPreset] = [];
    has answered: list[str] = [];
    has loading: bool = True;

    # Heartbeat. Its only job is to re-render so time-derived values move.
    has tick: int = 0;

    has bannerState: str = "";        # "" | "asking" | "affirmed" | "deferred"
    has activeSlot: str = "";
    has burstKey: int = 0;

    has primingOpen: bool = False;
    has primingDismissed: bool = False;
    has reflectionNotified: bool = False;
    has permission: str = "default";

    async can with entry {
        if not eventId {
            loading = False;
            return;
        }
        loaded = await get_event(eventId);
        event = loaded;
        presets = await list_intentions();
        rows = await list_pings(eventId);
        answered = [str(row["scheduled_for"]) for row in rows];
        permission = permission_state();
        loading = False;
    }

    # Ten seconds: fine enough that a reminder never feels late, coarse enough
    # to be invisible.
    useEffect(lambda {
        ticker = setInterval(lambda { tick = tick + 1; }, 10000);
        return lambda { clearInterval(ticker); };
    }, []);

    # ── Derived, every render ───────────────────────────────────────────────
    slots: list[str] = [];
    due = "";
    ended = False;
    priming_due = False;
    remaining = 0;

    if event is not None {
        ended = has_ended(event.ends_at);
        if event.intention_key {
            slots = reminder_slots(
                event.starts_at, event.ends_at, event.interval_minutes
            );
            remaining = remaining_slots(slots, now_ms());
            # Reminders stop at the event's end, permanently. Without this the
            # last unanswered slot stays due forever, and opening a finished
            # event would ask whether you are still following an intention for
            # an experience you already left.
            if not ended {
                due = due_slot(slots, answered, now_ms());
            }
            priming_due = (
                not event.primed
                and not primingDismissed
                and in_priming_window(event.starts_at, now_ms())
            );
        }
    }

    # ── Effects keyed on derived values ─────────────────────────────────────

    useEffect(lambda {
        if due and due != activeSlot and not bannerState {
            activeSlot = due;
            bannerState = "asking";
            fire_reminder("reinforce-" + due);
            browser: any = window;
            browser.dispatchEvent(new(browser.CustomEvent, "neuro-pulse", {}));
        }
    }, [due]);

    useEffect(lambda {
        if priming_due and not primingOpen {
            primingOpen = True;
        }
    }, [priming_due]);

    useEffect(lambda {
        if ended and event is not None and event.intention_key
            and not event.reflection and not reflectionNotified {
            reflectionNotified = True;
            fire_reflection("reflect-" + event.id);
        }
    }, [ended]);

    # ── Handlers ────────────────────────────────────────────────────────────

    async def choose_intention(key: str) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await set_intention(current.id, key);
        if updated is not None {
            event = updated;
        }
    }

    async def choose_interval(minutes: int) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await set_interval(current.id, minutes);
        if updated is not None {
            event = updated;
        }
    }

    async def respond(response: str) -> None {
        current = event;
        slot = activeSlot;
        if current is None or not slot {
            return;
        }
        # Optimistic: the slot is answered locally before the round trip, so a
        # slow network cannot re-raise the same reminder.
        answered = answered + [slot];
        bannerState = "affirmed" if response == "yes" else "deferred";
        if response == "yes" {
            burstKey = burstKey + 1;
            # The acknowledgement clears itself. Long enough for the confetti
            # to land before the banner goes.
            setTimeout(lambda { bannerState = ""; activeSlot = ""; }, 4200);
        }
        updated = await record_ping(current.id, slot, response);
        if updated is not None {
            event = updated;
        }
    }

    async def reflect(rating: str) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await record_reflection(current.id, rating);
        if updated is not None {
            event = updated;
        }
    }

    async def confirm_primed -> None {
        current = event;
        primingOpen = False;
        if current is None {
            return;
        }
        updated = await mark_primed(current.id);
        if updated is not None {
            event = updated;
        }
    }

    async def ask_permission(_e: MouseEvent) -> None {
        result = await request_permission();
        permission = result;
    }

    def skip_priming(_e: MouseEvent) {
        primingOpen = False;
        primingDismissed = True;
    }

    def dismiss_banner(_e: MouseEvent) {
        bannerState = "";
        activeSlot = "";
    }

    def answer_yes(_e: MouseEvent) {
        respond("yes");
    }

    def answer_not_yet(_e: MouseEvent) {
        respond("not_yet");
    }

    def back(_e: MouseEvent) {
        onBack();
    }

    # ── Render ──────────────────────────────────────────────────────────────

    if loading {
        return <div className="scroll event-screen" aria-busy="true">
            <div className="ev-skel-title"></div>
            <div className="ev-skel-card"></div>
        </div>;
    }

    if event is None {
        return <div className="scroll event-screen">
            <button className="ev-back" onClick={back}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"
                    strokeLinejoin="round">
                    <polyline points="15 18 9 12 15 6"/>
                </svg>
                Calendar
            </button>
            <p className="empty-inline">That event is no longer available.</p>
        </div>;
    }

    # Resolved to plain strings rather than kept as an optional: `is not None`
    # narrowing does not carry into a JSX slot body.
    chosen_title = "";
    chosen_rehearsal = "";
    for preset in presets {
        if preset.key == event.intention_key {
            chosen_title = preset.title;
            chosen_rehearsal = preset.rehearsal;
        }
    }

    meta = date_label(event.starts_at);
    if not event.all_day {
        meta = meta + " · " + time_label(event.starts_at);
    }
    if duration_label(event.duration_minutes) {
        meta = meta + " · " + duration_label(event.duration_minutes);
    }
    if event.location {
        meta = meta + " · " + event.location;
    }

    return <div className="scroll event-screen">
        <button className="ev-back" onClick={back}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"
                strokeLinejoin="round">
                <polyline points="15 18 9 12 15 6"/>
            </svg>
            Calendar
        </button>

        <header className="ev-head">
            <h1 className="ev-title">{event.title}</h1>
            <p className="ev-count" aria-live="polite">
                {countdown_label(event.starts_at, event.ends_at)}
            </p>
            <p className="ev-meta">{meta}</p>
        </header>

        {#* ── The reminder, when one is live ──────────────────────────── *#}
        {if bannerState and not ended {
            <div key="banner" className={"ev-banner " + bannerState}>
                {if bannerState == "asking" {
                    <div key="ask" className="ev-ask">
                        <h3>Stay on track?</h3>
                        <p>Are we still following today's intention?</p>
                        {if chosen_title {
                            <p key="ct" className="ev-ask-intent">{chosen_title}</p>
                        }}
                        <div className="ev-ask-btns">
                            <button className="primary-btn" onClick={answer_yes}>YES</button>
                            <button className="ghost-btn" onClick={answer_not_yet}>NOT YET</button>
                        </div>
                    </div>
                }}

                {if bannerState == "affirmed" {
                    <div key="aff" className="ev-affirmed">
                        <p className="ev-affirmed-big">Yes!</p>
                        <p className="ev-affirmed-sub">
                            Small moments become lasting habits.
                        </p>
                    </div>
                }}

                {if bannerState == "deferred" {
                    <div key="def" className="ev-deferred">
                        <p className="ev-deferred-big">You're still in the experience.</p>
                        <p>There's time. Take the next opportunity.</p>
                        <button className="ghost-btn wide-quiet" onClick={dismiss_banner}>
                            Dismiss
                        </button>
                    </div>
                }}
            </div>
        }}

        {#* ── Reflection, once it is over ─────────────────────────────── *#}
        {if ended and event.intention_key {
            <section key="reflect" className="ev-section">
                <h2 className="section-label">How did it go?</h2>
                <div className="ev-reflect">
                    {for row in REFLECTIONS {
                        <ReflectButton
                            key={row[0]}
                            value={row[0]}
                            label={row[1]}
                            chosen={event.reflection == row[0]}
                            onChoose={reflect}
                        />
                    }}
                </div>
            </section>
        }}

        {#* ── Today's Intention ───────────────────────────────────────── *#}
        {if not ended {
            <section key="intent" className="ev-section">
                <h2 className="section-label">Today's intention</h2>
                <p className="ev-section-sub">
                    Choose one behavior to reinforce during this experience.
                </p>
                <div className="ev-intents">
                    {for preset in presets {
                        <IntentButton
                            key={preset.key}
                            intentionKey={preset.key}
                            title={preset.title}
                            subtitle={preset.subtitle}
                            selected={event.intention_key == preset.key}
                            onSelect={choose_intention}
                        />
                    }}
                </div>
            </section>
        }}

        {#* ── Cadence, only once something is committed ───────────────── *#}
        {if event.intention_key and not ended {
            <section key="cadence" className="ev-section bordered">
                <h2 className="section-label">Reminder frequency</h2>
                <p className="ev-section-sub">
                    Reminders run only while the event is happening, then stop.
                </p>
                <div className="ev-intervals">
                    {for row in INTERVALS {
                        <IntervalButton
                            key={row[0]}
                            minutes={int(row[0])}
                            label={row[1]}
                            selected={event.interval_minutes == int(row[0])}
                            onSelect={choose_interval}
                        />
                    }}
                </div>

                {if remaining > 0 {
                    <p key="rem" className="ev-remaining">
                        {str(remaining) + (" reminder ahead" if remaining == 1
                                           else " reminders ahead")}
                    </p>
                }}

                {if permission == "default" {
                    <button key="perm" className="text-btn sm" onClick={ask_permission}>
                        Enable notifications
                    </button>
                }}

                {if permission == "denied" {
                    <p key="denied" className="ev-note">
                        {"Notifications are blocked in this browser. Reminders still "
                         + "appear here while the app is open."}
                    </p>
                }}
            </section>
        }}

        {#* ── The pre-event rehearsal ─────────────────────────────────── *#}
        {if primingOpen and chosen_title {
            <div key="priming" className="ev-priming">
                <div className="ev-priming-card">
                    <p className="ev-priming-kicker">
                        {countdown_label(event.starts_at, event.ends_at)}
                    </p>
                    <h2>{chosen_title}</h2>
                    <p className="ev-priming-rehearse">{chosen_rehearsal}</p>
                    <button className="primary-btn" onClick={confirm_primed}>
                        I'm ready
                    </button>
                    <button className="text-btn sm" onClick={skip_priming}>
                        Not now
                    </button>
                </div>
            </div>
        }}

        {#* Mounted last so it paints over everything, including the banner. *#}
        <BigConfetti burstKey={burstKey}/>
    </div>;
}


"""One intention option. Own component so the tap closes over its key."""
def:pub IntentButton(
    intentionKey: str,
    title: str,
    subtitle: str,
    selected: bool,
    onSelect: Callable[[str], None]
) -> JsxElement {
    def tap(_e: MouseEvent) {
        onSelect(intentionKey);
    }

    return <button className={"ev-intent on" if selected else "ev-intent"} onClick={tap}>
        <span className="ev-intent-mark" aria-hidden="true"></span>
        <span className="ev-intent-body">
            <span className="ev-intent-title">{title}</span>
            <span className="ev-intent-sub">{subtitle}</span>
        </span>
    </button>;
}


def:pub IntervalButton(
    minutes: int,
    label: str,
    selected: bool,
    onSelect: Callable[[int], None]
) -> JsxElement {
    def tap(_e: MouseEvent) {
        onSelect(minutes);
    }

    return <button className={"ev-chip on" if selected else "ev-chip"} onClick={tap}>
        {label}
    </button>;
}


def:pub ReflectButton(
    value: str,
    label: str,
    chosen: bool,
    onChoose: Callable[[str], None]
) -> JsxElement {
    def tap(_e: MouseEvent) {
        onChoose(value);
    }

    return <button className={"ev-reflect-btn on" if chosen else "ev-reflect-btn"} onClick={tap}>
        {label}
    </button>;
}
