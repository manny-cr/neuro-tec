"""The recalling brain: the background of the survey.

The ambient field elsewhere in the app breathes once and rests. This one does
not rest -- while the survey is open, signals travel continuously along the
pathways, because the user is doing the thing the animation depicts: pulling a
memory back up. The message is the one the product is built on. You are a
scientist, and the instrument is your own brain.

Three things run at once, on deliberately unequal periods so the field never
visibly loops:

  - **nodes** breathe on staggered cycles;
  - **pathways** carry a travelling highlight, one per path, offset;
  - **the core** glows on a slow swell, the recall itself.

Geometry is a fixed table rather than random. A background that reshuffles on
every render is the exact distraction this screen is trying not to be, and a
fixed table also means the paths can be authored to read as a network rather
than as a scatter of line segments.

Purely decorative: `aria-hidden`, no pointer events, and it holds still for
anyone who has asked for reduced motion.
"""

obj Cell {
    has x: float,
        y: float,
        r: float,
        delay: float;
}


# A rough two-hemisphere arrangement in a 400x520 field: denser toward the
# middle, sparser at the edges, so it reads as a brain rather than a grid.
glob CELLS: list[Cell] = [
    Cell(x=200.0, y=250.0, r=6.0, delay=0.0),

    Cell(x=132.0, y=150.0, r=3.4, delay=0.7),
    Cell(x=104.0, y=246.0, r=4.2, delay=1.9),
    Cell(x=140.0, y=344.0, r=3.0, delay=2.6),
    Cell(x=196.0, y=118.0, r=3.8, delay=1.2),
    Cell(x=188.0, y=390.0, r=3.6, delay=0.4),
    Cell(x=262.0, y=152.0, r=3.2, delay=2.2),
    Cell(x=296.0, y=248.0, r=4.4, delay=1.5),
    Cell(x=258.0, y=346.0, r=3.4, delay=3.0),

    Cell(x=60.0, y=96.0, r=2.4, delay=2.8),
    Cell(x=44.0, y=310.0, r=2.8, delay=1.1),
    Cell(x=96.0, y=430.0, r=2.6, delay=3.4),
    Cell(x=206.0, y=52.0, r=2.6, delay=0.9),
    Cell(x=248.0, y=452.0, r=3.0, delay=2.0),
    Cell(x=340.0, y=110.0, r=2.8, delay=1.7),
    Cell(x=356.0, y=318.0, r=3.2, delay=0.5),
    Cell(x=308.0, y=424.0, r=2.4, delay=2.5),
    Cell(x=372.0, y=214.0, r=2.6, delay=3.2)
];


# Index pairs. Sparse on purpose: a fully-connected mesh reads as a net.
glob WIRES: list[list[int]] = [
    [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [0, 8],
    [1, 4], [1, 2], [2, 3], [3, 5], [4, 6], [6, 7], [7, 8], [5, 8],
    [1, 9], [2, 10], [3, 11], [4, 12], [5, 13], [6, 14], [7, 15],
    [8, 16], [15, 17], [14, 17]
];


"""Pathways a signal runs along, as index runs through CELLS.

Authored rather than generated: each one crosses the core, so every pulse
reads as something being routed *through* the middle instead of skirting it.
"""
glob PATHS: list[list[int]] = [
    [9, 1, 0, 7, 15],
    [11, 3, 0, 6, 14],
    [10, 2, 0, 8, 16],
    [12, 4, 0, 5, 13]
];


def _points_of(path: list[int]) -> str {
    parts: list[str] = [];
    for index in path {
        spot = CELLS[index];
        parts.append(str(spot.x) + "," + str(spot.y));
    }
    return " ".join(parts);
}


"""Render the field.

`preserveAspectRatio` is `slice`, so the field always fills the screen. `meet`
letterboxes the network into the middle -- exactly where the survey card sits
-- which hides the whole thing. Slicing crops the outermost cells instead and
keeps live pathways in the margins above and below the card, which is where
they are actually visible.
"""
def:pub RecallField -> JsxElement {
    return <svg
        className="recall-field"
        viewBox="0 0 400 520"
        preserveAspectRatio="xMidYMid slice"
        aria-hidden="true"
        focusable="false"
    >
        <defs>
            <radialGradient id="recall-core">
                <stop offset="0%" stopColor="#5b8cff" stopOpacity="0.75"/>
                <stop offset="55%" stopColor="#5b8cff" stopOpacity="0.2"/>
                <stop offset="100%" stopColor="#5b8cff" stopOpacity="0"/>
            </radialGradient>
        </defs>

        {#* The recall itself: a slow swell behind everything. *#}
        <circle className="recall-core" cx="200" cy="250" r="185" fill="url(#recall-core)"/>

        {#* Resting wires. *#}
        <g className="recall-wires">
            {for (i, pair) in enumerate(WIRES) {
                <line
                    key={"w" + str(i)}
                    x1={CELLS[pair[0]].x} y1={CELLS[pair[0]].y}
                    x2={CELLS[pair[1]].x} y2={CELLS[pair[1]].y}
                />
            }}
        </g>

        {#* Travelling signals. One dash chases along each path forever, each
            on its own period so the four never sync into a single beat. *#}
        <g className="recall-signals">
            {for (i, path) in enumerate(PATHS) {
                <polyline
                    key={"p" + str(i)}
                    className="recall-signal"
                    points={_points_of(path)}
                    style={{
                        "animationDuration": str(2.6 + i * 0.55) + "s",
                        "animationDelay": str(i * 0.42) + "s"
                    }}
                />
            }}
        </g>

        {#* Cell bodies. *#}
        <g className="recall-cells">
            {for (i, cell) in enumerate(CELLS) {
                <circle
                    key={"c" + str(i)}
                    cx={cell.x} cy={cell.y} r={cell.r}
                    style={{"animationDelay": str(cell.delay) + "s"}}
                />
            }}
        </g>
    </svg>;
}
