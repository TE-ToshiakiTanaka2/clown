extends CharacterBody2D
class_name Spiny
## Armored ground enemy: patrols, telegraphs, then charges. It cannot be
## stomped; a sliding shell is the safe defeat route.

enum State { PATROL, WINDUP, CHARGE, STUNNED, DEFEATED }

@export var patrol_speed: float = 34.0
@export var charge_speed: float = 145.0
@export var detection_range: float = 210.0
@export var vertical_tolerance: float = 42.0
@export var windup_sec: float = 0.45
@export var charge_sec: float = 1.25
@export var stunned_sec: float = 0.7

@onready var floor_ray: RayCast2D = $FloorRay
@onready var contact_area: Area2D = $ContactArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.PATROL
var direction: int = -1
var _target: Player
var _state_elapsed: float = 0.0
var _defeated: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("spinies")
	contact_area.body_entered.connect(_on_contact_area_body_entered)
	_cache_target()
	if _target == null:
		call_deferred("_cache_target")
	_update_facing()
	sprite.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	_state_elapsed += delta

	match state:
		State.PATROL:
			velocity.x = direction * patrol_speed
			if is_on_wall() or (is_on_floor() and not floor_ray.is_colliding()):
				_reverse_direction()
			elif _can_charge():
				_enter_windup()
		State.WINDUP:
			velocity.x = 0.0
			if _state_elapsed >= windup_sec:
				_enter_charge()
		State.CHARGE:
			velocity.x = direction * charge_speed
			if is_on_wall():
				_enter_stunned()
			elif _state_elapsed >= charge_sec:
				_enter_patrol()
		State.STUNNED:
			velocity.x = 0.0
			if _state_elapsed >= stunned_sec:
				_reverse_direction()
				_enter_patrol()
		State.DEFEATED:
			velocity.x = 0.0

	move_and_slide()


func _cache_target() -> void:
	var candidate := get_tree().get_first_node_in_group("player")
	_target = candidate as Player


func _target_is_valid() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()


func _can_charge() -> bool:
	return (
		_target_is_valid()
		and absf(_target.global_position.x - global_position.x) <= detection_range
		and absf(_target.global_position.y - global_position.y) <= vertical_tolerance
	)


func _enter_windup() -> void:
	if not _target_is_valid():
		return
	direction = 1 if _target.global_position.x > global_position.x else -1
	_update_facing()
	state = State.WINDUP
	_state_elapsed = 0.0
	velocity.x = 0.0
	sprite.play("windup")


func _enter_charge() -> void:
	state = State.CHARGE
	_state_elapsed = 0.0
	sprite.play("charge")


func _enter_stunned() -> void:
	state = State.STUNNED
	_state_elapsed = 0.0
	velocity.x = 0.0
	sprite.play("windup")


func _enter_patrol() -> void:
	state = State.PATROL
	_state_elapsed = 0.0
	sprite.play("walk")


func _reverse_direction() -> void:
	direction *= -1
	_update_facing()


func _update_facing() -> void:
	floor_ray.position.x = absf(floor_ray.position.x) * direction
	sprite.flip_h = direction > 0


func _on_contact_area_body_entered(body: Node) -> void:
	if _defeated or not body is Player:
		return
	var player := body as Player
	var outcome: Player.ContactOutcome = player.classify_enemy_contact(global_position.y)
	if outcome == Player.ContactOutcome.IGNORE:
		return
	var accepted: bool = player.take_damage()
	if outcome == Player.ContactOutcome.STOMP and accepted and not player.is_dead():
		player.bounce()


func defeat_by_shell() -> void:
	if _defeated:
		return
	_defeated = true
	state = State.DEFEATED
	Game.add_score(300)
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	contact_area.set_deferred("monitoring", false)
	sprite.flip_v = true
	get_tree().create_timer(0.4).timeout.connect(queue_free)
