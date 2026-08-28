extends Node
class_name GameManager

signal state_changed(old: GameState, new: GameState)

enum GameState {
	CUTSCENE,
	EMBODIMENT,
	TRAVERSAL,
	PLANE_EVENT,
	RESOLUTION
}

const SCENE_PATHS := {
	GameState.CUTSCENE: "res://scenes/levels/cutscene_apartment.tscn",
	GameState.TRAVERSAL: "res://scenes/levels/city_traversal.tscn",
	GameState.PLANE_EVENT: "res://scenes/levels/plane_crash_site.tscn",
}

var state: GameState = GameState.CUTSCENE


func transition_to(new_state: GameState) -> void:
	if state == new_state:
		return

	var old_state := state
	state = new_state
	state_changed.emit(old_state, new_state)

	# Change scene if the new state maps to a different tscn
	if SCENE_PATHS.has(new_state):
		var target_path: String = SCENE_PATHS[new_state]
		if get_tree().current_scene and get_tree().current_scene.scene_file_path != target_path:
			get_tree().change_scene_to_file(target_path)
