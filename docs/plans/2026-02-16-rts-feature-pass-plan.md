# RTS Colony Stage Feature Pass - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring the RTS Colony Wars stage to full genre-standard quality with evolved bioluminescent UI, tech tree, unit abilities, veterancy, map events, formations, threat alerts, and production management.

**Architecture:** New standalone scripts for self-contained systems (tech tree, formations, map events, threat detection, damage numbers, production tab, selection panel). Heavy modifications to existing unit/building/HUD/AI scripts to integrate these systems. All UI is procedural `_draw()` with organic/bioluminescent aesthetic.

**Tech Stack:** Godot 4 GDScript, procedural `_draw()` UI, `SynthSounds` audio generation pattern, `NavigationAgent2D` pathfinding, group-based entity queries.

---

## Task Groups (Parallelizable)

These groups are independent and can be dispatched to parallel agents:
- **Group A**: Tech Tree + Building Upgrades (Tasks 1-2)
- **Group B**: Unit Abilities + Veterancy (Tasks 3-4)
- **Group C**: UI Overhaul - Selection Panel + Control Groups + Command Card (Tasks 5-7)
- **Group D**: HUD Evolution + Threat Alerts (Tasks 8-9)
- **Group E**: Map Events + Enhanced NPCs (Tasks 10-11)
- **Group F**: Formations + Shift-Queue (Tasks 12-13)
- **Group G**: Minimap + Damage Numbers + Production Tab (Tasks 14-16)
- **Group H**: Audio + AI Integration (Tasks 17-18)
- **Group I**: Wiring + Final Integration (Task 19, depends on all above)

---

### Task 1: Tech Tree System (`rts_tech_tree.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_tech_tree.gd`
- Modify: `scripts/rts_stage/rts_unit.gd` (stat application)
- Modify: `scripts/rts_stage/rts_building.gd` (research queue + building upgrades)

**Step 1: Create `rts_tech_tree.gd`**

Static data class + per-faction runtime state. Pattern matches `unit_stats.gd` / `building_stats.gd`.

```gdscript
class_name RtsTechTree
extends Node

enum UpgradeId {
	HARDENED_MEMBRANES = 0, METABOLIC_BOOST = 1, SHARPENED_CILIA = 2,
	REGENERATIVE_TISSUE = 3, EXTENDED_PSEUDOPODS = 4, RAPID_MITOSIS = 5,
	BERSERKER_ENZYMES = 6, HIVE_MIND = 7, APEX_PREDATOR = 8
}

enum BuildingUpgradeId {
	HATCHERY = 0, SPINE_TOWER = 1, REFINERY = 2
}

const UPGRADE_DATA: Dictionary = {
	UpgradeId.HARDENED_MEMBRANES: {
		"name": "Hardened Membranes", "tier": 1,
		"cost_biomass": 100, "cost_genes": 25, "research_time": 20.0,
		"description": "All units +2 armor",
		"effect": "armor_bonus", "value": 2.0
	},
	UpgradeId.METABOLIC_BOOST: {
		"name": "Metabolic Boost", "tier": 1,
		"cost_biomass": 100, "cost_genes": 25, "research_time": 20.0,
		"description": "All units +15% speed",
		"effect": "speed_mult", "value": 1.15
	},
	UpgradeId.SHARPENED_CILIA: {
		"name": "Sharpened Cilia", "tier": 1,
		"cost_biomass": 100, "cost_genes": 25, "research_time": 20.0,
		"description": "All units +3 damage",
		"effect": "damage_bonus", "value": 3.0
	},
	UpgradeId.REGENERATIVE_TISSUE: {
		"name": "Regenerative Tissue", "tier": 2,
		"cost_biomass": 200, "cost_genes": 50, "research_time": 30.0,
		"description": "Units regen 1 HP/s out of combat",
		"effect": "regen", "value": 1.0
	},
	UpgradeId.EXTENDED_PSEUDOPODS: {
		"name": "Extended Pseudopods", "tier": 2,
		"cost_biomass": 200, "cost_genes": 50, "research_time": 30.0,
		"description": "Melee +20 range, ranged +50 range",
		"effect": "range_bonus", "value_melee": 20.0, "value_ranged": 50.0
	},
	UpgradeId.RAPID_MITOSIS: {
		"name": "Rapid Mitosis", "tier": 2,
		"cost_biomass": 200, "cost_genes": 50, "research_time": 30.0,
		"description": "Unit production 25% faster",
		"effect": "production_speed", "value": 0.75
	},
	UpgradeId.BERSERKER_ENZYMES: {
		"name": "Berserker Enzymes", "tier": 3,
		"cost_biomass": 350, "cost_genes": 100, "research_time": 45.0,
		"description": "Units below 30% HP deal 2x damage",
		"effect": "berserker", "value": 2.0, "threshold": 0.3
	},
	UpgradeId.HIVE_MIND: {
		"name": "Hive Mind", "tier": 3,
		"cost_biomass": 350, "cost_genes": 100, "research_time": 45.0,
		"description": "Nearby units share +2 armor (max +6)",
		"effect": "hive_armor", "value": 2.0, "radius": 80.0, "max_stack": 6.0
	},
	UpgradeId.APEX_PREDATOR: {
		"name": "Apex Predator", "tier": 3,
		"cost_biomass": 350, "cost_genes": 100, "research_time": 45.0,
		"description": "Veterancy XP gain doubled",
		"effect": "xp_mult", "value": 2.0
	}
}

const BUILDING_UPGRADE_DATA: Dictionary = {
	BuildingUpgradeId.HATCHERY: {
		"name": "Hatchery", "target_building": 0, # SPAWNING_POOL
		"cost_biomass": 250, "cost_genes": 50, "research_time": 20.0,
		"description": "+10 supply, +1 queue slot",
		"supply_bonus": 10, "queue_bonus": 1
	},
	BuildingUpgradeId.SPINE_TOWER: {
		"name": "Spine Tower", "target_building": 2, # MEMBRANE_TOWER
		"cost_biomass": 150, "cost_genes": 30, "research_time": 15.0,
		"description": "+50% damage, +50 range",
		"damage_mult": 1.5, "range_bonus": 50.0
	},
	BuildingUpgradeId.REFINERY: {
		"name": "Refinery", "target_building": 4, # NUTRIENT_PROCESSOR
		"cost_biomass": 200, "cost_genes": 40, "research_time": 18.0,
		"description": "+50% gather rate nearby",
		"gather_mult": 1.5, "effect_radius": 200.0
	}
}

const TIER_REQUIREMENTS: Dictionary = {
	1: {"upgrades_needed": 0, "evolve_cost_biomass": 0, "evolve_cost_genes": 0},
	2: {"upgrades_needed": 1, "evolve_cost_biomass": 200, "evolve_cost_genes": 50},
	3: {"upgrades_needed": 3, "evolve_cost_biomass": 400, "evolve_cost_genes": 100}
}

# Per-faction state
var _faction_upgrades: Dictionary = {} # faction_id -> Array of UpgradeId
var _faction_building_upgrades: Dictionary = {} # faction_id -> Array of BuildingUpgradeId
var _faction_tier: Dictionary = {} # faction_id -> int (current max tier)

func setup(num_factions: int) -> void:
	for i in range(num_factions):
		_faction_upgrades[i] = []
		_faction_building_upgrades[i] = []
		_faction_tier[i] = 1

func has_upgrade(faction_id: int, upgrade_id: int) -> bool:
	return upgrade_id in _faction_upgrades.get(faction_id, [])

func has_building_upgrade(faction_id: int, upgrade_id: int) -> bool:
	return upgrade_id in _faction_building_upgrades.get(faction_id, [])

func get_faction_tier(faction_id: int) -> int:
	return _faction_tier.get(faction_id, 1)

func get_completed_count(faction_id: int) -> int:
	return _faction_upgrades.get(faction_id, []).size()

func can_research(faction_id: int, upgrade_id: int) -> bool:
	if has_upgrade(faction_id, upgrade_id):
		return false
	var data: Dictionary = UPGRADE_DATA[upgrade_id]
	return data["tier"] <= get_faction_tier(faction_id)

func can_unlock_tier(faction_id: int, tier: int) -> bool:
	if tier <= get_faction_tier(faction_id):
		return false
	var req: Dictionary = TIER_REQUIREMENTS[tier]
	return get_completed_count(faction_id) >= req["upgrades_needed"]

func complete_upgrade(faction_id: int, upgrade_id: int) -> void:
	if not has_upgrade(faction_id, upgrade_id):
		_faction_upgrades[faction_id].append(upgrade_id)

func complete_building_upgrade(faction_id: int, upgrade_id: int) -> void:
	if not has_building_upgrade(faction_id, upgrade_id):
		_faction_building_upgrades[faction_id].append(upgrade_id)

func unlock_tier(faction_id: int, tier: int) -> void:
	if tier > _faction_tier.get(faction_id, 1):
		_faction_tier[faction_id] = tier

func get_available_upgrades(faction_id: int) -> Array:
	var available: Array = []
	for uid in UPGRADE_DATA.keys():
		if can_research(faction_id, uid):
			available.append(uid)
	return available

# Stat modifiers - called by units to apply upgrade effects
func get_armor_bonus(faction_id: int) -> float:
	var bonus: float = 0.0
	if has_upgrade(faction_id, UpgradeId.HARDENED_MEMBRANES):
		bonus += UPGRADE_DATA[UpgradeId.HARDENED_MEMBRANES]["value"]
	return bonus

func get_speed_mult(faction_id: int) -> float:
	var mult: float = 1.0
	if has_upgrade(faction_id, UpgradeId.METABOLIC_BOOST):
		mult *= UPGRADE_DATA[UpgradeId.METABOLIC_BOOST]["value"]
	return mult

func get_damage_bonus(faction_id: int) -> float:
	var bonus: float = 0.0
	if has_upgrade(faction_id, UpgradeId.SHARPENED_CILIA):
		bonus += UPGRADE_DATA[UpgradeId.SHARPENED_CILIA]["value"]
	return bonus

func get_regen_rate(faction_id: int) -> float:
	if has_upgrade(faction_id, UpgradeId.REGENERATIVE_TISSUE):
		return UPGRADE_DATA[UpgradeId.REGENERATIVE_TISSUE]["value"]
	return 0.0

func get_range_bonus(faction_id: int, is_ranged: bool) -> float:
	if has_upgrade(faction_id, UpgradeId.EXTENDED_PSEUDOPODS):
		var data: Dictionary = UPGRADE_DATA[UpgradeId.EXTENDED_PSEUDOPODS]
		return data["value_ranged"] if is_ranged else data["value_melee"]
	return 0.0

func get_production_mult(faction_id: int) -> float:
	if has_upgrade(faction_id, UpgradeId.RAPID_MITOSIS):
		return UPGRADE_DATA[UpgradeId.RAPID_MITOSIS]["value"]
	return 1.0

func get_berserker_mult(faction_id: int, hp_ratio: float) -> float:
	if has_upgrade(faction_id, UpgradeId.BERSERKER_ENZYMES):
		var data: Dictionary = UPGRADE_DATA[UpgradeId.BERSERKER_ENZYMES]
		if hp_ratio <= data["threshold"]:
			return data["value"]
	return 1.0

func get_hive_armor(faction_id: int, nearby_count: int) -> float:
	if has_upgrade(faction_id, UpgradeId.HIVE_MIND):
		var data: Dictionary = UPGRADE_DATA[UpgradeId.HIVE_MIND]
		return minf(nearby_count * data["value"], data["max_stack"])
	return 0.0

func get_xp_mult(faction_id: int) -> float:
	if has_upgrade(faction_id, UpgradeId.APEX_PREDATOR):
		return UPGRADE_DATA[UpgradeId.APEX_PREDATOR]["value"]
	return 1.0
```

**Step 2: Add research queue to `rts_building.gd`**

Add these vars after the existing production queue vars:

```gdscript
var _research_queue: Array = [] # Array of UpgradeId or BuildingUpgradeId
var _research_timer: float = 0.0
var _current_research_time: float = 0.0
var _is_researching: bool = false
var _current_research_type: String = "" # "upgrade" or "building_upgrade"
var _building_upgrade_id: int = -1 # BuildingUpgradeId if upgraded
var _tech_tree: Node = null # RtsTechTree reference
```

Add methods:

```gdscript
func set_tech_tree(tree: Node) -> void:
	_tech_tree = tree

func queue_research(upgrade_id: int, is_building_upgrade: bool = false) -> bool:
	if _is_researching:
		return false
	var data: Dictionary
	if is_building_upgrade:
		data = RtsTechTree.BUILDING_UPGRADE_DATA[upgrade_id]
		_current_research_type = "building_upgrade"
	else:
		data = RtsTechTree.UPGRADE_DATA[upgrade_id]
		_current_research_type = "upgrade"
	_research_queue.append(upgrade_id)
	_current_research_time = data["research_time"]
	_research_timer = 0.0
	_is_researching = true
	return true

func _process_research(delta: float) -> void:
	if not _is_researching or _research_queue.is_empty():
		return
	_research_timer += delta
	if _research_timer >= _current_research_time:
		var uid: int = _research_queue.pop_front()
		if _current_research_type == "building_upgrade":
			if _tech_tree:
				_tech_tree.complete_building_upgrade(faction_id, uid)
			_building_upgrade_id = uid
			_apply_building_upgrade(uid)
		else:
			if _tech_tree:
				_tech_tree.complete_upgrade(faction_id, uid)
		_is_researching = false
		_research_timer = 0.0

func _apply_building_upgrade(uid: int) -> void:
	var data: Dictionary = RtsTechTree.BUILDING_UPGRADE_DATA[uid]
	if uid == RtsTechTree.BuildingUpgradeId.HATCHERY:
		supply_provided += data["supply_bonus"]
	elif uid == RtsTechTree.BuildingUpgradeId.SPINE_TOWER:
		attack_damage *= data["damage_mult"]
		attack_range += data["range_bonus"]
	# REFINERY effect is checked by workers at gather time

func get_research_progress() -> float:
	if not _is_researching or _current_research_time <= 0.0:
		return 0.0
	return _research_timer / _current_research_time

func is_upgraded() -> bool:
	return _building_upgrade_id >= 0

func get_upgrade_name() -> String:
	if _building_upgrade_id >= 0:
		return RtsTechTree.BUILDING_UPGRADE_DATA[_building_upgrade_id]["name"]
	return ""
```

Call `_process_research(delta)` from `_process()`.

**Step 3: Apply tech upgrades in `rts_unit.gd`**

Add a `_tech_tree: Node` var. In the unit's combat and movement methods, query the tech tree for modifiers:

- In `_process_move()`: multiply speed by `_tech_tree.get_speed_mult(faction_id)` if tech_tree exists
- In `_perform_attack()`: add `_tech_tree.get_damage_bonus(faction_id)` to damage, multiply by `_tech_tree.get_berserker_mult(faction_id, health/max_health)`
- In `take_damage()`: add `_tech_tree.get_armor_bonus(faction_id)` to armor calculation
- In idle/patrol states: apply regen if `_tech_tree.get_regen_rate(faction_id) > 0` and `_last_combat_time > 5.0`
- Add `_last_combat_time: float` var, reset to 0 on attack/take_damage, increment in `_process()`

**Step 4: Commit**

```
git add scripts/rts_stage/rts_tech_tree.gd
git commit -m "feat(rts): add tech tree system with 9 upgrades across 3 tiers + building upgrades"
```

---

### Task 2: Research UI in Command Card

**Files:**
- Modify: `scripts/rts_stage/rts_hud.gd` (research buttons when Evo Chamber selected)

**Step 1: Add research button rendering**

When a single Evolution Chamber is selected, the command card shows available upgrades instead of production buttons. Add to `_draw()` bottom-right section:

- If selected building is EVOLUTION_CHAMBER and is_complete:
  - Show available upgrades as buttons in the 3x4 grid
  - Each button: upgrade name + cost + tier indicator
  - Researching upgrade shows progress bar (DNA helix animation)
  - Grayed out if tier locked or insufficient resources
- If selected building has a building upgrade available (Spawning Pool, Tower, Processor):
  - Show "Upgrade to [name]" button in command card
  - Show cost, grayed if can't afford

**Step 2: Add research hotkeys to `rts_input_handler.gd`**

When Evo Chamber selected, number keys 1-9 map to upgrade slots. U key for building self-upgrade.

**Step 3: Commit**

```
git commit -m "feat(rts): add research UI to command card for Evolution Chamber and building upgrades"
```

---

### Task 3: Unit Abilities System

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd` (ability vars, cooldowns, execution)
- Modify: `scripts/rts_stage/unit_stats.gd` (ability definitions)
- Modify: `scripts/rts_stage/command_system.gd` (ability command)
- Modify: `scripts/rts_stage/rts_input_handler.gd` (V hotkey)

**Step 1: Add ability data to `unit_stats.gd`**

Add to each unit's UNIT_DATA dict:

```gdscript
# FIGHTER
"ability_name": "Charge", "ability_cooldown": 12.0,
"ability_range": 150.0, "ability_damage_mult": 2.5, "ability_stun": 0.5,

# DEFENDER
"ability_name": "Fortify", "ability_cooldown": 20.0,
"ability_duration": 5.0, "ability_armor_bonus": 8.0, "ability_taunt_radius": 120.0,

# SCOUT
"ability_name": "Emit Spores", "ability_cooldown": 15.0,
"ability_reveal_radius": 400.0, "ability_reveal_duration": 8.0,

# RANGED
"ability_name": "Acid Volley", "ability_cooldown": 18.0,
"ability_projectile_count": 3, "ability_damage_mult": 0.75,

# WORKER
"ability_name": "Burst Gather", "ability_cooldown": 30.0,
"ability_duration": 5.0, "ability_gather_mult": 3.0,
```

**Step 2: Add ability state to `rts_unit.gd`**

```gdscript
var _ability_cooldown_timer: float = 0.0
var _ability_cooldown_max: float = 0.0
var _ability_active: bool = false
var _ability_timer: float = 0.0
var _ability_duration: float = 0.0
var _is_fortified: bool = false
var _is_burst_gathering: bool = false
var _is_stunned: bool = false
var _stun_timer: float = 0.0
var _veterancy_cooldown_reduction: float = 1.0 # multiplied by vet bonus
```

**Step 3: Implement each ability**

```gdscript
func can_use_ability() -> bool:
	return _ability_cooldown_timer <= 0.0 and not _is_stunned and unit_type != UnitStats.UnitType.WORKER or (unit_type == UnitStats.UnitType.WORKER and state == State.GATHER)

func use_ability(target_pos: Vector2 = Vector2.ZERO) -> void:
	if not can_use_ability():
		return
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	_ability_cooldown_timer = stats.get("ability_cooldown", 10.0) * _veterancy_cooldown_reduction
	_ability_cooldown_max = _ability_cooldown_timer
	match unit_type:
		UnitStats.UnitType.FIGHTER:
			_execute_charge(target_pos)
		UnitStats.UnitType.DEFENDER:
			_execute_fortify()
		UnitStats.UnitType.SCOUT:
			_execute_spores()
		UnitStats.UnitType.RANGED:
			_execute_acid_volley()
		UnitStats.UnitType.WORKER:
			_execute_burst_gather()

func _execute_charge(target_pos: Vector2) -> void:
	var dir: Vector2 = (target_pos - global_position).normalized()
	var charge_dest: Vector2 = global_position + dir * 150.0
	# Instant dash
	global_position = charge_dest
	_ability_active = true
	_ability_timer = 0.3 # brief window for bonus damage
	# Stun + damage nearby enemies at destination
	for enemy in get_tree().get_nodes_in_group("faction_" + str(faction_id)):
		pass # skip own faction
	for fid in range(4):
		if fid == faction_id:
			continue
		for enemy in get_tree().get_nodes_in_group("faction_" + str(fid)):
			if enemy is CharacterBody2D and enemy.global_position.distance_to(global_position) < 40.0:
				var charge_dmg: float = damage * 2.5
				enemy.take_damage(charge_dmg, self)
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(0.5)
				break # hit first enemy only

func _execute_fortify() -> void:
	_is_fortified = true
	_ability_active = true
	_ability_timer = 5.0
	_ability_duration = 5.0
	# Taunt handled in _process - nearby enemies retarget

func _execute_spores() -> void:
	_ability_active = true
	_ability_timer = 8.0
	# Fog reveal handled by fog_of_war checking unit metadata
	set_meta("spore_reveal", true)
	set_meta("spore_reveal_radius", 400.0)

func _execute_acid_volley() -> void:
	if not is_instance_valid(_attack_target):
		return
	var base_dir: Vector2 = (_attack_target.global_position - global_position).normalized()
	var spread_angle: float = 0.3 # ~17 degrees
	for i in range(3):
		var angle_offset: float = (i - 1) * spread_angle
		var dir: Vector2 = base_dir.rotated(angle_offset)
		_fire_projectile_direction(dir, damage * 0.75)

func _execute_burst_gather() -> void:
	_is_burst_gathering = true
	_ability_active = true
	_ability_timer = 5.0

func apply_stun(duration: float) -> void:
	_is_stunned = true
	_stun_timer = duration
```

In `_process()` tick down `_ability_cooldown_timer`, `_ability_timer`, `_stun_timer`, and clear flags when timers expire. Fortify adds armor in `take_damage()`. Burst gather multiplies gather amount.

**Step 4: Add V hotkey to `rts_input_handler.gd`**

```gdscript
KEY_V:
	if _selection_mgr.selected_units.size() > 0:
		var world_pos: Vector2 = _camera.get_world_mouse_pos(event.position)
		for unit in _selection_mgr.selected_units:
			if unit.has_method("use_ability"):
				unit.use_ability(world_pos)
```

**Step 5: Commit**

```
git commit -m "feat(rts): add unit abilities - Charge, Fortify, Spores, Acid Volley, Burst Gather"
```

---

### Task 4: Veterancy System

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd` (XP tracking, star levels, stat bonuses)
- Modify: `scripts/rts_stage/rts_stage_manager.gd` (XP distribution on kill)

**Step 1: Add veterancy vars to `rts_unit.gd`**

```gdscript
var _xp: int = 0
var _vet_level: int = 0 # 0-3
const VET_THRESHOLDS: Array = [0, 3, 8, 15]
const VET_HP_BONUS: Array = [0.0, 0.1, 0.2, 0.3]
const VET_DMG_BONUS: Array = [0.0, 0.1, 0.2, 0.3]
const VET_SPD_BONUS: Array = [0.0, 0.0, 0.05, 0.1]
const VET_CD_BONUS: Array = [1.0, 1.0, 1.0, 0.75]
```

**Step 2: Add XP grant method**

```gdscript
func grant_xp(amount: int) -> void:
	_xp += amount
	var new_level: int = 0
	for i in range(VET_THRESHOLDS.size()):
		if _xp >= VET_THRESHOLDS[i]:
			new_level = i
	if new_level > _vet_level:
		_vet_level = new_level
		_apply_veterancy()
		# Audio cue handled by stage manager signal

func _apply_veterancy() -> void:
	var base_stats: Dictionary = UnitStats.get_stats(unit_type)
	max_health = base_stats["hp"] * (1.0 + VET_HP_BONUS[_vet_level])
	health = minf(health + base_stats["hp"] * VET_HP_BONUS[_vet_level], max_health)
	_veterancy_cooldown_reduction = VET_CD_BONUS[_vet_level]
```

Apply VET_DMG_BONUS and VET_SPD_BONUS as multipliers in `_perform_attack()` and movement speed calculation.

**Step 3: Draw veterancy stars in `_draw()`**

After the health bar, draw gold stars:

```gdscript
if _vet_level > 0:
	var star_y: float = -_cell_radius - 12.0
	for i in range(_vet_level):
		var star_x: float = (i - (_vet_level - 1) * 0.5) * 6.0
		_draw_star(Vector2(star_x, star_y), 2.5, Color(1.0, 0.85, 0.2, 0.9))
```

**Step 4: Distribute XP on kill in `rts_stage_manager.gd`**

In `_on_unit_killed(unit, killer)`:

```gdscript
# Grant XP to killer
var xp_mult: float = 1.0
if _tech_tree:
	xp_mult = _tech_tree.get_xp_mult(killer.faction_id)
if killer.has_method("grant_xp"):
	killer.grant_xp(int(1 * xp_mult))
# Assist XP to nearby allies
for ally in get_tree().get_nodes_in_group("faction_" + str(killer.faction_id)):
	if ally != killer and ally is CharacterBody2D and ally.global_position.distance_to(unit.global_position) < 150.0:
		if ally.has_method("grant_xp"):
			ally.grant_xp(int(1 * xp_mult))
```

**Step 5: Commit**

```
git commit -m "feat(rts): add veterancy system with 3 star levels and XP from kills/assists"
```

---

### Task 5: Selection Panel (`rts_selection_panel.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_selection_panel.gd`

**Step 1: Create selection panel**

New Control that draws in the bottom-left area. Replaces the basic selection info in rts_hud.gd.

```gdscript
extends Control

var _selection_mgr: Node
var _time: float = 0.0
var _hovered_unit_idx: int = -1

const PANEL_W: float = 320.0
const PANEL_H: float = 120.0
const GRID_COLS: int = 8
const GRID_ROWS: int = 3
const ICON_SIZE: float = 28.0
const ICON_PAD: float = 2.0

func setup(selection_mgr: Node) -> void:
	_selection_mgr = selection_mgr
	mouse_filter = MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var panel_x: float = 10.0
	var panel_y: float = vp.y - PANEL_H - 10.0
	# Membrane border
	_draw_membrane_panel(Vector2(panel_x, panel_y), Vector2(PANEL_W, PANEL_H))
	if not _selection_mgr:
		return
	var selected: Array = _selection_mgr.selected_units
	if selected.is_empty():
		_draw_no_selection(panel_x, panel_y)
	elif selected.size() == 1:
		_draw_single_unit(selected[0], panel_x, panel_y)
	else:
		_draw_multi_selection(selected, panel_x, panel_y)
```

Include methods for:
- `_draw_membrane_panel(pos, size)` - wobbly sine-wave border with bioluminescent glow
- `_draw_single_unit(unit, x, y)` - organism portrait, HP bar (organic gradient), ATK/ARM/SPD stats, current order icon, vet stars, ability cooldown indicator
- `_draw_multi_selection(units, x, y)` - 8x3 wire-frame grid of unit icons, click to subselect
- `_draw_building_info(building, x, y)` - production queue as organic pods, progress membrane, rally indicator
- `_draw_no_selection(x, y)` - faint "Select units" text

**Step 2: Add click handling for sub-selection**

In `_gui_input()`, detect clicks on individual unit icons in the grid. Click = select only that unit. Shift+click = remove from selection.

**Step 3: Commit**

```
git commit -m "feat(rts): add selection panel with single/multi/building views and sub-selection"
```

---

### Task 6: Control Groups Bar

**Files:**
- Modify: `scripts/rts_stage/rts_selection_panel.gd` (add control groups strip)
- Modify: `scripts/rts_stage/selection_manager.gd` (expose control group data)

**Step 1: Add control group strip to selection panel**

Draw a horizontal strip at bottom-center showing groups 1-9:

```gdscript
func _draw_control_groups(vp: Vector2) -> void:
	var strip_w: float = 9 * 42.0
	var strip_x: float = (vp.x - strip_w) * 0.5
	var strip_y: float = vp.y - 28.0
	for i in range(1, 10):
		var gx: float = strip_x + (i - 1) * 42.0
		var group: Array = _selection_mgr.get_control_group(i)
		var valid: Array = group.filter(func(u): return is_instance_valid(u))
		if valid.is_empty():
			# Empty group - dim outline
			draw_rect(Rect2(gx, strip_y, 38, 24), Color(0.3, 0.3, 0.3, 0.2), false, 1.0)
			draw_string(_font, Vector2(gx + 4, strip_y + 16), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.4, 0.4, 0.3))
		else:
			# Active group
			var comp_color: Color = _get_composition_color(valid)
			var under_attack: bool = _is_group_under_attack(valid)
			var bg_alpha: float = 0.3 + (0.2 * sin(_time * 4.0)) if under_attack else 0.3
			draw_rect(Rect2(gx, strip_y, 38, 24), Color(comp_color.r, comp_color.g, comp_color.b, bg_alpha), true)
			_draw_membrane_border_small(Rect2(gx, strip_y, 38, 24), comp_color)
			draw_string(_font, Vector2(gx + 4, strip_y + 16), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			draw_string(_font, Vector2(gx + 16, strip_y + 16), str(valid.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))
```

Color logic: all workers = green, all military = red, mixed = blue.

**Step 2: Add `get_control_group()` to `selection_manager.gd`**

```gdscript
func get_control_group(group_num: int) -> Array:
	return _control_groups.get(group_num, [])
```

**Step 3: Add click/double-click on control group strip**

Click = recall group (select those units). Double-click = center camera on group.

**Step 4: Commit**

```
git commit -m "feat(rts): add control groups bar with composition coloring and attack alerts"
```

---

### Task 7: Evolved Command Card

**Files:**
- Modify: `scripts/rts_stage/rts_hud.gd` (replace 2x3 grid with 3x4 context-sensitive card)

**Step 1: Redesign command button layout**

Replace the existing 2x3 grid with a 3x4 grid (12 buttons). Each button is context-sensitive:

```gdscript
const CMD_CARD_COLS: int = 3
const CMD_CARD_ROWS: int = 4
const CMD_BTN_W: float = 58.0
const CMD_BTN_H: float = 34.0
const CMD_BTN_PAD: float = 4.0

func _get_command_buttons(selected: Array) -> Array:
	if selected.is_empty():
		return []
	# Check if building selected
	if selected.size() == 1 and selected[0] is StaticBody2D:
		return _get_building_commands(selected[0])
	# Check unit composition
	var has_workers: bool = false
	var has_military: bool = false
	for u in selected:
		if u is CharacterBody2D:
			if u.unit_type == UnitStats.UnitType.WORKER:
				has_workers = true
			else:
				has_military = true
	if has_workers and not has_military:
		return _get_worker_commands()
	elif has_military:
		return _get_military_commands()
	return []

func _get_worker_commands() -> Array:
	return [
		{"name": "Move", "hotkey": "M", "icon": "move"},
		{"name": "Stop", "hotkey": "S", "icon": "stop"},
		{"name": "Hold", "hotkey": "H", "icon": "hold"},
		{"name": "Attack", "hotkey": "A", "icon": "attack"},
		{"name": "Patrol", "hotkey": "P", "icon": "patrol"},
		{"name": "Build", "hotkey": "B", "icon": "build"},
		{"name": "Gather", "hotkey": "G", "icon": "gather"},
		{}, # empty
		{"name": "Burst\nGather", "hotkey": "V", "icon": "ability", "is_ability": true},
	]

func _get_military_commands() -> Array:
	return [
		{"name": "Move", "hotkey": "M", "icon": "move"},
		{"name": "Stop", "hotkey": "S", "icon": "stop"},
		{"name": "Hold", "hotkey": "H", "icon": "hold"},
		{"name": "Attack", "hotkey": "A", "icon": "attack"},
		{"name": "Patrol", "hotkey": "P", "icon": "patrol"},
		{"name": "Formation", "hotkey": "F", "icon": "formation"},
		{}, # empty
		{}, # empty
		{"name": "Ability", "hotkey": "V", "icon": "ability", "is_ability": true},
	]
```

**Step 2: Draw command buttons with bioluminescent styling**

Each button gets:
- Dark organic background with membrane border
- Hotkey letter (small, top-left, cyan)
- Command name (center)
- Bioluminescent glow on hover (lerp to bright cyan/green)
- Pulse animation when command is available
- For abilities: radial cooldown sweep overlay

**Step 3: Add building command card**

When a building is selected, show: Set Rally, Cancel Queue, unit production buttons, Upgrade button (if available).

**Step 4: Commit**

```
git commit -m "feat(rts): evolve command card to context-sensitive 3x4 grid with bioluminescent styling"
```

---

### Task 8: HUD Visual Evolution

**Files:**
- Modify: `scripts/rts_stage/rts_hud.gd` (top bar, resource display, supply vessel)

**Step 1: Add membrane border drawing utility**

```gdscript
func _draw_membrane_border(rect: Rect2, color: Color, amplitude: float = 2.0, freq: float = 8.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 60
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var perimeter_pos: Vector2
		# Walk around rectangle perimeter
		var total_len: float = 2.0 * (rect.size.x + rect.size.y)
		var dist: float = t * total_len
		if dist < rect.size.x:
			perimeter_pos = rect.position + Vector2(dist, 0)
			perimeter_pos.y += sin(_time * 2.0 + dist * freq * 0.01) * amplitude
		elif dist < rect.size.x + rect.size.y:
			var d: float = dist - rect.size.x
			perimeter_pos = rect.position + Vector2(rect.size.x, d)
			perimeter_pos.x += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		elif dist < 2.0 * rect.size.x + rect.size.y:
			var d: float = dist - rect.size.x - rect.size.y
			perimeter_pos = rect.position + Vector2(rect.size.x - d, rect.size.y)
			perimeter_pos.y += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		else:
			var d: float = dist - 2.0 * rect.size.x - rect.size.y
			perimeter_pos = rect.position + Vector2(0, rect.size.y - d)
			perimeter_pos.x += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		points.append(perimeter_pos)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, 1.5, true)
```

**Step 2: Evolve top bar**

- Resource panel: Dark organic background with membrane border, pulsing glow when income changes
- Supply vessel: Vertical organic tube shape showing population fill level (like fluid in a test tube)
- Resource icons: Bioluminescent circle (biomass=green, genes=purple) with inner glow

