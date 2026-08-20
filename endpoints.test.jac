"""Tests for the server-side brain (endpoints.jac).

An annex, not a standalone file: it pairs with `endpoints.jac` and sees its
declarations without importing them. Run with `jac test endpoints.jac`.

Two kinds of test live here:

- **Pure-function tests** (classify, similarity, layout, ...) touch no graph
  and are order-independent.
- **Graph tests** exercise the walker/`def:pub` layer that broke once already:
  on Jac >=0.17 a single-node `++>` returns the node, not a list, so the old
  `(root ++> Thought(...))[0]` unwrap threw at runtime and every capture,
  seed and skill-build silently failed. These tests are the regression guard.

Tests share one persisted `root` in declaration order, so every graph test
opens with `reset_brain()` to start from a known-empty brain -- and the suite
expects a clean `.jac/` (CI runs `jac clean` first; locally, do the same if a
graph test goes red on a re-run).
"""

# --- Pure functions -------------------------------------------------------

test "normalize pads to word boundaries" {
    low = normalize("Grateful!");
    assert low == " grateful ", f"got {low}";
    # The whole point of the padding: 'ate' must not match inside 'grateful'.
    assert " ate " not in low;
}

test "classify picks a category by keyword" {
    assert classify("I want to ship the demo") == "goal";
    assert classify("remember the whiteboard session") == "memory";
    assert classify("just some plain unremarkable sentence") == "idea";
}

test "match_skills finds every skill a thought feeds" {
    hits = match_skills("debugging a jac walker and its graph traversal");
    names = [s.name for s in hits];
    assert "Object-Spatial Programming" in names, f"got {names}";
    assert match_skills("xyzzy qwerty plugh") == [];
}

test "similarity is an overlap coefficient" {
    assert similarity("machine learning model", "machine learning model") == 1.0;
    assert similarity("machine learning", "completely unrelated jargon") == 0.0;
    # Containment scores high even when the two thoughts are very different
    # lengths -- the reason overlap beats Jaccard here.
    assert similarity(
        "machine learning",
        "machine learning is a broad and fascinating discipline"
    ) == 1.0;
    # Empty / stopword-only input never raises.
    assert similarity("", "anything") == 0.0;
}

test "tokens stems trailing plurals and drops stopwords" {
    toks = tokens("walkers and walker with that graph");
    assert "walker" in toks;      # 'walkers' stemmed onto 'walker'
    assert "graph" in toks;
    assert "that" not in toks;    # stopword
    assert "and" not in toks;     # too short
}

test "layout is deterministic and bounded" {
    ids = ["a", "b", "c", "d"];
    links: list[GraphLink] = [];
    first = layout(ids, links);
    second = layout(ids, links);
    assert first == second, "layout must be reproducible across loads";
    for tid in ids {
        assert tid in first;
        assert 0.0 <= first[tid][0] <= CANVAS;
        assert 0.0 <= first[tid][1] <= CANVAS_H;
    }
}

test "layout centers a single node" {
    solo = layout(["only"], []);
    assert solo["only"][0] == CANVAS / 2.0;
    assert solo["only"][1] == CANVAS_H / 2.0;
}

# --- Graph layer (regression guard for the ++> unwrap) --------------------

test "create_thought captures a reachable thought" {
    _ = reset_brain();
    assert create_thought("jac walker graph traversal finally clicked", "");
    thoughts = [root -->[?:Thought]];
    assert len(thoughts) == 1, f"expected 1 thought, got {len(thoughts)}";
    assert thoughts[0].content == "jac walker graph traversal finally clicked";
}

test "create_thought wires the thought to a skill" {
    _ = reset_brain();
    _ = create_thought("debugging a jac walker and graph traversal", "");
    names = [s.name for s in [root -->[?:Skill]]];
    assert "Object-Spatial Programming" in names, f"got {names}";
}

test "create_thought rejects blank input" {
    _ = reset_brain();
    assert not create_thought("   ", "");
    assert len([root -->[?:Thought]]) == 0;
}

test "delete_thought forgets a thought" {
    _ = reset_brain();
    _ = create_thought("a lone thought about writing an essay", "");
    only = [root -->[?:Thought]][0];
    assert delete_thought(jid(only));
    assert len([root -->[?:Thought]]) == 0;
    assert not delete_thought("not-a-real-id");
}

test "seed_demo fills an empty brain exactly once" {
    _ = reset_brain();
    assert seed_demo() == len(DEMO);
    assert seed_demo() == 0, "seeding a non-empty brain must be a no-op";
}

test "LoadBrain reports the whole seeded graph" {
    _ = reset_brain();
    _ = seed_demo();
    result = root spawn LoadBrain();
    assert result.reports, "LoadBrain reported nothing";
    view = result.reports[0];
    assert len(view.skills) == len(SKILLS), f"got {len(view.skills)} skills";
    # Every node is a thought or a skill; thoughts are the whole demo corpus.
    assert len(view.nodes) == len(DEMO) + len(view.skills);
    assert len(view.links) > 0;
}

test "set_goal and get_goal round-trip and clear" {
    stored = set_goal("ship the demo");
    assert stored == "ship the demo";
    assert get_goal() == "ship the demo";
    assert set_goal("") == "";
    assert get_goal() == "";
}

test "reset_brain erases thoughts and skills" {
    _ = reset_brain();
    _ = seed_demo();
    gone = reset_brain();
    assert gone == len(DEMO);
    assert len([root -->[?:Thought]]) == 0;
    assert len([root -->[?:Skill]]) == 0;
}
