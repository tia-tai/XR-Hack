# Updated scripts/gameplay/plane_controller.gd
extends RigidBody3D
class_name PlaneController

const PLANE_WEIGHT_LBS: float = 502500.0
const BASE_WEB_CAPACITY_LBS: float = 2000.0

@export var plane_speed: float = 50.0 # m/s
var accumulated_stopping_force: float = 0.0


func _physics_process(_delta: float) -> void:
	# Continuous plane forward movement
	var plane_dir := -transform.basis.z.normalized()
	linear_velocity = plane_dir * plane_speed


func _on_body_entered(body: Node) -> void:
	# Triggered when plane collides with player-created web nets
	if body.is_in_group("web_nets"):
		var anchor_a: Vector3 = body.get_meta("anchor_a")
		var anchor_b: Vector3 = body.get_meta("anchor_b")

		var strand_vector := (anchor_b - anchor_a).normalized()
		var plane_dir := -transform.basis.z.normalized()

		# Angle multiplier 1: Perpendicular alignment to plane flight path
		# Webs perpendicular to flight path (90 deg / dot product near 0) absorb max force
		var alignment_dot := absf(plane_dir.dot(strand_vector))
		var angle_multiplier := 1.0 - alignment_dot # Max when perpendicular (1.0)

		# Angle multiplier 2: Structural spread angle multiplier
		var strand_length := anchor_a.distance_to(anchor_b)
		var length_multiplier := clampf(strand_length / 10.0, 0.5, 2.5)

		# Total force calculation in lbs
		var strand_capacity := BASE_WEB_CAPACITY_LBS * angle_multiplier * length_multiplier
		accumulated_stopping_force += strand_capacity

		# Destroy the web strand after impact
		body.queue_free()

		_check_plane_stopped()


func _check_plane_stopped() -> void:
	if accumulated_stopping_force >= PLANE_WEIGHT_LBS:
		plane_speed = 0.0
		freeze = true
		
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.transition_to(game_manager.GameState.RESOLUTION)