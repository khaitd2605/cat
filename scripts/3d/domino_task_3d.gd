class_name DominoTask3D
extends Node3D
## BUILD system, 3D + physics edition. Same public API as the 2D DominoTask so
## the events / FocusSystem / FailureSystem do not care which one is running:
##   is_focusing(), placed_count(), standing_count(), get_progress(),
##   next_slot_index(), focus_point_global(), landing_spot(), set_shaking(),
##   set_shield(), shield_active, gust(), smash_at(), debug_place_next()
##
## The player carries a domino by its TOP; the bottom swings like a pendulum
## along the run. Release straight -> it stands (frozen, stable). Release while
## swinging -> it is handed to physics with that tilt, and physics decides.

signal drag_started
signal drag_ended

@export var spacing := 0.62
@export var slot_tolerance := 0.22
@export var max_off_path := 0.7
@export_group("Serpentine")
@export var rows := 3
@export var row_length := 8.0
@export var row_gap := 1.6
@export var wave_amp := 0.22
@export var wave_len := 2.6
@export_group("Pendulum")
@export var swing_stiffness := 38.0
@export var swing_damping := 2.2
@export var swing_from_hand := 0.14
@export var straight_swing := 0.05     # world units at the bottom
@export var topple_swing := 0.11
@export_group("")
@export var tray_pos := Vector3(-4.6, 0, 3.2)
@export var camera_path: NodePath

const HEIGHT := 1.0
## Hand height while carrying. The bottom of the domino rides 3 cm above the
## desk so it reads as "held just over the table", not floating in mid-air.
const HAND_Y := HEIGHT + 0.03

var slots: Array[Dictionary] = []      # { "pos": Vector3 (y=0), "angle": float (XZ travel) }
var dominoes: Array[DominoBody] = []
var total_dominoes := 0
var shaking := false
var shield_active := false

var dragging := false
var drag_pos := Vector3.ZERO           # the hand (top of the carried domino)
var drag_angle := 0.0
var swing := 0.0
var swing_vel := 0.0
var debug_lock_hand := false
var _drag_prev := Vector3.ZERO
var _carried: DominoBody

var _collapse_active := false
var _disturbed: Array[DominoBody] = []
var _collapse_standing_before := 0
var _last_disturb := 0.0
var _collapse_started := 0.0
var _time := 0.0
var _pulse := 0.0
var _hover_hot := false

var _camera: Camera3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _base_ring: MeshInstance3D
var _base_mat: StandardMaterial3D
var _guide_root: Node3D
var _feedback: Label3D
var _feedback_t := 0.0
var _hands: Node3D
var _tray_hint: Label3D
var _finish_flag: MeshInstance3D
var _fingers: Node3D

func _ready() -> void:
	_camera = get_node(camera_path)
	_build_path()
	_build_visuals()
	(func(): EventBus.task_progress.emit(placed_count(), total_dominoes)).call_deferred()

# --------------------------------------------------------------- path

func _build_path() -> void:
	slots.clear()
	var pts: Array[Vector2] = []
	var half := row_length * 0.5
	var top := -row_gap * (rows - 1) * 0.5
	for r in rows:
		var z := top + r * row_gap
		var dir := 1.0 if r % 2 == 0 else -1.0
		var steps := int(row_length / 0.05)
		for i in steps + 1:
			var x := -half * dir + (float(i) / steps) * row_length * dir
			pts.append(Vector2(x, z + sin(x / wave_len * TAU) * wave_amp))
		if r < rows - 1:
			var cx := half * dir
			var cz := z + row_gap * 0.5
			var rad := row_gap * 0.5
			for i in range(1, 40):
				var a := -PI / 2 + (float(i) / 40) * PI
				pts.append(Vector2(cx + cos(a) * rad * dir, cz + sin(a) * rad))
	var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if seg <= 0.00001:
			continue
		var t := carry
		while t <= seg:
			var p := a.lerp(b, t / seg)
			slots.append({ "pos": Vector3(p.x, 0.0, p.y), "angle": (b - a).angle() })
			t += spacing
		carry = t - seg
	total_dominoes = slots.size()

static func travel_dir(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))

# --------------------------------------------------------------- visuals

