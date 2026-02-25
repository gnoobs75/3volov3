# RTS AAA Polish Pass Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring the RTS Colony Wars stage from 4.6/5 to full AAA quality across 5 pillars: new units, maps, save/load+replay, AI personalities, and supporting polish.

**Architecture:** Extends existing RTS subsystem architecture. New units extend `unit_stats.gd` enum + `rts_unit.gd` state machine. New maps extend `petri_dish_map.gd` as base class. Save/load serializes all game objects to JSON. AI personalities add composition/timing overrides to `ai_director.gd`. Music uses AudioStreamGenerator matching existing SynthSounds pattern.

**Tech Stack:** Godot 4, GDScript, procedural audio via AudioStreamGenerator, JSON serialization, procedural 2D drawing

---

## Task Groups (Parallelizable)

| Group | Pillar | Tasks | Dependencies |
|-------|--------|-------|-------------|
| A | New Units — Stats & Data | 1-2 | None |
| B | New Units — Behavior & Combat | 3-6 | A |
| C | Map System — Base Class & New Maps | 7-10 | None |
| D | Pre-Game Screen | 11 | C |
| E | Save/Load System | 12-15 | None |
| F | Replay System | 16-18 | E |
| G | AI Personalities | 19-21 | A |
| H | Unit Stances | 22-23 | None |
| I | Superweapon | 24-25 | A |
| J | Dynamic Music | 26-27 | None |
| K | Polish Grab-Bag | 28-31 | A, H |

**Parallel execution:** Groups A, C, E, H, J can all start simultaneously. After A completes, B/G/I/K can start. After C, D starts. After E, F starts.

---

## Group A: New Units — Stats & Data

### Task 1: Add 3 new unit types to UnitStats

**Files:**
- Modify: `scripts/rts_stage/unit_stats.gd`

**What to do:**

Add to enum (after RANGED=4):
```gdscript
enum UnitType { WORKER, FIGHTER, DEFENDER, SCOUT, RANGED, MEDIC, SIEGE_WORM, PSI_CASTER }
# MEDIC=5, SIEGE_WORM=6, PSI_CASTER=7
```

Add 3 entries to `UNIT_DATA` dictionary. Follow exact field pattern of existing entries (see FIGHTER for reference). Key stats:

**MEDIC (UnitType.MEDIC = 5):**
```
name: "Medic", hp: 80, armor: 0, speed: 90, damage: 0, attack_range: 0, attack_cooldown: 0,
cost_biomass: 75, cost_genes: 15, build_time: 25.0, supply_cost: 1,
detection_range: 200.0, can_build: false, can_gather: false,
heal_range: 150.0, heal_rate: 4.0, heal_cost_per_sec: 0.5,
ability_name: "Regen Aura", ability_cooldown: 30.0, ability_duration: 10.0,
ability_heal_rate: 2.0, ability_radius: 80.0
```

**SIEGE_WORM (UnitType.SIEGE_WORM = 6):**
```
name: "Siege Worm", hp: 100, armor: 1, speed: 50, damage: 18, attack_range: 300, attack_cooldown: 3.0,
cost_biomass: 150, cost_genes: 40, build_time: 40.0, supply_cost: 3,
detection_range: 350.0, can_build: false, can_gather: false,
deploy_time: 1.5, splash_radius_full: 0.0, splash_radius_half: 40.0, splash_radius_zero: 80.0,
ability_name: "Burrow Bomb", ability_cooldown: 20.0, ability_duration: 2.0,
ability_damage: 40.0, ability_radius: 80.0,
projectile_speed: 200.0, min_range: 80.0
```

**PSI_CASTER (UnitType.PSI_CASTER = 7):**
```
name: "Psi-Caster", hp: 60, armor: 0, speed: 100, damage: 8, attack_range: 180, attack_cooldown: 1.8,
cost_biomass: 100, cost_genes: 35, build_time: 35.0, supply_cost: 2,
detection_range: 250.0, can_build: false, can_gather: false,
psi_field_radius: 60.0, psi_field_armor_debuff: 1.0,
ability_name: "Neural Disruption", ability_cooldown: 15.0, ability_duration: 6.0,
ability_slow_mult: 0.5, ability_damage_mult: 0.5, ability_range: 180.0,
projectile_speed: 250.0
```

**Commit:** `feat(rts): add Medic, Siege Worm, Psi-Caster unit stats`

---

### Task 2: Register new units in BuildingStats production lists

**Files:**
- Modify: `scripts/rts_stage/building_stats.gd`

**What to do:**

Add MEDIC to Spawning Pool's `can_produce` array:
```gdscript
# SPAWNING_POOL entry
"can_produce": [UnitStats.UnitType.WORKER, UnitStats.UnitType.MEDIC],
```

Add SIEGE_WORM and PSI_CASTER to Evolution Chamber's `can_produce`:
```gdscript
# EVOLUTION_CHAMBER entry
"can_produce": [UnitStats.UnitType.FIGHTER, UnitStats.UnitType.DEFENDER, UnitStats.UnitType.SCOUT, UnitStats.UnitType.RANGED, UnitStats.UnitType.SIEGE_WORM, UnitStats.UnitType.PSI_CASTER],
```

Also add Singularity Core building (for Task 24 later, but add the data now):
```gdscript
# Add to BuildingType enum: SINGULARITY_CORE = 6
# Add to BUILDING_DATA:
BuildingType.SINGULARITY_CORE: {
    "name": "Singularity Core", "hp": 200, "armor": 0,
    "cost_biomass": 500, "cost_genes": 150, "build_time": 120.0,
    "size_radius": 50.0, "is_depot": false, "is_production": false,
    "is_main_base": false, "can_produce": [], "supply_provided": 0,
    "attack_range": 0, "attack_damage": 0, "attack_cooldown": 0,
    "max_per_player": 1,
}
```

