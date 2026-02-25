# RTS AAA Polish Pass Design

**Date**: 2026-02-22
**Status**: Approved
**Scope**: Breadth-first pass across 5 pillars — new units, maps, save/load+replay, AI personalities, supporting polish

## Context

The RTS Colony Wars stage is at 4.6/5 AAA quality after 3 implementation passes (initial build, feature pass, gaps pass). 45 scripts, deep combat/economy/UI. This pass fills the remaining gaps to reach a polished AAA single-player skirmish RTS experience embedded within a multi-stage game (cell -> snake -> RTS).

---

## Pillar 1: New Units (3)

### Medic (Healer)
- 80 HP, 90 speed, no attack, 150u heal range
- Auto-heals nearest wounded ally at 4 HP/s, costs 0.5 biomass/s
- Ability (V): **Regeneration Aura** — 8u radius, +2 HP/s to all allies for 10s, 30s cooldown
- Produced at Spawning Pool after T1 research
- Cost: 75 biomass, 15 genes, 1 supply
- AI target: 1 per 4 military units

### Siege Worm (AoE Artillery)
- 100 HP, 50 speed, 18 damage, 300u range, 3s attack cooldown
- Splash damage: 100% center, 50% at 40u, 0% at 80u
- Must **deploy** (1.5s setup) before attacking; immobile while deployed
- Ability (V): **Burrow Bomb** — delayed explosion at target (2s fuse, 40 AoE damage), 20s cooldown
- Produced at Evolution Chamber after T2 research
- Cost: 150 biomass, 40 genes, 3 supply
- Very vulnerable when undeployed (cannot attack)

### Psi-Caster (Debuff Specialist)
- 60 HP, 100 speed, 8 damage, 180u range
- Ability (V): **Neural Disruption** — target enemy slowed 50% and deals 50% damage for 6s, 15s cooldown
- Passive: **Psi Field** — enemy units within 60u have -1 armor
- Produced at Evolution Chamber after T2 research
- Cost: 100 biomass, 35 genes, 2 supply

### Integration
- `unit_stats.gd`: 3 new UnitType entries (MEDIC=5, SIEGE_WORM=6, PSI_CASTER=7)
- `rts_unit.gd`: New states (HEALING, DEPLOYED), deploy/undeploy logic, heal tick, psi field aura
- AI director learns composition targets per personality
- Voice generator gets 3 new species presets
- Tutorial contextual tip mentions new units
- Command card gets new buttons (Deploy/Undeploy for Siege Worm, heal toggle for Medic)

---

## Pillar 2: New Maps (2)

### Blood Vessel (Narrow Lanes)
- **Shape**: Elongated oval (12000 x 4000)
- **Layout**: 3 parallel vessel lanes connected by narrow capillary passages
- **Resources**: Concentrated at lane intersections (contested choke points)
- **Terrain**: 4 elevation zones along vessel walls (flanking high ground)
- **Spawns**: 2v2 layout — 2 factions per end
- **Strategy**: Lane control, defensive play, siege. Narrow passages make AoE devastating.
- **Visual**: Red/crimson tones, pulsing vessel walls, flowing current particles

### Brain Cortex (Open Plateau)
- **Shape**: Irregular blob (~10000 x 10000), organic brain fold edges
- **Layout**: Large open central plateau with 6 resource-rich gyri (ridges) around edges, connected by narrow sulci (valleys)
- **Resources**: Scattered across open ground + rich deposits in defensible gyri
- **Terrain**: Central plateau is high ground, valleys are low ground. 8 elevation zones.
- **Spawns**: 4 corners (standard FFA)
- **Strategy**: Aggression and map control. Open center forces early fights.
- **Visual**: Grey/pink neural tissue, synapse spark particles, dendrite obstacles

### Map System Architecture
- `petri_dish_map.gd` becomes base class with virtual `_generate_layout()`
- `blood_vessel_map.gd` and `brain_cortex_map.gd` extend base
- Each map defines: shape boundary, resource node positions, spawn positions, terrain zones, obstacle placements, visual theme (particle colors, background tint)
- AI adapts strategy per map (more defensive on Blood Vessel, more aggressive on Brain Cortex)

### Pre-Game Setup Screen
- Map selection: 3 thumbnails with name + brief description
- Difficulty selector: 5 tiers
- AI count: 1-3 opponents
- "Start" button
- Replaces current instant-start flow
- Accessed from main menu "Colony Wars" button

---

## Pillar 3: Save/Load + Replay

### Save/Load
- Every game object gets `serialize() -> Dictionary` and `deserialize(data: Dictionary)`
- Save format: JSON in `user://saves/rts_save_TIMESTAMP.json`
- Saved state: unit positions/HP/states/orders, building queues/HP, resource counts, fog state, tech tree progress, AI phase+state, map event timer, game clock, camera position, map ID
- Triggers: Pause menu "Save Game" button, F5 quicksave, F9 quickload
- Auto-save: Every 5 minutes, keeps last 3 auto-saves
- Load: From main menu or pause menu

### Replay Recording
- Command-stream recording: every command (move, attack, build, research) with timestamp
- Storage: `user://replays/rts_replay_TIMESTAMP.json`
- Playback UI: Timeline scrubber, play/pause, 1x/2x/4x/8x speed, free camera (fog disabled), player perspective toggle
- Auto-record every match, keep last 10. Manual "Save Replay" at end-of-match stats screen.
- Replays break across game versions (acceptable for single-player)

### Implementation
- `rts_save_manager.gd`: Handles serialization, file I/O, auto-save timer
- `rts_replay_recorder.gd`: Records command stream during play
- `rts_replay_player.gd`: Plays back recorded commands, manages replay UI
- Pause menu: Save/Load buttons
- Pre-game screen: "Load Game" and "Watch Replay" options

---

## Pillar 4: AI Faction Personalities

### Swarm (Faction 1, Green) — Rush
- Early aggression, overwhelming numbers
- Build: Workers fast -> mass Fighters -> constant pressure
- Composition: 70% Fighters, 20% Scouts, 10% Ranged
- Tech: Metabolic Boost (speed) -> Berserker Enzymes
- Attack pattern: Waves every 90s starting early
- Weakness: Poor late-game, thin defenses

### Bulwark (Faction 2, Gold) — Turtle
- Defensive economy -> unstoppable late-game deathball
- Build: Towers + Bio-Walls -> economy -> Defenders + Siege Worms
- Composition: 40% Defenders, 25% Siege Worms, 20% Ranged, 10% Medics, 5% Fighters
- Tech: Hardened Membranes -> Spine Tower -> Hive Mind
- Attack pattern: Turtles until T3, then massive push
- Weakness: Vulnerable to early rushes

### Predator (Faction 3, Red) — Raider
- Map control, harassment, denying enemy economy
- Build: Scouts -> Psi-Casters + Ranged -> deny resource nodes
- Composition: 30% Scouts, 25% Ranged, 20% Psi-Casters, 15% Fighters, 10% Siege Worms
- Tech: Extended Pseudopods -> Apex Predator -> Rapid Mitosis
- Attack pattern: Multi-pronged raids (2-3 small squads hitting different spots)
- Weakness: Loses even fights, fragile units

### Implementation
- `ai_director.gd` gets `faction_personality` enum (SWARM / BULWARK / PREDATOR)
- Personality overrides: build priorities, unit composition targets, attack timing, tech path, expansion behavior
- Difficulty still scales speed/resource bonuses on top of personality
- Player faction (0) keeps "Adaptive" identity (no AI personality)

---

## Pillar 5: Supporting Polish

### Unit Stances (3 modes)
- **Aggressive**: Auto-chases enemies to max range (current default)
- **Defensive**: Fights when attacked, returns to position after 80u
- **Passive**: Never auto-attacks, only explicit commands
- Toggle: G key cycles. Icon on selection panel. Per-unit state.
- `rts_unit.gd`: New `stance` enum, affects `_find_best_target()` and chase logic

### Superweapon: Evolutionary Singularity
- Unlock: All 3 Tier 3 upgrades researched
- New building: **Singularity Core** (500B/150G, 120s build, 1 per player)
- Ability: **Singularity Pulse** — 60s charge (visible on minimap), deals 80 damage to ALL enemy units + 40% slow for 8s. 180s cooldown.
- Counterplay: Core is fragile (200 HP), visible during charge, charge resets if destroyed
- `building_stats.gd`: New BuildingType SINGULARITY_CORE=6
- AI builds Core in ENDGAME phase if all T3 researched

### Dynamic Music System
- Procedural synth (AudioStreamGenerator, matching SynthSounds pattern)
- 3 intensity layers with 3s crossfade:
  - **Calm**: Low drone + ambient bubbles (no combat for 30s)
  - **Tension**: Pulsing rhythm + rising harmonics (enemy spotted / building attacked)
  - **Combat**: Driving beat + aggressive synth (3+ units in combat)
- Per-map tonal flavor: Petri Dish=blue/cool, Blood Vessel=red/warm, Brain Cortex=grey/eerie
- `rts_music.gd`: New script, manages intensity state + procedural generation

### Additional Polish
- **Worker multi-build**: Multiple workers on one building; each extra adds 50% build speed (diminishing)
- **Voice variety**: 8 unit types x 3 pitch-shifted variants
- **Victory fanfare**: Procedural synth celebration on win, somber drone on loss
- **Hotkey reference card**: H key toggles overlay showing all hotkeys

---

## Summary

| Pillar | Features | New Scripts |
|--------|----------|-------------|
| Units | 3 new unit types | unit_stats.gd updates, rts_unit.gd states |
| Maps | 2 maps + map picker + pre-game screen | blood_vessel_map.gd, brain_cortex_map.gd, rts_pregame.gd |
| Save/Replay | Save/load + replay recording + replay playback | rts_save_manager.gd, rts_replay_recorder.gd, rts_replay_player.gd |
| AI | 3 faction personalities | ai_director.gd personality system |
| Polish | Stances, superweapon, music, multi-build, voice variety, hotkey card | rts_music.gd, hotkey_overlay additions |
