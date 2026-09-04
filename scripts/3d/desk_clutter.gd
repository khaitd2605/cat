class_name DeskClutter
extends RefCounted
## The things that are actually on a desk, and get in the way of a domino run.
##
## Obstacles used to be grey boxes of random size. They worked as obstacles and
## read as nothing: you routed around a rectangle because the game said so, not
## because there was a mug there. These are real objects at the desk's real
## scale, which is what makes the desk a place instead of a playing field.
##
## THE SCALE IS FIXED BY THE DOMINO. A piece is 1.0 tall in game units and about
## 4.5 cm in the hand, so one unit is ~4.5 cm and the playable desk is roughly
## 67 x 39 cm - a real desk. Every size below is derived from that, which is why
## the book is 4.0 long (18 cm, a paperback) and the mug 1.55 tall (7 cm, an
## espresso cup) rather than whatever looked right on screen.
##
## HEIGHT IS A GAMEPLAY PROPERTY, not decoration. The camera sits low and close,
## so a tall object walls off the part of the desk you are trying to route
## across - you end up going around something you cannot see past. That is what
## SCALE is for, and why the table keeps no phone lying face down and no eraser:
## even at full size those were too flat to read as blockers at all.
##
## `size` is the full AABB, including anything that sticks out such as the mug
## handle: DominoTask3D checks placement against that box, so an object is never
## allowed to be prettier than its own footprint.

## Everything is built at this fraction of the sizes in the table below.
##
## The table is in TRUE desk proportions - a mug really is about one and a half
## dominoes tall. On screen, with the camera low and close, true proportions read
## as furniture rather than clutter and they swallow the desk. Anh Khai called
## it: half size. It lives here as one knob so the table can stay honest about
## what these things actually are, and so changing his mind costs one number.
##
## What it costs: at half size nothing on the desk is as tall as a domino, so a
## piece that fell against one of these would tip over it rather than be stopped
## dead. Nothing is ever laid close enough for that to happen - the placement
## rule forbids the whole footprint plus a margin - so what these objects really
## do is take space away from your route, which is the job they were put here
## for anyway.
const SCALE := 0.5

## Every kind, with the footprint the desk rules see, BEFORE SCALE. `turnable`
## marks the ones that are not square and may be laid across instead of
## lengthways.
const KINDS := [
	{"kind": "cup",      "size": Vector3(2.20, 1.55, 1.75), "turnable": false},
	{"kind": "can",      "size": Vector3(1.50, 2.00, 1.50), "turnable": false},
	{"kind": "pen_cup",  "size": Vector3(1.60, 1.70, 1.60), "turnable": false},
	{"kind": "plant",    "size": Vector3(1.80, 1.70, 1.80), "turnable": false},
	{"kind": "tape",     "size": Vector3(2.40, 0.95, 2.40), "turnable": false},
	{"kind": "book",     "size": Vector3(4.00, 0.70, 2.80), "turnable": true},
	{"kind": "stapler",  "size": Vector3(1.10, 1.10, 3.30), "turnable": true},
	{"kind": "mouse",    "size": Vector3(1.50, 0.95, 2.30), "turnable": true},
]

## Pick one object: a kind, a size jittered a little so two mugs are not twins,
## and whether it lies across the desk instead of along it.
##
## `avoid` lists the kinds already on the desk. Two cans and two mice on one desk
## is not impossible, it just reads as the game having run out of ideas - and
## there are eight kinds for six slots, so variety is free.
static func pick(avoid: Array = []) -> Dictionary:
	var pool: Array = KINDS.filter(func(e: Dictionary) -> bool: return not (e["kind"] in avoid))
	if pool.is_empty():
		pool = KINDS
	var k: Dictionary = pool.pick_random()
	var s: Vector3 = k["size"] * SCALE * randf_range(0.92, 1.08)
	var turned: bool = k["turnable"] and randf() < 0.5
	if turned:
		s = Vector3(s.z, s.y, s.x)
	return {"kind": k["kind"], "size": s, "turned": turned}