Add to BUILD_BUTTONS in `rts_hud.gd` (line ~103):
```gdscript
{"type": BuildingStats.BuildingType.SINGULARITY_CORE, "key": "U"},
```

**Commit:** `feat(rts): register new units in production lists, add Singularity Core building stats`

---

## Group B: New Units — Behavior & Combat

### Task 3: Implement Medic healing behavior in rts_unit.gd

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd`

**What to do:**

Add new state: `HEALING = 10` to State enum.

In `_physics_process()`, add Medic auto-heal logic (after existing state processing):
- If unit_type == MEDIC and state == IDLE or MOVE:
  - Scan allies within `heal_range` (150u) for wounded (health < max_health)
  - Pick nearest wounded ally
  - If found and in range: enter HEALING state, set `_heal_target`
  - If target moves out of range or fully healed: return to IDLE
- In HEALING state:
  - Apply `heal_rate` (4 HP/s) to target each tick (`delta * heal_rate`)
  - Deduct `heal_cost_per_sec * delta` biomass from faction via `_resource_manager`
  - If biomass insufficient: stop healing, return to IDLE
  - Draw green heal beam from self to target (in `_draw()`)

Add Medic ability `_execute_regen_aura()`:
- Apply `+ability_heal_rate` (2 HP/s) to all allies within `ability_radius` (80u) for `ability_duration` (10s)
- Use metadata on affected units: `set_meta("regen_aura_remaining", duration)`, tick down in `_physics_process`
- Draw green pulsing ring around Medic while active

Add Medic to the `use_ability()` match statement.

Add Medic visual in `_draw_unit_decorations()`: white cross symbol.

**Commit:** `feat(rts): implement Medic healing behavior and Regen Aura ability`

---

### Task 4: Implement Siege Worm deploy/splash in rts_unit.gd

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd`
- Modify: `scripts/rts_stage/combat_system.gd`

**What to do:**

Add new state: `DEPLOYED = 11` to State enum.

Add deploy/undeploy toggle:
- New var `_is_deployed: bool = false`, `_deploy_timer: float = 0.0`
- Deploy command (V key when no target): starts deploy timer (1.5s), unit cannot move
- When deployed: speed = 0, can attack, show deployed visual (wider, flattened shape)
- Undeploy: 1.5s timer again, then can move but cannot attack
- If given move command while deployed: auto-undeploy first, then move

Siege Worm attack must be ranged with splash:
- In `_perform_attack()`, if unit_type == SIEGE_WORM:
  - Fire projectile to target
  - On impact, call `combat_system.apply_splash_damage()`
  - Full damage at center, 50% at 40u, 0% at 80u (linear falloff)

Add `apply_splash_damage()` to `combat_system.gd`:
```gdscript
func apply_splash_damage(epicenter: Vector2, base_damage: float, full_radius: float, half_radius: float, zero_radius: float, attacker: Node2D) -> void:
    for unit in get_tree().get_nodes_in_group("rts_units"):
        if unit.faction_id == attacker.faction_id:
            continue
        var dist: float = unit.global_position.distance_to(epicenter)
        if dist > zero_radius:
            continue
        var mult: float = 1.0
        if dist > full_radius:
            mult = lerpf(0.5, 0.0, (dist - half_radius) / (zero_radius - half_radius))
            if dist < half_radius:
                mult = lerpf(1.0, 0.5, (dist - full_radius) / (half_radius - full_radius))
        apply_damage(unit, base_damage * mult, attacker)
```

Add Siege Worm ability `_execute_burrow_bomb(target_pos)`:
- Spawn delayed AoE marker at target (red pulsing circle)
- After 2s fuse: `combat_system.apply_splash_damage(target_pos, 40.0, 0, 40, 80, self)`
- Use a timer or `_bomb_targets` array to track pending explosions

Add Siege Worm visual: segmented worm body. When deployed: segments spread flat.

**Commit:** `feat(rts): implement Siege Worm deploy mechanic and splash damage`

---

