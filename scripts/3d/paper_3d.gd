class_name Paper3D
extends Node3D
## A loose sheet on the desk. Flutters as the wind builds (ESCALATING signal),
## blows away on the gust, drifts back later. API: flutter, blow_away(), reset().

var flutter := 0.0
var _cur := 0.0
var _t := 0.0
var _blown := 0.0
var _rest: Vector3
var _sheet: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	_rest = position
	_sheet = InteractableObject3D.box(Vector3(0.9, 0.01, 0.65), Color(0.93, 0.9, 0.82))
	_mat = _sheet.material_override
	add_child(_sheet)
	for i in 4:
		var line := InteractableObject3D.box(Vector3(0.6, 0.004, 0.02), Color(0.55, 0.55, 0.6), Vector3(0, 0.008, -0.2 + i * 0.13))
		_sheet.add_child(line)

func blow_away() -> void:
	_blown = 0.001

func reset() -> void:
	_blown = 0.0
	position = _rest
	rotation = Vector3.ZERO
	_mat.albedo_color.a = 1.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

func _process(delta: float) -> void:
	_t += delta
	_cur = lerp(_cur, flutter, delta * 3.0)
	if _blown > 0.0 and _blown < 1.0:
		_blown = min(_blown + delta / 1.4, 1.0)
		position = _rest + Vector3(2.5 * _blown, 0.8 * sin(_blown * PI) + 0.2 * _blown, 2.2 * _blown)
		rotation = Vector3(_blown * 2.0, _blown * 3.0, _blown)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color.a = 1.0 - _blown
		if _blown >= 1.0:
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(self): reset())
		return
	# flutter: one corner lifts and shivers
	_sheet.rotation.x = -_cur * 0.12 * (0.5 + 0.5 * sin(_t * 9.0))
	_sheet.rotation.z = _cur * 0.08 * sin(_t * 13.0)
	_sheet.position.y = _cur * 0.03 * absf(sin(_t * 7.0))
