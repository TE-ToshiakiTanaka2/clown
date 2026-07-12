extends CharacterBody2D
## Simple patrolling enemy: walks until it hits a wall or the edge of a
## platform, then reverses. Squashed when the player stomps it from above.

@export var walk_speed: float = 40.0

@onready var floor_ray: RayCast2D = $FloorRay
@onready var stomp_area: Area2D = $StompArea
@onready var hit_area: Area2D = $HitArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var squash_timer: Timer = $SquashTimer

var direction: int = -1
var _squashed: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	squash_timer.timeout.connect(_on_squash_timer_timeout)
	floor_ray.position.x = abs(floor_ray.position.x) * direction
	sprite.flip_h = direction > 0


func _physics_process(delta: float) -> void:
	if _squashed:
		return

	if not is_on_floor():
		velocity.y += _gravity * delta

	velocity.x = direction * walk_speed

	if is_on_wall() or (is_on_floor() and not floor_ray.is_colliding()):
		_reverse_direction()

	move_and_slide()


func _reverse_direction() -> void:
	direction *= -1
	floor_ray.position.x = abs(floor_ray.position.x) * direction
	sprite.flip_h = direction > 0


func _is_stomp(body: Node) -> bool:
	return body is Player and body.velocity.y > 0.0 and body.feet_global_y() < global_position.y


func _on_stomp_area_body_entered(body: Node) -> void:
	if _squashed:
		return
	if _is_stomp(body):
		squash(body)


func _on_hit_area_body_entered(body: Node) -> void:
	if _squashed:
		return
	if body is Player and not _is_stomp(body):
		body.die()


func squash(player: Player) -> void:
	if _squashed:
		return
	_squashed = true
	Game.add_score(200)
	player.bounce()
	stomp_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitoring", false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_physics_process(false)
	sprite.play("squashed")
	squash_timer.start()


func _on_squash_timer_timeout() -> void:
	queue_free()