### Task 5: Implement Psi-Caster debuff behavior in rts_unit.gd

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd`

**What to do:**

Psi Field passive aura:
- In `_physics_process()`, if unit_type == PSI_CASTER:
  - Every 0.5s, scan enemies within `psi_field_radius` (60u)
  - Set metadata on affected enemies: `set_meta("psi_debuff_armor", 1.0)`
  - Clear metadata when enemy moves out of range
- In `take_damage()`, check `get_meta("psi_debuff_armor", 0.0)` and subtract from armor

Neural Disruption ability `_execute_neural_disruption(target_pos)`:
- Find nearest enemy unit within `ability_range` (180u) of target_pos
- Apply debuff to target for `ability_duration` (6s):
  - `set_meta("neural_disruption_remaining", 6.0)`
  - `set_meta("neural_slow", 0.5)` — speed multiplied by this
  - `set_meta("neural_damage_mult", 0.5)` — damage multiplied by this
- In `_physics_process()`, tick down `neural_disruption_remaining`; when 0, clear metas
- In movement code: multiply speed by `get_meta("neural_slow", 1.0)`
- In `_perform_attack()`: multiply damage by `get_meta("neural_damage_mult", 1.0)`

Psi-Caster visual: purple-tinted body with crackling energy arcs. Neural Disruption shows purple tether to target.

**Commit:** `feat(rts): implement Psi-Caster Psi Field aura and Neural Disruption ability`

---

### Task 6: Add new unit voice lines and HUD integration

**Files:**
- Modify: `scripts/audio/synth_sounds.gd` — 3 new voice generators
- Modify: `scripts/autoload/audio_manager.gd` — 3 new voice buffers + play functions
- Modify: `scripts/rts_stage/rts_hud.gd` — command card for new units
- Modify: `scripts/rts_stage/rts_selection_panel.gd` — display new unit info
- Modify: `scripts/rts_stage/rts_contextual_tips.gd` — tip about new units

**What to do:**

Voice generators in `synth_sounds.gd`:
- `gen_rts_voice_medic(type)` — soft, harmonic, gentle chirp (select/ack/attack)
- `gen_rts_voice_siege(type)` — deep, rumbling, heavy impact (select/ack/attack)
- `gen_rts_voice_psi(type)` — ethereal, shimmering, crystalline (select/ack/attack)
- Follow pattern of existing `gen_rts_voice_worker/fighter/defender/scout/ranged`

Audio buffers in `audio_manager.gd`:
- `_buf_rts_voice_medic_select/ack/attack` (3 buffers)
- `_buf_rts_voice_siege_select/ack/attack` (3 buffers)
- `_buf_rts_voice_psi_select/ack/attack` (3 buffers)
- Play functions: `play_rts_voice_medic(type)`, etc.

HUD command card:
- Medic selected: Show Heal toggle in slot, Regen Aura as V ability
- Siege Worm selected: Show Deploy/Undeploy toggle, Burrow Bomb as V ability
- Psi-Caster selected: Show Neural Disruption as V ability
- Add to `_get_military_command_set()` with unit_type checks

Selection panel: Add unit type icons for Medic (white cross), Siege Worm (segmented circle), Psi-Caster (purple eye).

Contextual tip: "New unit types available! Medics heal allies, Siege Worms deal AoE damage when deployed, and Psi-Casters debuff enemies."

**Commit:** `feat(rts): add voice lines, HUD commands, and tips for new units`

---

## Group C: Map System

### Task 7: Refactor petri_dish_map.gd into base class

**Files:**
- Modify: `scripts/rts_stage/petri_dish_map.gd`

**What to do:**

Extract a virtual interface that new maps will override. Add these virtual methods:
```gdscript
func get_map_name() -> String: return "Petri Dish"
func get_map_description() -> String: return "Circular arena..."
func get_map_bounds_type() -> String: return "circle"  # or "rect" or "polygon"
func get_map_radius() -> float: return MAP_RADIUS  # For circular maps
func get_map_rect() -> Rect2: return Rect2()  # For rectangular maps
func get_spawn_positions() -> Array: return spawn_positions
func get_background_color() -> Color: return Color(0.03, 0.05, 0.08)
func get_particle_colors() -> Array: return [Color(0.2, 0.8, 0.3), Color(0.3, 0.5, 0.9), Color(0.6, 0.3, 0.8)]
```

Make `spawn_resources()` call virtual helper methods:
```gdscript
func _get_resource_layout() -> Array  # Returns [{pos, type, amount}]
func _get_obstacle_layout() -> Array  # Returns [{pos, radius}]
func _get_npc_layout() -> Array  # Returns [{pos, count}]
func _get_terrain_zone_layout() -> Array  # Returns [{pos, radius, elevation}]
```

Keep all existing Petri Dish behavior as the default implementation. New maps override virtual methods.

Also update `is_within_bounds()` and `clamp_to_bounds()` to use `get_map_bounds_type()` and support non-circular maps.

**Commit:** `refactor(rts): extract map base class interface from petri_dish_map.gd`

---

### Task 8: Create Blood Vessel map

**Files:**
- Create: `scripts/rts_stage/blood_vessel_map.gd`

**What to do:**

Extend the refactored `petri_dish_map.gd` (or use same script pattern — standalone Node2D with same interface).

Map shape: Elongated oval, 12000 x 4000. Use `get_map_bounds_type() -> "rect"` with Rect2(-6000, -2000, 12000, 4000).

Layout generation:
- 3 horizontal lanes at y = -1200, 0, +1200 (each 600u wide)
- 4 vertical capillary passages connecting lanes (at x = -3000, -1000, +1000, +3000, each 400u wide)
- Walls between lanes (obstacles blocking movement except at capillaries)
- Resources at lane intersections (6 rich nodes at capillary-lane crosses)
- Starter resources near each spawn (4 per spawn, 200u radius)

Spawns: 2 factions at left end (x=-5000, y=±1200), 2 at right end (x=+5000, y=±1200).

Terrain zones: 4 elevated ridges along the vessel walls (high ground flanking).

Visual theme:
- Background: dark crimson `Color(0.08, 0.02, 0.02)`
- Vessel walls: pulsing red-pink (`Color(0.4, 0.1, 0.1)` with sine-wave pulse)
- Flowing particles: red blood cells (small circles moving left-to-right)
- Capillary passages: slightly brighter floor tint

Override `_draw()` to render vessel walls, lane floors, flowing current particles.

**Commit:** `feat(rts): add Blood Vessel map with lane-based layout`

---

### Task 9: Create Brain Cortex map

**Files:**
- Create: `scripts/rts_stage/brain_cortex_map.gd`

**What to do:**

Map shape: Irregular blob ~10000x10000. Use `get_map_bounds_type() -> "polygon"` with a pre-defined polygon of ~16 vertices forming brain-fold edges.

Layout generation:
- Central plateau: circular area r=2500 at center (high ground)
- 6 gyri (ridges): semicircular bumps at edges (r=1500 each), evenly spaced at 60-degree intervals, each contains 1 rich resource node (300 biomass) + 2 medium nodes
- Sulci (valleys): narrow passages (400u wide) between gyri (low ground)
- Scattered resources: 20 small nodes across open central area
- Obstacles: Dendrite formations (organic-looking clusters of small circles)
- NPC pockets: 4 clusters in sulci valleys

Spawns: 4 corners of the map boundary.

Terrain zones: Central plateau = elevation 2 (high ground), gyri = elevation 1, sulci = elevation 0 (low ground). 8 total zones.

Visual theme:
- Background: grey-pink `Color(0.06, 0.04, 0.05)`
- Neural tissue floor: organic folds drawn as overlapping arcs
- Synapse sparks: occasional bright flashes between dendrite obstacles
- Particles: small dot-like neurotransmitters drifting

**Commit:** `feat(rts): add Brain Cortex map with open plateau layout`

---

### Task 10: Update rts_stage_manager.gd and navigation for multi-map

**Files:**
- Modify: `scripts/rts_stage/rts_stage_manager.gd`
- Modify: `scripts/rts_stage/rts_terrain_zones.gd`

**What to do:**

Add map selection support to stage manager:
```gdscript
var _map_id: String = "petri_dish"  # Set by pre-game screen via GameManager

