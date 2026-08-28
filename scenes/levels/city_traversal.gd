extends Node3D

@export var plane_event_trigger: Area3D

func _ready() -> void:
	if plane_event_trigger:
		plane_event_trigger.body_entered.connect(_on_plane_zone_entered)

func _on_plane_zone_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		get_node("/root/GameManager").transition_to(GameManager.GameState.PLANE_EVENT)