func _build_visuals() -> void:
	_guide_root = Node3D.new()
	add_child(_guide_root)
	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = 0.035
	dot_mesh.bottom_radius = 0.035
	dot_mesh.height = 0.01
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1, 0.95, 0.85, 0.45)
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for s in slots:
		var m := MeshInstance3D.new()
		m.mesh = dot_mesh
		m.material_override = dot_mat
		m.position = s["pos"] + Vector3(0, 0.006, 0)
		_guide_root.add_child(m)
	# next-slot ring
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = slot_tolerance - 0.03
	torus.outer_radius = slot_tolerance
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _ring_mat
	add_child(_ring)
	# marker under the carried bottom
	_base_ring = MeshInstance3D.new()
	var t2 := TorusMesh.new()
	t2.inner_radius = 0.06
	t2.outer_radius = 0.085
	_base_ring.mesh = t2
	_base_mat = StandardMaterial3D.new()
	_base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_base_ring.material_override = _base_mat
	_base_ring.visible = false
	add_child(_base_ring)
	# tray: a box with spare dominoes
	var tray := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(1.6, 0.25, 0.7)
	tray.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 0.18, 0.1)
	tray.material_override = tm
	tray.position = tray_pos + Vector3(0, 0.125, 0)
	add_child(tray)
	for i in 5:
		var spare := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = DominoBody.SIZE
		spare.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color.from_hsv(0.08 + i * 0.13, 0.5, 0.8)
		spare.material_override = sm
		spare.position = tray_pos + Vector3(-0.5 + i * 0.25, 0.25 + 0.5, 0)
		spare.rotation.z = 0.12 * (i - 2)
		add_child(spare)
	_tray_hint = _make_label("khay domino", 0.28, Color(1, 0.95, 0.85, 0.7))
	_tray_hint.position = tray_pos + Vector3(0, 1.35, 0)
	add_child(_tray_hint)
	# start / finish
	var start_label := _make_label("BẮT ĐẦU", 0.26, Color(1, 0.95, 0.8, 0.7))
	start_label.position = slots[0]["pos"] - travel_dir(slots[0]["angle"]) * 0.6 + Vector3(0, 0.5, 0)
	add_child(start_label)
	var last := slots[slots.size() - 1]
	var fpos: Vector3 = last["pos"] + travel_dir(last["angle"]) * 0.7
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.02
	pm.bottom_radius = 0.02
	pm.height = 1.2
	pole.mesh = pm
	pole.position = fpos + Vector3(0, 0.6, 0)
	add_child(pole)
	_finish_flag = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.45, 0.28, 0.02)
	_finish_flag.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.85, 0.45)
	_finish_flag.material_override = fmat
	_finish_flag.position = fpos + Vector3(0.24, 1.05, 0)
	add_child(_finish_flag)
	var finish_label := _make_label("ĐÍCH", 0.26, Color(1, 0.9, 0.6, 0.8))
	finish_label.position = fpos + Vector3(0, 1.45, 0)
	add_child(finish_label)
	# feedback label
	_feedback = _make_label("", 0.34, Color.WHITE)
	_feedback.visible = false
	add_child(_feedback)
	# shield hands
	_hands = Node3D.new()
	_hands.visible = false
	add_child(_hands)
	for side in [-1.0, 1.0]:
		var hand := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.45
		cm.height = 1.6
		hand.mesh = cm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.93, 0.76, 0.6, 0.85)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hand.material_override = hm
		hand.position = Vector3(side * 2.2, 1.3, 0.2)
		hand.rotation.z = side * 0.5
		_hands.add_child(hand)
	var hl := _make_label("ĐANG CHE CHẮN", 0.34, Color(1, 0.9, 0.6))
	hl.position = Vector3(0, 2.4, 0.5)
	_hands.add_child(hl)
	# fingers pinching the top of the carried domino
	_fingers = Node3D.new()
	_fingers.visible = false
	add_child(_fingers)
	for side in [-1.0, 1.0]:
		var finger := MeshInstance3D.new()
		var fcap := CapsuleMesh.new()
		fcap.radius = 0.09
		fcap.height = 0.5
		finger.mesh = fcap
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color(0.93, 0.76, 0.6)
		finger.material_override = skin
		finger.position = Vector3(0, 0.18, side * 0.13)
		finger.rotation.x = side * 0.25
		_fingers.add_child(finger)