func _create_map() -> Node2D:
    match _map_id:
        "blood_vessel": return BloodVesselMap.new()
        "brain_cortex": return BrainCortexMap.new()
        _: return PetriDishMap.new()
```

Replace hardcoded `PetriDishMap.new()` with `_create_map()`.

Update navigation region to match map bounds (use map's bounds type — polygon for Brain Cortex, rectangular for Blood Vessel, circular for Petri Dish).

Update terrain zones to receive zone layout from map (`map.get_terrain_zone_layout()`).

Add `GameManager.rts_map_id: String = "petri_dish"` for the pre-game screen to set.

AI director: Add map awareness — read `_map_id` and adjust:
- Blood Vessel: `_aggression_threshold += 2` (need more units for lane control), prefer towers at chokes
- Brain Cortex: `_aggression_threshold -= 1` (early fighting expected), prefer expansion

**Commit:** `feat(rts): wire multi-map support into stage manager and AI`

---

## Group D: Pre-Game Screen

### Task 11: Create pre-game setup screen

**Files:**
- Create: `scripts/rts_stage/rts_pregame.gd`
- Modify: `scripts/autoload/game_manager.gd` — add `rts_map_id`, `rts_difficulty`, `rts_ai_count`

**What to do:**

Create `rts_pregame.gd` as a CanvasLayer (layer=15) with procedural `_draw()` UI (matching existing UI pattern — no scene files).

Layout:
- Title: "COLONY WARS" centered at top
- Map selection: 3 cards side by side (each ~200x150), showing map name + 1-line description + simple thumbnail sketch (drawn procedurally — circle for Petri Dish, oval for Blood Vessel, blob for Brain Cortex)
- Selected map highlighted with green border
- Difficulty: 5 buttons in a row (NOOB through SWEATY), selected highlighted
- AI Count: 3 buttons (1, 2, 3 opponents)
- "START" button at bottom center (large, pulsing green)
- "BACK" button at bottom left

Input handling:
- Click map card → set `GameManager.rts_map_id`
- Click difficulty → set `GameManager.rts_difficulty`
- Click AI count → set `GameManager.rts_ai_count`
- Click START → hide pregame, start RTS stage
- Click BACK → return to main menu
- ESC → return to main menu

Wire into main menu: The existing main menu button for Colony Wars should show this screen instead of immediately starting the RTS stage.

Store in GameManager:
```gdscript
var rts_map_id: String = "petri_dish"
var rts_difficulty: int = 2  # MEDIUM
var rts_ai_count: int = 3
```

Stage manager reads these in `_ready()` to configure the match.

**Commit:** `feat(rts): add pre-game setup screen with map/difficulty/AI selection`

---

## Group E: Save/Load System

### Task 12: Add serialize/deserialize to all game objects

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd` — `serialize() -> Dictionary`, `deserialize(data)`
- Modify: `scripts/rts_stage/rts_building.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/resource_node.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/rts_tech_tree.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/resource_manager.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/rts_fog_of_war.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/ai_director.gd` — `serialize()`, `deserialize()`
- Modify: `scripts/rts_stage/rts_map_events.gd` — `serialize()`, `deserialize()`

**What to do:**

Each game object gets a `serialize() -> Dictionary` that captures its full state, and a `deserialize(data: Dictionary)` that restores it.

Unit serialize pattern:
```gdscript
func serialize() -> Dictionary:
    return {
        "type": unit_type, "faction": faction_id,
        "pos_x": global_position.x, "pos_y": global_position.y,
        "health": health, "state": _state, "stance": stance,
        "xp": _xp, "vet_level": _vet_level,
        "carried_biomass": carried_biomass, "carried_genes": carried_genes,
        "ability_cooldown": _ability_cooldown_timer,
        "is_deployed": _is_deployed,
        "command_queue": _serialize_command_queue(),
    }
```

Building serialize pattern:
```gdscript
func serialize() -> Dictionary:
    return {
        "type": building_type, "faction": faction_id,
        "pos_x": global_position.x, "pos_y": global_position.y,
        "health": health, "construction_progress": construction_progress,
        "production_queue": _production_queue.duplicate(),
        "research_queue": _research_queue.duplicate(),
        "rally_x": _rally_point.x, "rally_y": _rally_point.y,
    }
```

Resource node: `{pos_x, pos_y, type, amount_remaining}`
Tech tree: `{faction_upgrades, faction_building_upgrades, faction_tier}` (already dictionaries)
Resource manager: `{faction_resources}` dict of faction_id -> {biomass, genes}
Fog of war: `{grid_data}` (the visibility grid as flat array)
AI director: `{phase, faction_id, difficulty, personality, timers, army_composition_targets}`
Map events: `{next_event_timer, event_history}`

**Commit:** `feat(rts): add serialize/deserialize to all game objects`

---

### Task 13: Create rts_save_manager.gd

**Files:**
- Create: `scripts/rts_stage/rts_save_manager.gd`

**What to do:**

Save manager that collects state from all game objects and writes/reads JSON.

