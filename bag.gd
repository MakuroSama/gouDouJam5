extends Node2D
class_name Chain

signal bag_broken

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
# SAFETY
# ============================================================

@export_category("Safety")

# Hard cap on the corrective force applied by the length
# constraint. Without this, a huge sudden stretch (e.g. a fast
# object slamming into the bag) can generate a corrective force
# large enough to fling links to extreme speeds in a single
# frame, which then cascades through every neighboring spring.
@export var max_correction_force: float = 4000.0

# Hard cap on how fast any single link is allowed to move.
# This is the actual "safety net": no matter what force gets
# applied to a link (physics engine impulses, other scripts,
# an exploding constraint, etc.) its velocity can never exceed
# this, so the simulation can't run away.
@export var max_link_speed: float = 6000.0

# If a link moves further than this in a single physics step,
# it's treated as a numerical explosion (not a "real" fast
# collision) and the affected segment is broken immediately
# instead of fighting it with more force.
@export var max_step_displacement: float = 400.0

# If enabled, any link/joint that goes NaN or Infinite (the
# clearest sign the simulation has gone haywire) is caught and
# repaired instead of being allowed to silently corrupt the
# rest of the chain and the renderer.
@export var recover_from_invalid_state: bool = true


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
@export_category("Bag Fill")
@export var draw_bag_fill: bool = true
@export var bag_fill_shader: Shader

# ============================================================
# INTERNAL
# ============================================================

var links: Array[RigidBody2D] = []
var joints: Array[DampedSpringJoint2D] = []
var broken: Array[bool] = []
var _is_broken_signaled: bool = false
# Original distance between neighboring links.
var rest_distances: Array[float] = []

# Position of each link at the end of the previous physics
# step. Used purely for explosion / teleport detection.
var previous_positions: Array[Vector2] = []

var left_hook: Node2D
var right_hook: Node2D

var bag_fill: Polygon2D

# ============================================================
# READY
# ============================================================

func _ready() -> void:

	$LeftHook.position.x = -width / 2.0
	$rightHook.position.x = width / 2.0
	
	left_hook = $LeftHook


	right_hook = $rightHook

	_build_bag()
	_connect_hooks()
	_setup_bag_fill()
	queue_redraw()
	for child in links[0].get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true
	for child in links[links.size()-1].get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true
	z_as_relative = false
	z_index = 4  # just below bag_fill's 5, so fill still layers over the line correctly if needed
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
	previous_positions.append(pos)

	return link


# ============================================================
# CREATE SMOOTH CIRCLE COLLIDER
# ============================================================

