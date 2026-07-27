"""The ambient neural background.

A fixed, non-interactive layer of faint nodes and connecting pathways that sit
behind every screen. At rest the nodes breathe on staggered cycles, slowly
enough to read as texture rather than motion.

When a reminder fires, `pulseKey` is bumped and a single signal travels along
one pathway -- the symbolic gesture the brief asks for: an intention being
reactivated, not a diagram of one. It is one pathway, once, and then the field
returns to rest.

The geometry is a fixed table rather than random, so the field is identical on
every render and across reloads. A background that reshuffles itself would be
the exact distraction this screen is trying not to be.
"""

obj FieldNode {
    has x: float,
        y: float,
        r: float,
        delay: float;
}


glob FIELD_NODES: list[FieldNode] = [
    FieldNode(x=90.0, y=120.0, r=3.5, delay=0.0),
    FieldNode(x=215.0, y=64.0, r=2.5, delay=1.2),
    FieldNode(x=196.0, y=232.0, r=4.0, delay=2.4),
    FieldNode(x=330.0, y=158.0, r=2.8, delay=0.6),
    FieldNode(x=308.0, y=340.0, r=3.2, delay=3.0),
    FieldNode(x=452.0, y=96.0, r=3.0, delay=1.8),
    FieldNode(x=470.0, y=268.0, r=4.4, delay=0.3),
    FieldNode(x=588.0, y=190.0, r=2.6, delay=2.7),
    FieldNode(x=610.0, y=386.0, r=3.4, delay=1.5),
    FieldNode(x=724.0, y=112.0, r=3.8, delay=3.6),
    FieldNode(x=742.0, y=296.0, r=2.4, delay=0.9),
    FieldNode(x=856.0, y=204.0, r=3.6, delay=2.1),
    FieldNode(x=880.0, y=438.0, r=2.9, delay=4.2),
    FieldNode(x=402.0, y=470.0, r=3.1, delay=3.3),
    FieldNode(x=148.0, y=412.0, r=2.7, delay=1.1),
    FieldNode(x=676.0, y=520.0, r=3.3, delay=2.9)
];


# Index pairs into FIELD_NODES. Sparse on purpose: a fully-connected mesh reads
# as a net, and a net is busy.
glob FIELD_EDGES: list[list[int]] = [
    [0, 1], [0, 2], [1, 3], [2, 3], [2, 4], [3, 5], [3, 6], [4, 6],
    [5, 7], [6, 7], [6, 8], [7, 9], [8, 10], [9, 11], [10, 11], [10, 12],
    [4, 13], [8, 13], [2, 14], [12, 15], [13, 15]
];


# The pathway the reactivation signal travels: a legible left-to-right run
# across the middle of the field, rather than an arbitrary hop.
glob PULSE_PATH: list[int] = [0, 2, 4, 6, 8, 11];


def _path_points -> str {
    parts: list[str] = [];
    for index in PULSE_PATH {
        spot = FIELD_NODES[index];
        parts.append(str(spot.x) + "," + str(spot.y));
    }
    return " ".join(parts);
}


"""Render the field.

`active` lifts the whole layer's opacity slightly -- used on the event screens,
where the field is thematically present rather than merely decorative.
`pulseKey` triggers one traversal each time its value changes; a value of 0
means "never pulsed".
"""
def:pub NeuralField(active: bool = False, pulseKey: int = 0) -> JsxElement {
    layer_opacity = "0.55" if active else "0.32";

    return <div
        className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
        aria-hidden="true"
    >
        <svg
            className="h-full w-full transition-opacity duration-1000"
            viewBox="0 0 1000 600"
            preserveAspectRatio="xMidYMid slice"
            style={{"opacity": layer_opacity}}
        >
            {for (i, pair) in enumerate(FIELD_EDGES) {
                <line
                    key={"edge-" + str(i)}
                    x1={FIELD_NODES[pair[0]].x}
                    y1={FIELD_NODES[pair[0]].y}
                    x2={FIELD_NODES[pair[1]].x}
                    y2={FIELD_NODES[pair[1]].y}
                    stroke="currentColor"
                    strokeWidth="0.6"
                    className="text-muted-foreground/25"
                />
            }}

            {for (i, spot) in enumerate(FIELD_NODES) {
                <circle
                    key={"node-" + str(i)}
                    cx={spot.x}
                    cy={spot.y}
                    r={spot.r}
                    fill="currentColor"
                    className="animate-breathe text-muted-foreground/60"
                    style={{"animationDelay": str(spot.delay) + "s"}}
                />
            }}

            {if pulseKey > 0 {
                # Keyed on pulseKey so React remounts the element and the
                # one-shot animation restarts from its beginning.
                <polyline
                    key={"pulse-" + str(pulseKey)}
                    points={_path_points()}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinecap="round"
                    className="animate-travel text-primary"
                    style={{"strokeDasharray": "26 100"}}
                />
            }}
        </svg>
    </div>;
}
