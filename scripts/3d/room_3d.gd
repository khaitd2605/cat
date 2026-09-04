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
	# floor & walls
	add_child(InteractableObject3D.box(Vector3(40, 0.2, 40), Color(0.12, 0.08, 0.06), Vector3(0, -3.5, 0)))
	add_child(InteractableObject3D.box(Vector3(40, 14, 0.3), Color(0.2, 0.13, 0.1), Vector3(0, 3.5, -4.75)))
	add_child(InteractableObject3D.box(Vector3(40, 0.3, 0.5), Color(0.3, 0.2, 0.14), Vector3(0, 0.15, -4.6)))  # wainscot
	# lamp
	add_child(InteractableObject3D.box(Vector3(1.4, 0.15, 1.4), Color(0.18, 0.36, 0.34), Vector3(-6.3, 0.07, -3.2)))
	var pole := InteractableObject3D.box(Vector3(0.12, 3.6, 0.12), Color(0.18, 0.36, 0.34), Vector3(-6.3, 1.9, -3.2))
	pole.rotation.z = -0.25
	add_child(pole)
	var arm := InteractableObject3D.box(Vector3(2.6, 0.12, 0.12), Color(0.18, 0.36, 0.34), Vector3(-4.7, 3.8, -3.0))
	arm.rotation.z = 0.25
	add_child(arm)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.9
	cone.height = 0.9
	head.mesh = cone
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.2, 0.42, 0.4)
	head.material_override = hm
	head.position = Vector3(-3.5, 3.5, -2.8)
	head.rotation.z = -0.35
	add_child(head)
	var bulb := InteractableObject3D.sphere(0.18, Color(1, 0.95, 0.7), Vector3(-3.35, 3.1, -2.8))
	bulb.material_override.emission_enabled = true
	bulb.material_override.emission = Color(1, 0.9, 0.6)
	bulb.material_override.emission_energy_multiplier = 3.0
	add_child(bulb)
	var light := OmniLight3D.new()
	light.position = Vector3(-3.0, 3.0, -2.2)
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.6
	light.omni_range = 14.0
	light.shadow_enabled = true
	add_child(light)
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
	# clock on the wall
	add_child(InteractableObject3D.box(Vector3(1.6, 0.8, 0.15), Color(0.1, 0.09, 0.09), Vector3(4.6, 3.4, -4.6)))
	_clock = Label3D.new()
	_clock.pixel_size = 0.006
	_clock.font_size = 96
	_clock.modulate = Color(1.0, 0.72, 0.2)
	_clock.position = Vector3(4.6, 3.4, -4.5)
	add_child(_clock)

func _process(_delta: float) -> void:
	_clock.text = GameManager.format_elapsed()
