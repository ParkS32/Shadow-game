extends RigidBody2D

@export var max_speed := 200.0  # Cap the carton's speed

func _physics_process(delta):
	if linear_velocity.length() > 0.1:
		print("BLOCK MOVING:", linear_velocity)
	
	# Cap velocity to prevent shooting
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed