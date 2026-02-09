extends Node3D
## Interactive fluid pool: semi-transparent liquid surface with ripple shader.
## Optional damage (acid pools), slow (bile), or cosmetic (water).
## Player proximity drives ripple animation via shader uniforms.

var pool_radius: float = 3.0
var pool_color: Color = Color(0.2, 0.5, 0.1, 0.5)
var hazard_type: String = ""  # "acid", "bile", or "" for cosmetic
var dps: float = 0.0
var slow_factor: float = 1.0

var _mesh_instance: MeshInstance3D = null
var _shader_mat: ShaderMaterial = null
var _hazard_node: Node3D = null
var _time: float = 0.0

const WATER_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 pool_color : source_color = vec4(0.2, 0.5, 0.1, 0.5);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_scale : hint_range(1.0, 20.0) = 8.0;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.05;
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_time = 0.0;

void vertex() {
	// Scrolling wave displacement
	float wave1 = sin(VERTEX.x * wave_scale + TIME * wave_speed) * wave_amplitude;
	float wave2 = sin(VERTEX.z * wave_scale * 0.7 + TIME * wave_speed * 1.3) * wave_amplitude * 0.6;

	// Ripple from player
	vec2 uv_pos = vec2(VERTEX.x, VERTEX.z) * 0.5 + 0.5;
	float ripple_dist = length(uv_pos - ripple_center);
	float ripple_ring = sin((ripple_dist - ripple_time * 2.0) * 15.0) * ripple_strength;
	ripple_ring *= smoothstep(0.5, 0.0, ripple_dist);  // Fade at edges

	VERTEX.y += wave1 + wave2 + ripple_ring * 0.08;
}

void fragment() {
	// Scrolling noise pattern for surface
	vec2 scroll_uv = UV + vec2(TIME * 0.03, TIME * 0.02);
	float noise1 = sin(scroll_uv.x * 12.0) * cos(scroll_uv.y * 10.0) * 0.5 + 0.5;
	float noise2 = sin(scroll_uv.x * 8.0 + 1.5) * cos(scroll_uv.y * 6.0 + 0.7) * 0.5 + 0.5;
	float pattern = mix(noise1, noise2, 0.5);

	// Edge fade (circular pool shape)
	vec2 center_uv = UV - 0.5;
	float edge_dist = length(center_uv) * 2.0;
	float edge_fade = 1.0 - smoothstep(0.7, 1.0, edge_dist);

	ALBEDO = pool_color.rgb * (0.8 + pattern * 0.4);
	ALPHA = pool_color.a * edge_fade;
	EMISSION = pool_color.rgb * 0.3 * (0.5 + pattern * 0.5);

	// Ripple highlight
	vec2 uv_pos = UV;
	float rd = length(uv_pos - ripple_center);
	float rr = sin((rd - ripple_time * 2.0) * 15.0) * ripple_strength;
	rr *= smoothstep(0.5, 0.0, rd);
	EMISSION += vec3(abs(rr) * 0.5);
}
"""

func setup(radius: float, color: Color, h_type: String = "", damage: float = 0.0, slow: float = 1.0) -> void:
	pool_radius = radius
	pool_color = color
	hazard_type = h_type
	dps = damage
	slow_factor = slow

func _ready() -> void:
	_build_visual()
	_build_hazard()

func _build_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(pool_radius * 2.0, pool_radius * 2.0)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	_mesh_instance.mesh = plane
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Water shader material
	var shader: Shader = Shader.new()
	shader.code = WATER_SHADER_CODE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.set_shader_parameter("pool_color", pool_color)
	_shader_mat.set_shader_parameter("wave_speed", 0.8)
	_shader_mat.set_shader_parameter("wave_scale", 8.0)
	_shader_mat.set_shader_parameter("wave_amplitude", 0.05)
	_shader_mat.set_shader_parameter("ripple_center", Vector2(0.5, 0.5))
	_shader_mat.set_shader_parameter("ripple_strength", 0.0)
	_shader_mat.set_shader_parameter("ripple_time", 0.0)
	_mesh_instance.material_override = _shader_mat

	# Slight offset above floor
	_mesh_instance.position.y = 0.1
	add_child(_mesh_instance)

	# Subtle glow light
	var pool_light: OmniLight3D = OmniLight3D.new()
	pool_light.light_color = pool_color
	pool_light.light_energy = 0.3
	pool_light.omni_range = pool_radius * 1.5
	pool_light.omni_attenuation = 2.0
	pool_light.shadow_enabled = false
	pool_light.position = Vector3(0, 0.5, 0)
	add_child(pool_light)

func _build_hazard() -> void:
	if hazard_type == "":
		return
	# Create hazard metadata node for player detection
	_hazard_node = Node3D.new()
	_hazard_node.name = "FluidHazard"
	_hazard_node.position = Vector3.ZERO
	_hazard_node.set_meta("hazard_type", hazard_type)
	_hazard_node.set_meta("radius", pool_radius)
	if hazard_type == "acid":
		_hazard_node.set_meta("dps", dps)
	elif hazard_type == "bile":
		_hazard_node.set_meta("slow_factor", slow_factor)
	add_child(_hazard_node)
	# Will be added to group after entering tree
	call_deferred("_add_hazard_group")

func _add_hazard_group() -> void:
	if _hazard_node:
		_hazard_node.add_to_group("biome_hazard")

func _process(delta: float) -> void:
	_time += delta
	if not _shader_mat:
		return

	# Find player for ripple
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	if players.size() > 0:
		var player: Node3D = players[0]
		var local_pos: Vector3 = to_local(player.global_position)
		var dist: float = Vector2(local_pos.x, local_pos.z).length()

		if dist < pool_radius * 1.2:
			# Player is near/in pool — drive ripple
			var uv_center: Vector2 = Vector2(
				clampf(local_pos.x / (pool_radius * 2.0) + 0.5, 0.0, 1.0),
				clampf(local_pos.z / (pool_radius * 2.0) + 0.5, 0.0, 1.0)
			)
			var strength: float = clampf(1.0 - dist / (pool_radius * 1.2), 0.0, 1.0)
			_shader_mat.set_shader_parameter("ripple_center", uv_center)
			_shader_mat.set_shader_parameter("ripple_strength", strength)
			_shader_mat.set_shader_parameter("ripple_time", _time)
		else:
			_shader_mat.set_shader_parameter("ripple_strength", 0.0)
	else:
		_shader_mat.set_shader_parameter("ripple_strength", 0.0)
