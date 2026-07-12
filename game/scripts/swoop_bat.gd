extends CharacterBody2D
class_name SwoopBat
## Flying enemy with a bounded PATROL -> DIVE -> RETURN loop.

enum State { PATROL, DIVE, RETURN, DEFEATED }

@export var patrol_radius: float = 72.0
@export var patrol_speed: float = 2.0
@export var detection_range: float = 220.0
@export var dive_speed: float = 150.0
@export var dive_duration: float = 1.15
@export var max_home_distance: float = 280.0
@export var return_speed: float = 105.0

@onready var contact_area: Area2D = $ContactArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.PATROL
var _target: Player
var _home: Vector2
var _patrol_phase: float = 0.0
var _state_elapsed: float = 0.0
var _dive_direction: Vector2 = Vector2.DOWN
var _defeated: bool = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("swoop_bats")
	_home = global_position
	contact_area.body_entered.connect(_on_contact_area_body_entered)
	_cache_target()
	if _target == null:
		call_deferred("_cache_target")
	sprite.play("fly")


func _physics_process(delta: float) -> void:
	_state_elapsed += delta
	match state:
		State.PATROL:
			_patrol_phase += delta * patrol_speed
			var patrol_target := _home + Vector2(
				sin(_patrol_phase) * patrol_radius,
				cos(_patrol_phase * 2.0) * patrol_radius * 0.22
			)
			velocity = global_position.direction_to(patrol_target) * return_speed
			if global_position.distance_to(patrol_target) < 3.0:
				velocity = Vector2.ZERO
			if _can_dive():
				_start_dive()
		State.DIVE:
			velocity = _dive_direction * dive_speed
			if (
				_state_elapsed >= dive_duration
				or global_position.distance_to(_home) >= max_home_distance
			):
				_enter_return()
		State.RETURN:
			velocity = global_position.direction_to(_home) * return_speed
			if global_position.distance_to(_home) <= 4.0:
				global_position = _home
				_enter_patrol()
		State.DEFEATED:
			velocity = Vector2.ZERO
	move_and_slide()
	sprite.flip_h = velocity.x > 0.0


func _cache_target() -> void:
	var candidate := get_tree().get_first_node_in_group("player")
	_target = candidate as Player


func _target_is_valid() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()


func _can_dive() -> bool:
	return (
		_target_is_valid()
		and global_position.distance_to(_target.global_position) <= detection_range
		and _target.global_position.y >= global_position.y - 16.0
	)


func _start_dive() -> void:
	if not _target_is_valid():
		return
	state = State.DIVE
	_state_elapsed = 0.0
	_dive_direction = global_position.direction_to(_target.global_position)
	if _dive_direction.is_zero_approx():
		_dive_direction = Vector2.DOWN
	sprite.play("dive")


func _enter_return() -> void:
	state = State.RETURN
	_state_elapsed = 0.0
	sprite.play("fly")


func _enter_patrol() -> void:
	state = State.PATROL
	_state_elapsed = 0.0
	sprite.play("fly")


func _on_contact_area_body_entered(body: Node) -> void:
	if _defeated or not body is Player:
		return
	match body.classify_enemy_contact(global_position.y):
		Player.ContactOutcome.STOMP:
			body.bounce()
			_defeat(300)
		Player.ContactOutcome.DAMAGE:
			body.take_damage()


func defeat_by_shell() -> void:
	_defeat(300)


func _defeat(score: int) -> void:
	if _defeated:
		return
	_defeated = true
	state = State.DEFEATED
	Game.add_score(score)
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	contact_area.set_deferred("monitoring", false)
	sprite.play("defeated")
	get_tree().create_timer(0.35).timeout.connect(queue_free)