**Step 3: Add organic resource bar helper**

```gdscript
func _draw_organic_bar(pos: Vector2, width: float, height: float, fill: float, color: Color) -> void:
	# Background tube
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.05, 0.08, 0.05, 0.6), true)
	# Fluid fill with gradient
	var fill_w: float = width * clampf(fill, 0.0, 1.0)
	if fill_w > 0:
		var top_color: Color = color.lightened(0.3)
		var bot_color: Color = color.darkened(0.2)
		draw_rect(Rect2(pos, Vector2(fill_w, height * 0.5)), top_color, true)
		draw_rect(Rect2(pos + Vector2(0, height * 0.5), Vector2(fill_w, height * 0.5)), bot_color, true)
		# Bubble at fill edge
		var bubble_x: float = pos.x + fill_w - 3.0
		if bubble_x > pos.x:
			draw_circle(Vector2(bubble_x, pos.y + height * 0.3), 1.5, Color(1, 1, 1, 0.3 + 0.1 * sin(_time * 5.0)))
	# Membrane border
	_draw_membrane_border(Rect2(pos - Vector2(1, 1), Vector2(width + 2, height + 2)), color.darkened(0.3), 1.0, 12.0)
```

**Step 4: Remove old selection info from rts_hud.gd**

Since rts_selection_panel.gd now handles selection display, remove the `SELECTION INFO` block from rts_hud's `_draw()`.

**Step 5: Commit**

```
git commit -m "feat(rts): evolve HUD with membrane borders, organic resource bars, and supply vessel"
```

---

### Task 9: Threat Alert System (`rts_threat_detector.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_threat_detector.gd`
- Modify: `scripts/rts_stage/rts_hud.gd` (draw threat alerts)

**Step 1: Create threat detector**

```gdscript
extends Node

signal threat_detected(threat_pos: Vector2, threat_count: int)
signal threat_cleared(threat_id: int)

const SCAN_INTERVAL: float = 1.5
const THREAT_RADIUS: float = 500.0
const MAX_ALERTS: int = 3
const ALERT_LIFETIME: float = 10.0

var _stage: Node
var _scan_timer: float = 0.0
var _active_threats: Array = [] # [{id, pos, count, time, enemy_units}]
var _next_threat_id: int = 0

func setup(stage: Node) -> void:
	_stage = stage

func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_threats()
	# Age out old threats
	for i in range(_active_threats.size() - 1, -1, -1):
		_active_threats[i]["time"] += delta
		if _active_threats[i]["time"] >= ALERT_LIFETIME:
			threat_cleared.emit(_active_threats[i]["id"])
			_active_threats.remove_at(i)

func _scan_for_threats() -> void:
	var player_buildings: Array = []
	for b in get_tree().get_nodes_in_group("faction_0"):
		if b is StaticBody2D:
			player_buildings.append(b)
	if player_buildings.is_empty():
		return
	# Check each enemy faction
	for fid in range(1, 4):
		for enemy in get_tree().get_nodes_in_group("faction_" + str(fid)):
			if not (enemy is CharacterBody2D) or not is_instance_valid(enemy):
				continue
			for building in player_buildings:
				if enemy.global_position.distance_to(building.global_position) < THREAT_RADIUS:
					_register_threat(enemy.global_position, fid)
					break

func _register_threat(pos: Vector2, faction_id: int) -> void:
	# Check if near existing threat
	for threat in _active_threats:
		if threat["pos"].distance_to(pos) < 200.0:
			threat["time"] = 0.0 # refresh timer
			threat["count"] += 1
			return
	if _active_threats.size() >= MAX_ALERTS:
		return
	var threat: Dictionary = {
		"id": _next_threat_id,
		"pos": pos,
		"count": 1,
		"time": 0.0,
		"faction_id": faction_id
	}
	_next_threat_id += 1
	_active_threats.append(threat)
	threat_detected.emit(pos, 1)

func get_active_threats() -> Array:
	return _active_threats

func clear_threat(threat_id: int) -> void:
	for i in range(_active_threats.size()):
		if _active_threats[i]["id"] == threat_id:
			_active_threats.remove_at(i)
			return
```

**Step 2: Draw threat alerts in `rts_hud.gd`**

Add to `_draw()`:

```gdscript
func _draw_threat_alerts() -> void:
	if not _threat_detector:
		return
	var vp: Vector2 = get_viewport_rect().size
	var threats: Array = _threat_detector.get_active_threats()
	for i in range(threats.size()):
		var threat: Dictionary = threats[i]
		# Calculate screen-edge position pointing toward threat
		var screen_center: Vector2 = vp * 0.5
		var threat_screen: Vector2 = _camera.world_to_screen(threat["pos"])
		var dir: Vector2 = (threat_screen - screen_center).normalized()
		# Clamp to screen edge with margin
		var edge_pos: Vector2 = _clamp_to_screen_edge(screen_center, dir, vp, 60.0)
		# Pulsing red membrane-vein indicator
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		var alert_color: Color = Color(0.9, 0.15, 0.1, 0.6 + 0.3 * pulse)
		# Draw vein-like tendrils from edge
		_draw_threat_vein(edge_pos, dir, alert_color)
		# Draw warning icon
		draw_circle(edge_pos, 12.0 + 2.0 * pulse, Color(0.8, 0.1, 0.05, 0.4))
		draw_circle(edge_pos, 8.0, alert_color)
		# "!" text
		draw_string(_font, edge_pos + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
```

**Step 3: Add click-to-snap on threat alerts**

In HUD `_input()`, check if click is near a threat alert edge_pos. If so, snap camera.

**Step 4: Commit**

```
git commit -m "feat(rts): add threat alert system with pulsing membrane-vein indicators"
```

---

### Task 10: Map Events (`rts_map_events.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_map_events.gd`
- Modify: `scripts/rts_stage/rts_hud.gd` (event announcements)
- Modify: `scripts/rts_stage/petri_dish_map.gd` (event zone visuals)

**Step 1: Create map events system**

```gdscript
extends Node

signal event_started(event_type: int, position: Vector2, name: String)
signal event_ended(event_type: int)

enum EventType { NUTRIENT_BLOOM, TOXIC_TIDE, EVOLUTIONARY_SURGE, PETRI_QUAKE, MIGRATION }

const EVENT_INTERVAL_MIN: float = 90.0
const EVENT_INTERVAL_MAX: float = 180.0
const WARNING_TIME: float = 5.0

const EVENT_DATA: Dictionary = {
	EventType.NUTRIENT_BLOOM: {"name": "Nutrient Bloom", "duration": 30.0, "color": Color(0.2, 0.9, 0.3)},
	EventType.TOXIC_TIDE: {"name": "Toxic Tide", "duration": 20.0, "color": Color(0.6, 0.1, 0.8)},
	EventType.EVOLUTIONARY_SURGE: {"name": "Evolutionary Surge", "duration": 15.0, "color": Color(1.0, 0.8, 0.1)},
	EventType.PETRI_QUAKE: {"name": "Petri Quake", "duration": 10.0, "color": Color(0.7, 0.3, 0.1)},
	EventType.MIGRATION: {"name": "Migration", "duration": 25.0, "color": Color(0.4, 0.7, 0.9)},
}

var _stage: Node
var _event_timer: float = 0.0
var _next_event_time: float = 0.0
var _active_event: int = -1
var _event_position: Vector2
var _event_remaining: float = 0.0
var _warning_active: bool = false
var _warning_timer: float = 0.0
var _pending_event_type: int = -1

func setup(stage: Node) -> void:
	_stage = stage
	_next_event_time = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)

func _process(delta: float) -> void:
	_event_timer += delta
	# Warning phase
	if _warning_active:
		_warning_timer += delta
		if _warning_timer >= WARNING_TIME:
			_warning_active = false
			_start_event(_pending_event_type)
		return
	# Active event
	if _active_event >= 0:
		_event_remaining -= delta
		_tick_active_event(delta)
		if _event_remaining <= 0.0:
			_end_event()
		return
	# Waiting for next event
	if _event_timer >= _next_event_time:
		_trigger_random_event()

func _trigger_random_event() -> void:
	_pending_event_type = randi_range(0, EventType.size() - 1)
	_event_position = Vector2(randf_range(-4000, 4000), randf_range(-4000, 4000))
	_warning_active = true
	_warning_timer = 0.0
	# Emit warning signal for HUD

func _start_event(event_type: int) -> void:
	_active_event = event_type
	var data: Dictionary = EVENT_DATA[event_type]
	_event_remaining = data["duration"]
	event_started.emit(event_type, _event_position, data["name"])
	match event_type:
		EventType.NUTRIENT_BLOOM:
			_spawn_bloom_resources()
		EventType.EVOLUTIONARY_SURGE:
			_apply_surge()

func _tick_active_event(delta: float) -> void:
	match _active_event:
		EventType.TOXIC_TIDE:
			_tick_toxic_tide(delta)
		EventType.MIGRATION:
			_tick_migration(delta)

func _end_event() -> void:
	match _active_event:
		EventType.EVOLUTIONARY_SURGE:
			_remove_surge()
	event_ended.emit(_active_event)
	_active_event = -1
	_event_timer = 0.0
	_next_event_time = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)
```

