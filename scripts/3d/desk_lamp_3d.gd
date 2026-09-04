class_name DeskLamp3D
extends InteractableObject3D
## The desk lamp, and the switch for it. Click the shade to turn it off and on.
##
## It lives in its own script rather than inside `room_3d.gd` because it stopped
## being scenery the moment it became clickable: the room draws things you look
## at, and everything you can click at is its own node with its own script - the
## cat, the dock, the robot. This is that pattern, not a new one.
##
## The lamp is also the only shadow caster in the room. The ceiling bulb and the
## ambient fill are deliberately shadowless, so every shadow on the desk radiates
## from this cone and lengthens with distance from it. Switching it off therefore
## does something no brightness slider does - it takes the shadows away, and the
## desk goes flat. That is the point of having the switch.

## Where the shade hangs, and the point on the desk it is aimed at. The cone, its
## lit inside, the bulb and the spotlight are all built from these two, so
## re-aiming the lamp is one edit and the geometry can never disagree with the
## light.
const HEAD := Vector3(-3.5, 3.5, -2.8)
## Aimed a little towards the player rather than straight across the desk. The
## beam has to contain the whole playable area - measured, not guessed: at the
## first aim the BAT DAU pad in the near-left corner sat 58.9 degrees off the beam
## axis against a 56-degree cone and went dark, which is the one landmark that
## must always be findable.
const AIM := Vector3(-0.5, 0.0, 0.6)

const CASE := Color(0.18, 0.36, 0.34)

## How hard the lit inside of the shade and the bulb glow. One constant because
## `_toggle()` paints the same surface back on, and two numbers that must match
## are one number waiting to drift.
##
## Dropped from 1.6: above the environment's glow threshold the shade stopped
## being a warm surface and became a bloom source, so the mouth smeared over the
## wall behind it and the whole lamp read as glare rather than as a lamp. It only
## has to look lit from across a desk, and 0.85 does that without crossing into
## bloom.
const GLOW := 0.85

var lit := true

var _light: SpotLight3D
var _liner: MeshInstance3D
var _bulb: MeshInstance3D

static func dir() -> Vector3:
	return (AIM - HEAD).normalized()

func _ready() -> void:
	# The click box wraps the SHADE, not the whole lamp. Clicking the pole to turn
	# the light off is not something anyone reaches for, and a box around the stand
	# would sit over a patch of desk the player needs for dominoes. Generous around
	# the shade itself, because at this camera distance the cone is a small target
	# and nothing else competes for that piece of sky.
	hit_size = Vector3(2.0, 1.5, 1.7)
	hit_offset = HEAD
	super._ready()
	hover_label = "Tắt đèn bàn"
	interacted.connect(_toggle)
	_build()

func _toggle() -> void:
	lit = not lit
	_light.visible = lit
	_bulb.visible = lit
	# The shade's lit inside is a flat emissive surface, so "off" has to be painted
	# rather than unlit: dropped to the dark teal of the outside, which is what an
	# unlit shade looks like from across a room.
	var lm := _liner.material_override as StandardMaterial3D
	lm.albedo_color = Color(1.0, 0.88, 0.62) if lit else Color(0.1, 0.2, 0.19)
	lm.emission_energy_multiplier = GLOW if lit else 0.0
	hover_label = "Tắt đèn bàn" if lit else "Bật đèn bàn"
	Sfx.play("switch", -6.0)

