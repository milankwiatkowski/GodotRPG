# Dialogues

Placeholder for the dialogue/storyline system. Not wired up yet.

When you're ready to bring in writing, a reasonable path is:
- Keep short one-off lines directly on the data resources that already carry
  them (`PatientArchetypeData.flavor_dialogue`, `DiseaseData.lore_text`,
  `DopplegangerProfile.lore_text` - see `scripts/resources/`).
- For anything longer/branching (recurring characters, the overarching
  plague/doppelganger plot, day-end story beats), consider a dedicated
  dialogue plugin (e.g. Dialogue Manager) and drop its `.dialogue` files here.

This folder intentionally has no code yet - it's on you per the project
scope, this is just reserving its place in the schema.
