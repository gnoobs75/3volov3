extends Area2D
## Ranged unit / tower projectile. Travels to target, deals damage on hit.

var _target: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _damage: float = 10.0
var _faction_id: int = 0
var faction_id: int = 0  # Public for kill tracking
var _speed: float = 300.0
var _time: float = 0.0
var _max_life: float = 3.0
var _direction: Vector2 = Vector2.RIGHT

func setup(origin: Vector2, target: Node2D, dmg: float, fid: int) -> void:
	global_position = origin
	_target = target
	_target_pos = target.global_position if is_instance_valid(target) else origin + Vector2(100, 0)
	_damage = dmg
	_faction_id = fid
	faction_id = fid

func _ready() -> void:
	# Collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	collision_layer = 0
	collision_mask = 0
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	if _time > _max_life:
		queue_free()
		return
	# Update target position if target is still alive
	if is_instance_valid(_target):
		_target_pos = _target.global_position
	# Move toward target
	var dir: Vector2 = (_target_pos - global_position).normalized()
	_direction = dir
	global_position += dir * _speed * delta
	# Check if reached target
	if global_position.distance_to(_target_pos) < 8.0:
		_hit()
	queue_redraw()

func _hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_combat_system"):
			stage.get_combat_system().apply_damage(_target, _damage, self)
		else:
			_target.take_damage(_damage, self)
	# Spawn impact effect
	_spawn_impact()
	queue_free()

func _spawn_impact() -> void:
	var impact := Node2D.new()
	impact.global_position = global_position
	impact.set_script(preload("res://scripts/rts_stage/rts_impact_effect.gd"))
	var fc: Color = FactionData.get_faction_color(_faction_id)
	impact.setup(fc)
	get_parent().add_child(impact)

func _on_body_entered(body: Node2D) -> void:
	if body == _target:
		_hit()

func _draw() -> void:
	# Acid glob projectile
	var fc: Color = FactionData.get_faction_color(_faction_id)
	draw_circle(Vector2.ZERO, 4.0, Color(fc.r, fc.g, fc.b, 0.8))
	draw_circle(Vector2.ZERO, 6.0, Color(fc.r, fc.g, fc.b, 0.2))
	# Trail
	var trail_dir: Vector2 = -_direction
	draw_line(Vector2.ZERO, trail_dir * 8.0, Color(fc.r, fc.g, fc.b, 0.3), 2.0)