func _create_smooth_collider(link: RigidBody2D) -> void:

	# Remove the collider created by this script if one exists.
	if get_tree().current_scene.name == "MainScene":
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
	previous_positions.clear()

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
	# SAFETY PASS 1: catch NaN/Infinite state and clamp speed
	#
	# This runs BEFORE any spring/constraint logic so a link
	# that already went haywire (e.g. from an engine-side
	# collision impulse) can't poison the calculations below.
	# --------------------------------------------------------

	_apply_safety_net()

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

		# SAFETY: if the distance itself is not a sane finite
		# number, don't try to correct it with force (that
		# would just inject NaN into the RigidBody2D). Break
		# the segment instead and move on.
		if not is_finite(distance):
			_break_joint(i)
			continue

		if i >= rest_distances.size():
			continue

		var rest_length := rest_distances[i]

		var maximum_length := (
			rest_length *
			maximum_stretch
		)

		# SAFETY: a jump this large in a single physics step
		# is not a "stretchy bag" situation, it's a numerical
		# explosion (huge impulse, tunneling collision, etc).
		# Breaking here avoids fighting it with an even bigger
		# corrective force next frame.
		if distance > rest_length + max_step_displacement:
			_break_joint(i)
			continue

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

			# SAFETY: clamp the correction force itself so a
			# single extreme stretch can't apply an unbounded
			# impulse.
			if correction_force.length() > max_correction_force:
				correction_force = (
					correction_force.normalized()
					* max_correction_force
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
			if distance > break_threshold/1.5:
				SfxPool.play_sfx(preload("res://SE・BGM/SE/audiostock_1309294.mp3"))
			if distance > break_threshold:
				_break_joint(i)

	# --------------------------------------------------------
	# SAFETY PASS 2: final velocity clamp
	#
	# Runs last so nothing added above (constraint forces,
	# engine collision response, etc.) can leave a link moving
	# faster than max_link_speed by the time the frame ends.
	# --------------------------------------------------------

	_clamp_velocities()
	_store_previous_positions()
	_update_bag_fill()
	queue_redraw()


# ============================================================
# SAFETY NET
# ============================================================

# Detects and repairs links that have gone NaN/Infinite, and
# catches single-frame teleports that indicate the simulation
# has already gone unstable (rather than a legitimately fast
# but valid collision response).
func _apply_safety_net() -> void:

	if not recover_from_invalid_state:
		return

	for i in range(links.size()):

		var link := links[i]

		if not is_instance_valid(link):
			continue

		var pos := link.global_position
		var vel := link.linear_velocity

		var pos_invalid := (
			not is_finite(pos.x) or not is_finite(pos.y)
		)
		var vel_invalid := (
			not is_finite(vel.x) or not is_finite(vel.y)
		)

		if pos_invalid or vel_invalid:

			push_warning(
				"Chain: link %d entered an invalid state, recovering." % i
			)

			# Recover to the last known-good position and stop
			# it dead rather than letting NaN/Infinity spread
			# through connected joints and the renderer.
			var fallback := Vector2.ZERO

			if i < previous_positions.size():
				fallback = previous_positions[i]

			link.global_position = fallback
			link.linear_velocity = Vector2.ZERO
			link.angular_velocity = 0.0

			# A link that just exploded is not trustworthy;
			# break its neighboring segments so the rest of
			# the bag doesn't get dragged along with it.
			if i - 1 >= 0:
				_break_joint(i - 1)
			if i < joints.size():
				_break_joint(i)

			continue

		# Detect an implausible single-frame teleport even
		# when the numbers are technically finite (e.g. a
		# huge but valid-looking impulse from a fast object).
		if i < previous_positions.size():

			var step_distance := pos.distance_to(previous_positions[i])

			if step_distance > max_step_displacement * 3.0:

				push_warning(
					"Chain: link %d moved implausibly far in one step, clamping."
					% i
				)

				link.global_position = (
					previous_positions[i]
					+ (pos - previous_positions[i]).normalized()
					* max_step_displacement
				)
				link.linear_velocity = link.linear_velocity.limit_length(
					max_link_speed
				)


# Hard ceiling on how fast any link may move. This is the last
# line of defense: whatever produced the velocity (springs,
# constraints, engine collision impulses, external scripts)
# doesn't matter — it simply cannot exceed this speed.
func _clamp_velocities() -> void:

	for link in links:

		if not is_instance_valid(link):
			continue

		if not is_finite(link.linear_velocity.x) or not is_finite(link.linear_velocity.y):
			link.linear_velocity = Vector2.ZERO
			continue

		if link.linear_velocity.length() > max_link_speed:
			link.linear_velocity = link.linear_velocity.limit_length(
				max_link_speed
			)


func _store_previous_positions() -> void:

	for i in range(links.size()):

		if i >= previous_positions.size():
			previous_positions.append(Vector2.ZERO)

		if is_instance_valid(links[i]):
			previous_positions[i] = links[i].global_position


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

	if not _is_broken_signaled:
		_is_broken_signaled = true
		bag_broken.emit()

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
			var p := link.global_position
			# SAFETY: never feed NaN/Infinite positions to the
			# renderer — Godot's line drawing can throw or
			# silently corrupt the draw batch on bad input.
			if is_finite(p.x) and is_finite(p.y):
				raw_points.append(to_local(p))

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

	
		
	var subdivisions = max(smooth_subdivisions, 1)

	var smooth_points := _get_offset_points()

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

# ============================================================
# SHADER BAG FILL
# ============================================================

func _setup_bag_fill() -> void:

	if not draw_bag_fill:
		return

	bag_fill = Polygon2D.new()
	bag_fill.name = "BagFill"
	bag_fill.color = Color(1, 1, 1, 1) # actual color/alpha comes from the shader

	var mat := ShaderMaterial.new()
	mat.shader = bag_fill_shader
	bag_fill.material = mat
	# Draw above other game objects (boxes, etc.) regardless of
	# where they sit in the scene tree, so the bag reads as
	# wrapping around them rather than sitting underneath.
	bag_fill.z_as_relative = false
	bag_fill.z_index = 5
	add_child(bag_fill)

func _update_bag_fill() -> void:

	if bag_fill == null:
		return

	if broken.has(true):
		bag_fill.visible = false
		return

	var local_points: Array[Vector2] = []

	for point in _get_offset_points():
		
		if is_finite(point.x) and is_finite(point.y):
			local_points.append(point)

	if local_points.size() < 2 or left_hook == null or right_hook == null:
		bag_fill.visible = false
		return

	local_points.append(to_local(left_hook.global_position))
	local_points.append(to_local(right_hook.global_position))

	var min_pt := local_points[0]
	var max_pt := local_points[0]

	for p in local_points:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)

	var size := max_pt - min_pt
	size.x = max(size.x, 0.001)
	size.y = max(size.y, 0.001)

	bag_fill.polygon = PackedVector2Array(local_points)

	var mat := bag_fill.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("bounds_min", min_pt)
		mat.set_shader_parameter("bounds_size", size)

	bag_fill.visible = true
	
# ============================================================
# OFFSET POINTS
# ============================================================

func _get_offset_points()-> Array[Vector2]:
	var raw_points: Array[Vector2] = []

	for link in links:
		if is_instance_valid(link):
			var p := link.global_position
			# SAFETY: never feed NaN/Infinite positions to the
			# renderer — Godot's line drawing can throw or
			# silently corrupt the draw batch on bad input.
			if is_finite(p.x) and is_finite(p.y):
				raw_points.append(to_local(p))

	if raw_points.size() < 2:
		return []

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

	return smooth_points
