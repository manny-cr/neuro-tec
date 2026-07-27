"""The event preparation screen -- the core of the feature.

One page carries the whole arc for a single event:

  1. **Commit**   choose one of five intentions, and a reminder cadence.
  2. **Prime**    in the ten minutes before the start, rehearse it once.
  3. **Reinforce** during the event, answer a reminder on the chosen cadence.
  4. **Reflect**  once it ends, one tap, three options, done.

**How the reminder engine avoids stale state.** A `setInterval` closure captures
the state of the render that created it, so an engine that both keeps time and
decides what is due inside one interval goes stale within a minute. The work is
split instead:

  - one interval does nothing but increment `tick`, a heartbeat;
  - the *render body* recomputes the due slot as a pure function of the current
    schedule and the answered slots, so it is always fresh;
  - one effect keyed on that computed value fires the notification exactly when
    it changes.

Everything meaningful is therefore derived, not accumulated -- which is also
why closing the tab mid-event loses nothing. Reopening recomputes the same
schedule and reads the answered slots back from the graph.
"""

import from "@jac/runtime" { useParams, useNavigate, Link }
import from react { useEffect }

import from ...reinforce.IntentionCard { IntentionCard }
import from ...reinforce.ReminderPicker { ReminderPicker }
import from ...reinforce.NotificationBanner { NotificationBanner }
import from ...reinforce.ReflectionCard { ReflectionCard }
import from ...reinforce.PrimingOverlay { PrimingOverlay }
import from ...reinforce.timefmt {
    countdown_label, time_label, date_label, duration_label, has_ended, now_ms
}
import from ...reinforce.schedule {
    reminder_slots, due_slot, in_priming_window, remaining_slots
}
import from ...reinforce.notify {
    permission_state, request_permission, fire_reminder, fire_reflection
}

sv import from ...reinforce.api {
    EventView, IntentionPreset, get_event, list_intentions, list_pings,
    set_intention, set_interval, mark_primed, record_ping, record_reflection
}


