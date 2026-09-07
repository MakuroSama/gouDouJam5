extends Node2D
class_name Chain

@export var link_scene: PackedScene
@export var width = 200
@export var break_threshold: float = 35.0
@export var hook_path: NodePath   # top-left
@export var hook2_path: NodePath  # top-right
@export var points: int = 10
@export var stiffness: float = 10000.0
@export var damping_ratio: float = 1.0
@export var link_collision_radius: float = 8.0  # NEW: used to size overlap


var links: Array[RigidBody2D] = []
var joints: Array[DampedSpringJoint2D] = []
var height

var collision_body: StaticBody2D
var collision_polygon: CollisionPolygon2D

func _ready():
	$LeftHook.position.x = -width/2.0
	$rightHook.position.x = width/2.0
	_build_bag()
	_connect_hooks()

func _make_link(pos: Vector2) -> RigidBody2D:
	var link = link_scene.instantiate()
	add_child(link)
	link.global_position = pos

	# NEW: prevent fast/heavy objects tunneling through this link
	link.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	links.append(link)
	return link

func _spring(a: RigidBody2D, b: RigidBody2D):
	var dist = a.global_position.distance_to(b.global_position)
	if dist < 0.01:
		push_warning("Chain: overlapping links, skipping spring")
		return
	
	var joint = DampedSpringJoint2D.new()
	add_child(joint)
	joint.global_position = (a.global_position + b.global_position) / 2.0
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()
	joint.disable_collision = true
	var avg_mass = (a.mass + b.mass) / 2.0
	#joint.softness = 1
	joint.damping = damping_ratio*2.0 * sqrt(stiffness * avg_mass)  # critically damped baseline
	joint.stiffness = stiffness * points
	joint.length = dist
	joint.rest_length = dist
	joints.append(joint)

func _build_bag():
	var leftHook = get_node_or_null(hook_path)
	var rightHook = get_node_or_null(hook2_path)
	var center =( rightHook.global_position + leftHook.global_position) /2
	# NEW: auto-tighten spacing so consecutive link colliders overlap
	# instead of leaving gaps for objects to fall through
	var total_dist = leftHook.global_position.distance_to(rightHook.global_position)
	var max_points_needed = int(ceil(total_dist / (link_collision_radius * 1.2)))
	if points < max_points_needed:
		push_warning("Chain: 'points' too low for gapless bag, consider raising it to at least %d" % max_points_needed)

	for i in range(points):
		var angle = i * PI / (points - 1 )
		var pos:Vector2 =  center + Vector2(cos(angle), sin(angle)) * (total_dist/2)
		_make_link(pos)
	for i in links.size() -1:
		_spring(links[i], links[i + 1])

func _connect_hooks():
	_add_hook(hook2_path, links[0])
	_add_hook(hook_path, links[links.size()-1])

func _add_hook(hook_path_: NodePath, link: RigidBody2D):
	if hook_path_.is_empty():
		push_warning("Chain: hook path not set!")
		return
	var hook_node = get_node_or_null(hook_path_)
	if hook_node == null:
		push_warning("Chain: hook path set but node not found: " + str(hook_path_))
		return
	var anchor_joint = PinJoint2D.new()
	add_child(anchor_joint)
	anchor_joint.global_position = hook_node.global_position
	anchor_joint.node_a = hook_node.get_path()
	anchor_joint.node_b = link.get_path()
	anchor_joint.disable_collision = true
	anchor_joint.softness = 0.0


func _physics_process(_delta):
	for joint in joints.duplicate():
		if not is_instance_valid(joint):
			continue
		var body_a = get_node(joint.node_a) as RigidBody2D
		var body_b = get_node(joint.node_b) as RigidBody2D
		if not body_a or not body_b:
			continue
		if body_a.global_position.distance_to(body_b.global_position) > break_threshold:
			break_joint(joint)
	queue_redraw()
func break_joint(joint: DampedSpringJoint2D):
	joints.erase(joint)
	joint.queue_free()

func _draw():
	
	if joints == null:
		return
	for i in joints:
		var node_a = get_node_or_null(i.node_a)
		var node_b = get_node_or_null(i.node_b)
		if node_a and node_b:
			var from = to_local(node_a.global_position)
			var to = to_local(node_b.global_position)
			draw_line(from, to, Color(i.damping,0,i.stiffness/2000), 2.0)
