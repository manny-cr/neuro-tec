"""The post-event survey: three sliders, one tap, done.

Frictionless by construction. Every slider opens at its midpoint, so the
survey is already answerable -- submitting without touching anything is a
valid, meaningful response (a flat middle reading), not an empty form. There
is no validation, no required field, and no second page.

The live word under each slider is the actual feedback: the number is never
shown, because a person reporting how an evening felt is not thinking in
percentages, and showing "63" invites them to fiddle toward a number instead
of answering.

Behind it, `RecallField` pulses continuously -- the user is recalling, and the
background says so.
"""

import from .RecallField { RecallField }


obj Axis {
    has key: str,
        prompt: str,
        low: str,
        high: str,
        words: list[str];
}


# Five words per axis, one per 20 points. Chosen so the midpoint word is
# genuinely neutral rather than mildly negative -- a midpoint that reads as a
# complaint biases every untouched slider.
glob AXES: list[Axis] = [
    Axis(
        key="comfort",
        prompt="How comfortable did you feel?",
        low="Uneasy",
        high="At ease",
        words=["Very uneasy", "A little tense", "Neutral", "Comfortable", "Completely at ease"]
    ),
    Axis(
        key="mood",
        prompt="How did it leave you feeling?",
        low="Drained",
        high="Energized",
        words=["Drained", "A bit flat", "Even", "Lifted", "Energized"]
    ),
    Axis(
        key="presence",
        prompt="How present were you?",
        low="Distracted",
        high="Fully there",
        words=["Elsewhere", "In and out", "Mostly with it", "Engaged", "Fully there"]
    )
];


"""The word for a 0-100 reading."""
def:pub word_for(axis: Axis, value: int) -> str {
    index = value // 20;
    if index > 4 {
        index = 4;
    }
    return axis.words[index];
}


def:pub SurveyOverlay(
    eventTitle: str,
    busy: bool,
    onSubmit: Callable[[int, int, int], None],
    onSkip: Callable[[], None]
) -> JsxElement {
    # Midpoints. See the module docstring: an untouched survey is still a
    # legitimate answer, so these are defaults rather than placeholders.
    has comfort: int = 50,
        mood: int = 50,
        presence: int = 50,
        sent: bool = False;

    def onComfort(e: any) {
        comfort = int(e.target.value);
    }

    def onMood(e: any) {
        mood = int(e.target.value);
    }

    def onPresence(e: any) {
        presence = int(e.target.value);
    }

    def submit(_e: MouseEvent) {
        # Guarded because the button stays mounted through the round trip: a
        # double tap would otherwise write the survey twice.
        if not sent {
            sent = True;
            onSubmit(comfort, mood, presence);
        }
    }

    def skip(_e: MouseEvent) {
        onSkip();
    }

    return <div className="survey" role="dialog" aria-label="Post-event survey">
        <RecallField/>

        <div className="survey-body">
            <header className="survey-head">
                <p className="survey-kicker">That's a wrap</p>
                <h2 className="survey-title">{eventTitle}</h2>
                <p className="survey-lede">
                    {"Three sliders. However it actually felt -- there is no "
                     + "right answer here."}
                </p>
            </header>

            <SurveySlider
                axis={AXES[0]}
                value={comfort}
                onInput={onComfort}
            />
            <SurveySlider
                axis={AXES[1]}
                value={mood}
                onInput={onMood}
            />
            <SurveySlider
                axis={AXES[2]}
                value={presence}
                onInput={onPresence}
            />

            <button className="primary-btn" onClick={submit} disabled={busy or sent}>
                {"Saving…" if busy else "Done"}
            </button>
            <button className="text-btn sm survey-skip" onClick={skip} disabled={busy}>
                Not now
            </button>
        </div>
    </div>;
}


def:pub SurveySlider(
    axis: Axis,
    value: int,
    onInput: Callable[[any], None]
) -> JsxElement {
    # The filled portion is painted with a gradient driven by this, rather
    # than by a second element, so the track stays one box at any width.
    pct = str(value) + "%";

    return <div className="survey-axis">
        <label className="survey-prompt" htmlFor={"sl-" + axis.key}>
            {axis.prompt}
        </label>

        <input
            id={"sl-" + axis.key}
            className="survey-range"
            type="range"
            min="0"
            max="100"
            step="1"
            value={str(value)}
            onChange={onInput}
            style={{"--fill": pct}}
            aria-valuetext={word_for(axis, value)}
        />

        <div className="survey-scale">
            <span>{axis.low}</span>
            <span className="survey-word" aria-live="polite">{word_for(axis, value)}</span>
            <span>{axis.high}</span>
        </div>
    </div>;
}
