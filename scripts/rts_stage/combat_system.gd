extends Node
## Resolves damage, armor reduction, and attack interactions.

signal unit_damaged(unit: Node2D, damage: float, attacker: Node2D)
signal unit_killed(unit: Node2D, killer: Node2D)

func calculate_damage(base_damage: float, armor: float) -> float:
	return maxf(base_damage - armor, 1.0)

func apply_damage(target: Node2D, base_damage: float, attacker: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var armor: float = target.armor if "armor" in target else 0.0
	var final_damage: float = calculate_damage(base_damage, armor)
	target.take_damage(final_damage, attacker)
	unit_damaged.emit(target, final_damage, attacker)
	if "health" in target and target.health <= 0:
		unit_killed.emit(target, attacker)

func apply_building_damage(target: Node2D, base_damage: float, attacker: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var armor: float = target.armor if "armor" in target else 0.0
	var final_damage: float = calculate_damage(base_damage, armor)
	target.take_damage(final_damage, attacker)

func apply_splash_damage(epicenter: Vector2, base_damage: float, full_radius: float, half_radius: float, zero_radius: float, attacker: Node2D) -> void:
	## Apply area-of-effect damage with falloff zones.
	## full_radius: 100% damage, half_radius: 50% damage, zero_radius: 0% damage (linear falloff between).
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if is_instance_valid(attacker) and "faction_id" in unit and "faction_id" in attacker:
			if unit.faction_id == attacker.faction_id:
				continue
		var dist: float = unit.global_position.distance_to(epicenter)
		if dist > zero_radius:
			continue
		var mult: float = 1.0
		if dist > full_radius:
			if dist < half_radius:
				mult = lerpf(1.0, 0.5, (dist - full_radius) / maxf(half_radius - full_radius, 0.01))
			else:
				mult = lerpf(0.5, 0.0, (dist - half_radius) / maxf(zero_radius - half_radius, 0.01))
		apply_damage(unit, base_damage * mult, attacker)
	# Also damage buildings in splash area
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if is_instance_valid(attacker) and "faction_id" in building and "faction_id" in attacker:
			if building.faction_id == attacker.faction_id:
				continue
		var dist: float = building.global_position.distance_to(epicenter)
		if dist > zero_radius:
			continue
		var mult: float = 1.0
		if dist > full_radius:
			if dist < half_radius:
				mult = lerpf(1.0, 0.5, (dist - full_radius) / maxf(half_radius - full_radius, 0.01))
			else:
				mult = lerpf(0.5, 0.0, (dist - half_radius) / maxf(zero_radius - half_radius, 0.01))
		apply_building_damage(building, base_damage * mult, attacker)
