extends Node3D

## Static placeholder room built from primitives: desk (with collision), floor,
## back wall, lamp (with light), mug, notebook, frames, clock. No gameplay.

var _clock: Label3D

func _ready() -> void:
	# desk top (physics floor for the dominoes) and legs
	var desk := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(15.0, 0.4, 8.6)
	shape.shape = bs
	shape.position = Vector3(0, -0.2, 0)
	desk.add_child(shape)
	var top := InteractableObject3D.box(Vector3(15.0, 0.4, 8.6), Color(0.4, 0.24, 0.14), Vector3(0, -0.2, 0))
	top.material_override.roughness = 0.75
	desk.add_child(top)
	add_child(desk)
	for lx in [-6.8, 6.8]:
		for lz in [-3.8, 3.8]:
			add_child(InteractableObject3D.box(Vector3(0.4, 3.0, 0.4), Color(0.35, 0.2, 0.12), Vector3(lx, -1.9, lz)))
	# Floor and walls. These were painted for a desk at 2am - the wall albedo was
	# 0.2 and the floor 0.12, which is very nearly black paint, and no amount of
	# light makes black paint bright. That is why adding the ceiling bulb lit the
	# desk beautifully and left the room around it looking switched off. Lifting the
	# albedo is the other half of "turn the lights on", and it has to be the surfaces
	# rather than more light: brighter lamps would only have blown out the desk.
	#
	# Still well below the desk top (an orange around 0.55) so the desk stays the
	# brightest surface in the frame and the eye keeps going there first.
	add_child(InteractableObject3D.box(Vector3(40, 0.2, 40), Color(0.26, 0.19, 0.15), Vector3(0, -3.5, 0)))
	add_child(InteractableObject3D.box(Vector3(40, 14, 0.3), Color(0.44, 0.34, 0.28), Vector3(0, 3.5, -4.75)))
	add_child(InteractableObject3D.box(Vector3(40, 0.3, 0.5), Color(0.5, 0.38, 0.28), Vector3(0, 0.15, -4.6)))  # wainscot
	# The desk lamp lives in DeskLamp3D now - it is clickable, so it belongs
	# with the cat, the dock and the robot rather than here with the scenery.
	# The ceiling light. The desk lamp is still the light that MATTERS - it draws
	# the pool the player works in and casts every shadow on the desk - but a room
	# lit by one desk lamp and nothing else is a room at 2am, and Anh Khai wants the
	# lights on. This is the overhead bulb doing exactly the job an overhead bulb
	# does: lifting the whole room off black without deciding anything.
	#
	# Shadows deliberately off. A second shadow-caster would give every domino a
	# second shadow going the other way, and the one thing the desk lamp buys is
	# that a piece's shadow tells you where it stands relative to the lamp. It hangs
	# high and behind the camera, so it is never in frame and needs no fixture mesh.
	var ceiling := OmniLight3D.new()
	ceiling.position = Vector3(0.0, 8.5, 1.0)
	ceiling.light_color = Color(1.0, 0.94, 0.85)
	ceiling.light_energy = 2.4
	ceiling.omni_range = 34.0
	ceiling.omni_attenuation = 1.0
	ceiling.shadow_enabled = false
	add_child(ceiling)
	# mug
	var mug := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.36
	cyl.height = 0.9
	mug.mesh = cyl
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.87, 0.65, 0.22)
	mug.material_override = mm
	mug.position = Vector3(-6.4, 0.45, -1.0)
	add_child(mug)
	# notebook
	var nb := InteractableObject3D.box(Vector3(1.6, 0.08, 2.0), Color(0.92, 0.88, 0.78), Vector3(-6.3, 0.04, 1.0))
	nb.rotation.y = 0.35
	add_child(nb)
	# frames on the wall
	for f in [Vector3(-3.6, 3.0, -4.55), Vector3(-2.3, 3.7, -4.55)]:
		add_child(InteractableObject3D.box(Vector3(0.9, 1.1, 0.06), Color(0.3, 0.18, 0.1), f))
		add_child(InteractableObject3D.box(Vector3(0.7, 0.9, 0.02), Color(0.85, 0.8, 0.7), f + Vector3(0, 0, 0.04)))
	# plant
	add_child(InteractableObject3D.box(Vector3(0.9, 0.9, 0.9), Color(0.65, 0.35, 0.22), Vector3(6.3, 0.45, -3.6)))
	for p in [Vector3(6.3, 1.4, -3.6), Vector3(6.7, 1.7, -3.4), Vector3(5.9, 1.8, -3.8), Vector3(6.4, 2.1, -3.5)]:
		add_child(InteractableObject3D.sphere(0.4, Color(0.22, 0.45, 0.25), p))
	# pencils & sticky note
	var pen := InteractableObject3D.box(Vector3(1.4, 0.08, 0.08), Color(0.5, 0.25, 0.45), Vector3(2.6, 0.04, 3.0))
	pen.rotation.y = 0.3
	add_child(pen)
	var note := InteractableObject3D.box(Vector3(0.7, 0.02, 0.7), Color(0.95, 0.8, 0.25), Vector3(5.6, 0.01, 3.2))
	note.rotation.y = 0.2
	add_child(note)
	# digital clock, standing ON the desk behind the run rather than up on the
	# wall: the player's eyes live on the desk, and the time is something they
	# need at a glance without ever looking away from the dominoes
	var clock_at := Vector3(4.3, 0.34, -3.9)
	add_child(InteractableObject3D.box(Vector3(1.25, 0.68, 0.5), Color(0.09, 0.08, 0.09), clock_at))
	add_child(InteractableObject3D.box(Vector3(1.05, 0.44, 0.02), Color(0.05, 0.05, 0.06), clock_at + Vector3(0, 0.02, 0.26)))
	_clock = Label3D.new()
	_clock.pixel_size = 0.0035
	_clock.font_size = 96
	_clock.modulate = Color(1.0, 0.72, 0.2)
	_clock.outline_size = 0
	_clock.position = clock_at + Vector3(0, 0.02, 0.29)
	add_child(_clock)

func _process(_delta: float) -> void:
	_clock.text = GameManager.format_elapsed()
