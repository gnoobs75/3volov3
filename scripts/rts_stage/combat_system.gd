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
