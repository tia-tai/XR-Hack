extends CharacterBody3D
class_name PlayerMovement

@export var web_shooter: WebShooter
@export var xr_origin: XROrigin3D

@export_group("Swing Physics")
@export var gravity: float = 9.8
@export var reel_in_speed: float = 2.0            # Speed at which rope shortens (reduced from 6.0)
@export var arm_pull_boost: float = 60.0          # Pull impulse strength (reduced from 300.0)
@export var max_hand_pull_speed: float = 2.0      # Cap hand tracking speed to ignore VR jitter spikes
@export var max_swing_speed: float = 28.0         # Max velocity cap to keep swings controlled
@export var air_drag: float = 0.07                # Air drag to prevent infinite speed buildup

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

var _rope_lengths: Array[float] = [0.0, 0.0]
var _prev_local_hand_positions: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


func _physics_process(delta: float) -> void:
	# 1. Apply gravity when airborne
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Process dynamic pendulum rope physics for both hands
	_process_rope_swing(delta)

	# 3. Apply air drag to bleed excess speed smoothly
	velocity -= velocity * air_drag * delta

	# 4. Cap overall velocity to prevent wild exponential launches
	if velocity.length() > max_swing_speed:
		velocity = velocity.normalized() * max_swing_speed

	# 5. Move player body
	move_and_slide()


func _process_rope_swing(delta: float) -> void:
	if not web_shooter:
		return

	for hand in 2:
		var is_attached: bool = web_shooter._attached[hand]

		if not is_attached:
			_rope_lengths[hand] = 0.0
			continue

		var tracker := XRServer.get_tracker(HAND_TRACKERS[hand]) as XRHandTracker
		if tracker == null or not tracker.get_has_tracking_data():
			_rope_lengths[hand] = 0.0
			continue

		var anchor_pos: Vector3 = web_shooter._attach_points[hand]
		var to_anchor := anchor_pos - global_position
		var current_dist := to_anchor.length()

		# Initialize rope length when first attaching
		if _rope_lengths[hand] <= 0.0:
			_rope_lengths[hand] = current_dist

		# Apply pendulum constraint ONLY while holding a fist
		if _is_fist_pose(tracker):
			var dir_to_anchor := to_anchor.normalized()

			# Measure physical VR hand pull speed in local tracking space
			var current_local_hand := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).origin
			var prev_local_hand := _prev_local_hand_positions[hand]
			_prev_local_hand_positions[hand] = current_local_hand

			# Calculate raw hand speed and clamp it to filter out VR tracking noise/spikes
			var raw_hand_speed := (current_local_hand - prev_local_hand).length() / delta
			var hand_pull_speed := minf(raw_hand_speed, max_hand_pull_speed)

			# Reel in web rope gradually
			var reel_amount := (reel_in_speed + hand_pull_speed * 1.5) * delta
			_rope_lengths[hand] = maxf(4.0, _rope_lengths[hand] - reel_amount)

			# --- PENDULUM ROPE CONSTRAINT MATH ---
			# If the rope is taut (player distance >= set rope length)
			if current_dist >= _rope_lengths[hand]:
				var radial_vel := velocity.dot(dir_to_anchor)

				# Strip away outward velocity component smoothly
				if radial_vel < 0.0:
					velocity -= dir_to_anchor * radial_vel

				# Add controlled physical arm pull impulse
				if hand_pull_speed > 0.1:
					velocity += dir_to_anchor * (hand_pull_speed * arm_pull_boost * delta)
		else:
			_prev_local_hand_positions[hand] = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).origin


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