static func _make_label(text: String, size: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.004
	l.font_size = int(size * 100)
	l.modulate = col
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l

# --------------------------------------------------------------- queries (shared API)

func can_work() -> bool:
	return GameManager.is_playing()

func is_focusing() -> bool:
	return dragging

func placed_count() -> int:
	var n := 0
	for d in dominoes:
		if d.slot >= 0 and not d.doomed and d.is_standing():
			n += 1
	return n

func standing_count() -> int:
	var n := 0
	for d in dominoes:
		if not d.doomed and d.is_standing():
			n += 1
	return n

func get_progress() -> float:
	return float(placed_count()) / max(total_dominoes, 1)

func next_slot_index() -> int:
	var filled := {}
	for d in dominoes:
		if d.slot >= 0 and not d.doomed and d.is_standing():
			filled[d.slot] = true
	for i in slots.size():
		if not filled.has(i):
			return i
	return -1

func focus_point_global() -> Vector3:
	var i := next_slot_index()
	if i >= 0:
		return to_global(slots[i]["pos"])
	return to_global(drag_pos if dragging else Vector3.ZERO)

## Where the cat lands: on the middle row, right side.
func landing_spot() -> Vector3:
	return to_global(Vector3(2.4, 0, 0))

func carried_base() -> Vector3:
	return drag_pos + Vector3(0, -HEIGHT, 0) + travel_dir(drag_angle) * swing

# --------------------------------------------------------------- input

## Where the hand must be so the BOTTOM of the carried domino sits under the
## cursor's point on the desk. Projecting the cursor onto a raised plane instead
## would put the domino a long way from where the player is pointing.
func _hand_from_cursor() -> Vector3:
	return to_local(_mouse_on_plane(0.0)) + Vector3(0, HAND_Y, 0)

func _mouse_on_plane(plane_y: float) -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mp)
	var dir := _camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector3(origin.x, plane_y, origin.z)
	var t := (plane_y - origin.y) / dir.y
	return origin + dir * t

func _unhandled_input(event: InputEvent) -> void:
	if not can_work():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging:
			if _try_pick(to_local(_mouse_on_plane(0.0))):
				get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			_drop()
			get_viewport().set_input_as_handled()

func _try_pick(table_local: Vector3) -> bool:
	var next := next_slot_index()
	if next < 0:
		return false
	var on_tray := Vector2(table_local.x, table_local.z).distance_to(Vector2(tray_pos.x, tray_pos.z)) <= 1.0
	var on_ring := _xz_dist(table_local, slots[next]["pos"]) <= slot_tolerance * 1.8
	if not (on_tray or on_ring):
		return false
	if shield_active:
		EventBus.notify.emit("Đang che chắn - bỏ tay ra mới xếp tiếp được!", Color(1.0, 0.8, 0.4))
		return true
	_begin_carry(next)
	return true

func _begin_carry(next: int) -> void:
	dragging = true
	drag_angle = slots[next]["angle"]
	drag_pos = _hand_from_cursor()
	_drag_prev = drag_pos
	swing = 0.0
	swing_vel = randf_range(-0.9, 0.9)
	_carried = DominoBody.new()
	_carried.carried = true
	_carried.setup(Color.from_hsv(fmod(float(next) / max(total_dominoes, 1) * 1.6, 1.0), 0.62, 0.9))
	_carried.disturbed.connect(_on_disturbed)
	add_child(_carried)
	_place_carried_transform()
	Sfx.play("place", -12.0)
	drag_started.emit()

func _place_carried_transform() -> void:
	var top := drag_pos
	var base := carried_base()
	var axis := (top - base).normalized()
	var t := travel_dir(drag_angle)
	var across := t.cross(Vector3.UP).normalized()
	var z := across.cross(axis).normalized()
	_carried.global_transform = Transform3D(Basis(across, axis, z), to_global((top + base) * 0.5))

func _drop() -> void:
	dragging = false
	drag_ended.emit()
	var d := _carried
	_carried = null
	var next := next_slot_index()
	var base := carried_base()
	if next < 0 or _xz_dist(base, slots[next]["pos"]) > max_off_path:
		d.queue_free()
		_show_feedback("Cất lại vào khay", Color(0.9, 0.88, 0.8), base)
		Sfx.play("place", -14.0)
		return
	if _debris_near(base):
		d.queue_free()
		_show_feedback("Còn quân đổ ở đó - đợi dọn xong", Color(1, 0.85, 0.5), base)
		Sfx.play("miss", -8.0)
		return
	var dist := _xz_dist(base, slots[next]["pos"])
	var counts := dist <= slot_tolerance
	d.carried = false
	d.slot = next if counts else -1
	dominoes.append(d)
	var tilt := absf(swing)
	if tilt <= straight_swing:
		# stands: snap upright, keep frozen -> rock solid
		var t := travel_dir(drag_angle)
		var across := t.cross(Vector3.UP).normalized()
		d.global_transform = Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP).normalized()), to_global(Vector3(base.x, HEIGHT * 0.5, base.z)))
		if counts:
			Sfx.play("place")
			_show_feedback("Chuẩn!" if dist < slot_tolerance * 0.5 else "Ổn", Color(0.7, 1, 0.7), base)
		else:
			Sfx.play("place", -4.0)
			_show_feedback("Lệch chỗ - không tính", Color(1, 0.8, 0.45), base)
	else:
		# handed to physics with its tilt; gravity decides
		var bottom := Vector3(base.x, 0.02, base.z)
		var top := drag_pos + Vector3(0, -(HAND_Y - HEIGHT) + 0.02, 0)
		var axis := (top - bottom).normalized()
		var t := travel_dir(drag_angle)
		var across := t.cross(Vector3.UP).normalized()
		d.global_transform = Transform3D(Basis(across, axis, across.cross(axis).normalized()), to_global((top + bottom) * 0.5))
		d.wake()
		Sfx.play("miss" if tilt > topple_swing else "place", -3.0)
		_show_feedback("Thả lúc đang lắc!" if tilt > topple_swing else "Hơi nghiêng...", Color(1, 0.45, 0.4) if tilt > topple_swing else Color(1, 0.9, 0.6), base)
	EventBus.task_progress.emit(placed_count(), total_dominoes)
	_check_complete()

