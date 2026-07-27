"""The goal, on one line, above every tab.

Deliberately the quietest element on the screen. It is a reminder, not a
banner: no card, no icon, no progress, no dismiss. A hairline underneath is
the only structure, so it reads as part of the frame rather than as content
competing with the tab below it.

Long goals truncate to a single line rather than wrapping -- two lines here
would push every screen down and stop reading as chrome.
"""

def:pub GoalBar(text: str) -> JsxElement {
    if not text {
        return <span aria-hidden="true"></span>;
    }

    return <div className="goalbar">
        <span className="goalbar-dot" aria-hidden="true"></span>
        <p className="goalbar-text" title={text}>{text}</p>
    </div>;
}