```gdscript
func save_game(slot_name: String) -> bool:
    var data: Dictionary = {
        "version": 1,
        "timestamp": Time.get_unix_time_from_system(),
        "map_id": _stage._map_id,
        "difficulty": _stage._difficulty,
        "game_time": _stage._victory_manager.get_game_time(),
        "camera": {"x": camera.global_position.x, "y": camera.global_position.y, "zoom": camera.zoom.x},
        "resources": _stage._resource_manager.serialize(),
        "tech_tree": _stage._tech_tree.serialize(),
        "fog": _stage._fog_of_war.serialize(),
        "map_events": _stage._map_events.serialize(),
        "units": [],
        "buildings": [],
        "resource_nodes": [],
        "ai_directors": [],
    }
    # Iterate all units/buildings/resources and append their serialize()
    for unit in get_tree().get_nodes_in_group("rts_units"):
        data.units.append(unit.serialize())
    # ... similar for buildings, resources, AI directors

    var path: String = "user://saves/%s.json" % slot_name
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
    return true

func load_game(slot_name: String) -> bool:
    var path: String = "user://saves/%s.json" % slot_name
    var file := FileAccess.open(path, FileAccess.READ)
    var data: Dictionary = JSON.parse_string(file.get_as_text())
    file.close()
    # Clear current game state
    _clear_all_game_objects()
    # Restore map, resources, tech, fog
    # Recreate all units/buildings/resources from data
    # Restore AI directors
    return true
```

Auto-save: Timer in `_process()`, saves every 300s to `"auto_save_1"`, rotates to `"auto_save_2"`, `"auto_save_3"`.

Quicksave: F5 → `save_game("quicksave")`, F9 → `load_game("quicksave")`.

List saves: `get_save_list() -> Array[Dictionary]` — scans `user://saves/` for JSON files, returns name + timestamp.

**Commit:** `feat(rts): create save/load manager with auto-save and quicksave`

---

### Task 14: Wire save/load into pause menu

**Files:**
- Modify: `scripts/rts_stage/rts_pause_menu.gd`

**What to do:**

Add "Save Game" and "Load Game" buttons to the pause menu.

Save: Opens a save slot picker (3 manual slots + quicksave), confirm overwrites.
Load: Opens save list showing all saves (manual + auto + quicksave) with timestamps. Click to load, confirm dialog.

Hotkeys: F5 (quicksave), F9 (quickload) handled in `rts_input_handler.gd` — call `_save_manager.save_game("quicksave")` / `_save_manager.load_game("quicksave")`.

Show brief "Game Saved" / "Game Loaded" toast notification (center screen, 2s fade).

**Commit:** `feat(rts): add save/load buttons to pause menu with F5/F9 hotkeys`

---

### Task 15: Add "Load Game" option to pre-game screen

**Files:**
- Modify: `scripts/rts_stage/rts_pregame.gd`

**What to do:**

Add "LOAD GAME" button next to "START" on the pre-game screen. Shows save list overlay when clicked. Selecting a save starts the RTS stage in load mode (stage manager checks `GameManager.rts_load_save` and calls `_save_manager.load_game()` after initialization).

**Commit:** `feat(rts): add Load Game option to pre-game screen`

---

## Group F: Replay System

### Task 16: Create rts_replay_recorder.gd

**Files:**
- Create: `scripts/rts_stage/rts_replay_recorder.gd`

**What to do:**

Records every command issued during a match as a timestamped event stream.

```gdscript
var _events: Array = []  # [{time, type, data}]
var _recording: bool = true

func record_event(event_type: String, data: Dictionary) -> void:
    if not _recording:
        return
    _events.append({
        "time": _game_time,
        "type": event_type,
        "data": data,
    })
```

Event types to record:
- `"move"`: `{units: [ids], target_x, target_y}`
- `"attack"`: `{units: [ids], target_id}`
- `"attack_move"`: `{units: [ids], target_x, target_y}`
- `"build"`: `{worker_id, building_type, pos_x, pos_y}`
- `"produce"`: `{building_id, unit_type}`
- `"research"`: `{building_id, upgrade_id}`
- `"ability"`: `{unit_id, target_x, target_y}`
- `"rally"`: `{building_id, pos_x, pos_y}`

Hook into `command_system.gd` signals to capture all player AND AI commands.

Save replay: `save_replay(name: String)` — writes `_events` + initial game state (map_id, difficulty, spawn positions, random seed) to JSON.

Auto-record: Starts recording on match start, saves to ring buffer of last 10 replays at match end.

**Commit:** `feat(rts): create replay event recorder`

---

### Task 17: Create rts_replay_player.gd

**Files:**
- Create: `scripts/rts_stage/rts_replay_player.gd`

**What to do:**

Replays a recorded match by re-issuing commands at their recorded timestamps.

```gdscript
var _events: Array = []
var _event_index: int = 0
var _playback_time: float = 0.0
var _playback_speed: float = 1.0
var _is_playing: bool = false
var _is_paused: bool = false

func _process(delta: float) -> void:
    if not _is_playing or _is_paused:
        return
    _playback_time += delta * _playback_speed
    while _event_index < _events.size() and _events[_event_index].time <= _playback_time:
        _execute_event(_events[_event_index])
        _event_index += 1
    if _event_index >= _events.size():
        _is_playing = false  # Replay complete
```

`_execute_event()` dispatches to command_system based on event type.

Playback controls:
- Play/Pause toggle
- Speed: 1x/2x/4x/8x (buttons)
- Timeline scrubber: Click to jump (requires save/load to reconstruct state — simplified approach: only support forward playback, scrubbing reloads initial state and fast-forwards)

Replay mode differences:
- Fog of war disabled (see everything)
- Player cannot issue commands
- Free camera (not locked to player faction)
- "REPLAY" watermark in corner

**Commit:** `feat(rts): create replay playback system with speed controls`

---

### Task 18: Wire replay into end-of-match and pre-game

**Files:**
- Modify: `scripts/rts_stage/rts_stats_screen.gd` — "Save Replay" button
- Modify: `scripts/rts_stage/rts_pregame.gd` — "Watch Replay" button
- Modify: `scripts/rts_stage/rts_stage_manager.gd` — replay mode flag

**What to do:**

