extends StaticBody2D
class_name Cannon
## Stationary ranged enemy with a telegraph and strict live-projectile limit.

enum State { IDLE, WARNING, COOLDOWN, DEFEATED }

const PROJECTILE_SCENE := preload("res://scenes/enemy_projectile.tscn")

@export var detection_range: float = 450.0
@export var vertical_tolerance: float = 100.0
@export var warning_sec: float = 0.55
@export var cooldown_sec: float = 2.0
@export var max_active_projectiles: int = 2
@export var projectile_speed: float = 180.0

@onready var contact_area: Area2D = $ContactArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.IDLE
var _target: Player
var _state_elapsed: float = 0.0
var _active_projectiles: Array[EnemyProjectile] = []
var _defeated: bool = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("cannons")
	contact_area.body_entered.connect(_on_contact_area_body_entered)
	_cache_target()
	if _target == null:
		call_deferred("_cache_target")
	sprite.play("idle")


func _process(delta: float) -> void:
	_state_elapsed += delta
	match state:
		State.IDLE:
			if _can_fire() and active_projectile_count() < max_active_projectiles:
				_enter_warning()
		State.WARNING:
			if not _can_fire():
				_enter_idle()
			elif _state_elapsed >= warning_sec:
				_fire()
				_enter_cooldown()
		State.COOLDOWN:
			if _state_elapsed >= cooldown_sec:
				_enter_idle()
		State.DEFEATED:
			pass


func _cache_target() -> void:
	var candidate := get_tree().get_first_node_in_group("player")
	_target = candidate as Player


func _target_is_valid() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()


func _can_fire() -> bool:
	return (
		_target_is_valid()
		and absf(_target.global_position.x - global_position.x) <= detection_range
		and absf(_target.global_position.y - global_position.y) <= vertical_tolerance
	)


func _enter_warning() -> void:
	state = State.WARNING
	_state_elapsed = 0.0
	sprite.play("warning")


func _enter_idle() -> void:
	state = State.IDLE
	_state_elapsed = 0.0
	sprite.play("idle")


func _enter_cooldown() -> void:
	state = State.COOLDOWN
	_state_elapsed = 0.0
	sprite.play("fire")


func _fire() -> void:
	if not _can_fire() or active_projectile_count() >= max_active_projectiles:
		return
	var parent := get_parent()
	if parent == null:
		return
	var fire_direction := Vector2(signf(_target.global_position.x - global_position.x), 0.0)
	sprite.flip_h = fire_direction.x > 0.0
	muzzle.position.x = absf(muzzle.position.x) * int(fire_direction.x)
	var projectile := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	parent.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.speed = projectile_speed
	projectile.initialize(fire_direction)
	projectile.expired.connect(_on_projectile_expired)
	_active_projectiles.append(projectile)


func active_projectile_count() -> int:
	var live_projectiles: Array[EnemyProjectile] = []
	for projectile in _active_projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			live_projectiles.append(projectile)
	_active_projectiles = live_projectiles
	return _active_projectiles.size()


func _on_projectile_expired(projectile: EnemyProjectile) -> void:
	_active_projectiles.erase(projectile)


func _on_contact_area_body_entered(body: Node) -> void:
	if _defeated or not body is Player:
		return
	match body.classify_enemy_contact(global_position.y):
		Player.ContactOutcome.STOMP:
			body.bounce()
			_defeat(400)
		Player.ContactOutcome.DAMAGE:
			body.take_damage()


func defeat_by_shell() -> void:
	_defeat(400)


func _defeat(score: int) -> void:
	if _defeated:
		return
	_defeated = true
	state = State.DEFEATED
	Game.add_score(score)
	set_process(false)
	collision_shape.set_deferred("disabled", true)
	contact_area.set_deferred("monitoring", false)
	sprite.flip_v = true
	get_tree().create_timer(0.4).timeout.connect(queue_free)