Implement each event's tick/spawn/cleanup method. Nutrient Bloom spawns 5 rich resource nodes. Toxic Tide damages units in expanding circle. Evolutionary Surge sets metadata on all units. Petri Quake damages all buildings once. Migration spawns a line of NPC creatures that move across map.

**Step 2: Add event announcement to HUD**

Center-screen text flash with organic border, fades over 3s:

```gdscript
var _event_announcement: String = ""
var _event_announce_timer: float = 0.0
var _event_announce_color: Color = Color.WHITE

func show_event_announcement(text: String, color: Color) -> void:
	_event_announcement = text
	_event_announce_timer = 3.0
	_event_announce_color = color
```

Draw in `_draw()` at screen center with large font, membrane border frame, fade-out alpha.

**Step 3: Commit**

```
git commit -m "feat(rts): add map events system - Nutrient Bloom, Toxic Tide, Surge, Quake, Migration"
```

---

### Task 11: Enhanced NPCs

**Files:**
- Modify: `scripts/rts_stage/petri_dish_map.gd` (neutral camps, roaming predators)
- Modify: `scripts/rts_stage/npc_creature.gd` (patrol behavior, XP rewards)
- Modify: `scripts/rts_stage/titan_corpse.gd` (harvestable)

**Step 1: Add neutral camp spawning to `petri_dish_map.gd`**

Upgrade existing NPC pockets to be proper neutral camps with guarded bonus resources. Add 4 "roaming predator" spawns — large single NPCs that patrol a circular route.

**Step 2: Make titan corpses harvestable**

Add to `titan_corpse.gd`:
```gdscript
var _gene_reward: int = 25
var _harvested: bool = false

func harvest() -> int:
	if _harvested:
		return 0
	_harvested = true
	# Visual change - dim color
	queue_redraw()
	return _gene_reward
```

Workers with a gather command on a titan corpse call `harvest()` and deposit genes.

**Step 3: Add roaming predator behavior to `npc_creature.gd`**

Add a `_patrol_path` array and `_is_roaming` flag. Roaming predators cycle through 4 waypoints. They attack any faction's units within detection range. Worth 3 XP on kill (vs 1 for normal NPCs).

**Step 4: Commit**

```
git commit -m "feat(rts): enhance NPCs - neutral camps, harvestable titans, roaming predators"
```

---

### Task 12: Formation System (`rts_formation.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_formation.gd`
- Modify: `scripts/rts_stage/rts_unit.gd` (formation offset)
- Modify: `scripts/rts_stage/command_system.gd` (formation-aware move)
- Modify: `scripts/rts_stage/rts_input_handler.gd` (F hotkey)

**Step 1: Create formation calculator**

```gdscript
class_name RtsFormation

enum FormationType { SPREAD, LINE, BOX, WEDGE }

static func get_formation_name(type: int) -> String:
	match type:
		FormationType.SPREAD: return "Spread"
		FormationType.LINE: return "Line"
		FormationType.BOX: return "Box"
		FormationType.WEDGE: return "Wedge"
	return "Spread"

static func calculate_positions(units: Array, center: Vector2, direction: Vector2, formation: int) -> Array:
	match formation:
		FormationType.SPREAD:
			return _calc_spread(units, center)
		FormationType.LINE:
			return _calc_line(units, center, direction)
		FormationType.BOX:
			return _calc_box(units, center, direction)
		FormationType.WEDGE:
			return _calc_wedge(units, center, direction)
	return _calc_spread(units, center)

static func _calc_spread(units: Array, center: Vector2) -> Array:
	# Current behavior - just move to center, natural spacing via avoidance
	var positions: Array = []
	for u in units:
		positions.append(center)
	return positions

static func _calc_line(units: Array, center: Vector2, dir: Vector2) -> Array:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var spacing: float = 30.0
	var positions: Array = []
	# Sort: melee front, ranged back
	var melee: Array = []
	var ranged: Array = []
	for u in units:
		if u.unit_type == UnitStats.UnitType.RANGED:
			ranged.append(u)
		else:
			melee.append(u)
	var all_sorted: Array = melee + ranged
	var front_count: int = melee.size()
	for i in range(all_sorted.size()):
		var row: int = 0 if i < front_count else 1
		var col: int = i if i < front_count else i - front_count
		var col_count: int = front_count if row == 0 else ranged.size()
		var offset: Vector2 = perp * (col - (col_count - 1) * 0.5) * spacing
		offset += dir * (-row * spacing * 1.5) # ranged row behind
		positions.append(center + offset)
	return positions

static func _calc_box(units: Array, center: Vector2, dir: Vector2) -> Array:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var spacing: float = 28.0
	var side: int = ceili(sqrt(float(units.size())))
	var positions: Array = []
	for i in range(units.size()):
		var row: int = i / side
		var col: int = i % side
		var offset: Vector2 = perp * (col - (side - 1) * 0.5) * spacing
		offset += dir * (row - (side - 1) * 0.5) * spacing
		positions.append(center + offset)
	return positions

static func _calc_wedge(units: Array, center: Vector2, dir: Vector2) -> Array:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var spacing: float = 30.0
	var positions: Array = []
	# V-shape: fastest at tip
	var sorted: Array = units.duplicate()
	sorted.sort_custom(func(a, b): return a.speed > b.speed)
	positions.append(center) # tip
	for i in range(1, sorted.size()):
		var row: int = ceili(float(i) / 2.0)
		var side: int = 1 if i % 2 == 1 else -1
		var offset: Vector2 = dir * (-row * spacing) + perp * (side * row * spacing * 0.7)
		positions.append(center + offset)
	return positions
```

**Step 2: Add formation state to command_system + units**

```gdscript
# command_system.gd
var _current_formation: int = RtsFormation.FormationType.SPREAD

func cycle_formation() -> int:
	_current_formation = (_current_formation + 1) % 4
	return _current_formation

func issue_move_formation(units: Array, target_pos: Vector2, camera_dir: Vector2) -> void:
	var positions: Array = RtsFormation.calculate_positions(units, target_pos, camera_dir, _current_formation)
	for i in range(units.size()):
		if i < positions.size():
			units[i].command_move(positions[i])
```

**Step 3: F hotkey in input handler**

```gdscript
KEY_F:
	if _selection_mgr.selected_units.size() >= 3:
		var form: int = _command_sys.cycle_formation()
		# Show formation name briefly on HUD
```

**Step 4: Draw formation lines in command_vfx**

When units are moving in formation (not SPREAD), draw faint lines connecting them.

**Step 5: Commit**

```
git commit -m "feat(rts): add formation system - Spread, Line, Box, Wedge with F key cycling"
```

---

### Task 13: Shift-Queue Commands

**Files:**
- Modify: `scripts/rts_stage/rts_unit.gd` (command queue)
- Modify: `scripts/rts_stage/rts_input_handler.gd` (shift detection)
- Modify: `scripts/rts_stage/command_system.gd` (queue vs immediate)

**Step 1: Add command queue to `rts_unit.gd`**

```gdscript
var _command_queue: Array = [] # [{type, target_pos, target_node}]
const MAX_QUEUE: int = 8

func queue_command(cmd: Dictionary) -> void:
	if _command_queue.size() < MAX_QUEUE:
		_command_queue.append(cmd)

func _advance_queue() -> void:
	if _command_queue.is_empty():
		return
	var cmd: Dictionary = _command_queue.pop_front()
	match cmd["type"]:
		"move": command_move(cmd["target_pos"])
		"attack": command_attack(cmd["target_node"])
		"gather": command_gather(cmd["target_node"])
		"patrol": command_patrol(cmd["point_a"], cmd["point_b"])
		"build": command_build(cmd["target_node"])
```

Call `_advance_queue()` when current command completes (state returns to IDLE and queue is non-empty).

**Step 2: Modify input handler for Shift detection**

When Shift is held during RMB commands, call `queue_command()` instead of direct command. Draw queued waypoints as faint lines with numbered dots.

