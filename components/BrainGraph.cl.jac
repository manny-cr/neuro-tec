"""The graph view - Obsidian's map, sized for a thumb.

Two node kinds share one canvas: thoughts (small, coloured by category) and
skills (larger, ringed, always labelled). Skill rings double as progress
bars - the arc length is mastery. Edges are quadratic beziers whose opacity
encodes link weight.

Positions arrive precomputed from the server walker; this component owns the
camera. One-finger drag pans (with momentum on release), two-finger pinch and
the trackpad wheel zoom, the +/- controls do the same for anyone who prefers
buttons, and tapping a node frames it with its neighbours. The camera and
gesture bookkeeping live in module `glob`s rather than `has` state - pointer
events and animation frames outrun React re-renders, so reactive reads would
be stale mid-gesture. State only mirrors the camera for rendering.

The viewport aspect is measured from the container rather than assumed, so
the viewBox always matches the element it renders into. Assuming the server's
canvas ratio here letterboxes twice (once in the camera, once again in
`preserveAspectRatio`) and throws away most of the screen.
"""

sv import from endpoints { GraphNode, GraphLink, SkillView }

import from .palette { cat_color, node_radius }

glob WORLD_W: float = 1000.0;
glob MIN_W: float = 320.0;
glob MAX_W: float = 2200.0;

# Labels are drawn at a fixed *screen* size, so they stay readable at every
# zoom instead of shrinking with the world.
glob LABEL_PX: float = 12.0;
glob SKILL_LABEL_PX: float = 13.5;

# Apple's minimum touch target is 44pt; a thought dot renders around 12px at
# fit zoom, so every node carries an invisible circle of at least this radius.
glob HIT_PX: float = 22.0;

# Thought labels would smother the overview, so they appear only once the
# camera is close enough for them to be legible.
glob LABEL_ZOOM_W: float = 700.0;

# Half the average glyph advance, as a fraction of font size. Estimating a
# label's width this way avoids measuring text in the DOM every render.
glob LABEL_EM: float = 0.29;

# Assumed share of the stage hidden by the detail sheet before one exists to
# measure. Keeps the very first selection from landing underneath it.
glob SHEET_FRAC: float = 0.46;

# Camera source of truth (see module docstring). `seen` remembers the node
# count so the auto-fit fires on first data and again after a wipe+reseed.
# `touched` records that the user has driven the camera themselves, which
# stops a resize from yanking the view back to the overview under them.
glob cam: dict[str, float] = {
    "x": 0.0, "y": 0.0, "w": 1000.0, "seen": 0.0, "touched": 0.0
};

# Measured container box: width in CSS px and aspect as height/width. A glob
# for the same reason the camera is one - `fit_camera` runs inside the mount
# effect and needs the value measured moments earlier, not last render's.
glob view: dict[str, float] = {"w": 380.0, "ar": 1.7};

# Non-reactive gesture state.
glob gesture: dict[str, float] = {
    "mode": 0.0,   # 0 idle, 1 pan, 2 pinch
    "x": 0.0, "y": 0.0,
    "id1": -1.0, "id2": -1.0,
    "x2": 0.0, "y2": 0.0,
    "dist": 0.0,
    "moved": 0.0,
    "vx": 0.0, "vy": 0.0   # smoothed px-per-event velocity for momentum
};

# One animation driver for both inertia (mode 1) and glide-to-target (mode 2).
# `token` invalidates any in-flight loop the moment a new gesture starts.
glob motion: dict[str, float] = {
    "token": 0.0, "mode": 0.0, "t": 0.0, "k": 1.0,
    "vx": 0.0, "vy": 0.0,
    "sx": 0.0, "sy": 0.0, "sw": 0.0,
    "tx": 0.0, "ty": 0.0, "tw": 0.0
};

"""Clip a label to something that fits beside a node on a phone."""
def:pub trim(text: str, limit: int) -> str {
    if len(text) <= limit {
        return text;
    }
    return text[:limit].strip() + "...";
}

