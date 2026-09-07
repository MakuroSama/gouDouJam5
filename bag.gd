
extends Node2D
class_name Chain

# ============================================================
# BAG
# ============================================================

@export_category("Bag")

@export var link_scene: PackedScene

@export var width: float = 350

@export_range(8, 100, 1)
var points: int = 16

@export var link_collision_radius: float = 32

# Collision circles overlap by this amount.
@export_range(1.0, 2.0, 0.05)
var collision_overlap: float = 1.5

# ============================================================
# PHYSICS
# ============================================================

@export_category("Physics")

# Higher = harder bag.
@export var stiffness: float = 1800.0

# Higher = less bouncing.
@export var damping_ratio: float = 1.5

# How much a link can stretch before the constraint
# starts strongly pulling it back.
#
# 1.0 = no stretch
# 1.05 = 5% stretch
# 1.15 = 15% stretch
@export_range(1.0, 1.5, 0.01)
var maximum_stretch: float = 1.08

# Strength of the hard length constraint.
@export var constraint_strength: float = 80.0

# Prevents violent movement when a box hits the bag.
@export var link_linear_damping: float = 3.0
@export var link_angular_damping: float = 5.0

# Mass of each bag link.
@export var link_mass: float = 0.05

# ============================================================
# HOOKS
# ============================================================

@export_category("Hooks")

@export var hook_path: NodePath
@export var hook2_path: NodePath

# ============================================================
# BREAKING
# ============================================================

@export_category("Breaking")

# Set to 0 to effectively disable breaking.
@export var break_threshold: float = 70.0

# ============================================================
# RENDERING
# ============================================================

@export_category("Rendering")

@export var draw_bag: bool = true
@export var bag_line_width: float = 2
@export var smooth_subdivisions: int = 40
@export var bag_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var bag_break_color: Color = Color(1.0, 0.0, 0.0, 1.0)


# ============================================================
# INTERNAL
# ============================================================

var links: Array[RigidBody2D] = []
var joints: Array[DampedSpringJoint2D] = []
var broken: Array[bool] = []
# Original distance between neighboring links.
var rest_distances: Array[float] = []

var left_hook: Node2D
var right_hook: Node2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	$LeftHook.position.x = -width / 2.0
	$rightHook.position.x = width / 2.0

	left_hook = get_node_or_null(hook_path)
	right_hook = get_node_or_null(hook2_path)

	if left_hook == null:
		left_hook = $LeftHook

	if right_hook == null:
		right_hook = $rightHook

	_build_bag()
	_connect_hooks()

	queue_redraw()


# ============================================================
# CREATE LINK
# ============================================================

func _make_link(pos: Vector2) -> RigidBody2D:

	if link_scene == null:
		push_error("Chain: link_scene is not assigned.")
		return null

	var link := link_scene.instantiate() as RigidBody2D

	if link == null:
		push_error("Chain: link_scene must contain a RigidBody2D.")
		return null

	add_child(link)

	link.global_position = pos

	# --------------------------------------------------------
	# PHYSICS
	# --------------------------------------------------------

	link.mass = link_mass

	link.linear_damp = link_linear_damping
	link.angular_damp = link_angular_damping

	# Prevent fast falling objects from tunneling through
	# individual bag links.
	link.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	link.freeze = false

	# --------------------------------------------------------
	# COLLIDER
	# --------------------------------------------------------

	_create_smooth_collider(link)

	links.append(link)

	return link


# ============================================================
# CREATE SMOOTH CIRCLE COLLIDER
# ============================================================

func _create_smooth_collider(link: RigidBody2D) -> void:

	# Remove the collider created by this script if one exists.
	var old := link.get_node_or_null("_BagCollider")

	if old != null:
		old.queue_free()

	var collision := CollisionShape2D.new()

	collision.name = "_BagCollider"

	var circle := CircleShape2D.new()

	circle.radius = link_collision_radius

	collision.shape = circle

	link.add_child(collision)

	# --------------------------------------------------------
	# BAG COLLISION
	#
	# BAG = layer 2
	# BOX = layer 1
	# --------------------------------------------------------

	link.collision_layer = 2
	link.collision_mask = 1


