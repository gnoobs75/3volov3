extends Node2D
## Manages an infinite procedural world via a chunk grid system.
## Chunks activate/deactivate as the player moves, with local memory of what happened.

const CHUNK_SIZE: float = 800.0
const ACTIVE_RADIUS: int = 1        # Chunks around player that stay active (3x3 = 9)
const MEMORY_RADIUS: int = 4        # Chunks that keep memory before cleanup

const FOOD_SCENE := preload("res://scenes/food_particle.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy_cell.tscn")
const COMPETITOR_SCENE := preload("res://scenes/competitor_cell.tscn")
const HAZARD_SCENE := preload("res://scenes/hazard_organism.tscn")
const REPELLER_SCENE := preload("res://scenes/repeller_organism.tscn")
const BLOCKER_SCENE := preload("res://scenes/blocker_organism.tscn")
const PARASITE_SCENE := preload("res://scenes/parasite_organism.tscn")
const VIRUS_SCENE := preload("res://scenes/virus_organism.tscn")
const SNAKE_SCENE := preload("res://scenes/snake_prey.tscn")
const CURRENT_SCENE := preload("res://scenes/current_zone.tscn")
const DART_PREDATOR_SCENE := preload("res://scenes/dart_predator.tscn")
const LEVIATHAN_SCENE := preload("res://scenes/leviathan.tscn")
const DANGER_ZONE_SCENE := preload("res://scenes/danger_zone.tscn")

enum Biome { NORMAL, THERMAL_VENT, DEEP_ABYSS, SHALLOWS, NUTRIENT_RICH }

# Chunk data: Vector2i -> Dictionary
var _chunks: Dictionary = {}
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)
var _player: Node2D = null
var _world_seed: int = 0

# Spawn tables per biome: {type: [min_count, max_count]}
# Spawn tables — food density halved, creatures reduced but more varied
const SPAWN_TABLES: Dictionary = {
	Biome.NORMAL: {
		"food": [2, 5], "enemy": [0, 1], "competitor": [0, 1], "snake": [0, 1],
		"hazard": [0, 1], "repeller": [0, 1], "blocker": [0, 1], "parasite": [0, 1],
		"virus": [0, 1], "dart_predator": [0, 0], "leviathan": [0, 0],
	},
	Biome.THERMAL_VENT: {
		"food": [3, 4], "enemy": [0, 1], "competitor": [0, 1], "snake": [0, 1],
		"hazard": [0, 1], "repeller": [0, 1], "blocker": [0, 1], "parasite": [0, 1],
		"virus": [0, 1], "dart_predator": [0, 1], "leviathan": [0, 0],
	},
	Biome.DEEP_ABYSS: {
		"food": [1, 3], "enemy": [0, 1], "competitor": [0, 1], "snake": [0, 1],
		"hazard": [0, 1], "repeller": [0, 1], "blocker": [0, 1], "parasite": [0, 1],
		"virus": [0, 1], "dart_predator": [0, 1], "leviathan": [0, 1],
	},
	Biome.SHALLOWS: {
		"food": [4, 6], "enemy": [0, 1], "competitor": [0, 1], "snake": [0, 2],
		"hazard": [0, 1], "repeller": [0, 1], "blocker": [0, 1], "parasite": [0, 1],
		"virus": [0, 0], "dart_predator": [0, 0], "leviathan": [0, 0],
	},
	Biome.NUTRIENT_RICH: {
		"food": [4, 7], "enemy": [0, 1], "competitor": [0, 1], "snake": [0, 1],
		"hazard": [0, 1], "repeller": [0, 1], "blocker": [0, 1], "parasite": [0, 1],
		"virus": [0, 1], "dart_predator": [0, 1], "leviathan": [0, 0],
	},
}

func _ready() -> void:
	_world_seed = randi()

func setup(player: Node2D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if not _player:
		return
	var current_chunk := _get_chunk_coord(_player.global_position)
	if current_chunk != _last_player_chunk:
		_last_player_chunk = current_chunk
		_update_active_chunks()

func _get_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CHUNK_SIZE),
		floori(world_pos.y / CHUNK_SIZE)
	)

func _get_chunk_center(coord: Vector2i) -> Vector2:
	return Vector2(
		(coord.x + 0.5) * CHUNK_SIZE,
		(coord.y + 0.5) * CHUNK_SIZE
	)

func _get_chunk_seed(coord: Vector2i) -> int:
	# Deterministic seed from coord + world seed
	return hash(Vector3i(coord.x, coord.y, _world_seed))

