extends Area3D
## Acid Spit projectile fired by player (Gut Warden trait) or Gut Warden boss.
## Flies forward, sticks to first enemy hit, applies DoT.

var direction: Vector3 = Vector3.FORWARD
var speed: float = 25.0
var damage: float = 8.0
var dot_dps: float = 5.0
var dot_duration: float = 4.0
var _time: float = 0.0
var _mesh: MeshInstance3D = null
var _light: OmniLight3D = null
var _stuck: bool = false
var _lifetime: float = 5.0

func _ready() -> void:
	_build_visuals()
	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.3
	col.shape = sphere
	add_child(col)
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 8
	sphere.rings = 4
	_mesh.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = mat
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.9, 0.1)
	_light.light_energy = 1.5
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	if _stuck:
		_lifetime -= delta
		if _lifetime <= 0:
			queue_free()
		return
	# Fly forward
	position += direction * speed * delta
	# Spin
	if _mesh:
		_mesh.rotation.y += delta * 8.0
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _stuck:
		return
	if body.is_in_group("player_worm"):
		return  # Don't hit the player who fired it
	# Check if this is an enemy
	var is_enemy: bool = false
	for group in ["white_blood_cell", "phagocyte", "killer_t_cell", "mast_cell", "flyer", "boss"]:
		if body.is_in_group(group):
			is_enemy = true
			break
	if not is_enemy:
		queue_free()
		return
	# Hit! Apply initial damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
	# Apply DoT via venom metadata (reuse existing system)
	body.set_meta("venomed", true)
	body.set_meta("venom_remaining", dot_duration)
	body.set_meta("venom_dps", dot_dps)
	# Stick to the enemy
	_stuck = true
	_lifetime = dot_duration
	speed = 0.0
	# Reparent to enemy for following
	var current_pos: Vector3 = global_position
	get_parent().remove_child(self)
	body.add_child(self)
	position = body.to_local(current_pos)
	if _light:
		_light.light_energy = 0.8
