extends Node
class_name WebAnchor

@export var is_attachable: bool = true

func can_attach() -> bool:
	return is_attachable