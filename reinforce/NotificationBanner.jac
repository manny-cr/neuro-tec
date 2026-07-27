"""The in-app reminder, and the two responses to it.

This is where the actual answer is given -- the OS notification is only a nudge
to come back (see `notify.jac` for why the buttons cannot live there).

Three states:

  - **asking**   the reminder itself: "Are we still following today's intention?"
  - **affirmed** after YES: a small confetti burst and one sentence. No points,
                 no streak, no score. The acknowledgement is deliberately
                 smaller than the action.
  - **deferred** after NOT YET: no red, no warning icon, no guilt. It restates
                 that the experience is still happening and there is time.

Both answers lead somewhere calm. That symmetry is the point: a user who
answers honestly should never feel worse for having done so.
"""

import from .Confetti { Confetti }


def:pub NotificationBanner(
    state: str,
    intentionTitle: str,
    burstKey: int,
    onRespond: Callable[[str], None],
    onDismiss: Callable[[], None]
) -> JsxElement {

    def answer_yes(e: MouseEvent) {
        onRespond("yes");
    }

    def answer_not_yet(e: MouseEvent) {
        onRespond("not_yet");
    }

    def dismiss(e: MouseEvent) {
        onDismiss();
    }

    shell = "animate-rise pointer-events-auto relative w-full overflow-hidden rounded-2xl "
        + "border bg-popover/95 p-5 shadow-2xl backdrop-blur-xl ";

    if state == "affirmed" {
        shell = shell + "border-primary/40";
    } else {
        shell = shell + "border-border";
    }

    return <div role="status" aria-live="polite" className={shell}>

        {if state == "asking" {
            <div className="space-y-4">
                <div className="space-y-1.5">
                    <h3 className="text-lg font-semibold tracking-tight">
                        {"Stay on track?"}
                    </h3>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                        {"Are we still following today's intention?"}
                    </p>
                    {if intentionTitle {
                        <p className="pt-0.5 text-sm font-medium text-primary">
                            {intentionTitle}
                        </p>
                    }}
                </div>

                <div className="flex gap-2.5">
                    <button
                        type="button"
                        onClick={answer_yes}
                        className={
                            "h-11 flex-1 rounded-full bg-primary text-sm font-semibold "
                            + "text-primary-foreground transition-all duration-200 hover:brightness-110 "
                            + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                        }
                    >
                        {"YES"}
                    </button>
                    <button
                        type="button"
                        onClick={answer_not_yet}
                        className={
                            "h-11 flex-1 rounded-full border border-border bg-transparent text-sm "
                            + "font-semibold text-muted-foreground transition-all duration-200 "
                            + "hover:border-muted-foreground/50 hover:text-foreground "
                            + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                        }
                    >
                        {"NOT YET"}
                    </button>
                </div>
            </div>
        }}

        {if state == "affirmed" {
            <div className="relative space-y-1.5 py-1 text-center">
                <Confetti burstKey={burstKey} />
                <p className="text-base font-medium text-foreground">{"Great."}</p>
                <p className="text-sm text-muted-foreground">
                    {"Small moments become lasting habits."}
                </p>
            </div>
        }}

        {if state == "deferred" {
            <div className="space-y-4">
                <div className="space-y-1.5">
                    <p className="text-base font-medium text-foreground">
                        {"You're still in the experience."}
                    </p>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                        {"There's time. Take the next opportunity."}
                    </p>
                </div>
                <button
                    type="button"
                    onClick={dismiss}
                    className={
                        "h-10 w-full rounded-full border border-border text-sm font-medium "
                        + "text-muted-foreground transition-all duration-200 "
                        + "hover:border-muted-foreground/50 hover:text-foreground "
                        + "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    }
                >
                    {"Dismiss"}
                </button>
            </div>
        }}
    </div>;
}
