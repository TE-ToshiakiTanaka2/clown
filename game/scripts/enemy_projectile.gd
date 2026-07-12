extends Area2D
class_name EnemyProjectile
## Bounded cannon shot. Every terminal path emits expired exactly once.

signal expired(projectile: EnemyProjectile)

@export var speed: float = 180.0
@export var lifetime_sec: float = 3.0
@export var max_distance: float = 600.0

var direction: Vector2 = Vector2.LEFT
var _origin: Vector2
var _elapsed: float = 0.0
var _expired: bool = false


func _ready() -> void:
	_origin = global_position
	body_entered.connect(_on_body_entered)


func initialize(new_direction: Vector2) -> void:
	# Cannon positions the shot after add_child() has delivered _ready(). Capture
	# the real muzzle location here so distance bounds are stage-local.
	_origin = global_position
	direction = new_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.LEFT
	$AnimatedSprite2D.flip_h = direction.x > 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	global_position += direction * speed * delta
	if _elapsed >= lifetime_sec or global_position.distance_to(_origin) >= max_distance:
		expire()


func _on_body_entered(body: Node) -> void:
	if _expired:
		return
	if body is Player:
		body.take_damage()
	expire()


func expire() -> void:
	if _expired:
		return
	_expired = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	expired.emit(self)
	queue_free()
