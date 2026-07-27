"""The five behaviors a user can commit to for a single experience.

This is the one place the preset list exists. The server validates against it,
the client renders from it, and the graph stores only a preset's `key` -- so a
wording change here rewrites every screen without touching stored data.

Five is deliberate. The choice is meant to take seconds, not deliberation: the
point of the feature is the commitment, not the shopping.
"""


obj IntentionPreset {
    has key: str,
        title: str,
        subtitle: str,
        # Shown on the priming screen, phrased as the rehearsal instruction.
        rehearsal: str;
}


glob INTENTIONS: list[IntentionPreset] = [
    IntentionPreset(
        key="speak_up",
        title="Speak up at least once",
        subtitle="Raise your hand or contribute to the conversation.",
        rehearsal="Picture the moment you speak. Hear your own voice carrying."
    ),
    IntentionPreset(
        key="meet_people",
        title="Meet 30 new people",
        subtitle="Start conversations with people you normally wouldn't meet.",
        rehearsal="Picture walking toward someone you don't know, and opening."
    ),
    IntentionPreset(
        key="stay_present",
        title="Stay fully present",
        subtitle="Avoid distractions and remain engaged.",
        rehearsal="Picture your attention resting in the room. Nowhere else."
    ),
    IntentionPreset(
        key="ask_question",
        title="Ask one meaningful question",
        subtitle="Be curious. Seek understanding.",
        rehearsal="Picture the question forming, and the silence after you ask it."
    ),
    IntentionPreset(
        key="lead_confident",
        title="Lead with confidence",
        subtitle="Stand tall. Speak clearly. Trust yourself.",
        rehearsal="Picture your posture settling. Steady breath, unhurried words."
    )
];


"""Look up a preset by key, or None if the key is unknown."""
def preset_for(key: str) -> IntentionPreset | None {
    for preset in INTENTIONS {
        if preset.key == key {
            return preset;
        }
    }
    return None;
}


"""True for a known preset key. The empty string means "none chosen"."""
def is_valid_intention(key: str) -> bool {
    return preset_for(key) is not None;
}