def:pub GraphNodeMark(
    item: GraphNode,
    index: int,
    mastery: float,
    scale: float,
    labelX: float,
    dim: bool,
    lit: bool,
    labelled: bool,
    onPick: Callable[[str], None]
) -> JsxElement {
    def handle(_e: MouseEvent) {
        onPick(item.id);
    }

    skill = item.kind == "skill";
    color = "#c9d1ff" if skill else cat_color(item.category);
    r = node_radius(item.kind, item.strength);

    # `scale` is world units per screen pixel: multiplying by it pins a
    # measurement to the screen so zoom cannot shrink it away.
    hit = HIT_PX * scale;
    if hit < r {
        hit = r;
    }
    label_px = (SKILL_LABEL_PX if skill else LABEL_PX) * scale;

    klass = "gnode";
    if dim {
        klass = "gnode dim";
    }
    if lit {
        klass = "gnode lit";
    }

    # Staggered spring-in on mount; keys are node ids so data refreshes
    # only replay the animation for genuinely new nodes.
    delay = index * 30;
    if delay > 600 {
        delay = 600;
    }

    # Mastery ring geometry (skills only).
    ring_r = r + 8.0;
    circ = 6.28318 * ring_r;

    return <g className={klass} style={{"animationDelay": str(delay) + "ms"}} onClick={handle}>
        <circle cx={item.x} cy={item.y} r={hit} fill="transparent" pointerEvents="all"/>
        {if lit {
            <circle key="glow" className="gnode-glow" cx={item.x} cy={item.y} r={r * 2.4} fill={color}/>
        }}
        {if skill {
            <circle
                key="ring-track"
                cx={item.x}
                cy={item.y}
                r={ring_r}
                fill="none"
                stroke="#2b2e3d"
                strokeWidth={3.0}
            />
            <circle
                key="ring"
                className="gnode-ring"
                cx={item.x}
                cy={item.y}
                r={ring_r}
                fill="none"
                stroke={color}
                strokeWidth={3.0}
                strokeLinecap="round"
                strokeDasharray={str(circ * mastery) + " " + str(circ)}
                transform={"rotate(-90 " + str(item.x) + " " + str(item.y) + ")"}
            />
        }}
        <circle
            className={"gnode-core skill" if skill else "gnode-core"}
            cx={item.x}
            cy={item.y}
            r={r}
            fill={"#171a2e" if skill else color}
            stroke={color}
            strokeWidth={3.0 if skill else 0.0}
        />
        {if labelled {
            <text
                key="label"
                className={"glabel skill" if skill else "glabel"}
                x={labelX}
                y={item.y + (ring_r if skill else r) + label_px * 1.4}
                textAnchor="middle"
                fill={color}
                style={{
                    "fontSize": str(label_px) + "px",
                    "strokeWidth": str(3.0 * scale) + "px"
                }}
            >
                {trim(item.label, 17 if skill else 22)}
            </text>
        }}
    </g>;
}

"""Quadratic bezier between two nodes, bowed perpendicular to the chord."""
def:pub edge_path(x1: float, y1: float, x2: float, y2: float) -> str {
    dx = x2 - x1;
    dy = y2 - y1;
    d = (dx * dx + dy * dy) ** 0.5;
    if d < 1.0 {
        return "M " + str(x1) + " " + str(y1) + " L " + str(x2) + " " + str(y2);
    }
    mx = (x1 + x2) / 2.0 - dy / d * d * 0.14;
    my = (y1 + y2) / 2.0 + dx / d * d * 0.14;
    return "M " + str(x1) + " " + str(y1)
        + " Q " + str(mx) + " " + str(my)
        + " " + str(x2) + " " + str(y2);
}