func _check_complete() -> void:
	if next_slot_index() < 0 and not _collapse_active:
		EventBus.task_completed.emit()

## A fallen (or still moving) domino lying where we want to put a new one.
func _debris_near(base: Vector3) -> bool:
	for d in dominoes:
		if d.carried:
			continue
		if not d.is_standing() and _xz_dist(d.position, base) < 0.6:
			return true
	return false

## Debug/bot helper: instant straight placement of the next slot.
func debug_place_next() -> bool:
	var next := next_slot_index()
	if next < 0 or not can_work() or _debris_near(slots[next]["pos"]):
		return false
	var d := DominoBody.new()
	d.setup(Color.from_hsv(fmod(float(next) / max(total_dominoes, 1) * 1.6, 1.0), 0.62, 0.9))
	d.disturbed.connect(_on_disturbed)
	d.slot = next
	add_child(d)
	var t := travel_dir(slots[next]["angle"])
	var across := t.cross(Vector3.UP).normalized()
	var p: Vector3 = slots[next]["pos"]
	d.global_transform = Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP).normalized()), to_global(Vector3(p.x, HEIGHT * 0.5, p.z)))
	dominoes.append(d)
	EventBus.task_progress.emit(placed_count(), total_dominoes)
	_check_complete()
	return true

static func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _show_feedback(text: String, col: Color, at: Vector3) -> void:
	_feedback.text = text
	_feedback.modulate = col
	_feedback.position = at + Vector3(0, 1.5, 0)
	_feedback.visible = true
	_feedback_t = 1.1

# --------------------------------------------------------------- environment hooks (shared API)

func set_shaking(on: bool) -> void:
	shaking = on
	if not on:
		for d in dominoes:
			d.set_jitter(Vector3.ZERO)

func set_shield(on: bool) -> void:
	shield_active = on
	_hands.visible = on
	if on and dragging:
		_cancel_carry("Buông quân ra để che")

func _cancel_carry(reason: String) -> void:
	dragging = false
	drag_ended.emit()
	if _carried:
		_show_feedback(reason, Color(1, 0.85, 0.5), carried_base())
		_carried.queue_free()
		_carried = null

## Gust from the window (back of the desk, -z): everything standing on the
## window half is shoved toward the player. Shield absorbs it.
func gust() -> void:
	if shield_active:
		return
	for d in dominoes:
		if d.doomed or not d.is_standing():
			continue
		if d.position.z < 0.3:
			d.wake()
			d.apply_impulse(Vector3(randf_range(-0.2, 0.2), 0.0, 3.0), Vector3(0, 0.45, 0))

## Something lands at a global point: flatten what is nearby.
func smash_at(global_pos: Vector3, radius: float) -> void:
	var local := to_local(global_pos)
	for d in dominoes:
		if d.doomed:
			continue
		var dist := _xz_dist(d.position, local)
		if dist <= radius:
			var away := Vector3(d.position.x - local.x, 0, d.position.z - local.z).normalized()
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			d.wake()
			d.apply_impulse(away * 4.0 * (1.0 - dist / (radius + 0.5)) + Vector3(0, 0.3, 0), Vector3(0, 0.4, 0))

func _on_disturbed(d: DominoBody) -> void:
	if d.carried:
		return
	if not _collapse_active:
		_collapse_active = true
		_collapse_started = _time
		_disturbed.clear()
		_collapse_standing_before = standing_count()
		Sfx.play("fall", -6.0)
	if not _disturbed.has(d):
		_disturbed.append(d)
	_last_disturb = _time

