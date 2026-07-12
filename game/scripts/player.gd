extends CharacterBody2D
class_name Player
## Player controller: run/jump with acceleration, variable jump height,
## coyote time, and jump buffering. Also owns the shared damage API
## (take_damage/power_up) that enemies and pickups call into -- see #7.

signal died

## SMALL is the default, one-hit-death state; SUPER survives one hit by
## dropping back to SMALL with a brief invincibility window instead of dying.
## Only the sprite changes between the two -- the collision shape stays the
## same size in both states (see docs/design/#7/design.md).
enum PowerState { SMALL, SUPER }
enum ContactOutcome { IGNORE, STOMP, DAMAGE }

const INVINCIBILITY_SEC: float = 1.5
const INVINCIBILITY_BLINK_SEC: float = 0.1

@export var speed: float = 150.0
@export var acceleration: float = 1000.0
@export var friction: float = 1000.0
@export var jump_velocity: float = -380.0
@export var jump_cut_factor: float = 0.5
@export var bounce_velocity_factor: float = 0.7

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var power_state: PowerState = PowerState.SMALL
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _is_dead: bool = false
var _half_height: float = 0.0
var _invincible: bool = false


func _ready() -> void:
	Game.level_cleared.connect(_on_level_cleared)
	invincibility_timer.wait_time = INVINCIBILITY_SEC
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	var collision_shape: CollisionShape2D = $CollisionShape2D
	var rect := collision_shape.shape as RectangleShape2D
	_half_height = collision_shape.position.y + rect.size.y / 2.0


func feet_global_y() -> float:
	## Global y of the player's bottom edge; used by enemies for stomp checks.
	return global_position.y + _half_height


func classify_enemy_contact(enemy_center_y: float) -> ContactOutcome:
	## A single classification point keeps overlapping physics callbacks from
	## producing contradictory stomp and damage outcomes. Dead and temporarily
	## invincible players never affect or take damage from an enemy contact.
	if _is_dead or _invincible:
		return ContactOutcome.IGNORE
	if velocity.y > 0.0 and feet_global_y() <= enemy_center_y:
		return ContactOutcome.STOMP
	return ContactOutcome.DAMAGE


func is_dead() -> bool:
	return _is_dead


func is_invincible() -> bool:
	return _invincible


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
	_update_animation()


func _update_animation() -> void:
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	var prefix: String = "super_" if power_state == PowerState.SUPER else ""
	if not is_on_floor():
		sprite.play(prefix + "jump")
	elif absf(velocity.x) > 1.0:
		sprite.play(prefix + "run")
	else:
		sprite.play(prefix + "idle")


func _do_jump() -> void:
	velocity.y = jump_velocity
	coyote_timer.stop()
	jump_buffer_timer.stop()


func bounce() -> void:
	if _is_dead:
		return
	velocity.y = jump_velocity * bounce_velocity_factor


func launch(vertical_velocity: float) -> void:
	## Stage springs use the same guarded vertical-impulse entry point.
	if _is_dead:
		return
	velocity.y = vertical_velocity
	coyote_timer.stop()
	jump_buffer_timer.stop()


func power_up() -> void:
	## SMALL -> SUPER. Picking up a second mushroom while already SUPER is a
	## no-op here -- the mushroom itself still awards its score either way.
	if power_state == PowerState.SUPER:
		return
	power_state = PowerState.SUPER


func take_damage() -> bool:
	## Shared damage entrypoint: enemies/hazards call this instead of die()
	## directly. SUPER loses its power-up and gets a brief invincibility
	## window (with a blinking sprite); SMALL dies outright.
	if _is_dead or _invincible:
		return false
	if power_state == PowerState.SUPER:
		power_state = PowerState.SMALL
		_start_invincibility()
	else:
		die()
	return true


func die() -> bool:
	if _is_dead:
		return false
	_is_dead = true
	set_physics_process(false)
	sprite.play("death")
	died.emit()
	Game.player_died()
	return true


func _start_invincibility() -> void:
	_invincible = true
	invincibility_timer.start()
	_blink()


func _blink() -> void:
	if not _invincible:
		sprite.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.2, INVINCIBILITY_BLINK_SEC)
	tween.tween_property(sprite, "modulate:a", 1.0, INVINCIBILITY_BLINK_SEC)
	tween.tween_callback(_blink)


func _on_invincibility_timeout() -> void:
	_invincible = false
	sprite.modulate.a = 1.0
