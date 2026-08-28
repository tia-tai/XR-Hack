# Attached to cutscene_apartment.tscn root
extends Node3D

@export var cutscene_camera: Camera3D
@export var xr_origin: XROrigin3D
@export var tv_animation_player: AnimationPlayer

func _ready() -> void:
	# Start in 3rd-person camera mode
	cutscene_camera.current = true
	get_viewport().use_xr = false
	
	#tv_animation_player.play("news_report_goose_crash")
	#tv_animation_player.animation_finished.connect(_on_tv_report_ended)


#func _on_tv_report_ended(_anim_name: String) -> void:
	# Jump out window animation triggers perspective shift into VR
	#cutscene_camera.current = false
	#get_viewport().use_xr = true # Enables VR Headset view[cite: 3]
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.transition_to(game_manager.GameState.EMBODIMENT)