**Step 3: Draw queue waypoints**

In unit's `_draw()`, if `_command_queue` is non-empty, draw connecting lines from current position through queued waypoints.

**Step 4: Commit**

```
git commit -m "feat(rts): add shift-queue commands with visual waypoint lines"
```

---

### Task 14: Minimap Evolution

**Files:**
- Modify: `scripts/rts_stage/rts_minimap.gd`

**Step 1: Add camera viewport rectangle**

Draw white rectangle outline showing currently visible area:

```gdscript
func _draw_camera_rect() -> void:
	var cam_pos: Vector2 = _camera.global_position
	var vp: Vector2 = get_viewport_rect().size
	var zoom: float = _camera.zoom.x
	var half_w: float = (vp.x * 0.5) / zoom
	var half_h: float = (vp.y * 0.5) / zoom
	var corners: Array = [
		_world_to_minimap(cam_pos + Vector2(-half_w, -half_h)),
		_world_to_minimap(cam_pos + Vector2(half_w, -half_h)),
		_world_to_minimap(cam_pos + Vector2(half_w, half_h)),
		_world_to_minimap(cam_pos + Vector2(-half_w, half_h)),
	]
	for i in range(4):
		draw_line(corners[i], corners[(i + 1) % 4], Color(1, 1, 1, 0.6), 1.0)
```

**Step 2: Fix attack ping fade**

Change ping rendering to fade based on age:

```gdscript
# In _draw(), ping section:
var alpha: float = 1.0 - (ping["time"] / ALERT_PING_LIFE)
# Remove pings when time >= ALERT_PING_LIFE in _process()
```

And in `_process()`:
```gdscript
for i in range(_alert_pings.size() - 1, -1, -1):
	_alert_pings[i]["time"] += delta
	if _alert_pings[i]["time"] >= ALERT_PING_LIFE:
		_alert_pings.remove_at(i)
```

**Step 3: Add Alt+click ping**

```gdscript
# In _input:
if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
	if event.alt_pressed:
		# Player ping - green expanding ring
		var world_pos: Vector2 = _minimap_to_world(event.position)
		add_player_ping(world_pos)
```

**Step 4: Terrain coloring**

Draw resource nodes as yellow dots and obstacles as dark patches on minimap.

**Step 5: Commit**

```
git commit -m "feat(rts): evolve minimap - camera rect, ping fade fix, alt-click pings, terrain colors"
```

---

### Task 15: Damage Numbers (`rts_damage_numbers.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_damage_numbers.gd`
- Modify: `scripts/rts_stage/combat_system.gd` (emit damage events)

**Step 1: Create floating damage number pool**

```gdscript
extends Node2D

const MAX_NUMBERS: int = 50
const LIFETIME: float = 0.6
const RISE_SPEED: float = 40.0

var _numbers: Array = [] # [{pos, value, time, color}]

func add_damage(pos: Vector2, value: int, is_crit: bool = false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	_numbers.append({
		"pos": pos,
		"value": value,
		"time": 0.0,
		"color": Color(1.0, 0.3, 0.1) if not is_crit else Color(1.0, 0.9, 0.1),
		"is_crit": is_crit,
		"offset_x": randf_range(-8.0, 8.0)
	})

func _process(delta: float) -> void:
	var changed: bool = false
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i]["time"] += delta
		if _numbers[i]["time"] >= LIFETIME:
			_numbers.remove_at(i)
			changed = true
		else:
			changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	for num in _numbers:
		var t: float = num["time"] / LIFETIME
		var alpha: float = 1.0 - t * t # ease out
		var y_offset: float = -t * RISE_SPEED
		var pos: Vector2 = num["pos"] + Vector2(num["offset_x"], y_offset)
		var scale: float = 1.0 + (0.3 if num["is_crit"] else 0.0) * (1.0 - t)
		var color: Color = num["color"]
		color.a = alpha
		var font_size: int = int(11.0 * scale) if num["is_crit"] else 9
		draw_string(ThemeDB.fallback_font, pos, str(num["value"]), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
```

**Step 2: Hook into combat_system**

When `deal_damage()` is called, emit position + value to damage numbers node.

**Step 3: Commit**

```
git commit -m "feat(rts): add floating damage numbers with pooling and crit highlighting"
```

---

### Task 16: Production Tab (`rts_production_tab.gd`)

**Files:**
- Create: `scripts/rts_stage/rts_production_tab.gd`
- Modify: `scripts/rts_stage/rts_input_handler.gd` (F1 hotkey)

**Step 1: Create production overview**

```gdscript
extends Control

var _stage: Node
var _visible_tab: bool = false
var _time: float = 0.0
var _hovered_building_idx: int = -1

func setup(stage: Node) -> void:
	_stage = stage
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false

func toggle() -> void:
	_visible_tab = not _visible_tab
	visible = _visible_tab
	mouse_filter = MOUSE_FILTER_STOP if _visible_tab else MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _visible_tab:
		_time += delta
		queue_redraw()

func _draw() -> void:
	if not _visible_tab:
		return
	var vp: Vector2 = get_viewport_rect().size
	# Semi-transparent backdrop
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.05, 0.02, 0.85), true)
	# Title
	draw_string(ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 80, 40), "PRODUCTION OVERVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.9, 0.5))
	# List all player production buildings with queues
	var buildings: Array = []
	for b in get_tree().get_nodes_in_group("faction_0"):
		if b is StaticBody2D and is_instance_valid(b) and b.is_production and b.is_complete():
			buildings.append(b)
	var y: float = 70.0
	for i in range(buildings.size()):
		var b: Node = buildings[i]
		_draw_building_row(b, i, 40.0, y, vp.x - 80.0)
		y += 60.0
```

Each row shows: building name, building type icon, current production (unit name + progress bar), queue (up to 6 unit icons), click to center camera, click to queue/cancel.

**Step 2: Add F1 hotkey**

In `rts_input_handler.gd` `_unhandled_input()`:
```gdscript
KEY_F1:
	if _production_tab:
		_production_tab.toggle()
```

**Step 3: Commit**

```
git commit -m "feat(rts): add F1 production tab overview with building queues and camera snap"
```

---

### Task 17: Audio - New Synth Generators

**Files:**
- Modify: `scripts/audio/synth_sounds.gd` (~10 new generators)
- Modify: `scripts/autoload/audio_manager.gd` (new buffers + play functions)

**Step 1: Add synth generators to `synth_sounds.gd`**

Follow the existing pattern (see gen_collect, gen_eat, gen_hurt). Each returns PackedFloat32Array.

```gdscript
## Rising crystalline chime for upgrade complete
static func gen_upgrade_complete() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase1: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.1, 0.4, 0.3, dur)
		var freq1: float = lerpf(600.0, 1200.0, t / dur)
		var freq2: float = lerpf(900.0, 1800.0, t / dur)
		phase1 += freq1 / SAMPLE_RATE
		phase2 += freq2 / SAMPLE_RATE
		var s: float = sine(phase1) * 0.4 + sine(phase2) * 0.2 + triangle(phase1 * 3.0) * 0.1
		buf[i] = s * env * 0.5
	return buf

## Deep harmonic for tech tier unlock
static func gen_tech_unlock() -> PackedFloat32Array:
	# ... similar pattern, deep 80Hz base + bright 1600Hz overtone

## Low organic rumble for threat alert
static func gen_threat_alert() -> PackedFloat32Array:
	# ... 0.8s, 50-80Hz rumble + noise, rising urgency envelope

## Quick whoosh for charge ability
static func gen_ability_charge() -> PackedFloat32Array:
	# ... 0.3s, noise sweep 200->2000Hz, fast attack

## Deep thud for fortify ability
static func gen_ability_fortify() -> PackedFloat32Array:
	# ... 0.2s, 60Hz sine + impact noise

## Airy release for spore ability
static func gen_ability_spores() -> PackedFloat32Array:
	# ... 0.4s, white noise filtered, breathy

## Sizzle burst for acid volley
static func gen_ability_acid() -> PackedFloat32Array:
	# ... 0.25s, noise + high sine, crackling

## Squelch for burst gather
static func gen_ability_burst_gather() -> PackedFloat32Array:
	# ... 0.3s, low bubbling + wet noise

## Ascending triple-note for veterancy
static func gen_veterancy_star() -> PackedFloat32Array:
	# ... 0.4s, three quick ascending tones (C-E-G pattern)

## Organic click for formation change
static func gen_formation_click() -> PackedFloat32Array:
	# ... 0.1s, sharp click + brief organic resonance

## Soft ping for queued command
static func gen_queue_ping() -> PackedFloat32Array:
	# ... 0.15s, soft high-pitched ping, distinct from move command
```

