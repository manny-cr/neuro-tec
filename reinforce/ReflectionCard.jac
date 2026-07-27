"""The post-event reflection: one question, three taps, done.

No text box and no journaling prompt, by design. The brief asks for low
friction, and the research this feature draws on is about repeated activation
during the experience -- the reflection is a light closing marker, not the
intervention.

None of the three answers is styled as failure. "Needs improvement" gets the
same neutral treatment as the other two.
"""

obj ReflectionOption {
    has value: str,
        label: str;
}


glob OPTIONS: list[ReflectionOption] = [
    ReflectionOption(value="better", label="Better than expected"),
    ReflectionOption(value="expected", label="About as expected"),
    ReflectionOption(value="needs_work", label="Needs improvement")
];


def:pub ReflectionCard(
    chosen: str,
    onChoose: Callable[[str], None]
) -> JsxElement {

    def pick(value: str) {
        onChoose(value);
    }

    return <section className="animate-rise space-y-5 rounded-2xl border border-border bg-card/60 p-6">
        <div className="space-y-1.5">
            <h2 className="text-xl font-semibold tracking-tight">{"How did today go?"}</h2>
            {if chosen {
                <p className="text-sm text-muted-foreground">
                    {"Thanks for closing the loop."}
                </p>
            }}
        </div>

        <div role="radiogroup" aria-label="How did today go?" className="space-y-2.5">
            {for option in OPTIONS {
                <button
                    key={option.value}
                    type="button"
                    role="radio"
                    aria-checked={chosen == option.value}
                    onClick={lambda (e: MouseEvent) { pick(option.value); }}
                    className={
                        "flex h-12 w-full items-center justify-between rounded-xl border px-4 "
                        + "text-sm font-medium transition-all duration-200 "
                        + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring "
                        + ("border-primary bg-primary/[0.07] text-primary"
                           if chosen == option.value
                           else "border-border bg-transparent text-muted-foreground hover:border-muted-foreground/50 hover:text-foreground")
                    }
                >
                    <span>{option.label}</span>
                    {if chosen == option.value {
                        <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="2.5"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            className="h-4 w-4"
                        >
                            <polyline points="20 6 9 17 4 12" />
                        </svg>
                    }}
                </button>
            }}
        </div>
    </section>;
}