def:pub BrainGraph(
    nodes: list[GraphNode],
    links: list[GraphLink],
    skills: list[SkillView],
    hidden: list[str],
    focus: str,
    onPick: Callable[[str], None],
    onClear: Callable[[], None]
) -> JsxElement {
    # Render mirror of the camera glob, plus the measured container box.
    has vx: float = 0.0,
        vy: float = 0.0,
        vw: float = 1000.0,
        cw: float = 380.0,
        car: float = 1.7,
        panning: bool = False;

    def set_cam(x: float, y: float, w: float) -> None {
        cam["x"] = x;
        cam["y"] = y;
        cam["w"] = w;
        vx = x;
        vy = y;
        vw = w;
    }

    """Read the container box so the viewBox can match it exactly.

    Called on mount and again at the start of every interaction rather than
    from a resize listener, which would need teardown this component has no
    hook for. The guards make it a no-op when nothing has actually moved.
    """
    def measure_view() -> None {
        el: any = document.querySelector(".graph-svg");
        if not el {
            return;
        }
        rect = el.getBoundingClientRect();
        w = float(rect.width);
        h = float(rect.height);
        if w < 1.0 or h < 1.0 {
            return;
        }
        view["w"] = w;
        view["ar"] = h / w;
        if w != cw {
            cw = w;
        }
        if view["ar"] != car {
            car = view["ar"];
        }
    }

    """World units per screen pixel at the current zoom."""
    def world_per_px(el: any) -> float {
        rect = el.getBoundingClientRect();
        vh = cam["w"] * view["ar"];
        sx = rect.width / cam["w"];
        sy = rect.height / vh;
        s = sx if sx < sy else sy;
        return 1.0 / s if s > 0 else 1.0;
    }

    """Re-centre a new width around the current view centre, clamped."""
    def apply_zoom(new_w: float) -> None {
        cam["touched"] = 1.0;
        w = new_w;
        if w < MIN_W {
            w = MIN_W;
        }
        if w > MAX_W {
            w = MAX_W;
        }
        cx = cam["x"] + cam["w"] / 2.0;
        cy = cam["y"] + (cam["w"] * view["ar"]) / 2.0;
        set_cam(cx - w / 2.0, cy - (w * view["ar"]) / 2.0, w);
    }

    """The single rAF loop: inertia after a flick, or a glide to a target."""
    def run_motion() -> None {
        token = motion["token"];
        def frame(_ts: any) {
            if motion["token"] != token {
                return;
            }
            if motion["mode"] == 1.0 {
                motion["vx"] = motion["vx"] * 0.9;
                motion["vy"] = motion["vy"] * 0.9;
                set_cam(
                    cam["x"] - motion["vx"] * motion["k"],
                    cam["y"] - motion["vy"] * motion["k"],
                    cam["w"]
                );
                speed = (motion["vx"] if motion["vx"] > 0 else -motion["vx"])
                      + (motion["vy"] if motion["vy"] > 0 else -motion["vy"]);
                if speed > 0.25 {
                    requestAnimationFrame(frame);
                }
            } elif motion["mode"] == 2.0 {
                motion["t"] = motion["t"] + 0.055;
                t = motion["t"];
                if t >= 1.0 {
                    set_cam(motion["tx"], motion["ty"], motion["tw"]);
                    return;
                }
                e = 1.0 - (1.0 - t) ** 3;
                set_cam(
                    motion["sx"] + (motion["tx"] - motion["sx"]) * e,
                    motion["sy"] + (motion["ty"] - motion["sy"]) * e,
                    motion["sw"] + (motion["tw"] - motion["sw"]) * e
                );
                requestAnimationFrame(frame);
            }
        }
        requestAnimationFrame(frame);
    }

    def stop_motion() -> None {
        motion["token"] = motion["token"] + 1.0;
        motion["mode"] = 0.0;
    }

    """Glide the camera so (cx, cy) centres a box of `tw` world units wide.

    `band` is the fraction of the viewport actually visible - the detail
    sheet covers the rest - so the target is centred in what the user can
    see rather than behind the sheet.
    """
    def glide_to(cx: float, cy: float, tw: float, band: float) -> None {
        cam["touched"] = 1.0;
        w = tw;
        if w < MIN_W {
            w = MIN_W;
        }
        if w > MAX_W {
            w = MAX_W;
        }
        motion["token"] = motion["token"] + 1.0;
        motion["mode"] = 2.0;
        motion["t"] = 0.0;
        motion["sx"] = cam["x"];
        motion["sy"] = cam["y"];
        motion["sw"] = cam["w"];
        motion["tx"] = cx - w / 2.0;
        motion["ty"] = cy - w * view["ar"] * band / 2.0;
        motion["tw"] = w;
        run_motion();
    }

    """How much of the stage the open detail sheet eats, measured live."""
    def sheet_fraction() -> float {
        stage: any = document.querySelector(".graph-stage");
        sheet: any = document.querySelector(".node-sheet");
        if stage and sheet {
            stage_h = float(stage.getBoundingClientRect().height);
            sheet_h = float(sheet.getBoundingClientRect().height);
            if stage_h > 1.0 {
                f = sheet_h / stage_h;
                if f > 0.05 and f < 0.7 {
                    return f;
                }
            }
        }
        return SHEET_FRAC;
    }

    """Frame the whole graph with breathing room."""
    def fit_camera() -> None {
        if len(nodes) == 0 {
            set_cam(0.0, 0.0, WORLD_W);
            return;
        }
        minx = nodes[0].x;
        maxx = nodes[0].x;
        miny = nodes[0].y;
        maxy = nodes[0].y;
        for n in nodes {
            if n.x < minx { minx = n.x; }
            if n.x > maxx { maxx = n.x; }
            if n.y < miny { miny = n.y; }
            if n.y > maxy { maxy = n.y; }
        }
        pad = 70.0;
        w = maxx - minx + pad * 2.0;
        h = maxy - miny + pad * 2.0;
        w_for_h = h / view["ar"];
        if w_for_h > w {
            w = w_for_h;
        }
        if w < MIN_W {
            w = MIN_W;
        }
        if w > MAX_W {
            w = MAX_W;
        }
        set_cam(
            (minx + maxx) / 2.0 - w / 2.0,
            (miny + maxy) / 2.0 - (w * view["ar"]) / 2.0,
            w
        );
    }

    """Re-measure after the container changes size, and reframe if the view
    is still the one we chose rather than one the user drove themselves.

    Without this the camera keeps a width chosen for the old container while
    labels and hit targets keep dividing by a stale container width, so both
    the framing and the fixed-size type drift away from correct.
    """
    def sync_view() -> None {
        was_w = view["w"];
        was_ar = view["ar"];
        measure_view();
        moved = view["w"] - was_w;
        if moved < 0.0 {
            moved = -moved;
        }
        tilted = view["ar"] - was_ar;
        if tilted < 0.0 {
            tilted = -tilted;
        }
        if (moved > 1.0 or tilted > 0.01) and cam["touched"] == 0.0 {
            stop_motion();
            fit_camera();
        }
    }

    can with [nodes] entry {
        measure_view();
        if len(nodes) > 0 and cam["seen"] == 0.0 {
            fit_camera();
        }
        cam["seen"] = len(nodes);
        window.addEventListener("resize", sync_view);
        return lambda { window.removeEventListener("resize", sync_view); };
    }

    def pointer_down(e: Event) {
        p = e as any;
        stop_motion();
        measure_view();
        if gesture["mode"] == 0.0 {
            gesture["mode"] = 1.0;
            gesture["id1"] = p.pointerId;
            gesture["x"] = p.clientX;
            gesture["y"] = p.clientY;
            gesture["moved"] = 0.0;
            gesture["vx"] = 0.0;
            gesture["vy"] = 0.0;
            panning = True;
        } elif gesture["mode"] == 1.0 {
            gesture["mode"] = 2.0;
            gesture["id2"] = p.pointerId;
            gesture["x2"] = p.clientX;
            gesture["y2"] = p.clientY;
            dx = gesture["x2"] - gesture["x"];
            dy = gesture["y2"] - gesture["y"];
            gesture["dist"] = (dx * dx + dy * dy) ** 0.5;
        }
    }

    def pointer_move(e: Event) {
        p = e as any;
        if gesture["mode"] == 1.0 and p.pointerId == gesture["id1"] {
            dx = p.clientX - gesture["x"];
            dy = p.clientY - gesture["y"];
            gesture["x"] = p.clientX;
            gesture["y"] = p.clientY;
            gesture["moved"] = gesture["moved"] + (dx * dx + dy * dy) ** 0.5;
            gesture["vx"] = gesture["vx"] * 0.7 + dx * 0.3;
            gesture["vy"] = gesture["vy"] * 0.7 + dy * 0.3;
            k = world_per_px(p.currentTarget);
            cam["touched"] = 1.0;
            set_cam(cam["x"] - dx * k, cam["y"] - dy * k, cam["w"]);
        } elif gesture["mode"] == 2.0 {
            if p.pointerId == gesture["id1"] {
                gesture["x"] = p.clientX;
                gesture["y"] = p.clientY;
            } elif p.pointerId == gesture["id2"] {
                gesture["x2"] = p.clientX;
                gesture["y2"] = p.clientY;
            }
            dx = gesture["x2"] - gesture["x"];
            dy = gesture["y2"] - gesture["y"];
            d = (dx * dx + dy * dy) ** 0.5;
            if gesture["dist"] > 0.0 and d > 0.0 {
                gesture["moved"] = gesture["moved"] + 10.0;
                apply_zoom(cam["w"] * gesture["dist"] / d);
                gesture["dist"] = d;
            }
        }
    }

    def pointer_up(e: Event) {
        p = e as any;
        if p.pointerId == gesture["id1"] or p.pointerId == gesture["id2"] {
            speed = (gesture["vx"] if gesture["vx"] > 0 else -gesture["vx"])
                  + (gesture["vy"] if gesture["vy"] > 0 else -gesture["vy"]);
            if gesture["mode"] == 1.0 and speed > 3.0 {
                motion["token"] = motion["token"] + 1.0;
                motion["mode"] = 1.0;
                motion["vx"] = gesture["vx"];
                motion["vy"] = gesture["vy"];
                motion["k"] = world_per_px(p.currentTarget);
                run_motion();
            }
            gesture["mode"] = 0.0;
            gesture["id1"] = -1.0;
            gesture["id2"] = -1.0;
            panning = False;
        }
    }

    def wheel(e: Event) {
        p = e as any;
        stop_motion();
        measure_view();
        apply_zoom(cam["w"] * 1.12 if p.deltaY > 0 else cam["w"] / 1.12);
    }

    def zoom_in(_e: MouseEvent) {
        stop_motion();
        measure_view();
        apply_zoom(cam["w"] / 1.3);
    }

    def zoom_out(_e: MouseEvent) {
        stop_motion();
        measure_view();
        apply_zoom(cam["w"] * 1.3);
    }

    def zoom_reset(_e: MouseEvent) {
        stop_motion();
        measure_view();
        cam["touched"] = 0.0;
        fit_camera();
    }

    visible = [n for n in nodes if n.kind == "skill" or n.category not in hidden];

    at: dict[str, GraphNode] = {};
    for n in visible {
        at[n.id] = n;
    }

    shown = [l for l in links if l.source in at and l.target in at];

    """Frame a node together with everything it connects to.

    Centring the node alone is not enough: selecting it opens the sheet over
    the lower half of the stage, and the neighbours it just lit up are what
    the user wants to see. So the whole neighbourhood is fitted into the band
    the sheet leaves visible.
    """
    def focus_on(id: str) -> None {
        n = at[id];
        minx = n.x;
        maxx = n.x;
        miny = n.y;
        maxy = n.y;
        for l in shown {
            other = "";
            if l.source == id {
                other = l.target;
            } elif l.target == id {
                other = l.source;
            }
            if other and other in at {
                o = at[other];
                if o.x < minx { minx = o.x; }
                if o.x > maxx { maxx = o.x; }
                if o.y < miny { miny = o.y; }
                if o.y > maxy { maxy = o.y; }
            }
        }

        band = 1.0 - sheet_fraction();
        pad = 130.0;
        tw = maxx - minx + pad * 2.0;
        w_for_h = (maxy - miny + pad * 2.0) / (view["ar"] * band);
        if w_for_h > tw {
            tw = w_for_h;
        }
        glide_to((minx + maxx) / 2.0, (miny + maxy) / 2.0, tw, band);
    }

    # A tap that travelled is a pan, not a pick. Selecting glides the camera.
    def pick(id: str) -> None {
        if gesture["moved"] < 8.0 {
            if id != focus and id in at {
                focus_on(id);
            }
            onPick(id);
        }
    }

    def clear(_e: MouseEvent) {
        if gesture["moved"] < 8.0 {
            onClear();
        }
    }

    masteryOf: dict[str, float] = {};
    for s in skills {
        masteryOf[s.id] = s.mastery if s.mastery < 1.0 else 1.0;
    }

    # Neighbourhood of the focused node, so focus lights a whole cluster.
    # `focused` is tracked as its own bool rather than testing `len(near)`:
    # len() of a dict compiles to `undefined` in the browser, so the guard
    # silently never fires and no highlight class is ever applied.
    near: dict[str, bool] = {};
    focused = False;

    if focus and focus in at {
        near[focus] = True;
        focused = True;
        for l in shown {
            if l.source == focus {
                near[l.target] = True;
            }
            if l.target == focus {
                near[l.source] = True;
            }
        }
    }

    # Matching the viewBox to the measured container makes `meet` a no-op,
    # so nothing is letterboxed away.
    vh = vw * car;
    box = str(vx) + " " + str(vy) + " " + str(vw) + " " + str(vh);

    # World units per screen pixel, for anything that must hold its size.
    scale = vw / cw if cw > 1.0 else 1.0;
    close_up = vw < LABEL_ZOOM_W;

    # Labels sit centred under their node, so one belonging to a node at the
    # edge of the frame would run off it. Nudging the text back inside costs
    # nothing, where padding the camera enough to fit it would throw away a
    # chunk of the viewport on every graph.
    labelAt: dict[str, float] = {};
    for n in visible {
        half = LABEL_EM * len(trim(n.label, 17 if n.kind == "skill" else 22))
             * (SKILL_LABEL_PX if n.kind == "skill" else LABEL_PX) * scale;
        lx = n.x;
        if lx - half < vx {
            lx = vx + half;
        }
        if lx + half > vx + vw {
            lx = vx + vw - half;
        }
        labelAt[n.id] = lx;
    }

    return <div className="graph-wrap">
        <svg
            className={"graph-svg panning" if panning else "graph-svg"}
            viewBox={box}
            preserveAspectRatio="xMidYMid meet"
            onPointerDown={pointer_down}
            onPointerMove={pointer_move}
            onPointerUp={pointer_up}
            onPointerCancel={pointer_up}
            onWheel={wheel}
        >
            <rect x={vx - vw} y={vy - vh} width={vw * 3} height={vh * 3} fill="transparent" onClick={clear}/>

            {for l in shown {
                <path
                    key={l.source + "-" + l.target}
                    className={"glink builds" if l.kind == "builds" else "glink"}
                    d={edge_path(at[l.source].x, at[l.source].y, at[l.target].x, at[l.target].y)}
                    fill="none"
                    pathLength={1}
                    strokeWidth={1.8}
                    strokeOpacity={
                        0.9 if focused and l.source in near and l.target in near
                        else (0.06 if focused else 0.12 + l.weight * 0.4)
                    }
                />
            }}

            {for (i, n) in enumerate(visible) {
                <GraphNodeMark
                    key={n.id}
                    item={n}
                    index={i}
                    mastery={masteryOf[n.id] if n.id in masteryOf else 0.0}
                    scale={scale}
                    labelX={labelAt[n.id]}
                    dim={focused and n.id not in near}
                    lit={focused and n.id == focus}
                    labelled={
                        n.kind == "skill"
                        or (focused and n.id in near)
                        or (close_up and not focused)
                    }
                    onPick={pick}
                />
            }}
        </svg>

        <div className="zoom-controls">
            <button className="zoom-btn" onClick={zoom_in} aria-label="Zoom in">+</button>
            <button className="zoom-btn" onClick={zoom_out} aria-label="Zoom out">&minus;</button>
            <button className="zoom-btn" onClick={zoom_reset} aria-label="Fit graph">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M3 9V5a2 2 0 0 1 2-2h4M15 3h4a2 2 0 0 1 2 2v4M21 15v4a2 2 0 0 1-2 2h-4M9 21H5a2 2 0 0 1-2-2v-4"/>
                </svg>
            </button>
        </div>
    </div>;
}
