extends Node
class_name WebGestureDetector

signal web_gesture_started(hand: int)
signal web_gesture_ended(hand: int)

var _was_active := [false, false]

func _process(_delta: float) -> void:
	for hand in 2:
		var tracker := XRServer.get_tracker(
			&"/user/hand_tracker/left" if hand == 0 else &"/user/hand_tracker/right"
		) as XRHandTracker
		if tracker == null or not tracker.get_has_tracking_data():
			continue

		var active := _is_web_pose(tracker)
		if active and not _was_active[hand]:
			web_gesture_started.emit(hand)
		elif not active and _was_active[hand]:
			web_gesture_ended.emit(hand)
		_was_active[hand] = active


func _is_web_pose(tracker: XRHandTracker) -> bool:
	var index_curl := _finger_curl(tracker, [6, 7, 8, 9, 10])
	var middle_curl := _finger_curl(tracker, [11, 12, 13, 14, 15])
	var ring_curl := _finger_curl(tracker, [16, 17, 18, 19, 20])
	var pinky_curl := _finger_curl(tracker, [21, 22, 23, 24, 25])

	return index_curl < 0.3 and pinky_curl < 0.3 \
		and middle_curl > 0.6 and ring_curl > 0.6


## Rough curl = 1 - (straight-line tip distance / summed bone lengths)
func _finger_curl(tracker: XRHandTracker, chain: Array) -> float:
	var straight := tracker.get_hand_joint_transform(chain[0]).origin \
		.distance_to(tracker.get_hand_joint_transform(chain[-1]).origin)
	var summed := 0.0
	for i in chain.size() - 1:
		summed += tracker.get_hand_joint_transform(chain[i]).origin \
			.distance_to(tracker.get_hand_joint_transform(chain[i+1]).origin)
	if summed == 0.0:
		return 0.0
	return 1.0 - (straight / summed)
