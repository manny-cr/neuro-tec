"""What the graph says you are getting better at.

Mastery is never entered by the user - it is counted from the thoughts that
point at each skill. This screen does one job: show that formation.
"""

sv import from endpoints { SkillView }

"""Level label derived from mastery, so the row never needs a legend."""
def:pub level_of(mastery: float) -> str {
    if mastery >= 1.0 {
        return "Fluent";
    }
    if mastery >= 0.6 {
        return "Solid";
    }
    if mastery < 0.3 {
        return "Just started";
    }
    return "Practising";
}

def:pub SkillRow(
    skill: SkillView,
    index: int,
    onOpen: Callable[[str], None]
) -> JsxElement {
    def handle(_e: MouseEvent) {
        onOpen(skill.id);
    }

    pct = skill.mastery * 100.0;
    delay = index * 40;
    if delay > 320 {
        delay = 320;
    }

    return <button
        className="skill-row"
        style={{"animationDelay": str(delay) + "ms"}}
        onClick={handle}
    >
        <span className="skill-row-head">
            <span className="skill-row-name">{skill.name}</span>
            <span className="skill-row-level">{level_of(skill.mastery)}</span>
        </span>
        <span className="skill-row-progress">
            <span className="bar-track tall">
                <span className="bar-fill accent" style={{"width": str(pct) + "%"}}></span>
            </span>
            <span className="skill-row-meta">
                {str(skill.reps) + " of " + str(skill.target) + " thoughts"}
            </span>
        </span>
    </button>;
}

def:pub Skills(
    skills: list[SkillView],
    busy: bool,
    onOpenSkill: Callable[[str], None],
    onCapture: Callable[[MouseEvent], None]
) -> JsxElement {
    ranked = sorted(skills, key=lambda (s: SkillView) -> float { return 0.0 - s.mastery; });

    summary = "";
    if len(ranked) > 0 {
        summary = str(len(ranked)) + " forming · strongest " + ranked[0].name;
    }

    # Nearest skill to its next level, so the nudge is always actionable.
    nextName = "";
    nextNeed = 0;
    nextLevel = "";
    bestGap = 9999;
    for s in ranked {
        goal = s.target;
        label = "Fluent";
        if s.mastery < 0.6 {
            goal = round(s.target * 0.6);
            label = "Solid";
        }
        need = goal - s.reps;
        if need > 0 and need < bestGap {
            bestGap = need;
            nextNeed = need;
            nextName = s.name;
            nextLevel = label;
        }
    }

    return <div className="scroll skills-page">
        <header className="skills-top">
            <h1 className="skills-title">Skills</h1>
            {if summary {
                <p className="skills-summary">{summary}</p>
            }}
            {if nextName {
                <p className="skills-next">
                    <span className="skills-next-count">
                        {str(nextNeed) + (" more thought" if nextNeed == 1 else " more thoughts")}
                    </span>
                    {" to reach " + nextLevel + " on " + nextName}
                </p>
            }}
        </header>

        {if len(ranked) == 0 {
            <div key="empty" className="skills-empty">
                <p>Capture learning or goals — skills appear automatically.</p>
                <button className="primary-btn" onClick={onCapture} disabled={busy}>
                    Capture a thought
                </button>
            </div>
            skip;
        }}

        <div className="skill-list">
            {for (i, s) in enumerate(ranked) {
                <SkillRow key={s.id} skill={s} index={i} onOpen={onOpenSkill}/>
            }}
        </div>
    </div>;
}
