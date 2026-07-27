"""When reminders fire.

The schedule is *derived*, never stored. Given an event's window and the chosen
interval, the slot times are a pure function -- so a reload, a second tab, or a
server restart all reconstruct exactly the same slots, and a stored `ReminderPing`
matches back to its slot by timestamp. Nothing can drift out of sync because
there is only one copy of the truth.

The hard rule from the brief lives here: **reminders exist only inside the
event.** The first fires as the event begins, the last strictly before it ends,
and nothing fires outside that window under any interval.
"""

import from .timefmt { to_ms }

# A rehearsal offered ~10 minutes ahead, which is the span the brief calls
# for: close enough that the event is imminent, far enough to be calm.
glob PRIMING_LEAD_MINUTES: float = 10.0;

# Ceiling on generated slots. A 1-minute interval across an all-day event
# would otherwise produce a thousand of them; past this many the schedule
# has stopped being a reminder and become a metronome.
glob MAX_SLOTS: int = 240;


"""Every reminder instant for an event, as ISO-8601 UTC strings.

Empty when the event has no valid window -- an all-day event with no real
duration gets no reminders rather than one per minute for 24 hours.
"""
def:pub reminder_slots(starts_at: str, ends_at: str, interval_minutes: int) -> list[str] {
    start_ms = to_ms(starts_at);
    end_ms = to_ms(ends_at);
    if start_ms == 0.0 or end_ms <= start_ms or interval_minutes <= 0 {
        return [];
    }

    step = (interval_minutes as float) * 60000.0;
    slots: list[str] = [];
    cursor = start_ms;
    # Strictly `<` end: a reminder at the closing second asks about an
    # experience the user has already left.
    while cursor < end_ms and len(slots) < MAX_SLOTS {
        slots.append(new(Date, cursor).toISOString() as str);
        cursor = cursor + step;
    }
    return slots;
}


"""The slot that is currently due, or "" if none is.

A slot is due once its time has passed and it has not been answered. Only
the *most recent* due slot is returned: someone who closes the laptop for
an hour should come back to one question, not twelve stacked up.
"""
def:pub due_slot(slots: list[str], answered: list[str], now: float) -> str {
    pending = "";
    for slot in slots {
        if to_ms(slot) <= now and slot not in answered {
            pending = slot;
        }
    }
    return pending;
}


"""True while the pre-event rehearsal should be offered.

Opens `PRIMING_LEAD_MINUTES` before the start and closes at the start
itself -- priming is preparation, so once the experience is underway the
moment for it has passed.
"""
def:pub in_priming_window(starts_at: str, now: float) -> bool {
    start_ms = to_ms(starts_at);
    if start_ms == 0.0 {
        return False;
    }
    lead = PRIMING_LEAD_MINUTES * 60000.0;
    return now >= (start_ms - lead) and now < start_ms;
}


"""How many slots remain unfired, for the "N reminders ahead" summary."""
def:pub remaining_slots(slots: list[str], now: float) -> int {
    count = 0;
    for slot in slots {
        if to_ms(slot) > now {
            count += 1;
        }
    }
    return count;
}
