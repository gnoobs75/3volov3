extends Control
## Expressive anime-style face for the worm, rendered in a SubViewport.
## Draws eyes, eyebrows, mouth, and special effects (tears, sweat, sparkles).
## Displayed on a Sprite3D billboard attached to the worm's head.

enum Mood { IDLE, HAPPY, EXCITED, STRESSED, SCARED, ANGRY, EATING, HURT, DEPLETED, ZOOM, SICK, STEALTH }

var mood: Mood = Mood.IDLE
var _mood_timer: float = 0.0
var _time: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _mouth_open: float = 0.0
var _eye_sparkle_timer: float = 0.0
var _eye_shake: Vector2 = Vector2.ZERO
var _spiral_angle: float = 0.0
var _sweat_drop_y: float = 0.0
var _damage_flash: float = 0.0

# Face geometry (relative to 128x128 viewport center)
var _eye_spacing: float = 18.0
var _eye_size: float = 12.0
var _pupil_size: float = 5.0
var _has_eyebrows: bool = true
var _iris_color: Color = Color(0.2, 0.5, 0.9, 1.0)

# External input from player_worm
var look_direction: Vector2 = Vector2.ZERO  # Where pupils look (-1 to 1)
var speed_ratio: float = 0.0  # 0=still, 1=max speed

const FACE_SIZE: float = 128.0

func _ready() -> void:
	_randomize_face()
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _randomize_face() -> void:
	_eye_spacing = randf_range(16.0, 22.0)
	_eye_size = randf_range(10.0, 14.0)
	_pupil_size = randf_range(4.0, 6.0)
	_has_eyebrows = randf() > 0.2

func set_mood(new_mood: Mood, duration: float = 0.8) -> void:
	mood = new_mood
	_mood_timer = duration

func trigger_damage_flash() -> void:
	_damage_flash = 1.0

func _process(delta: float) -> void:
	_time += delta
	_eye_sparkle_timer += delta
	_spiral_angle += delta * 5.0

	# Mood timer decay
	if _mood_timer > 0:
		_mood_timer -= delta
		if _mood_timer <= 0:
			mood = Mood.IDLE

	# Blink cycle
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.0, 4.5)
		else:
			_is_blinking = true
			_blink_timer = 0.12

	# Eye shake for stress/hurt
	if mood in [Mood.HURT, Mood.SCARED, Mood.STRESSED]:
		_eye_shake = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	else:
		_eye_shake = _eye_shake.lerp(Vector2.ZERO, delta * 10.0)

	# Damage flash decay
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)

	# Mouth animation
	match mood:
		Mood.EATING:
			_mouth_open = 0.5 + sin(_time * 8.0) * 0.5
		Mood.SCARED:
			_mouth_open = lerpf(_mouth_open, 0.8, delta * 6.0)
		Mood.HURT:
			_mouth_open = lerpf(_mouth_open, 0.3, delta * 5.0)
		_:
			_mouth_open = lerpf(_mouth_open, 0.0, delta * 5.0)

	# Sweat drop animation
	if mood in [Mood.SCARED, Mood.STRESSED, Mood.DEPLETED]:
		_sweat_drop_y = fmod(_sweat_drop_y + delta * 30.0, 20.0)

	queue_redraw()

