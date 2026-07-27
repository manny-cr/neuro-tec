"""A portrait of this particular brain, read straight off the graph.

Two views, both derived: how the thinking is distributed across categories,
and the handful of facts only this person's own graph can answer. Nothing is
entered by hand, so every row disappears the moment its data does.
"""

sv import from endpoints { GraphNode, GraphLink, SkillView }

import from .palette { cat_color }
import from .Feed { short_date }

# Keyed by the MM substring so no parsing or date library is involved.
glob MONTH_ABBR: dict[str, str] = {
    "01": "Jan", "02": "Feb", "03": "Mar", "04": "Apr",
    "05": "May", "06": "Jun", "07": "Jul", "08": "Aug",
    "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dec"
};

"""ISO timestamp to a short human date - "2026-07-08T..." becomes "8 Jul"."""
def:pub since_date(iso: str) -> str {
    if len(iso) < 10 {
        return "";
    }
    month = iso[5:7];
    if month not in MONTH_ABBR {
        return "";
    }
    day = iso[8:10];
    if day[0] == "0" {
        day = day[1:];
    }
    return day + " " + MONTH_ABBR[month];
}

"""One derived fact: quiet label on the left, the answer on the right."""
def:pub FactRow(label: str, value: str, index: int) -> JsxElement {
    delay = index * 45;
    if delay > 180 {
        delay = 180;
    }

    return <div className="fact-row" style={{"animationDelay": str(delay) + "ms"}}>
        <span className="fact-label">{label}</span>
        <span className="fact-value">{value}</span>
    </div>;
}

def:pub BrainPortrait(
    nodes: list[GraphNode],
    links: list[GraphLink],
    skills: list[SkillView]
) -> JsxElement {
    thoughts = [n for n in nodes if n.kind == "thought"];
    total = len(thoughts);

    # Only categories this brain actually contains, ranked by how much of it
    # they are. First-seen order survives ties because sorted() is stable.
    counts: dict[str, int] = {};
    present: list[str] = [];
    for n in thoughts {
        counts[n.category] = counts[n.category] + 1 if n.category in counts else 1;
        if n.category not in present {
            present = present + [n.category];
        }
    }
    ranked = sorted(present, key=lambda (c: str) -> int { return 0 - counts[c]; });

    # The last segment takes whatever is left rather than its own quotient, so
    # float drift can never leave a sliver of empty track at the end.
    widths: list[float] = [];
    used = 0.0;
    last = len(ranked) - 1;
    for (i, c) in enumerate(ranked) {
        if i == last {
            widths = widths + [100.0 - used];
        } else {
            share: float = counts[c] * 100.0 / total;
            used = used + share;
            widths = widths + [share];
        }
    }

    labels: list[str] = [];
    values: list[str] = [];

    strongest = "";
    peak = -1.0;
    for s in skills {
        if s.mastery > peak {
            peak = s.mastery;
            strongest = s.name;
        }
    }
    if strongest {
        labels = labels + ["Strongest skill"];
        values = values + [strongest];
    }

    degree: dict[str, int] = {};
    for l in links {
        degree[l.source] = degree[l.source] + 1 if l.source in degree else 1;
        degree[l.target] = degree[l.target] + 1 if l.target in degree else 1;
    }
    hub = "";
    busiest = 0;
    for n in thoughts {
        reach = degree[n.id] if n.id in degree else 0;
        if reach > busiest {
            busiest = reach;
            hub = n.label if n.label else n.detail;
        }
    }
    if hub {
        labels = labels + ["Most connected"];
        values = values + [hub];
    }

    # ISO strings sort correctly as plain text, so no parsing is needed.
    newest = "";
    oldest = "";
    for n in thoughts {
        stamp = n.created_at;
        if stamp {
            if not newest or stamp > newest {
                newest = stamp;
            }
            if not oldest or stamp < oldest {
                oldest = stamp;
            }
        }
    }
    latest = short_date(newest);
    if latest {
        labels = labels + ["Last captured"];
        values = values + [latest];
    }
    # A single thought would answer both time rows identically; one is enough.
    started = since_date(oldest) if oldest != newest else "";
    if started {
        labels = labels + ["Capturing since"];
        values = values + [started];
    }

    return <div className="brain-portrait">
        {if len(ranked) > 0 {
            <section key="mix" className="portrait-block">
                <p className="section-title">What you think about</p>
                <div className="mix-bar">
                    {for (i, c) in enumerate(ranked) {
                        <span
                            key={c}
                            className="mix-seg"
                            style={{"background": cat_color(c), "width": str(widths[i]) + "%"}}
                        ></span>
                    }}
                </div>
                <div className="mix-legend">
                    {for c in ranked {
                        <span key={c} className="mix-item">
                            <span className="mix-dot" style={{"background": cat_color(c)}}></span>
                            <span className="mix-name">{c}</span>
                            <span className="mix-count">{str(counts[c])}</span>
                        </span>
                    }}
                </div>
            </section>
        }}

        {if len(labels) > 0 {
            <section key="facts" className="portrait-block">
                <p className="section-title">Your brain right now</p>
                <div className="fact-list">
                    {for (i, name) in enumerate(labels) {
                        <FactRow key={name} label={name} value={values[i]} index={i}/>
                    }}
                </div>
            </section>
        }}
    </div>;
}
