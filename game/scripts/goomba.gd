extends CharacterBody2D
## Simple patrolling enemy: walks until it hits a wall or the edge of a
## platform, then reverses. Squashed when the player stomps it from above.

@export var walk_speed: float = 40.0

@onready var floor_ray: RayCast2D = $FloorRay
@onready var contact_area: Area2D = $ContactArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var squash_timer: Timer = $SquashTimer

var direction: int = -1
var _squashed: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	add_to_group("enemies")
	contact_area.body_entered.connect(_on_contact_area_body_entered)
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


func _on_contact_area_body_entered(body: Node) -> void:
	if _squashed or not body is Player:
		return
	match body.classify_enemy_contact(global_position.y):
		Player.ContactOutcome.STOMP:
			squash(body)
		Player.ContactOutcome.DAMAGE:
			body.take_damage()


func squash(player: Player) -> void:
	if _squashed:
		return
	player.bounce()
	_die(200)


func defeat_by_shell() -> void:
	## Duck-typed defeat entrypoint called by a sliding turtle shell (see
	## turtle.gd) -- any "enemies" group member exposing this method can be
	## chained-defeated by a shell, no direct goomba/turtle coupling needed.
	if _squashed:
		return
	_die(100)


func _die(score: int) -> void:
	_squashed = true
	Game.add_score(score)
	contact_area.set_deferred("monitoring", false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_physics_process(false)
	sprite.play("squashed")
	squash_timer.start()


func _on_squash_timer_timeout() -> void:
	queue_free()