Stats screen: Add "Save Replay" button that saves the auto-recorded replay with a name.

Pre-game: Add "WATCH REPLAY" button that opens replay list. Selecting a replay starts the stage in replay mode.

Stage manager: Check `GameManager.rts_replay_file` — if set, initialize in replay mode (create replay_player, disable player input, start playback).

**Commit:** `feat(rts): wire replay save/load into stats screen and pre-game`

---

## Group G: AI Faction Personalities

### Task 19: Add personality enum and composition targets to ai_director.gd

**Files:**
- Modify: `scripts/rts_stage/ai_director.gd`

**What to do:**

Add personality enum:
```gdscript
enum Personality { ADAPTIVE, SWARM, BULWARK, PREDATOR }
```

Add `_personality: Personality` variable, set based on faction_id in `setup()`:
- faction 1 → SWARM, faction 2 → BULWARK, faction 3 → PREDATOR

Add personality-driven composition targets:
```gdscript
const PERSONALITY_COMPOSITION: Dictionary = {
    Personality.SWARM: {
        UnitStats.UnitType.FIGHTER: 0.70, UnitStats.UnitType.SCOUT: 0.20,
        UnitStats.UnitType.RANGED: 0.10,
    },
    Personality.BULWARK: {
        UnitStats.UnitType.DEFENDER: 0.40, UnitStats.UnitType.SIEGE_WORM: 0.25,
        UnitStats.UnitType.RANGED: 0.20, UnitStats.UnitType.MEDIC: 0.10,
        UnitStats.UnitType.FIGHTER: 0.05,
    },
    Personality.PREDATOR: {
        UnitStats.UnitType.SCOUT: 0.30, UnitStats.UnitType.RANGED: 0.25,
        UnitStats.UnitType.PSI_CASTER: 0.20, UnitStats.UnitType.FIGHTER: 0.15,
        UnitStats.UnitType.SIEGE_WORM: 0.10,
    },
}
```

Replace current unit selection logic in `_produce_combat_unit()` with personality-weighted random selection: pick unit type based on composition ratios vs current army composition.

**Commit:** `feat(rts): add AI personality enum and composition targets`

---

### Task 20: Implement personality-driven build order and tech path

**Files:**
- Modify: `scripts/rts_stage/ai_director.gd`

**What to do:**

Override build priorities per personality:

SWARM:
- `_do_opening()`: Rush to 6 workers, skip Nutrient Processor, build Evolution Chamber at worker 4
- `_do_expansion()`: Build second Evolution Chamber, mass Fighters, 1 tower max
- Tech priority: Metabolic Boost → Sharpened Cilia → Berserker Enzymes
- Never builds Bio-Walls or Supply Depots beyond minimum

BULWARK:
- `_do_opening()`: 5 workers, early Nutrient Processor, Bio-Wall ring around base
- `_do_expansion()`: 3+ towers before Evolution Chamber, second Nutrient Processor
- Tech priority: Hardened Membranes → Spine Tower → Hive Mind → Regenerative Tissue
- Builds Bio-Walls at every expansion

PREDATOR:
- `_do_opening()`: 4 workers, fast Scout production
- `_do_expansion()`: Split army into 2-3 groups, send Scouts to all corners
- Tech priority: Extended Pseudopods → Apex Predator → Rapid Mitosis
- Minimal towers, maximum mobility

Add `_get_tech_priority() -> Array[int]` per personality — returns ordered list of UpgradeId to research.

**Commit:** `feat(rts): implement personality-driven build orders and tech paths`

---

### Task 21: Implement personality-driven attack patterns

**Files:**
- Modify: `scripts/rts_stage/ai_director.gd`

**What to do:**

Override attack timing and behavior per personality:

SWARM:
- `_attack_interval = 90.0` (constant pressure)
- Sends waves as soon as `combat_units >= 4` (not waiting for full army)
- All-in: never retreats, always sends everything
- Targets closest enemy buildings

BULWARK:
- `_attack_interval = 300.0` (wait for deathball)
- Only attacks when `combat_units >= 12` AND has T3 research
- Attacks in single massive group, targets main base directly
- Retreats if army drops below 50%

PREDATOR:
- `_attack_interval = 60.0` (constant harassment)
- Splits army into 2-3 raid groups of 3-5 units each
- Targets workers and resource depots (not main army)
- Retreats each raid group after 10s of combat
- `_split_army_into_raids()` — divides units into groups, sends to different targets

Add `_execute_personality_attack()` that branches based on `_personality`.

Add taunt flavor per personality:
- SWARM: aggressive taunts ("SWARM! CONSUME!", "Your walls crumble before our numbers")
- BULWARK: patient taunts ("Your time grows short", "Our fortress is complete")
- PREDATOR: mocking taunts ("Your workers scatter like prey", "We strike from every shadow")

**Commit:** `feat(rts): implement personality-driven attack patterns and taunts`

---

## Group H: Unit Stances

### Task 22: Implement stance system in rts_unit.gd

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd`

**What to do:**

The Stance enum already exists (`AGGRESSIVE=0, DEFENSIVE=1, PASSIVE=2`). Wire it into behavior:

In `_find_best_target()`:
- If `stance == Stance.PASSIVE`: return null (never auto-acquire targets)
- If `stance == Stance.DEFENSIVE`: only return targets that have attacked this unit recently (check `_last_attacker` var, set in `take_damage()`)
- If `stance == Stance.AGGRESSIVE`: current behavior (scan full detection range)

In movement/chase logic:
- `Stance.DEFENSIVE`: Add `_anchor_position: Vector2` set when unit stops moving. If chasing an enemy and distance from anchor > 80u, disengage and return to anchor.
- `Stance.AGGRESSIVE`: Current behavior (chase indefinitely).

Add `cycle_stance()` function:
```gdscript
func cycle_stance() -> void:
    stance = (stance + 1) % 3 as Stance
    _anchor_position = global_position