func _build() -> void:
	add_child(InteractableObject3D.box(Vector3(1.4, 0.15, 1.4), CASE, Vector3(-6.3, 0.07, -3.2)))
	var pole := InteractableObject3D.box(Vector3(0.12, 3.6, 0.12), CASE, Vector3(-6.3, 1.9, -3.2))
	pole.rotation.z = -0.25
	add_child(pole)
	var arm := InteractableObject3D.box(Vector3(2.6, 0.12, 0.12), CASE, Vector3(-4.7, 3.8, -3.0))
	arm.rotation.z = 0.25
	add_child(arm)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 0.9
	cone.height = 0.9
	# Open at the wide end, which is the whole point of a lampshade. A CylinderMesh
	# caps both ends by default, so the shade was a sealed solid: the bulb and the
	# lit inside were behind a disc, and looking into the mouth showed the OUTSIDE
	# of that disc - a black ellipse. That is why the lamp read as a dark cone with
	# a beam appearing out of thin air beneath it.
	cone.cap_bottom = false

	var head := MeshInstance3D.new()
	head.mesh = cone
	var hm := StandardMaterial3D.new()
	# Much darker teal than the pole it hangs off, and that is not a style choice:
	# the shade sits about 0.9 units from the light, which is point-blank, and at
	# the old albedo it blew out to a mint-green glow brighter than the bulb. A lamp
	# whose shade outshines its bulb reads as a lamp made of light.
	hm.albedo_color = Color(0.08, 0.17, 0.16)
	hm.roughness = 1.0
	head.material_override = hm
	head.position = HEAD
	head.quaternion = Quaternion(Vector3.UP, -dir())
	# Off, so the shade does not cut its own light. A cone with a light inside it
	# casts a shadow of itself onto the beam it is making, and at this size that
	# arrives as shadow acne round the rim rather than as a crisp edge - the
	# spotlight's own angle draws a much cleaner cone than the geometry does.
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(head)

	# The lit inside of the shade, and it needs its own mesh. A CylinderMesh only
	# renders its outward faces, so looking into the mouth of the shade meant
	# looking straight through it at the dark wall behind. This is the same cone a
	# hair smaller with the FRONT faces culled instead of the back ones, so what it
	# draws is exactly the surface the bulb is shining on.
	#
	# Unshaded and emissive rather than lit: the spotlight sits inside this cone and
	# a real light would give it a hotspot at the bulb and a falloff up the walls,
	# which at this scale is two pixels of gradient. A flat warm glow is what the
	# eye expects from a lampshade seen from across a desk - and it is also what
	# makes the off state a one-line change instead of a lighting problem.
	_liner = MeshInstance3D.new()
	_liner.mesh = cone
	_liner.position = head.position
	_liner.quaternion = head.quaternion
	_liner.scale = Vector3.ONE * 0.97
	_liner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.88, 0.62)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.cull_mode = BaseMaterial3D.CULL_FRONT
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.87, 0.6)
	lm.emission_energy_multiplier = GLOW
	_liner.material_override = lm
	add_child(_liner)

	# Inside the shade, on its axis, a little back from the mouth - so you catch the
	# glow when the desk is in front of you and the shade hides it from the side.
	_bulb = InteractableObject3D.sphere(0.16, Color(1, 0.95, 0.7), HEAD + dir() * 0.22)
	_bulb.material_override.emission_enabled = true
	_bulb.material_override.emission = Color(1, 0.9, 0.6)
	# Unshaded, so the bulb is exactly the warm colour it emits instead of that
	# colour plus whatever the light beside it adds - it came out white otherwise,
	# and it is the one thing in the room that has to look warm.
	_bulb.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bulb.material_override.emission_energy_multiplier = GLOW
	add_child(_bulb)

	# THE light, and it comes OUT OF THE SHADE. An omni cannot do this job: a point
	# light does not know it is supposed to be inside a housing, so it lit the
	# outside of its own shade at point-blank range and the lamp glowed green like
	# a lantern. A spotlight sitting in the cone is the honest version - its beam
	# leaves through the mouth, the shade is behind the beam so nothing lights it,
	# and the cone drawn on the desk is the cone of the lamp.
	_light = SpotLight3D.new()
	_light.position = HEAD + dir() * 0.2
	_light.light_color = Color(1.0, 0.86, 0.64)
	# Measured on the desk wood, the beam is 1.34x the brightness of the desk outside
	# it at 6.5 energy and 1.35x at 9.0 - the ACES tonemapper compresses the whole
	# range, so past about 4 more energy buys no contrast at all. It only pushes the
	# hotspot under the shade towards white, and THAT is the glare: a white patch on
	# the desk with no wood grain left in it. So this comes back down to where the
	# curve still has room. What says "the lamp is the light" was never the energy
	# anyway - it is that this is the only shadow caster in the room.
	_light.light_energy = 4.0
	# Wide, because a 30-degree beam on a 67 cm desk is a torch and this is a room
	# light. The soft edge matters as much as the width: a hard rim would read as a
	# cut-out, and the far corner is meant to fade, not to end.
	_light.spot_angle = 60.0
	_light.spot_angle_attenuation = 0.9
	_light.spot_range = 26.0
	_light.spot_attenuation = 0.7
	_light.shadow_enabled = true
	# The beam grazes the desk at a shallow angle, which is the case shadow bias is
	# worst at - a domino would otherwise trail a dark seam back to its own foot.
	_light.shadow_normal_bias = 2.5
	add_child(_light)
	# After add_child: look_at works in global space and needs the node in the tree.
	_light.look_at(AIM, Vector3.UP)