# ============================================================
# BUILD BAG
# ============================================================

func _build_bag() -> void:

	if left_hook == null or right_hook == null:
		push_error("Chain: Could not find hooks.")
		return

	# --------------------------------------------------------
	# CLEAN OLD BAG
	# --------------------------------------------------------

	for link in links:
		if is_instance_valid(link):
			link.queue_free()

	for joint in joints:
		if is_instance_valid(joint):
			joint.queue_free()

	links.clear()
	joints.clear()
	rest_distances.clear()
	broken.clear()

	# --------------------------------------------------------
	# BAG GEOMETRY
	# --------------------------------------------------------

	var left_position := left_hook.global_position
	var right_position := right_hook.global_position

	var center := (
		left_position + right_position
	) * 0.5

	var total_width := left_position.distance_to(
		right_position
	)

	var radius := total_width * 0.5


	# --------------------------------------------------------
	# AUTOMATIC POINT COUNT
	# --------------------------------------------------------

	var spacing := (
		link_collision_radius * 2.0
		/ collision_overlap
	)

	var minimum_points := int(
		ceil(total_width / spacing)
	) + 1

	points = max(points, minimum_points)


	# --------------------------------------------------------
	# CREATE U SHAPE
	# --------------------------------------------------------

	for i in range(points):

		var t := float(i) / float(points - 1)

		var angle := t * PI

		var Thisposition := center + Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)

		_make_link(Thisposition)


	# --------------------------------------------------------
	# CONNECT LINKS
	# --------------------------------------------------------

	for i in range(links.size() - 1):

		_create_spring(
			links[i],
			links[i + 1]
		)


# ============================================================
# CREATE SPRING
# ============================================================

func _create_spring(
	a: RigidBody2D,
	b: RigidBody2D
) -> void:

	if a == null or b == null:
		return

	var distance := a.global_position.distance_to(
		b.global_position
	)

	if distance <= 0.01:
		return

	# Remember the ORIGINAL spacing.
	rest_distances.append(distance)
	broken.append(false) 
	var joint := DampedSpringJoint2D.new()

	add_child(joint)

	joint.global_position = (
		a.global_position +
		b.global_position
	) * 0.5

	joint.node_a = a.get_path()
	joint.node_b = b.get_path()

	# Neighboring links must not collide with one another.
	joint.disable_collision = true

	joint.length = distance
	joint.rest_length = distance

	joint.stiffness = stiffness

	var average_mass := (
		a.mass + b.mass
	) * 0.5

	average_mass = max(average_mass, 0.01)

	joint.damping = (
		damping_ratio *
		2.0 *
		sqrt(stiffness * average_mass)
	)

	joints.append(joint)


# ============================================================
# HOOKS
# ============================================================

func _connect_hooks() -> void:

	if links.size() < 2:
		return

	_add_hook(
		right_hook,
		links[0]
	)

	_add_hook(
		left_hook,
		links[links.size() - 1]
	)


func _add_hook(
	hook: Node2D,
	link: RigidBody2D
) -> void:

	if hook == null or link == null:
		return

	var joint := PinJoint2D.new()

	add_child(joint)

	joint.global_position = hook.global_position

	joint.node_a = hook.get_path()
	joint.node_b = link.get_path()

	joint.disable_collision = true

	joint.softness = 0.0


# ============================================================
# PHYSICS CONSTRAINT
# ============================================================

