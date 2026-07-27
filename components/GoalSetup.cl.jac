"""First run: the one question the app opens with.

Shown instead of the tab shell while no goal is set, so a new user's first
screen is a decision rather than an empty brain. There is no skip: the goal
is what every other screen refers back to, and an app that quietly lets you
past it has nothing to put in its header.

Presets are starting points, not a closed list -- picking one fills the field
rather than submitting, so a goal can always be edited into the user's own
words before it is saved.
"""

glob PRESETS: list[str] = [
    "Ship my first real product",
    "Become a stronger public speaker",
    "Learn something new every day",
    "Build a deeper network",
    "Take better care of my mind"
];


def:pub GoalSetup(
    busy: bool,
    onSave: Callable[[str], None]
) -> JsxElement {
    has draft: str = "";

    clean = draft.strip();

    def onType(e: any) {
        draft = e.target.value;
    }

    def save(_e: MouseEvent) {
        if clean {
            onSave(clean);
        }
    }

    # Enter submits. A single-line field that ignores Enter feels broken on a
    # phone, where the keyboard's return key is the obvious way to finish.
    def onKey(e: any) {
        if e.key == "Enter" and clean {
            onSave(clean);
        }
    }

    # Filling the field rather than submitting: a preset is a draft, not a
    # decision, and the user should still be able to reword it.
    def pick(text: str) {
        draft = text;
    }

    return <div className="goal-setup">
        <div className="goal-setup-inner">
            <p className="goal-kicker">Neurotech</p>

            <h1 className="goal-ask">What is your goal?</h1>
            <p className="goal-lede">
                {"One thing you're working toward. Everything else in here "
                 + "points back at it."}
            </p>

            <input
                className="goal-input"
                placeholder="Type your goal"
                value={draft}
                onChange={onType}
                onKeyDown={onKey}
                autoFocus={True}
                aria-label="Your goal"
            />

            <p className="goal-or">or start from one of these</p>

            <div className="goal-presets">
                {for (i, p) in enumerate(PRESETS) {
                    <PresetChip
                        key={"p" + str(i)}
                        text={p}
                        selected={clean == p}
                        onPick={pick}
                    />
                }}
            </div>

            <button
                className="primary-btn"
                onClick={save}
                disabled={busy or not clean}
            >
                {"Saving…" if busy else "Set my goal"}
            </button>
        </div>
    </div>;
}


def:pub PresetChip(
    text: str,
    selected: bool,
    onPick: Callable[[str], None]
) -> JsxElement {
    def tap(_e: MouseEvent) {
        onPick(text);
    }

    return <button className={"goal-chip on" if selected else "goal-chip"} onClick={tap}>
        {text}
    </button>;
}
