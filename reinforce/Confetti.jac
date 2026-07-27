"""A very small confetti burst.

Twelve pieces, one short drift upward, then gone. The brief is explicit that
this must not read as celebration -- there are no points, streaks, or XP behind
it, and a big animation would imply there were.

Geometry is a fixed table for the same reason the neural field is: identical
every time, so it reads as a considered acknowledgement rather than a slot
machine.
"""

obj Fleck {
    has dx: float,
        dy: float,
        delay: float,
        size: float,
        tone: str;
}


glob FLECKS: list[Fleck] = [
    Fleck(dx=-46.0, dy=-30.0, delay=0.00, size=5.0, tone="bg-primary"),
    Fleck(dx=-30.0, dy=-44.0, delay=0.04, size=4.0, tone="bg-primary/70"),
    Fleck(dx=-14.0, dy=-52.0, delay=0.02, size=6.0, tone="bg-primary"),
    Fleck(dx=2.0, dy=-56.0, delay=0.06, size=4.5, tone="bg-chart-1"),
    Fleck(dx=18.0, dy=-50.0, delay=0.01, size=5.5, tone="bg-primary/80"),
    Fleck(dx=34.0, dy=-42.0, delay=0.05, size=4.0, tone="bg-primary"),
    Fleck(dx=48.0, dy=-28.0, delay=0.03, size=5.0, tone="bg-chart-1/80"),
    Fleck(dx=-38.0, dy=-16.0, delay=0.07, size=3.5, tone="bg-primary/60"),
    Fleck(dx=40.0, dy=-14.0, delay=0.02, size=3.5, tone="bg-primary/60"),
    Fleck(dx=-8.0, dy=-38.0, delay=0.08, size=4.0, tone="bg-chart-1"),
    Fleck(dx=12.0, dy=-34.0, delay=0.05, size=4.5, tone="bg-primary/80"),
    Fleck(dx=-22.0, dy=-24.0, delay=0.03, size=3.5, tone="bg-primary")
];


"""Render one burst.

`burstKey` doubles as the React key at the call site, so a new value remounts
the component and replays the animation. Rendering with `burstKey == 0` shows
nothing.
"""
def:pub Confetti(burstKey: int = 0) -> JsxElement {
    if burstKey == 0 {
        return <span aria-hidden="true" />;
    }

    return <span
        className="pointer-events-none absolute left-1/2 top-1/2 h-0 w-0"
        aria-hidden="true"
    >
        {for (i, fleck) in enumerate(FLECKS) {
            <span
                key={"fleck-" + str(burstKey) + "-" + str(i)}
                className={"animate-drift absolute block rounded-full " + fleck.tone}
                style={{
                    "width": str(fleck.size) + "px",
                    "height": str(fleck.size) + "px",
                    "--dx": str(fleck.dx) + "px",
                    "--dy": str(fleck.dy) + "px",
                    "animationDelay": str(fleck.delay) + "s"
                }}
            />
        }}
    </span>;
}