# --------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_time += delta
	_pulse += delta * 4.0
	if _feedback_t > 0.0:
		_feedback_t -= delta
		_feedback.position.y += delta * 0.4
		_feedback.modulate.a = clamp(_feedback_t * 1.5, 0.0, 1.0)
		if _feedback_t <= 0.0:
			_feedback.visible = false

	if shaking:
		for d in dominoes:
			if d.is_standing():
				d.set_jitter(Vector3(randf_range(-0.012, 0.012), 0, randf_range(-0.012, 0.012)))

	if dragging:
		# Safety net: the button can be released over a HUD panel or outside the
		# canvas, and that event never reaches us - the domino would then hang in
		# the air following the cursor forever.
		if not debug_lock_hand and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drop()
		elif not can_work():
			_cancel_carry("")
		else:
			if not debug_lock_hand:
				drag_pos = _hand_from_cursor()
			var next := next_slot_index()
			if next >= 0:
				drag_angle = slots[next]["angle"]
			var hand_vel: Vector3 = (drag_pos - _drag_prev) / maxf(delta, 0.0001)
			_drag_prev = drag_pos
			var t := travel_dir(drag_angle)
			swing_vel -= hand_vel.dot(t) * swing_from_hand
			if shaking:
				swing_vel += randf_range(-0.4, 0.4)
			swing_vel += (-swing_stiffness * swing - swing_damping * swing_vel) * delta
			swing += swing_vel * delta
			swing = clamp(swing, -0.24, 0.24)
			if _carried:
				_place_carried_transform()
	_fingers.visible = dragging
	if dragging:
		_fingers.position = drag_pos
		_fingers.rotation.y = -drag_angle

	_update_collapse()
	_update_ring()
	_update_cursor()

func _update_collapse() -> void:
	if not _collapse_active:
		return
	var settled := _time > _last_disturb + 0.5
	for d in _disturbed:
		if is_instance_valid(d) and not d.is_at_rest():
			settled = false
			break
	# safety net: something keeps twitching -> call it after a while anyway
	if not settled and _time < _collapse_started + 6.0:
		return
	_collapse_active = false
	var knocked := 0
	for d in _disturbed:
		if not is_instance_valid(d):
			continue
		if d.is_standing():
			d.freeze = true          # survived: lock it again
		else:
			knocked += 1
			_doom(d)
	_disturbed.clear()
	EventBus.collapse_finished.emit(knocked, _collapse_standing_before)
	EventBus.task_progress.emit(placed_count(), total_dominoes)
	_check_complete()

## A fallen domino fades out and is removed - the player rebuilds that bit.
func _doom(d: DominoBody) -> void:
	d.doomed = true
	d.slot = -1
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_method(d.set_alpha, 1.0, 0.0, 0.7)
	tw.tween_callback(func():
		dominoes.erase(d)
		d.queue_free()
		EventBus.task_progress.emit(placed_count(), total_dominoes))

func _update_ring() -> void:
	var next := next_slot_index()
	_ring.visible = next >= 0 and can_work()
	if _ring.visible:
		var p: Vector3 = slots[next]["pos"]
		_ring.position = p + Vector3(0, 0.01, 0)
		var aligned := dragging and _xz_dist(carried_base(), p) <= slot_tolerance and absf(swing) <= straight_swing
		var glow := 0.55 + 0.3 * sin(_pulse)
		_ring_mat.albedo_color = Color(0.6, 1.0, 0.6, 0.95) if aligned else (Color(0.7, 0.7, 0.7, 0.4) if shield_active else Color(1.0, 0.9, 0.55, glow))
	_finish_flag.material_override.albedo_color = Color(0.6, 1.0, 0.6) if next < 0 else Color(1.0, 0.85, 0.45)
	_base_ring.visible = dragging
	if dragging:
		var b := carried_base()
		_base_ring.position = Vector3(b.x, 0.012, b.z)
		var a := absf(swing)
		_base_mat.albedo_color = Color(0.6, 1, 0.6) if a <= straight_swing else (Color(1, 0.8, 0.4) if a <= topple_swing else Color(1, 0.4, 0.35))

func _update_cursor() -> void:
	var next := next_slot_index()
	var hot := false
	if can_work() and not dragging and next >= 0:
		var tl := to_local(_mouse_on_plane(0.0))
		hot = Vector2(tl.x, tl.z).distance_to(Vector2(tray_pos.x, tray_pos.z)) <= 1.0 or _xz_dist(tl, slots[next]["pos"]) <= slot_tolerance * 1.8
	if hot != _hover_hot:
		_hover_hot = hot
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)
