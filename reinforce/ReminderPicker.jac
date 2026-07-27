"""Reminder cadence: five presets plus a custom interval.

Rendered as a radio group rather than a set of buttons, because that is what it
is -- one cadence at a time -- and screen readers should hear it that way.

Choosing "Custom" reveals a number field. The committed value is clamped
server-side; this component clamps too, so the input cannot display a value the
server would silently reject.
"""

glob PRESETS: list[int] = [5, 10, 15, 30, 60];


def _preset_label(minutes: int) -> str {
    if minutes < 60 {
        return "Every " + str(minutes) + " min";
    }
    return "Every hour";
}


def:pub ReminderPicker(
    intervalMinutes: int,
    onChange: Callable[[int], None],
    disabled: bool = False
) -> JsxElement {

    has customOpen: bool = False;
    has customText: str = "";

    is_preset = intervalMinutes in PRESETS;
    # A stored value that is not one of the presets can only have come from a
    # custom entry, so the custom field opens already reflecting it.
    show_custom = customOpen or not is_preset;

    def choose_preset(minutes: int) {
        if disabled {
            return;
        }
        customOpen = False;
        onChange(minutes);
    }

    def open_custom(e: MouseEvent) {
        if disabled {
            return;
        }
        customOpen = True;
        customText = str(intervalMinutes);
    }

    def commit_custom(e: ChangeEvent) {
        customText = e.target.value;
        parsed = int(e.target.value or "0");
        if parsed > 0 {
            onChange(max(1, min(720, parsed)));
        }
    }

    return <div className="space-y-3">
        <div
            role="radiogroup"
            aria-label="Reminder frequency"
            className="flex flex-wrap gap-2"
        >
            {for minutes in PRESETS {
                <button
                    key={"preset-" + str(minutes)}
                    type="button"
                    role="radio"
                    aria-checked={intervalMinutes == minutes and not show_custom}
                    disabled={disabled}
                    onClick={lambda (e: MouseEvent) { choose_preset(minutes); }}
                    className={
                        "h-10 rounded-full border px-4 text-sm font-medium transition-all duration-200 "
                        + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
                        + "disabled:cursor-not-allowed disabled:opacity-40 "
                        + ("border-primary bg-primary/10 text-primary"
                           if (intervalMinutes == minutes and not show_custom)
                           else "border-border bg-card/50 text-muted-foreground hover:border-muted-foreground/50 hover:text-foreground")
                    }
                >
                    {_preset_label(minutes)}
                </button>
            }}

            <button
                type="button"
                role="radio"
                aria-checked={show_custom}
                disabled={disabled}
                onClick={open_custom}
                className={
                    "h-10 rounded-full border px-4 text-sm font-medium transition-all duration-200 "
                    + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
                    + "disabled:cursor-not-allowed disabled:opacity-40 "
                    + ("border-primary bg-primary/10 text-primary" if show_custom
                       else "border-border bg-card/50 text-muted-foreground hover:border-muted-foreground/50 hover:text-foreground")
                }
            >
                {"Custom"}
            </button>
        </div>

        {if show_custom {
            <div className="animate-settle flex items-center gap-3 pt-1">
                <label htmlFor="custom-interval" className="text-sm text-muted-foreground">
                    {"Every"}
                </label>
                <input
                    id="custom-interval"
                    type="number"
                    min="1"
                    max="720"
                    inputMode="numeric"
                    disabled={disabled}
                    value={customText if customText else str(intervalMinutes)}
                    onChange={commit_custom}
                    className={
                        "tabular h-10 w-24 rounded-xl border border-border bg-card/60 px-3 "
                        + "text-sm text-foreground focus-visible:outline-none "
                        + "focus-visible:ring-2 focus-visible:ring-ring"
                    }
                />
                <span className="text-sm text-muted-foreground">{"minutes"}</span>
            </div>
        }}
    </div>;
}
