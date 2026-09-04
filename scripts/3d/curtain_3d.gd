class_name Curtain3D
extends Node3D
## Two cloth panels hanging from a rod; the right one lifts and flaps with the
## wind (the first signal of the wind event). API: wind_level, gust().

var wind_level := 0.0
var _cur := 0.0
var _t := 0.0
var _gust := 0.0
var _left: Node3D
var _right: Node3D
var _right_segments: Array[MeshInstance3D] = []

func _ready() -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.8, 0.76, 0.7)
	cloth.roughness = 1.0
	var rod := InteractableObject3D.box(Vector3(6.0, 0.08, 0.08), Color(0.3, 0.2, 0.12), Vector3(0, 0, 0))
	add_child(rod)
	_left = Node3D.new()
	_left.position = Vector3(-2.4, 0, 0.15)
	add_child(_left)
	var lp := InteractableObject3D.box(Vector3(0.9, 3.2, 0.06), Color.WHITE, Vector3(0, -1.6, 0))
	lp.material_override = cloth
	_left.add_child(lp)
	# right curtain: a chain of segments so it can bend as it blows
	_right = Node3D.new()
	_right.position = Vector3(2.3, 0, 0.15)
	add_child(_right)
	var parent: Node3D = _right
	for i in 5:
		var seg := Node3D.new()
		seg.position = Vector3(0, -0.64 if i > 0 else 0.0, 0)
		parent.add_child(seg)
		var panel := InteractableObject3D.box(Vector3(1.0, 0.66, 0.06), Color.WHITE, Vector3(0, -0.33, 0))
		panel.material_override = cloth
		seg.add_child(panel)
		_right_segments.append(panel)
		parent = seg

func gust() -> void:
	_gust = 1.0

func _process(delta: float) -> void:
	_t += delta
	_cur = lerp(_cur, wind_level, delta * 2.5)
	_gust = max(_gust - delta * 0.7, 0.0)
	var strength: float = 0.15 + _cur * 0.35 + _gust * 1.2
	var seg: Node3D = _right.get_child(0)
	var i := 0
	while seg:
		var k := float(i) / 4.0
		seg.rotation.x = strength * (0.25 + 0.2 * k) + sin(_t * (2.5 + strength * 2.0) + k * 2.0) * 0.08 * (0.3 + strength)
		seg.rotation.z = sin(_t * 1.7 + k) * 0.03 * strength
		i += 1
		seg = seg.get_child(1) if seg.get_child_count() > 1 else null
	_left.rotation.x = 0.03 + sin(_t * 1.3) * 0.02 * (1.0 + _cur)
