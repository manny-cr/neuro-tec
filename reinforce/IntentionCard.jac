"""One selectable preset intention.

Selection is the only place orange appears on this screen, and it appears three
ways at once -- outline, glow, checkmark -- because the commitment is the
single most important piece of state in the feature and should be unmistakable
at a glance.

Rendered as a real `<button>` with `aria-pressed`, so the five cards announce
themselves as a toggle group to a screen reader rather than as decorative divs.
"""

def:pub IntentionCard(
    intentionKey: str,
    title: str,
    subtitle: str,
    selected: bool,
    onSelect: Callable[[str], None],
    disabled: bool = False
) -> JsxElement {

    def handle_select(e: MouseEvent) {
        if not disabled {
            onSelect(intentionKey);
        }
    }

    shell = "group relative w-full rounded-2xl border p-5 text-left "
        + "transition-all duration-300 ease-out focus-visible:outline-none "
        + "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 "
        + "focus-visible:ring-offset-background";

    if disabled {
        shell = shell + " cursor-not-allowed border-border/50 bg-card/40 opacity-50";
    } elif selected {
        shell = shell + " animate-glow border-primary bg-primary/[0.07] shadow-lg shadow-primary/10";
    } else {
        shell = shell + " border-border bg-card/60 hover:border-muted-foreground/40 hover:bg-card";
    }

    return <button
        type="button"
        onClick={handle_select}
        disabled={disabled}
        aria-pressed={selected}
        className={shell}
    >
        <div className="flex items-start justify-between gap-4">
            <div className="flex-1 space-y-1.5">
                <h3 className={
                    "text-lg font-semibold leading-snug transition-colors duration-300 "
                    + ("text-primary" if selected else "text-foreground")
                }>
                    {title}
                </h3>
                <p className="text-sm leading-relaxed text-muted-foreground">
                    {subtitle}
                </p>
            </div>

            <span className={
                "mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full "
                + "border transition-all duration-300 "
                + ("border-primary bg-primary text-primary-foreground scale-100"
                   if selected else "border-border/70 bg-transparent scale-90")
            }>
                {if selected {
                    <svg
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="3"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="h-3.5 w-3.5 animate-settle"
                    >
                        <polyline points="20 6 9 17 4 12" />
                    </svg>
                }}
            </span>
        </div>
    </button>;
}