func _determine_biome(coord: Vector2i) -> int:
	var s := _get_chunk_seed(coord)
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var n: float = rng.randf()
	if n < 0.12:
		return Biome.DEEP_ABYSS
	elif n < 0.25:
		return Biome.THERMAL_VENT
	elif n < 0.40:
		return Biome.NUTRIENT_RICH
	elif n < 0.55:
		return Biome.SHALLOWS
	return Biome.NORMAL

func _update_active_chunks() -> void:
	var needed_chunks: Array[Vector2i] = []
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			needed_chunks.append(_last_player_chunk + Vector2i(dx, dy))

	# Activate new chunks
	for coord in needed_chunks:
		if not _chunks.has(coord):
			_activate_chunk(coord)
		elif not _chunks[coord].get("active", false):
			_reactivate_chunk(coord)

	# Deactivate distant chunks
	var to_deactivate: Array[Vector2i] = []
	var to_forget: Array[Vector2i] = []
	for coord in _chunks:
		var dist: int = maxi(absi(coord.x - _last_player_chunk.x), absi(coord.y - _last_player_chunk.y))
		if dist > ACTIVE_RADIUS and _chunks[coord].get("active", false):
			to_deactivate.append(coord)
		if dist > MEMORY_RADIUS:
			to_forget.append(coord)

	for coord in to_deactivate:
		_deactivate_chunk(coord)
	for coord in to_forget:
		# Remove from memory entirely — will regenerate fresh from seed
		_deactivate_chunk(coord)
		_chunks.erase(coord)

func _activate_chunk(coord: Vector2i) -> void:
	var biome: int = _determine_biome(coord)
	var chunk_data: Dictionary = {
		"coord": coord,
		"seed": _get_chunk_seed(coord),
		"biome": biome,
		"organisms": [] as Array[Node2D],
		"active": true,
		"memory": {
			"deaths": 0,
			"food_eaten": 0,
			"remaining": {},  # type -> count override
		},
		"spawned": true,
	}
	_chunks[coord] = chunk_data
	_spawn_chunk_population(coord)

func _reactivate_chunk(coord: Vector2i) -> void:
	var chunk: Dictionary = _chunks[coord]
	chunk["active"] = true
	# Respawn based on memory — fewer organisms if some were killed
	_spawn_chunk_population(coord)

func _deactivate_chunk(coord: Vector2i) -> void:
	if not _chunks.has(coord):
		return
	var chunk: Dictionary = _chunks[coord]
	chunk["active"] = false
	# Save remaining organism counts to memory
	var remaining: Dictionary = {}
	for org in chunk.get("organisms", []):
		if is_instance_valid(org):
			var type_name: String = _get_organism_type(org)
			remaining[type_name] = remaining.get(type_name, 0) + 1
			org.queue_free()
	chunk["memory"]["remaining"] = remaining
	chunk["organisms"] = []

func _get_organism_type(org: Node2D) -> String:
	if org.is_in_group("food"):
		return "food"
	elif org.is_in_group("enemies"):
		return "enemy"
	elif org.is_in_group("competitors"):
		return "competitor"
	elif org.is_in_group("prey"):
		return "snake"
	elif org.is_in_group("hazards"):
		return "hazard"
	elif org.is_in_group("repellers"):
		return "repeller"
	elif org.is_in_group("viruses"):
		return "virus"
	elif org.is_in_group("parasites"):
		return "parasite"
	elif org.is_in_group("blockers"):
		return "blocker"
	return "blocker"

# Types suppressed during the safe zone (no hostiles until player learns controls)
const HOSTILE_TYPES: Array = ["enemy", "hazard", "parasite", "virus", "dart_predator", "leviathan"]

