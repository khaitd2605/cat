class_name VacuumDock3D
extends InteractableObject3D
## The robot's charging dock: a clickable spot at the back edge of the desk.
##
## It holds no logic. RobotVacuum3D listens to its `interacted` signal and
## drives the light on it - the dock is a button and a lamp, and the robot is
## the thing with opinions. Keeping the state in one place means there is
## exactly one answer to "what is the robot doing", instead of two that can
## drift apart.
##
## It sits OUTSIDE the play area on purpose. A dock in the middle of the desk
## would be one more obstacle to route around, and it would put the interesting
## decision - which line home is safe - in the wrong place: the whole point is
## that the line crosses the desk you have been building on.
##
## The BACK edge, specifically, and that was a lesson from a screenshot. At the
## near edge the camera clipped it off the bottom of the frame and the robot
## parked on it filled a quarter of the screen; from the back it reads at the
## same size as everything else on the desk, and the road home crosses the
## build diagonal instead of running along beside it.
##
## The plate is modelled with its back wall towards +z, so a dock on the far
## edge is turned around in the scene - the wall belongs on the outside.

## Wide enough for the robot to sit on, shallow enough to fit in the strip
## between the play area and the back edge of the desk. Scaled down with the
## robot - a full-size cradle under a palm-sized machine looked like a bath mat.
const PLATE := Vector3(1.5, 0.09, 0.95)

var _led_mat: StandardMaterial3D

func _ready() -> void:
	# Roomier than the plate, for the same reason the robot is: this is a button.
	hit_size = Vector3(PLATE.x * 1.4, 0.8, PLATE.z * 1.6)
	hit_offset = Vector3(0, 0.35, 0)
	super._ready()
	hover_label = "Gọi robot về sạc"
	_build()
	if not GameManager.level_def()["robot"]:
		visible = false
		input_ray_pickable = false

func set_led(col: Color) -> void:
	if _led_mat:
		_led_mat.albedo_color = col
		_led_mat.emission = col

func _build() -> void:
	# Slate teal, and the colour is doing real work. Charcoal vanished into the
	# lamp's shadow at the back of the desk; the light grey that replaced it then
	# merged with the loose paper lying next to it. Teal is the one family that
	# is neither the desk (orange), the paper (white) nor the robot (grey), so it
	# stays findable whatever ends up around it.
	var case := Color(0.24, 0.42, 0.48)
	# the ramp plate the robot parks on
	add_child(box(PLATE, case, Vector3(0, PLATE.y * 0.5, 0)))
	# a pale bay marked on the plate, so it reads as a parking spot even with the
	# robot standing on it
	add_child(box(Vector3(PLATE.x * 0.78, 0.02, PLATE.z * 0.62),
		Color(0.62, 0.78, 0.82), Vector3(0, PLATE.y + 0.01, -0.06)))
	# the back wall, angled back so it reads as a dock rather than a doorstep
	var wall := box(Vector3(PLATE.x * 0.88, 0.52, 0.11), Color(0.68, 0.70, 0.76),
		Vector3(0, 0.26, PLATE.z * 0.40))
	wall.rotation.x = -0.18
	add_child(wall)
	# two contact pins, the detail that says "charger" without a label
	for x in [-0.30, 0.30]:
		add_child(box(Vector3(0.11, 0.15, 0.06), Color(0.90, 0.76, 0.34),
			Vector3(PLATE.x * x, 0.13, PLATE.z * 0.30)))
	# The status light goes up a mast rather than sitting on the plate. From this
	# camera - high, in front - the plate is nearly edge-on and everything flat on
	# it is a couple of pixels tall, so the one part that has to be readable from
	# across the desk is the one part that stands up.
	add_child(box(Vector3(0.07, 0.55, 0.07), case, Vector3(0, 0.28, PLATE.z * 0.34)))
	var led := box(Vector3(0.34, 0.20, 0.12), Color(0.35, 0.95, 0.5),
		Vector3(0, 0.62, PLATE.z * 0.34))
	_led_mat = led.material_override as StandardMaterial3D
	_led_mat.emission_enabled = true
	_led_mat.emission_energy_multiplier = 0.7
	add_child(led)