func _draw() -> void:
	var center: Vector2 = Vector2(FACE_SIZE * 0.5, FACE_SIZE * 0.5)

	# Determine eye parameters based on mood
	var eye_r: float = _eye_size
	var eye_squash: float = 0.9
	var pupil_r: float = _pupil_size
	var iris_col: Color = _iris_color
	var brow_angle_l: float = 0.0
	var brow_angle_r: float = 0.0
	var pupil_offset: Vector2 = look_direction * eye_r * 0.25
	var mouth_curve: float = 0.0  # positive=smile, negative=frown

	match mood:
		Mood.IDLE:
			eye_squash = 0.9
			mouth_curve = 0.3
		Mood.HAPPY:
			eye_squash = 0.4  # Happy closed eyes ^_^
			brow_angle_l = 0.2
			brow_angle_r = 0.2
			mouth_curve = 3.0
		Mood.EXCITED:
			eye_r *= 1.2
			pupil_r *= 1.3
			brow_angle_l = 0.3
			brow_angle_r = 0.3
			mouth_curve = 2.5
			pupil_offset += Vector2(eye_r * 0.15, 0)
		Mood.ZOOM:
			eye_squash = 0.7
			brow_angle_l = -0.3
			brow_angle_r = 0.3
			pupil_r *= 0.7
			pupil_offset = Vector2(eye_r * 0.3, 0)
		Mood.STRESSED:
			eye_squash = 0.8
			brow_angle_l = -0.4
			brow_angle_r = 0.4
			pupil_r *= 0.75
			mouth_curve = -1.5
		Mood.SCARED:
			eye_r *= 1.5
			eye_squash = 1.3
			brow_angle_l = 0.5
			brow_angle_r = 0.5
			pupil_r *= 0.4  # Pinprick pupils
			mouth_curve = -2.0
		Mood.ANGRY:
			eye_squash = 0.55
			brow_angle_l = -0.6
			brow_angle_r = 0.6
			pupil_r *= 0.85
			iris_col = iris_col.lerp(Color(0.9, 0.2, 0.15), 0.6)
			mouth_curve = -1.0
		Mood.EATING:
			eye_squash = 0.3  # Closed happy
			brow_angle_l = 0.15
			brow_angle_r = 0.15
			mouth_curve = 2.0
		Mood.HURT:
			eye_squash = 0.25  # >_< squint
			brow_angle_l = -0.5
			brow_angle_r = -0.5
			mouth_curve = -2.5
		Mood.DEPLETED:
			eye_r *= 0.85
			eye_squash = 0.5
			brow_angle_l = -0.4
			brow_angle_r = -0.4
			pupil_r *= 0.65
			pupil_offset = Vector2(0, eye_r * 0.2)  # Looking down
			iris_col = iris_col.lerp(Color(0.4, 0.4, 0.5), 0.5)
			mouth_curve = -2.0
		Mood.SICK:
			eye_r *= 1.1
			pupil_r *= 0.6
			iris_col = iris_col.lerp(Color(0.3, 0.7, 0.2), 0.5)
			mouth_curve = -1.5
		Mood.STEALTH:
			eye_squash = 0.45  # Narrowed, focused
			brow_angle_l = -0.2
			brow_angle_r = 0.2
			pupil_r *= 0.6  # Focused pinpoint
			mouth_curve = 0.0

	# Apply blinking
	if _is_blinking:
		eye_squash = 0.05

	# Eye positions (centered in face viewport)
	var left_eye: Vector2 = center + Vector2(0, -_eye_spacing * 0.5) + _eye_shake
	var right_eye: Vector2 = center + Vector2(0, _eye_spacing * 0.5) + _eye_shake
	var mouth_pos: Vector2 = center + Vector2(eye_r * 1.2, 0)

	# Draw eyes
	_draw_eye(left_eye, eye_r, eye_squash, pupil_r, pupil_offset, iris_col, brow_angle_l)
	_draw_eye(right_eye, eye_r, eye_squash, pupil_r, pupil_offset, iris_col, brow_angle_r)

	# Draw mouth
	_draw_mouth(mouth_pos, mouth_curve)

	# Draw special effects
	if mood in [Mood.SCARED, Mood.STRESSED, Mood.HURT, Mood.DEPLETED]:
		_draw_sweat(right_eye + Vector2(-eye_r, -eye_r * 0.8))

	if mood == Mood.SCARED and _mouth_open > 0.3:
		_draw_tears(left_eye, right_eye, eye_r)

	if mood == Mood.SICK:
		_draw_spiral_eyes(left_eye, right_eye, eye_r)

	if mood == Mood.ZOOM:
		_draw_speed_lines(center)

	# Sparkles for happy/excited/idle
	if mood in [Mood.HAPPY, Mood.EXCITED, Mood.IDLE] and not _is_blinking:
		_draw_sparkles(left_eye, right_eye, eye_r)

	# Damage flash overlay
	if _damage_flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, Vector2(FACE_SIZE, FACE_SIZE)), Color(1.0, 0.2, 0.1, _damage_flash * 0.4))

