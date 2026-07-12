extends CharacterBody2D
class_name Player
## Player controller: run/jump with acceleration, variable jump height,
## coyote time, and jump buffering.

signal died

@export var speed: float = 150.0
@export var acceleration: float = 1000.0
@export var friction: float = 1000.0
@export var jump_velocity: float = -380.0
@export var jump_cut_factor: float = 0.5
@export var bounce_velocity_factor: float = 0.7

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _is_dead: bool = false


func _ready() -> void:
	Game.level_cleared.connect(_on_level_cleared)


func _on_level_cleared() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		coyote_timer.start()

	var input_direction: float = Input.get_axis("move_left", "move_right")
	if input_direction != 0.0:
		velocity.x = move_toward(velocity.x, speed * input_direction, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer.start()

	if jump_buffer_timer.time_left > 0.0 and coyote_timer.time_left > 0.0:
		_do_jump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_factor

	move_and_slide()


func _do_jump() -> void:
	velocity.y = jump_velocity
	coyote_timer.stop()
	jump_buffer_timer.stop()


func bounce() -> void:
	velocity.y = jump_velocity * bounce_velocity_factor


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	set_physics_process(false)
	died.emit()
	Game.player_died()
