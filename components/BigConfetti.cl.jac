"""Full-screen confetti for a YES.

Deliberately larger than the original twelve-fleck burst: this fires only when
someone confirms they are living the intention they set, which is the one
moment in the app worth making loud.

Seventy pieces on a fixed table -- identical every time, so it reads as a
considered celebration rather than a slot machine. Pieces fall the height of
the phone screen and fade near the bottom. The overlay never takes pointer
events, so the banner underneath stays tappable mid-burst.

`burstKey` doubles as the React key at the call site: a new value remounts the
component and replays the animation. `0` renders nothing.
"""

obj Piece {
    has left: float,        # % across the screen
        delay: float,       # s
        dur: float,         # s
        drift: float,       # px of horizontal sway
        spin: float,        # deg of rotation
        w: float,
        h: float,
        tone: str;
}


# Six tones drawn from the app's own palette: the steel accent plus the
# category colours, so a burst still looks like this product.
glob TONES: list[str] = [
    "#5b8cff", "#d889b4", "#e8a35c", "#5ecf9a", "#7eb6c9", "#b4a0d8"
];


"""Seventy pieces spread across the width on a deterministic lattice.

The spread is generated rather than hand-tabulated -- at this count a literal
table would be unreadable -- but it is pure arithmetic on the index, so the
output is byte-identical on every run.
"""
def build_pieces -> list[Piece] {
    pieces: list[Piece] = [];
    for i in range(70) {
        # Irrational-ish multipliers keep successive pieces from lining up
        # into visible columns without needing a random source.
        left = ((i * 13.7) % 100.0);
        delay = ((i * 7.0) % 45.0) / 100.0;
        dur = 1.9 + ((i * 11.0) % 90.0) / 100.0;
        drift = -60.0 + ((i * 29.0) % 120.0);
        spin = 180.0 + ((i * 53.0) % 540.0);
        wide = (i % 3) == 0;
        pieces.append(Piece(
            left=left,
            delay=delay,
            dur=dur,
            drift=drift,
            spin=spin,
            w=9.0 if wide else 6.0,
            h=5.0 if wide else 10.0,
            tone=TONES[i % len(TONES)]
        ));
    }
    return pieces;
}


glob PIECES: list[Piece] = build_pieces();


def:pub BigConfetti(burstKey: int = 0) -> JsxElement {
    if burstKey == 0 {
        return <span aria-hidden="true"></span>;
    }

    return <div className="confetti-sky" aria-hidden="true">
        {for (i, p) in enumerate(PIECES) {
            <span
                key={"c-" + str(burstKey) + "-" + str(i)}
                className="confetti-piece"
                style={{
                    "left": str(p.left) + "%",
                    "width": str(p.w) + "px",
                    "height": str(p.h) + "px",
                    "background": p.tone,
                    "animationDelay": str(p.delay) + "s",
                    "animationDuration": str(p.dur) + "s",
                    "--drift": str(p.drift) + "px",
                    "--spin": str(p.spin) + "deg"
                }}
            ></span>
        }}
    </div>;
}