func _draw_eye(pos: Vector2, r: float, squash: float, pupil_r: float, pupil_off: Vector2, iris_col: Color, _brow_angle: float) -> void:
	var eye_scale: Vector2 = Vector2(1.0, squash)

	# Eye white
	var white_col: Color = Color(1.0, 1.0, 1.0, 0.95)
	_draw_ellipse(pos, r * 1.1, r * squash * 1.1, white_col)

	# Iris
	var iris_r: float = r * 0.7
	var iris_pos: Vector2 = pos + pupil_off * 0.5
	_draw_ellipse(iris_pos, iris_r, iris_r * squash, iris_col)

	# Pupil
	var pupil_pos: Vector2 = pos + pupil_off
	_draw_ellipse(pupil_pos, pupil_r, pupil_r * squash, Color(0.02, 0.02, 0.08, 1.0))

	# Eye highlight (always present for anime style)
	if squash > 0.2:  # Don't show highlight when eyes nearly closed
		var highlight_pos: Vector2 = pos + Vector2(-r * 0.25, -r * 0.2)
		draw_circle(highlight_pos, r * 0.2, Color(1.0, 1.0, 1.0, 0.9))
		# Secondary smaller highlight
		draw_circle(pos + Vector2(r * 0.15, r * 0.15), r * 0.1, Color(1.0, 1.0, 1.0, 0.6))

	# Eyebrow
	if _has_eyebrows and squash > 0.15:
		var brow_y: float = pos.y
		var brow_start: Vector2 = pos + Vector2(-r * 1.3, 0)
		var brow_end: Vector2 = pos + Vector2(r * 1.3, 0)
		# Rotate brow by angle
		var brow_offset_start: Vector2 = Vector2(sin(_brow_angle) * r * 0.6, 0)
		var brow_offset_end: Vector2 = Vector2(-sin(_brow_angle) * r * 0.6, 0)
		brow_start = Vector2(pos.x - r * 1.3, pos.y - r * 0.8) + brow_offset_start
		brow_end = Vector2(pos.x + r * 1.3, pos.y - r * 0.8) + brow_offset_end
		draw_line(brow_start, brow_end, Color(0.15, 0.1, 0.2, 0.9), 2.5, true)