```

Draw stance indicator on unit (already partially exists — letter A/D/P):
- A = red, D = yellow, P = grey, drawn below unit circle

**Commit:** `feat(rts): implement unit stance behavior (aggressive/defensive/passive)`

---

### Task 23: Wire stance hotkey and HUD display

**Files:**
- Modify: `scripts/rts_stage/rts_input_handler.gd` — G key cycles stance
- Modify: `scripts/rts_stage/rts_hud.gd` — stance button in command card
- Modify: `scripts/rts_stage/rts_selection_panel.gd` — stance indicator

**What to do:**

Input handler: G key → for all selected units, call `unit.cycle_stance()`. Play UI click sound.

HUD command card: Replace empty slot in MILITARY_CMD/WORKER_CMD with stance button:
```gdscript
{"label": "Stance", "hotkey": "G", "tooltip": "Cycle Stance (G): Aggressive/Defensive/Passive", "action": "stance"},
```

Selection panel: Show current stance name and icon next to unit name. If multi-select with mixed stances, show "Mixed".

**Commit:** `feat(rts): wire stance hotkey (G) and HUD display`

---

## Group I: Superweapon

### Task 24: Implement Singularity Core building behavior

**Files:**
- Modify: `scripts/rts_stage/rts_building.gd`

**What to do:**

Add Singularity Core behavior (check `building_type == BuildingStats.BuildingType.SINGULARITY_CORE`):

State vars:
```gdscript
var _singularity_charge: float = 0.0  # 0 to 60
var _singularity_cooldown: float = 0.0  # 180s after firing
var _singularity_charging: bool = false
```

Charge mechanic:
- Player clicks "Charge" button (or auto-charges when complete)
- Charging: `_singularity_charge += delta` each frame
- At 60s: ready to fire. "FIRE" button appears.
- If building destroyed during charge: charge resets to 0

Fire mechanic (`_fire_singularity_pulse()`):
- Deal 80 damage to ALL enemy units on the map
- Apply 40% slow to all enemy units for 8s (set metadata `singularity_slow`)
- Set cooldown to 180s
- VFX: Screen-wide pulse wave expanding from Core position
- Audio: Deep bass boom + shimmering echo

Minimap indicator: While charging, draw pulsing red circle at Core position visible to all factions.

Visual: Core drawn as large pulsing orb with energy tendrils. Charge progress shown as filling ring.

Add to `_draw()` in `rts_building.gd` — special case for SINGULARITY_CORE.

Limit 1 per player: Check in `build_ghost.gd` `_check_validity()` — count existing SINGULARITY_CORE buildings for faction.

**Commit:** `feat(rts): implement Singularity Core building with charge and fire mechanics`

---

### Task 25: Wire superweapon into AI, HUD, and tech tree gate

**Files:**
- Modify: `scripts/rts_stage/ai_director.gd` — AI builds Core in ENDGAME
- Modify: `scripts/rts_stage/rts_hud.gd` — command card for Singularity Core
- Modify: `scripts/rts_stage/rts_tech_tree.gd` — gate check (all T3 researched)
- Modify: `scripts/rts_stage/build_ghost.gd` — unlock check

**What to do:**

Tech tree gate: Add `func can_build_singularity(faction_id: int) -> bool` — returns true if faction has ALL 3 Tier 3 upgrades (BERSERKER_ENZYMES, HIVE_MIND, APEX_PREDATOR).

Build ghost: In `_check_validity()`, if building_type is SINGULARITY_CORE:
- Check tech tree gate: `stage._tech_tree.can_build_singularity(faction_id)`
- Check max 1 per player

HUD command card for Singularity Core building:
- Slot 0: "Charge" button (starts charging, disabled if cooling down or already charging)
- Slot 1: "Fire" button (enabled only when fully charged)
- Show charge progress bar and cooldown timer

AI: In ENDGAME phase, if `can_build_singularity()` and no Core exists, build one. When charged, fire at optimal time.

**Commit:** `feat(rts): wire superweapon into AI, HUD, and tech tree gate`

---

## Group J: Dynamic Music

### Task 26: Create rts_music.gd procedural music system

**Files:**
- Create: `scripts/rts_stage/rts_music.gd`

**What to do:**

Procedural music engine using AudioStreamGenerator (matching existing SynthSounds pattern).

State machine: CALM → TENSION → COMBAT, with 3s crossfade.

State transitions:
- CALM: No combat for 30s, no threats visible
- TENSION: Enemy units spotted by fog of war, OR building under attack, OR threat alert active
- COMBAT: 3+ friendly units actively in combat (attacking or being attacked)

Procedural layers (each generates ~1s of audio buffer, looped):

**CALM layer:**
- Deep drone: sine wave at 45Hz, slow LFO modulation (0.1Hz) on amplitude
- Ambient bubbles: Random sine pings at 400-800Hz, 0.05-0.1s duration, every 0.5-2s
- Pad: Filtered sawtooth at 90Hz, very low amplitude, slow filter sweep

**TENSION layer:**
- Pulsing rhythm: Kick-like sine at 60Hz, 0.1s duration, every 0.8s beat
- Rising harmonics: Sawtooth sweep from 200Hz to 800Hz over 4s, repeating
- Staccato notes: Short triangle pings on beat subdivisions

**COMBAT layer:**
- Driving beat: Kick (60Hz sine, 0.05s) + snare (noise burst, 0.03s), 140 BPM
- Aggressive bass: Square wave at 55Hz with fast LFO on pitch
- Lead: Saw wave melody — simple 4-note pattern cycling, per-map pitch offset

Per-map tonal flavor:
- Petri Dish: Base frequencies, cool/blue filter (slight high-cut)
- Blood Vessel: Frequencies shifted up 10%, warmer (resonant low-mid boost)
- Brain Cortex: Frequencies shifted down 5%, eerie (detuned oscillators, wider vibrato)

Integration:
- Created by stage manager after map
- Reads combat state from stage manager's unit groups
- Uses AudioStreamGenerator + AudioStreamGeneratorPlayback (same as cell_ambient_generator.gd)

**Commit:** `feat(rts): create procedural dynamic music system with 3 intensity layers`

---

### Task 27: Wire music to game state and add victory/defeat jingles

**Files:**
- Modify: `scripts/rts_stage/rts_stage_manager.gd` — create music system, update state
- Modify: `scripts/audio/synth_sounds.gd` — victory fanfare + defeat drone generators
- Modify: `scripts/autoload/audio_manager.gd` — victory/defeat buffers

**What to do:**

Stage manager: Create `_music` (rts_music instance) in `_ready()`. In `_process()`, update music state based on combat activity.

Victory fanfare (`SynthSounds.gen_rts_victory_fanfare()`):
- 2s duration
- Ascending major arpeggio (C4-E4-G4-C5) on bright saw+sine mix
- Each note 0.3s with overlap
- Reverb tail (decaying echo)

Defeat drone (`SynthSounds.gen_rts_defeat_drone()`):
- 3s duration
- Descending minor chord (Am → Dm) on filtered saw
- Slow fade-out
- Low rumble undertone

AudioManager: Add `_buf_rts_victory` and `_buf_rts_defeat`, play on game over.

Music fades out over 2s when game ends, then fanfare/drone plays.

**Commit:** `feat(rts): wire music to game state, add victory/defeat jingles`

---

## Group K: Polish Grab-Bag

### Task 28: Worker multi-build (multiple workers speed up construction)

**Files:**
- Modify: `scripts/rts_stage/rts_building.gd`
- Modify: `scripts/rts_stage/rts_unit.gd`

**What to do:**

In `rts_building.gd`, track builders:
```gdscript
var _active_builders: int = 0  # Count of workers currently building this