func _spawn_chunk_population(coord: Vector2i) -> void:
	var chunk: Dictionary = _chunks[coord]
	var biome: int = chunk["biome"]
	var table: Dictionary = SPAWN_TABLES[biome]
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk["seed"]
	var center := _get_chunk_center(coord)
	var memory: Dictionary = chunk["memory"]
	var remaining_override: Dictionary = memory.get("remaining", {})
	var in_safe_zone: bool = GameManager.safe_zone_active

	for type_key in table:
		# Skip hostile spawns during the safe zone
		if in_safe_zone and type_key in HOSTILE_TYPES:
			continue

		var range_arr: Array = table[type_key]
		var base_count: int = rng.randi_range(range_arr[0], range_arr[1])
		# Boost food during safe zone so new players have enough to collect
		if in_safe_zone and type_key == "food":
			base_count = maxi(base_count, 4)
		# If we have memory of this chunk, use remembered count instead
		var count: int = base_count
		if remaining_override.has(type_key):
			count = remaining_override[type_key]

		for i in range(count):
			var pos := center + Vector2(
				rng.randf_range(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45),
				rng.randf_range(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45)
			)
			var org := _spawn_organism(type_key, pos, rng)
			if org:
				chunk["organisms"].append(org)

	# Thermal vent biome gets a current zone
	if biome == Biome.THERMAL_VENT:
		var cz := CURRENT_SCENE.instantiate()
		var current_type: int = rng.randi_range(0, 2)
		var dir := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		cz.setup(current_type, dir, rng.randf_range(70.0, 120.0), rng.randf_range(100.0, 160.0))
		cz.global_position = center + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
		add_child(cz)
		chunk["organisms"].append(cz)

	# Environmental danger zones (biome-specific)
	if biome == Biome.DEEP_ABYSS and rng.randf() < 0.4:
		# Acid pools in deep abyss
		var dz := DANGER_ZONE_SCENE.instantiate()
		dz.setup(0, rng.randf_range(60.0, 100.0))  # 0 = ACID_POOL
		dz.global_position = center + Vector2(rng.randf_range(-250, 250), rng.randf_range(-250, 250))
		add_child(dz)
		chunk["organisms"].append(dz)
	elif biome == Biome.THERMAL_VENT and rng.randf() < 0.3:
		# Static fields near thermal vents
		var dz := DANGER_ZONE_SCENE.instantiate()
		dz.setup(1, rng.randf_range(50.0, 90.0))  # 1 = STATIC_FIELD
		dz.global_position = center + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
		add_child(dz)
		chunk["organisms"].append(dz)

func _spawn_organism(type_key: String, pos: Vector2, rng: RandomNumberGenerator) -> Node2D:
	var org: Node2D = null
	match type_key:
		"food":
			org = FOOD_SCENE.instantiate()
			var is_org: bool = rng.randf() < 0.15
			if is_org:
				org.setup(BiologyLoader.get_random_organelle(), true)
			else:
				org.setup(BiologyLoader.get_random_biomolecule(), false)
			org.add_to_group("food")
		"enemy":
			org = ENEMY_SCENE.instantiate()
			org.add_to_group("enemies")
			# 10% chance of Titan variant (not during safe zone)
			if not GameManager.safe_zone_active and rng.randf() < 0.10:
				org.call_deferred("make_titan")
		"competitor":
			org = COMPETITOR_SCENE.instantiate()
		"snake":
			org = SNAKE_SCENE.instantiate()
		"hazard":
			org = HAZARD_SCENE.instantiate()
			org.setup(rng.randi() % 4)
		"repeller":
			org = REPELLER_SCENE.instantiate()
		"blocker":
			org = BLOCKER_SCENE.instantiate()
		"parasite":
			org = PARASITE_SCENE.instantiate()
		"virus":
			org = VIRUS_SCENE.instantiate()
		"dart_predator":
			org = DART_PREDATOR_SCENE.instantiate()
			org.add_to_group("enemies")
		"leviathan":
			org = LEVIATHAN_SCENE.instantiate()
			org.add_to_group("enemies")

	if org:
		org.global_position = pos
		add_child(org)
	return org

func notify_organism_died(pos: Vector2) -> void:
	## Called when an organism dies — update chunk memory
	var coord := _get_chunk_coord(pos)
	if _chunks.has(coord):
		_chunks[coord]["memory"]["deaths"] += 1

func notify_food_eaten(pos: Vector2) -> void:
	## Called when food is consumed
	var coord := _get_chunk_coord(pos)
	if _chunks.has(coord):
		_chunks[coord]["memory"]["food_eaten"] += 1

func get_biome_at(world_pos: Vector2) -> int:
	var coord := _get_chunk_coord(world_pos)
	if _chunks.has(coord):
		return _chunks[coord]["biome"]
	return _determine_biome(coord)

func get_biome_name(biome: int) -> String:
	match biome:
		Biome.NORMAL: return "Open Waters"
		Biome.THERMAL_VENT: return "Thermal Vent"
		Biome.DEEP_ABYSS: return "Deep Abyss"
		Biome.SHALLOWS: return "Shallows"
		Biome.NUTRIENT_RICH: return "Nutrient Garden"
	return "Unknown"