## The longest side of the footprint - what the scatter has to keep clear.
static func span(o: Dictionary) -> float:
	var s: Vector3 = o["size"]
	return maxf(s.x, s.z)

# --------------------------------------------------------------- building one

## A static body with the collider the chain really hits and the meshes you
## recognise it by. The collider comes from `size`, so what you see, what stops
## a domino, and what the placement rule forbids are all the same object.
static func build(o: Dictionary) -> StaticBody3D:
	var size: Vector3 = o["size"]
	var kind: String = o["kind"]
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	if kind in ["cup", "can", "pen_cup", "plant", "tape"]:
		var cs := CylinderShape3D.new()
		cs.radius = minf(size.x, size.z) * 0.5
		cs.height = size.y
		shape.shape = cs
	else:
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	match kind:
		"cup": _cup(body, size)
		"can": _can(body, size)
		"pen_cup": _pen_cup(body, size)
		"plant": _plant(body, size)
		"tape": _tape(body, size)
		"book": _book(body, size, o["turned"])
		"stapler": _stapler(body, size, o["turned"])
		"mouse": _mouse(body, size, o["turned"])
	return body

# --------------------------------------------------------------- the objects

## Coffee mug: a straight-sided cup, a dark disc of coffee near the rim, and a
## handle. The handle sits inside the AABB the KINDS table declares for it - the
## extra 0.45 of x is exactly this.
static func _cup(body: StaticBody3D, size: Vector3) -> void:
	var r := minf(size.x, size.z) * 0.5
	body.add_child(_cyl(r, r, size.y, Vector3(0, size.y * 0.5, 0), Color(0.93, 0.94, 0.96)))
	body.add_child(_cyl(r * 0.86, r * 0.86, 0.04, Vector3(0, size.y - 0.18, 0), Color(0.24, 0.14, 0.09)))
	var handle := _torus(r * 0.32, r * 0.62, Vector3(r * 0.95, size.y * 0.58, 0), Color(0.93, 0.94, 0.96))
	handle.rotation = Vector3(PI * 0.5, 0, 0)
	body.add_child(handle)

## Drinks can: a body, and a duller lid recessed at the top.
static func _can(body: StaticBody3D, size: Vector3) -> void:
	var r := minf(size.x, size.z) * 0.5
	body.add_child(_cyl(r, r, size.y, Vector3(0, size.y * 0.5, 0), Color(0.72, 0.24, 0.22)))
	body.add_child(_cyl(r * 0.9, r * 0.9, 0.06, Vector3(0, size.y - 0.02, 0), Color(0.78, 0.79, 0.82)))

## Pen pot: a cup with pencils leaning out of it. The pencils are above the
## collider, so they are scenery - a domino never touches them.
static func _pen_cup(body: StaticBody3D, size: Vector3) -> void:
	var r := minf(size.x, size.z) * 0.5
	body.add_child(_cyl(r, r * 0.88, size.y, Vector3(0, size.y * 0.5, 0), Color(0.32, 0.36, 0.42)))
	var cols := [Color(0.9, 0.72, 0.24), Color(0.3, 0.5, 0.8), Color(0.8, 0.35, 0.35)]
	for i in 3:
		var lean := 0.16 + 0.06 * i
		var a := TAU * (float(i) / 3.0) + 0.4
		var pen := _cyl(0.07, 0.07, 1.9, Vector3.ZERO, cols[i])
		pen.position = Vector3(cos(a) * r * 0.45, size.y * 0.75 + 0.75, sin(a) * r * 0.45)
		pen.rotation = Vector3(sin(a) * lean, 0.0, -cos(a) * lean)
		body.add_child(pen)