**Step 2: Add buffers and play functions to `audio_manager.gd`**

Follow the existing pattern — pregenerate buffers in `_ready()`, add `play_upgrade_complete()`, `play_threat_alert()`, `play_ability(ability_name)`, `play_veterancy_star()`, `play_formation_click()`, `play_queue_ping()`.

**Step 3: Commit**

```
git commit -m "feat(rts): add 10 new synth audio generators for upgrades, abilities, threats, formations"
```

---

### Task 18: AI Integration

**Files:**
- Modify: `scripts/rts_stage/ai_director.gd` (tech tree, abilities, map events)

**Step 1: Add tech tree decisions to AI**

```gdscript
var _tech_tree: Node = null

func set_tech_tree(tree: Node) -> void:
	_tech_tree = tree

func _try_research_upgrade() -> void:
	if not _tech_tree:
		return
	var available: Array = _tech_tree.get_available_upgrades(faction_id)
	if available.is_empty():
		# Try to unlock next tier
		var current_tier: int = _tech_tree.get_faction_tier(faction_id)
		if current_tier < 3 and _tech_tree.can_unlock_tier(faction_id, current_tier + 1):
			var req: Dictionary = RtsTechTree.TIER_REQUIREMENTS[current_tier + 1]
			if _try_spend(req["evolve_cost_biomass"], req["evolve_cost_genes"]):
				_tech_tree.unlock_tier(faction_id, current_tier + 1)
		return
	# Pick upgrade based on phase
	var pick: int = available[randi() % available.size()]
	var data: Dictionary = RtsTechTree.UPGRADE_DATA[pick]
	if _try_spend(data["cost_biomass"], data["cost_genes"]):
		# Find an Evolution Chamber to research at
		for b in get_tree().get_nodes_in_group("faction_" + str(faction_id)):
			if b is StaticBody2D and b.building_type == BuildingStats.BuildingType.EVOLUTION_CHAMBER and b.is_complete():
				b.queue_research(pick)
				break
```

Add to phase logic:
- EXPANSION: call `_try_research_upgrade()` 30% of decisions
- AGGRESSION: call `_try_research_upgrade()` 50% of decisions
- ENDGAME: call `_try_research_upgrade()` every decision

**Step 2: Add ability usage to AI units**

In AI decision loop, when army is in combat, trigger abilities:
- Fighters: Charge if >100u from target and cooldown ready
- Defenders: Fortify when HP < 50% and 3+ enemies nearby
- Scouts: Spores when entering unexplored area
- Spitters: Acid Volley when 2+ enemies in cone
- Workers: Burst Gather opportunistically (HARD+ only)

Difficulty scales ability usage: NOOB never, EASY 20%, MEDIUM 50%, HARD 80%, SWEATY 100%.

**Step 3: Add map event reactions**

Connect `event_started` signal. AI reacts:
- Nutrient Bloom: Send 2 workers to harvest (if MEDIUM+)
- Toxic Tide: Move units away from event area (if EASY+)
- Evolutionary Surge: Push attack timing forward (if HARD+)
- Petri Quake: Queue repairs (always)

**Step 4: Commit**

```
git commit -m "feat(rts): integrate tech tree, abilities, and map events into AI director"
```

---

### Task 19: Final Wiring + Integration

**Files:**
- Modify: `scripts/rts_stage/rts_stage_manager.gd` (create + wire all new subsystems)
- Modify: `scripts/rts_stage/rts_hud.gd` (final integration)
- Modify: `scripts/rts_stage/rts_building.gd` (visual upgrades in _draw)

**Step 1: Wire new systems in `rts_stage_manager.gd`**

In `_ready()`, after existing subsystem creation:

```gdscript
# After victory_manager setup:
_tech_tree = RtsTechTree.new()
_tech_tree.setup(4)
add_child(_tech_tree)

_threat_detector = preload("res://scripts/rts_stage/rts_threat_detector.gd").new()
_threat_detector.setup(self)
add_child(_threat_detector)

_map_events = preload("res://scripts/rts_stage/rts_map_events.gd").new()
_map_events.setup(self)
add_child(_map_events)

_damage_numbers = preload("res://scripts/rts_stage/rts_damage_numbers.gd").new()
_damage_numbers.z_index = 8
add_child(_damage_numbers)

# In HUD layer:
_selection_panel = preload("res://scripts/rts_stage/rts_selection_panel.gd").new()
_selection_panel.setup(_selection_manager)
_hud_layer.add_child(_selection_panel)

_production_tab = preload("res://scripts/rts_stage/rts_production_tab.gd").new()
_production_tab.setup(self)
_hud_layer.add_child(_production_tab)

# Pass tech_tree to AI directors
for ai in _ai_directors:
	ai.set_tech_tree(_tech_tree)

# Pass tech_tree to buildings when created
# In _create_building(): building.set_tech_tree(_tech_tree)
# In _spawn_unit(): unit._tech_tree = _tech_tree

# Connect map events
_map_events.event_started.connect(_on_map_event_started)
_map_events.event_ended.connect(_on_map_event_ended)

# Connect threat detector
_threat_detector.threat_detected.connect(_on_threat_detected)
```

**Step 2: Add upgraded building visuals**

In `rts_building.gd` `_draw()`, when `is_upgraded()`:
- Spawning Pool → Hatchery: larger, extra membrane ring, glowing center
- Membrane Tower → Spine Tower: spikier, wider range circle
- Nutrient Processor → Refinery: vane animation faster, processing glow

**Step 3: Pass references through to HUD**

Update `rts_hud.gd` to receive `_tech_tree`, `_threat_detector`, `_map_events` references for drawing research progress, threat alerts, and event announcements.

**Step 4: Update build placement validation**

In `build_ghost.gd` or `rts_input_handler.gd`, check overlap with existing buildings and map edge. Set ghost color to red when invalid. Show tower range circle during tower placement.

**Step 5: Update attack priority in `rts_unit.gd`**

In `_check_auto_retaliate()` and attack-move target selection:
```gdscript
func _find_best_target(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_score: float = -1.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var score: float = 0.0
		# Priority: attacking me > lowest HP > nearest
		if enemy.has_meta("attack_target") and enemy.get_meta("attack_target") == self:
			score += 1000.0
		score += (1.0 - enemy.health / enemy.max_health) * 100.0
		score += (1.0 - global_position.distance_to(enemy.global_position) / detection_range) * 50.0
		if score > best_score:
			best_score = score
			best = enemy
	return best
```

**Step 6: Final commit**

```
git commit -m "feat(rts): wire all new subsystems, build validation, attack priority, upgraded building visuals"
```

---

## Summary

| Task | Group | New Files | Modified Files |
|------|-------|-----------|---------------|
| 1. Tech Tree System | A | rts_tech_tree.gd | rts_unit.gd, rts_building.gd |
| 2. Research UI | A | - | rts_hud.gd, rts_input_handler.gd |
| 3. Unit Abilities | B | - | rts_unit.gd, unit_stats.gd, command_system.gd, rts_input_handler.gd |
| 4. Veterancy | B | - | rts_unit.gd, rts_stage_manager.gd |
| 5. Selection Panel | C | rts_selection_panel.gd | - |
| 6. Control Groups Bar | C | - | rts_selection_panel.gd, selection_manager.gd |
| 7. Command Card | C | - | rts_hud.gd |
| 8. HUD Evolution | D | - | rts_hud.gd |
| 9. Threat Alerts | D | rts_threat_detector.gd | rts_hud.gd |
| 10. Map Events | E | rts_map_events.gd | rts_hud.gd, petri_dish_map.gd |
| 11. Enhanced NPCs | E | - | petri_dish_map.gd, npc_creature.gd, titan_corpse.gd |
| 12. Formations | F | rts_formation.gd | rts_unit.gd, command_system.gd, rts_input_handler.gd |
| 13. Shift-Queue | F | - | rts_unit.gd, rts_input_handler.gd, command_system.gd |
| 14. Minimap Evolution | G | - | rts_minimap.gd |
| 15. Damage Numbers | G | rts_damage_numbers.gd | combat_system.gd |
| 16. Production Tab | G | rts_production_tab.gd | rts_input_handler.gd |
| 17. Audio | H | - | synth_sounds.gd, audio_manager.gd |
| 18. AI Integration | H | - | ai_director.gd |
| 19. Final Wiring | I | - | rts_stage_manager.gd, rts_hud.gd, rts_building.gd, build_ghost.gd |