func _physics_process(_delta: float) -> void:

	if links.size() < 2:
		return


	# --------------------------------------------------------
	# HARD LENGTH CONSTRAINT
	# --------------------------------------------------------
	#
	# This is the important part.
	#
	# The spring alone is allowed to stretch.
	# This constraint stops the bag from becoming infinitely
	# long.
	#

	for i in range(links.size() - 1):
		if i < broken.size() and broken[i]:
			continue 
		var a := links[i]
		var b := links[i + 1]
	
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue

		var difference := (
			b.global_position -
			a.global_position
		)

		var distance := difference.length()

		if distance <= 0.001:
			continue

		if i >= rest_distances.size():
			continue

		var rest_length := rest_distances[i]

		var maximum_length := (
			rest_length *
			maximum_stretch
		)

		# Only correct the chain when it is actually
		# stretched beyond its allowed length.
		if distance > maximum_length:

			var direction := difference / distance

			var error := (
				distance -
				maximum_length
			)

			# Pull both links toward one another.
			var correction_force := (
				direction *
				error *
				constraint_strength
			)

			a.apply_central_force(
				correction_force
			)

			b.apply_central_force(
				-correction_force
			)


	# --------------------------------------------------------
	# BREAKING
	# --------------------------------------------------------

	if break_threshold > 0.0:

		for i in range(joints.size()):

			if broken[i]:
				continue

			var joint := joints[i]
			if not is_instance_valid(joint):
				continue

			var a := links[i]
			var b := links[i + 1]

			var distance := a.global_position.distance_to(b.global_position)

			if distance > break_threshold:
				_break_joint(i)


	queue_redraw()


# ============================================================
# BREAK JOINT
# ============================================================

func _break_joint(
	index: int
) -> void:
	print("breaking joint ", index)

	if index < 0 or index >= joints.size():
		return

	broken[index] = true

	var joint := joints[index]
	if is_instance_valid(joint):
		joint.queue_free()

# ============================================================
# SMOOTH BAG DRAWING
# ============================================================

func _draw() -> void:


	if not draw_bag:
		return

	if links.size() < 2:
		return

	var raw_points: Array[Vector2] = []

	for link in links:
		if is_instance_valid(link):
			raw_points.append(to_local(link.global_position))

	if raw_points.size() < 2:
		return

	# --------------------------------------------------------
	# PUSH POINTS OUTWARD FROM CENTER
	#
	# raw_points only traces link CENTERS. Offsetting each
	# point away from the bag's centroid by ~link_collision_radius
	# makes the line trace the bag's outer surface instead,
	# so we don't need a huge line width to fake volume.
	# --------------------------------------------------------

	var center := Vector2.ZERO

	for p in raw_points:
		center += p

	center /= raw_points.size()

	var offset_points: Array[Vector2] = []

	for p in raw_points:

		var direction := p - center

		if direction.length() > 0.001:
			direction = direction.normalized()
		else:
			direction = Vector2.UP

		offset_points.append(p - direction * link_collision_radius)

	var subdivisions = max(smooth_subdivisions, 1)

	var smooth_points := _smooth_points(offset_points, subdivisions)

	for i in range(smooth_points.size() - 1):

		var orig_segment = i / subdivisions

		if orig_segment < broken.size() and broken[orig_segment]:
			continue

		draw_line(
			smooth_points[i],
			smooth_points[i + 1],
			lerp(bag_color,bag_break_color,(smooth_points[i].distance_to(smooth_points[i+1])*smooth_subdivisions)/break_threshold),
			bag_line_width,
			true
		)


# ============================================================
# CATMULL-ROM SMOOTHING
# ============================================================

func _smooth_points(
	points_array: Array[Vector2],
	subdivisions: int
) -> Array[Vector2]:

	var result: Array[Vector2] = []

	if points_array.size() < 2:
		return points_array

	subdivisions = max(
		subdivisions,
		1
	)

	for i in range(points_array.size() - 1):

		var p1 := points_array[i]
		var p2 := points_array[i + 1]

		var p0: Vector2
		var p3: Vector2

		if i == 0:
			p0 = p1
		else:
			p0 = points_array[i - 1]

		if i + 2 >= points_array.size():
			p3 = p2
		else:
			p3 = points_array[i + 2]

		for j in range(subdivisions):

			var t := float(j) / float(subdivisions)

			var t2 := t * t
			var t3 := t2 * t

			var point := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(
					2.0 * p0
					- 5.0 * p1
					+ 4.0 * p2
					- p3
				) * t2 +
				(
					-p0
					+ 3.0 * p1
					- 3.0 * p2
					+ p3
				) * t3
			)

			result.append(point)

	result.append(
		points_array[points_array.size() - 1]
	)

	return result