## Little pot plant: a tapered pot, soil, and a squashed ball of leaves.
static func _plant(body: StaticBody3D, size: Vector3) -> void:
	var r := minf(size.x, size.z) * 0.5
	var pot_h := size.y * 0.6
	body.add_child(_cyl(r, r * 0.72, pot_h, Vector3(0, pot_h * 0.5, 0), Color(0.7, 0.42, 0.3)))
	body.add_child(_cyl(r * 0.92, r * 0.92, 0.05, Vector3(0, pot_h - 0.03, 0), Color(0.22, 0.16, 0.12)))
	var leaves := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 1.0
	sm.height = (size.y - pot_h) * 1.8
	leaves.mesh = sm
	leaves.position = Vector3(0, pot_h + (size.y - pot_h) * 0.55, 0)
	leaves.material_override = _mat(Color(0.32, 0.55, 0.3))
	body.add_child(leaves)

## Roll of sticky tape, lying flat: the one object you can see straight through,
## which makes it read as a hole in the route that is not one.
static func _tape(body: StaticBody3D, size: Vector3) -> void:
	var r := minf(size.x, size.z) * 0.5
	var ring := _torus(r * 0.42, r, Vector3(0, size.y * 0.5, 0), Color(0.85, 0.8, 0.62, 1.0))
	body.add_child(ring)
	body.add_child(_cyl(r * 0.44, r * 0.44, size.y * 0.5, Vector3(0, size.y * 0.25, 0), Color(0.9, 0.9, 0.92)))

## Paperback lying flat: cover, and pages inset on three sides so the spine
## still reads as a spine from above.
static func _book(body: StaticBody3D, size: Vector3, turned: bool) -> void:
	body.add_child(_box(size, Vector3(0, size.y * 0.5, 0), Color(0.35, 0.42, 0.6)))
	var pages := Vector3(size.x - 0.16, size.y * 0.62, size.z - 0.16)
	var shift := Vector3(0.08 if turned else 0.0, 0.0, 0.0 if turned else 0.08)
	body.add_child(_box(pages, Vector3(0, size.y * 0.52, 0) + shift, Color(0.94, 0.92, 0.86)))

## Stapler: a base and a shorter top arm, hinged end raised.
static func _stapler(body: StaticBody3D, size: Vector3, turned: bool) -> void:
	var long := size.z if not turned else size.x
	body.add_child(_box(size * Vector3(1, 0.45, 1), Vector3(0, size.y * 0.22, 0), Color(0.2, 0.22, 0.26)))
	var arm := Vector3(size.x * 0.82, size.y * 0.4, size.z * 0.82)
	var back := Vector3(0, 0, long * 0.08) if not turned else Vector3(long * 0.08, 0, 0)
	body.add_child(_box(arm, Vector3(0, size.y * 0.72, 0) + back, Color(0.72, 0.24, 0.26)))

## Mouse: a squashed dome, buried to its equator so the desk cuts it flat, with
## the seam between the buttons scored across the top.
##
## The dome is scaled to twice `size.y` on purpose: a sphere spans half its
## height either side of its centre, so only the doubled version leaves a dome
## exactly `size.y` tall above the desk. Scaled to size.y it came out nearly as
## tall as it was wide - a ball, not a mouse.
static func _mouse(body: StaticBody3D, size: Vector3, turned: bool) -> void:
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	dome.mesh = sm
	dome.scale = Vector3(size.x, size.y * 2.0, size.z)
	dome.material_override = _mat(Color(0.26, 0.28, 0.32))
	body.add_child(dome)
	# A thin line LYING ON the shell. The first version was a tall thin plate, and
	# it read as a fin sticking out of a bowling ball.
	var seam := Vector3(0.05, 0.05, size.z * 0.45)
	if turned:
		seam = Vector3(size.x * 0.45, 0.05, 0.05)
	body.add_child(_box(seam, Vector3(0, size.y * 0.97, 0), Color(0.14, 0.15, 0.18)))

# --------------------------------------------------------------- mesh helpers

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

static func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	return mi

static func _cyl(top: float, bottom: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	return mi

static func _torus(inner: float, outer: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 20
	tm.ring_segments = 10
	mi.mesh = tm
	mi.position = pos
	mi.material_override = _mat(c)
	return mi
