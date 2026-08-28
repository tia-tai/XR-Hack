extends RefCounted
class_name WebStrand

var anchor_position: Vector3
var rest_length: float
var stiffness: float
var damping: float

func _init(p_anchor: Vector3, p_rest_length: float = 0.0, p_stiffness: float = 120.0, p_damping: float = 3.5) -> void:
	anchor_position = p_anchor
	rest_length = p_rest_length
	stiffness = p_stiffness
	damping = p_damping


## Calculates constraint forces and dynamic pendulum pull along the strand axis
func calculate_strand_force(current_position: Vector3, velocity: Vector3) -> Vector3:
	var to_anchor := anchor_position - current_position
	var current_length := to_anchor.length()

	if current_length < 0.001:
		return Vector3.ZERO

	var dir := to_anchor / current_length
	var stretch := current_length - rest_length

	# Only pull when the strand is taut (tautness constraint)
	if stretch <= 0.0:
		return Vector3.ZERO

	# Hooke's Law: F_spring = k * x
	var spring_force := dir * (stretch * stiffness)

	# Axis Damping: F_damping = c * (v · d)
	var vel_along_dir := velocity.dot(dir)
	var damping_force := dir * (vel_along_dir * damping)

	return spring_force - damping_force


## Calculates perpendicular swing force redirection (preserves momentum along arc)
func calculate_swing_vector(velocity: Vector3, current_position: Vector3) -> Vector3:
	var to_anchor := (anchor_position - current_position).normalized()
	# Strip radial velocity pointing away/towards anchor to create smooth circular arc motion
	var radial_velocity := to_anchor * velocity.dot(to_anchor)
	return velocity - radial_velocity