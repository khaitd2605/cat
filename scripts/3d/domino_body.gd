class_name DominoBody
extends RigidBody3D
## One physical domino. Placed dominoes are FROZEN (kinematic) so they never
## jitter; a moving domino that touches a frozen one wakes it up, which is how
## the chain reaction travels. The carried domino is frozen too and moved by hand.

signal disturbed(body: DominoBody)

const SIZE := Vector3(0.48, 1.0, 0.16)   # width across the run, height, thickness along it

var slot := -1
var carried := false
var color := Color.WHITE
var doomed := false          # fell over; fading out
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func setup(c: Color) -> void:
	color = c
	mass = 0.4
	gravity_scale = 10.0   # a 1 m domino falls like a 5 cm one
	can_sleep = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	contact_monitor = true
	max_contacts_reported = 6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	physics_material_override = pm
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = c
	_mat.roughness = 0.55
	_mesh.material_override = _mat
	add_child(_mesh)
	# pips on both faces
	for side in [-1.0, 1.0]:
		for k in 2:
			var pip := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.035
			sm.height = 0.07
			pip.mesh = sm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(1, 1, 1, 0.9)
			pip.material_override = pmat
			pip.position = Vector3(0, -0.2 + k * 0.4, side * SIZE.z * 0.5)
			_mesh.add_child(pip)
	body_entered.connect(_on_body_entered)

func is_standing() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > 0.9 and global_position.y > 0.3 and global_position.y < 0.7

func is_at_rest() -> bool:
	return freeze or (linear_velocity.length() < 0.06 and angular_velocity.length() < 0.2)

## Let physics take over (called by the chain, a gust, the cat...).
func wake() -> void:
	if carried or not freeze:
		return
	freeze = false
	sleeping = false
	disturbed.emit(self)

func _on_body_entered(b: Node) -> void:
	if b is DominoBody and not freeze and b.freeze and not b.carried:
		b.wake()

## Small visual jitter (wind) without touching the physics body.
func set_jitter(v: Vector3) -> void:
	_mesh.position = v

func set_alpha(a: float) -> void:
	if a < 1.0:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, a)