def:pub EventPreparationPage() -> JsxPage {
    has event: EventView | None = None;
    has presets: list[IntentionPreset] = [];
    has answered: list[str] = [];
    has loading: bool = True;

    # Heartbeat. Its only job is to re-render so time-derived values move.
    has tick: int = 0;

    has bannerState: str = "";                 # "" | "asking" | "affirmed" | "deferred"
    has activeSlot: str = "";
    has burstKey: int = 0;

    has primingOpen: bool = False;
    has primingDismissed: bool = False;
    has reflectionNotified: bool = False;
    has permission: str = "default";

    params = useParams();
    # useParams values are untyped and come back as JS `undefined` when the
    # segment is absent, so normalize to a real str once, here.
    event_id = str(params["id"] or "");
    nav = useNavigate();

    async can with entry {
        if not event_id {
            loading = False;
            return;
        }
        loaded = await get_event(event_id);
        event = loaded;
        presets = await list_intentions();
        rows = await list_pings(event_id);
        answered = [str(row["scheduled_for"]) for row in rows];
        permission = permission_state();
        loading = False;
    }

    # The heartbeat. Ten seconds is fine-grained enough that a reminder never
    # feels late, and coarse enough to be invisible.
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
            # Reminders stop at the event's end, permanently. Without this
            # guard the last unanswered slot stays "due" forever, and opening
            # a finished event would ask whether you are still following an
            # intention for an experience you already left.
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

    # A reminder comes due: raise the banner, nudge the OS, pulse one pathway.
    useEffect(lambda {
        if due and due != activeSlot and not bannerState {
            activeSlot = due;
            bannerState = "asking";
            fire_reminder("reinforce-" + due);
            # Untyped hop: browser globals carry no stubs in `jac check`.
            browser: any = window;
            browser.dispatchEvent(new(browser.CustomEvent, "neuro-pulse", {}));
        }
    }, [due]);

    useEffect(lambda {
        if priming_due and not primingOpen {
            primingOpen = True;
        }
    }, [priming_due]);

    # One reflection notification, when the event ends.
    useEffect(lambda {
        if ended and event is not None and event.intention_key
            and not event.reflection and not reflectionNotified {
            reflectionNotified = True;
            fire_reflection("reflect-" + event.id);
        }
    }, [ended]);

    # ── Handlers ────────────────────────────────────────────────────────────

    async def handle_intention(key: str) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await set_intention(current.id, key);
        if updated is not None {
            event = updated;
        }
    }

    async def handle_interval(minutes: int) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await set_interval(current.id, minutes);
        if updated is not None {
            event = updated;
        }
    }

    async def handle_respond(response: str) -> None {
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
            # The acknowledgement clears itself. Nothing to dismiss, nothing
            # to accumulate.
            setTimeout(lambda { bannerState = ""; activeSlot = ""; }, 2800);
        }
        updated = await record_ping(current.id, slot, response);
        if updated is not None {
            event = updated;
        }
    }

    def handle_dismiss() {
        bannerState = "";
        activeSlot = "";
    }

    async def handle_primed -> None {
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

    def handle_skip_priming() {
        primingOpen = False;
        primingDismissed = True;
    }

    async def handle_reflection(rating: str) -> None {
        current = event;
        if current is None {
            return;
        }
        updated = await record_reflection(current.id, rating);
        if updated is not None {
            event = updated;
        }
    }

    async def handle_permission -> None {
        result = await request_permission();
        permission = result;
    }

    def go_back(e: MouseEvent) {
        nav("/calendar");
    }

    # ── Render ──────────────────────────────────────────────────────────────

    if loading {
        return <div className="space-y-6 pt-6" aria-busy="true">
            <div className="h-10 w-2/3 animate-pulse rounded-xl bg-card/40" />
            <div className="h-40 animate-pulse rounded-2xl bg-card/30" />
        </div>;
    }

    if event is None {
        return <div className="space-y-4 pt-10 text-center">
            <p className="text-base font-medium">{"That event is no longer available."}</p>
            <Link
                to="/calendar"
                className="inline-block text-sm text-primary transition-opacity hover:opacity-70"
            >
                {"Back to calendar"}
            </Link>
        </div>;
    }

    # Resolved to plain strings rather than kept as an optional object:
    # `is not None` narrowing does not carry into a JSX slot body, so the
    # optional would fail type-checking at every use site below.
    chosen_title = "";
    chosen_rehearsal = "";
    for preset in presets {
        if preset.key == event.intention_key {
            chosen_title = preset.title;
            chosen_rehearsal = preset.rehearsal;
        }
    }

    return <div className="space-y-10">

        <button
            type="button"
            onClick={go_back}
            className="-ml-1 flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
            <svg
                viewBox="0 0 24 24" fill="none" stroke="currentColor"
                strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
                className="h-4 w-4"
            >
                <polyline points="15 18 9 12 15 6" />
            </svg>
            {"Calendar"}
        </button>

        {#* ── The event itself ────────────────────────────────────────── *#}
        <header className="animate-rise space-y-4">
            <h1 className="text-balance text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
                {event.title}
            </h1>

            <p className="tabular text-lg font-medium text-primary" aria-live="polite">
                {countdown_label(event.starts_at, event.ends_at)}
            </p>

            <div className="flex flex-wrap items-center gap-x-3 gap-y-1.5 text-sm text-muted-foreground">
                <span>{date_label(event.starts_at)}</span>
                {if not event.all_day {
                    <span key="time">{"· " + time_label(event.starts_at)}</span>
                }}
                {if duration_label(event.duration_minutes) {
                    <span key="dur">{"· " + duration_label(event.duration_minutes)}</span>
                }}
                {if event.location {
                    <span key="loc">{"· " + event.location}</span>
                }}
            </div>
        </header>

        {#* ── The reminder, when one is live ──────────────────────────── *#}
        {#* An in-flight reminder is also retired the moment the event ends,
            so a banner open at the closing minute does not outlive it. *#}
        {if bannerState and not ended {
            <div className="sticky top-20 z-40">
                <NotificationBanner
                    state={bannerState}
                    intentionTitle={chosen_title}
                    burstKey={burstKey}
                    onRespond={handle_respond}
                    onDismiss={handle_dismiss}
                />
            </div>
        }}

        {#* ── Reflection, once it is over ─────────────────────────────── *#}
        {if ended and event.intention_key {
            <ReflectionCard chosen={event.reflection} onChoose={handle_reflection} />
        }}

        {#* ── Today's Intention ───────────────────────────────────────── *#}
        {if not ended {
            <section className="space-y-5">
                <div className="space-y-1.5">
                    <h2 className="text-xl font-semibold tracking-tight">
                        {"Today's Intention"}
                    </h2>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                        {"Choose one behavior you want to reinforce during this experience."}
                    </p>
                </div>

                <div className="space-y-3">
                    {for preset in presets {
                        <IntentionCard
                            key={preset.key}
                            intentionKey={preset.key}
                            title={preset.title}
                            subtitle={preset.subtitle}
                            selected={event.intention_key == preset.key}
                            onSelect={handle_intention}
                        />
                    }}
                </div>
            </section>
        }}

        {#* ── Cadence + permission, only once something is committed ──── *#}
        {if event.intention_key and not ended {
            <section className="space-y-5 border-t border-border/50 pt-8">
                <div className="space-y-1.5">
                    <h2 className="text-xl font-semibold tracking-tight">
                        {"Reminder Frequency"}
                    </h2>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                        {"Reminders run only while the event is happening, then stop."}
                    </p>
                </div>

                <ReminderPicker
                    intervalMinutes={event.interval_minutes}
                    onChange={handle_interval}
                />

                {if remaining > 0 {
                    <p className="tabular text-xs text-muted-foreground/70">
                        {str(remaining) + (" reminder ahead" if remaining == 1 else " reminders ahead")}
                    </p>
                }}

                {if permission == "default" {
                    <button
                        type="button"
                        onClick={handle_permission}
                        className={
                            "flex h-10 items-center rounded-full border border-border px-4 text-xs "
                            + "font-medium text-muted-foreground transition-colors "
                            + "hover:border-muted-foreground/50 hover:text-foreground"
                        }
                    >
                        {"Enable notifications"}
                    </button>
                }}

                {if permission == "denied" {
                    <p className="text-xs leading-relaxed text-muted-foreground/70">
                        {"Notifications are blocked in this browser. Reminders will still "}
                        {"appear here while the app is open."}
                    </p>
                }}
            </section>
        }}

        {#* ── The pre-event rehearsal ─────────────────────────────────── *#}
        {if primingOpen and chosen_title {
            <PrimingOverlay
                intentionTitle={chosen_title}
                rehearsal={chosen_rehearsal}
                startsInLabel={countdown_label(event.starts_at, event.ends_at)}
                onComplete={handle_primed}
                onSkip={handle_skip_priming}
            />
        }}
    </div>;
}
