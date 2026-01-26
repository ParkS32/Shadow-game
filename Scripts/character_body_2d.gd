extends CharacterBody2D

# Movement tuning
@export var speed := 200.0
@export var gravity := 900.0
@export var jump_force := -280.0 # Slightly increased base force
@export var jump_gravity_scale := 0.4 # Scale gravity by this while holding jump
@export var fall_gravity_scale := 1.5 # Scale gravity by this when falling or released early
@export var jump_cut_multiplier := 0.5 # Factor to multiply velocity when jump is released early

# Clone / recording settings
@export var clone_scene: PackedScene = preload("res://Scenes/Main_Character.tscn")
@export var max_record_time: float = 5.0 # maximum seconds to record when holding F

# Internal state
@export var is_clone: bool = false

var recording: bool = false
var record_timer: float = 0.0
var recorded_frames: Array = []
var clone_instance: Node = null

# Replay state (used only by clones)
var replay_data: Array = []
var replay_index: int = 0
var is_replaying: bool = false

#Animation
@onready var anim = $AnimatedSprite2D

var on_ladder := false
var climb_speed := 150.0

#shadow
var buffer_max_time := 3.0
var buffer_max_frames := int(buffer_max_time / Engine.get_physics_ticks_per_second())

	
func _physics_process(delta):
	Global.record_input()
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	# Flip sprite based on direction
	if input_vector.x < 0:
		anim.flip_h = true
	elif input_vector.x > 0:
		anim.flip_h = false
	#idle Checker
	if input_vector == Vector2.ZERO:
		anim.play("Idle")
	# Horizontal movement — constant speed, no sliding
	velocity.x = 0.0
	if on_ladder:
		# Vertical movement on ladder
		velocity.y = 0.0
		if Input.is_action_pressed("jump") or Input.is_action_pressed("ui_up"): # W
			velocity.y = - climb_speed
			anim.play("Walking")
			print("[Player] Climbing UP")
		elif Input.is_action_pressed("Down") or Input.is_action_pressed("ui_down"): # S
			velocity.y = climb_speed
			anim.play("Walking")
			print("[Player] Climbing DOWN")
		
		# Allow horizontal movement on ladder too? Let's keep it simple for now or allow slight movement
		if Input.is_action_pressed("move_left"):
			velocity.x = - speed * 0.5
		elif Input.is_action_pressed("move_right"):
			velocity.x = speed * 0.5
	else:
		if Input.is_action_pressed("move_left"):
			velocity.x = - speed
			anim.play("Walking")
		elif Input.is_action_pressed("move_right"):
			velocity.x = speed
			anim.play("Walking")
		
		# Dynamic Gravity
		var current_gravity = gravity
		if velocity.y < 0: # Rising
			if Input.is_action_pressed("jump"):
				current_gravity *= jump_gravity_scale # Lighter gravity while holding
			else:
				current_gravity *= fall_gravity_scale # Heavier gravity if released
		else: # Falling
			current_gravity *= fall_gravity_scale # Faster fall for weightier feel
			
		velocity.y += current_gravity * delta

	# Jump logic
	if Input.is_action_just_pressed("jump") and is_on_floor() and not on_ladder:
		velocity.y = jump_force
		print("[Player] Jumped")

	move_and_slide()
	

	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			col.get_collider().apply_central_impulse(-col.get_normal() * 10)


func _start_recording() -> void:
	recording = true
	record_timer = 0.0
	recorded_frames.clear()

	print_debug("[testcharacter] started recording")


func _finish_recording() -> void:
	# After recording ends, start the clone replay process: make it visible and give it the recorded frames
	if recorded_frames.size() == 0:
		print_debug("[testcharacter] finished recording but no frames captured")
		return

	# instantiate clone now (spawn on release)
	if not clone_scene:
		print_debug("[testcharacter] no clone_scene assigned")
		return

	clone_instance = clone_scene.instantiate()
	if not clone_instance:
		print_debug("[testcharacter] failed to instantiate clone_scene")
		return

	# mark it as a clone so it won't start recording
	if clone_instance.has_method("set"):
		clone_instance.set("is_clone", true)

	# place clone at player's position with slight offset and add to scene
	clone_instance.global_position = global_position + Vector2(16, 0)
	clone_instance.visible = true
	get_parent().add_child(clone_instance)
	print_debug("[testcharacter] spawned clone at release; frames=%d duration=%.2f" % [recorded_frames.size(), record_timer])

	# start the clone replay by calling its start_replay method if available
	if clone_instance.has_method("start_replay"):
		clone_instance.call("start_replay", recorded_frames)
	else:
		if clone_instance.has_method("set"):
			clone_instance.set("replay_data", recorded_frames.duplicate(true))
			clone_instance.set("is_replaying", true)

	# add a timer to remove the clone after the recorded duration (plus small buffer)
	var replay_time = max(record_timer, 0.1)
	var t := Timer.new()
	t.wait_time = replay_time + 0.1
	t.one_shot = true
	t.autostart = true
	clone_instance.add_child(t)
	t.connect("timeout", Callable(clone_instance, "queue_free"))


func start_replay(data: Array) -> void:
	# Called on clone instances to receive recorded frames and begin playback
	replay_data = data.duplicate(true)
	replay_index = 0
	is_replaying = true


func _process_clone(delta: float) -> void:
	# Clone should follow replay_data frames one per physics tick
	if is_replaying and replay_index < replay_data.size():
		var frame = replay_data[replay_index]
		var dir := 0.0
		if frame.has("dir"):
			dir = frame["dir"]
		var jump_pressed := false
		if frame.has("jump"):
			jump_pressed = frame["jump"]

		velocity.x = dir * speed
		#if jump_pressed and is_on_floor():
			#velocity.y = jump_force 

		if not is_on_floor():
			velocity.y += gravity * delta

		replay_index += 1
	else:
		# If not replaying or finished replay, simple gravity to keep clone grounded
		if not is_on_floor():
			velocity.y += gravity * delta

	move_and_slide()
	
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			col.get_collider().apply_central_impulse(
				- col.get_normal() * 30)