func get_build_speed_multiplier() -> float:
    # First worker = 1.0x, each additional = +0.5x (diminishing)
    if _active_builders <= 1:
        return 1.0
    return 1.0 + (_active_builders - 1) * 0.5
```

In `rts_unit.gd` BUILD state: Register with building when starting (`building._active_builders += 1`), deregister when stopping or reassigned. Building applies multiplier to construction progress.

**Commit:** `feat(rts): allow multiple workers to speed up building construction`

---

### Task 29: Voice pitch variety (3 variants per unit type)

**Files:**
- Modify: `scripts/audio/synth_sounds.gd`
- Modify: `scripts/autoload/audio_manager.gd`

**What to do:**

For each existing RTS voice generator, add pitch_mult parameter:
```gdscript
static func gen_rts_voice_worker(type: String, pitch_mult: float = 1.0) -> PackedFloat32Array:
    # Existing code but multiply all frequencies by pitch_mult
```

Generate 3 variants per unit type at pitch multipliers 0.85, 1.0, 1.15. Store as `_buf_rts_voice_worker_select_0/1/2`.

When playing voice, pick random variant (0-2):
```gdscript
func play_rts_voice(unit_type: int, voice_type: String) -> void:
    var variant: int = randi() % 3
    # Play the variant buffer
```

**Commit:** `feat(rts): add 3 pitch variants per unit voice for variety`

---

### Task 30: Victory/defeat screen enhancement

**Files:**
- Modify: `scripts/rts_stage/rts_overlay.gd`

**What to do:**

Enhance the game-over overlay:
- Victory: Green pulsing "VICTORY" title, particle burst effect, army stats summary
- Defeat: Red dim "DEFEATED" title, fade-to-dark effect
- Both: "View Stats" button (opens stats screen), "Save Replay" button, "Return to Menu" button

**Commit:** `feat(rts): enhance victory/defeat screen with effects and buttons`

---

### Task 31: Hotkey reference card (H key toggle)

**Files:**
- Modify: `scripts/rts_stage/rts_hud.gd` (add overlay section in `_draw()`)
- Modify: `scripts/rts_stage/rts_input_handler.gd` (H key toggle)

**What to do:**

Add `_show_hotkey_card: bool = false` toggle.

H key: Toggle the card on/off.

Draw a semi-transparent overlay (right side of screen, 300px wide) listing all hotkeys in categories:

```
HOTKEY REFERENCE (H to close)

CAMERA: WASD/Arrow/Edge scroll, Scroll=Zoom, HOME=Base
SELECT: LMB=Select, Shift=Add, Ctrl+A=Military, .=Idle Worker, ,=Idle Military
COMMANDS: RMB=Context, A=Attack Move, P=Patrol, S=Stop, H=Hold
UNITS: G=Stance, V=Ability, F=Formation
BUILD: B=Build Menu, Q/W/E/R/T/Y/U=Buildings
GROUPS: Ctrl+1-9=Assign, 1-9=Select, Shift+#=Add, Alt+#=Steal
OTHER: TAB=Intel, F1=Production, F5=Quicksave, F9=Quickload, F10=Surrender, ESC=Pause
```

Use small font (FONT_TINY), organic panel background matching HUD aesthetic.

**Commit:** `feat(rts): add hotkey reference card overlay (H key)`

---

## Final Commit

After all groups complete:

```bash
git log --oneline -20  # Verify all commits landed
```

Verify by running the game and testing:
1. Pre-game screen → select each map → start game
2. Build Medic, Siege Worm, Psi-Caster → test abilities
3. F5 quicksave → make changes → F9 quickload → verify state restored
4. Play to completion → save replay → watch replay
5. Observe AI faction personalities (Swarm rushes, Bulwark turtles, Predator raids)
6. G key cycles stances, verify defensive/passive behavior
7. Research all T3 → build Singularity Core → charge → fire
8. H key shows hotkey card
9. Listen for dynamic music transitions (calm → tension → combat)