func _draw_ellipse(pos: Vector2, rx: float, ry: float, col: Color) -> void:
	if ry < 0.5:
		# Nearly closed - draw a line
		draw_line(pos + Vector2(-rx, 0), pos + Vector2(rx, 0), col, 1.5)
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 16
	for i in range(segments):
		var angle: float = TAU * i / segments
		pts.append(pos + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(pts, col)

func _draw_mouth(pos: Vector2, curve: float) -> void:
	var width: float = 8.0

	if _mouth_open > 0.15:
		# Open mouth (circle/oval)
		var mo_w: float = width * 0.6 * (0.5 + _mouth_open * 0.5)
		var mo_h: float = width * 0.4 * _mouth_open
		_draw_ellipse(pos, mo_w, mo_h, Color(0.15, 0.05, 0.08, 0.9))
		# Tongue
		if mood in [Mood.EATING, Mood.HAPPY, Mood.EXCITED]:
			draw_circle(pos + Vector2(mo_w * 0.1, 0), mo_w * 0.4, Color(0.85, 0.4, 0.45, 0.8))
		# Teeth when angry
		if mood == Mood.ANGRY:
			for t in range(3):
				var tx: float = pos.x - mo_w * 0.4 + mo_w * 0.4 * t
				draw_circle(Vector2(tx, pos.y - mo_h * 0.5), 1.5, Color(0.9, 0.9, 0.8, 0.8))
	else:
		# Curved line mouth
		var pts: int = 8
		var prev: Vector2 = Vector2.ZERO
		for i in range(pts + 1):
			var t: float = float(i) / pts
			var x: float = pos.x + (t - 0.5) * width * 0.3
			var y: float = pos.y + sin(t * PI) * curve
			var p: Vector2 = Vector2(x, y)
			if i > 0:
				draw_line(prev, p, Color(0.2, 0.12, 0.15, 0.9), 1.8, true)
			prev = p

func _draw_sweat(pos: Vector2) -> void:
	var drop_y: float = fmod(_sweat_drop_y, 15.0)
	var alpha: float = 1.0 - drop_y / 15.0
	# Teardrop shape
	draw_circle(pos + Vector2(0, drop_y), 2.5, Color(0.5, 0.7, 1.0, alpha * 0.7))
	# Trail
	draw_line(pos + Vector2(0, drop_y - 3), pos + Vector2(0, drop_y), Color(0.5, 0.7, 1.0, alpha * 0.4), 1.5)

func _draw_tears(left_eye: Vector2, right_eye: Vector2, eye_r: float) -> void:
	for eye_pos in [left_eye, right_eye]:
		for tc in range(3):
			var tear_phase: float = fmod(_time * (2.0 + tc * 0.5) + tc * 0.3, 1.0)
			var tear_x: float = eye_pos.x + eye_r * 0.8
			var tear_y: float = eye_pos.y + tear_phase * 15.0
			var tear_alpha: float = (1.0 - tear_phase) * 0.7
			draw_circle(Vector2(tear_x, tear_y), 1.2, Color(0.5, 0.7, 1.0, tear_alpha))

func _draw_spiral_eyes(left_eye: Vector2, right_eye: Vector2, eye_r: float) -> void:
	# Draw spiral overlay on eyes for sick/dizzy
	for eye_pos in [left_eye, right_eye]:
		var spiral_r: float = eye_r * 0.6
		var prev: Vector2 = eye_pos
		for i in range(20):
			var t: float = float(i) / 20.0
			var angle: float = _spiral_angle + t * TAU * 2.0
			var r: float = spiral_r * t
			var p: Vector2 = eye_pos + Vector2(cos(angle) * r, sin(angle) * r)
			if i > 0:
				draw_line(prev, p, Color(0.3, 0.7, 0.2, 0.7), 1.5)
			prev = p

func _draw_speed_lines(center: Vector2) -> void:
	for i in range(4):
		var y: float = center.y + (i - 1.5) * 12.0
		var alpha: float = 0.3 + sin(_time * 10.0 + i) * 0.15
		draw_line(Vector2(0, y), Vector2(20, y), Color(0.8, 0.9, 1.0, alpha), 1.5)

func _draw_sparkles(left_eye: Vector2, right_eye: Vector2, eye_r: float) -> void:
	var sparkle_alpha: float = 0.4 + sin(_eye_sparkle_timer * 3.0) * 0.3
	for eye_pos in [left_eye, right_eye]:
		var sp: Vector2 = eye_pos + Vector2(-eye_r * 0.3, -eye_r * 0.25)
		_draw_sparkle(sp, 3.0, sparkle_alpha)

func _draw_sparkle(pos: Vector2, size: float, alpha: float) -> void:
	var col: Color = Color(1.0, 1.0, 1.0, alpha)
	# Four-pointed star
	draw_line(pos + Vector2(-size, 0), pos + Vector2(size, 0), col, 1.5)
	draw_line(pos + Vector2(0, -size), pos + Vector2(0, size), col, 1.5)
	draw_line(pos + Vector2(-size * 0.5, -size * 0.5), pos + Vector2(size * 0.5, size * 0.5), col, 1.0)
	draw_line(pos + Vector2(size * 0.5, -size * 0.5), pos + Vector2(-size * 0.5, size * 0.5), col, 1.0)
