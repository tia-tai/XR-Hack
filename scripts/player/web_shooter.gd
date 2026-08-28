extends Node3D
class_name WebShooter

@export var player_body: CharacterBody3D
@export var xr_origin: XROrigin3D
@export var max_distance: float = 150.0
@export var web_color := Color(0.9, 0.9, 0.9)

const HAND_TRACKERS: Array[StringName] = [
	&"/user/hand_tracker/left",
	&"/user/hand_tracker/right",
]

const FINGER_CHAINS := [
	[6, 7, 8, 9, 10],     # Index
	[11, 12, 13, 14, 15], # Middle
	[16, 17, 18, 19, 20], # Ring
	[21, 22, 23, 24, 25]  # Pinky
]

var _attached := [false, false]
var _attach_points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _immediate_meshes: Array[ImmediateMesh] = []
var _mesh_instances: Array[MeshInstance3D] = []
var _was_web_pose := [false, false]


func _ready() -> void:
	_setup_line_renderers()


func _physics_process(_delta: float) -> void:
	var tracker_left := XRServer.get_tracker(HAND_TRACKERS[0]) as XRHandTracker
	var tracker_right := XRServer.get_tracker(HAND_TRACKERS[1]) as XRHandTracker

	for hand in 2:
		var tracker := tracker_left if hand == 0 else tracker_right
		if tracker == null or not tracker.get_has_tracking_data():
			_detach_web(hand)
			continue

		var is_web := _is_web_pose(tracker)

		# 1. Shoot web independently on gesture
		if is_web and not _was_web_pose[hand] and not _attached[hand]:
			print("WebShooter: Hand %d fired web..." % hand)
			_shoot_web(hand, tracker)

		_was_web_pose[hand] = is_web

		# 2. Detach when hand opens fully
		if _attached[hand] and _is_open_hand_pose(tracker):
			_detach_web(hand)

		# 3. Render web line
		if _attached[hand]:
			var hand_pos := _get_hand_position(tracker)
			_draw_web_line(hand, hand_pos, _attach_points[hand])
		else:
			_mesh_instances[hand].visible = false

	# 4. Trigger net connection if BOTH hands are attached and forming fists
	if _attached[0] and _attached[1] and tracker_left != null and tracker_right != null:
		if _is_fist_pose(tracker_left) and _is_fist_pose(tracker_right):
			_connect_both_webs()


func _shoot_web(hand: int, tracker: XRHandTracker) -> void:
	var origin := _get_hand_position(tracker)
	var direction := _get_hand_forward(tracker)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)

	if player_body:
		query.exclude = [player_body.get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		print("WebShooter: Hand %d attached to %s" % [hand, result.position])
		_attached[hand] = true
		_attach_points[hand] = result.position
		_mesh_instances[hand].visible = true


func _connect_both_webs() -> void:
	print("WebShooter: Connecting web net endpoints...")
	var point_a := _attach_points[0]
	var point_b := _attach_points[1]

	_spawn_net_strand(point_a, point_b)

	_detach_web(0)
	_detach_web(1)


func _spawn_net_strand(from: Vector3, to: Vector3) -> void:
	var net_line := ImmediateMesh.new()
	net_line.surface_begin(Mesh.PRIMITIVE_LINES)
	net_line.surface_add_vertex(from)
	net_line.surface_add_vertex(to)
	net_line.surface_end()

	var instance := MeshInstance3D.new()
	instance.mesh = net_line
	instance.set_meta("anchor_a", from)
	instance.set_meta("anchor_b", to)
	instance.add_to_group("web_nets")

	var material := StandardMaterial3D.new()
	material.albedo_color = web_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material

	get_tree().current_scene.add_child(instance)


func _detach_web(hand: int) -> void:
	_attached[hand] = false
	_mesh_instances[hand].visible = false


func _is_web_pose(tracker: XRHandTracker) -> bool:
	var index_curl := _finger_curl(tracker, FINGER_CHAINS[0])
	var middle_curl := _finger_curl(tracker, FINGER_CHAINS[1])
	var ring_curl := _finger_curl(tracker, FINGER_CHAINS[2])
	var pinky_curl := _finger_curl(tracker, FINGER_CHAINS[3])

	return index_curl < 0.35 and pinky_curl < 0.35 \
		and middle_curl > 0.55 and ring_curl > 0.55


func _is_open_hand_pose(tracker: XRHandTracker) -> bool:
	for chain in FINGER_CHAINS:
		if _finger_curl(tracker, chain) > 0.35:
			return false
	return true


func _is_fist_pose(tracker: XRHandTracker) -> bool:
	for chain in FINGER_CHAINS:
		if _finger_curl(tracker, chain) < 0.45:
			return false
	return true


func _finger_curl(tracker: XRHandTracker, chain: Array) -> float:
	var straight := tracker.get_hand_joint_transform(chain[0]).origin \
		.distance_to(tracker.get_hand_joint_transform(chain[-1]).origin)
	var summed := 0.0
	for i in chain.size() - 1:
		summed += tracker.get_hand_joint_transform(chain[i]).origin \
			.distance_to(tracker.get_hand_joint_transform(chain[i + 1]).origin)
	if summed == 0.0:
		return 0.0
	return 1.0 - (straight / summed)


func _get_hand_position(tracker: XRHandTracker) -> Vector3:
	var joint_transform := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST)
	if xr_origin:
		return xr_origin.global_transform * joint_transform.origin
	return global_transform * joint_transform.origin


func _get_hand_forward(tracker: XRHandTracker) -> Vector3:
	var wrist_pos := _get_hand_position(tracker)
	var index_transform := tracker.get_hand_joint_transform(10)
	
	var index_pos: Vector3
	if xr_origin:
		index_pos = xr_origin.global_transform * index_transform.origin
	else:
		index_pos = global_transform * index_transform.origin

	var forward_dir := (index_pos - wrist_pos).normalized()
	if forward_dir.is_zero_approx():
		return -global_transform.basis.z.normalized()

	return forward_dir


func _setup_line_renderers() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = web_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in 2:
		var imm_mesh := ImmediateMesh.new()
		var instance := MeshInstance3D.new()
		instance.mesh = imm_mesh
		instance.material_override = material
		instance.visible = false
		add_child(instance)

		_immediate_meshes.append(imm_mesh)
		_mesh_instances.append(instance)


func _draw_web_line(hand: int, from: Vector3, to: Vector3) -> void:
	var imm := _immediate_meshes[hand]
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	# Convert global world coordinates into local space for drawing
	imm.surface_add_vertex(to_local(from))
	imm.surface_add_vertex(to_local(to))
	imm.surface_end()
