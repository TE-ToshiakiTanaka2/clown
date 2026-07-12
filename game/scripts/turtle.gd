extends CharacterBody2D
class_name Turtle
## Patrolling shell enemy: WALK -> (stomped) SHELL -> (stomped/touched again)
## SLIDING. A sliding shell reflects off walls, defeats other "enemies"
## group members via defeat_by_shell(), and damages the player on side
## contact. Ledge-turning (unlike goomba) via a foot RayCast2D while WALK.

enum State { WALK, SHELL, SLIDING }

const SHELL_DEFEAT_SCORE: int = 200

@export var walk_speed: float = 40.0
@export var slide_speed: float = 220.0
@export var shell_revert_sec: float = 5.0

@onready var floor_ray: RayCast2D = $FloorRay
@onready var stomp_area: Area2D = $StompArea
@onready var hit_area: Area2D = $HitArea
@onready var enemy_hit_area: Area2D = $EnemyHitArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shell_timer: Timer = $ShellTimer

var state: State = State.WALK
var direction: int = -1
var _defeated: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	add_to_group("enemies")
	shell_timer.wait_time = shell_revert_sec
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	enemy_hit_area.body_entered.connect(_on_enemy_hit_area_body_entered)
	shell_timer.timeout.connect(_on_shell_timer_timeout)
	floor_ray.position.x = abs(floor_ray.position.x) * direction
	sprite.flip_h = direction > 0
	sprite.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	match state:
		State.WALK:
			velocity.x = direction * walk_speed
			if is_on_wall() or (is_on_floor() and not floor_ray.is_colliding()):
				_reverse_direction()
		State.SHELL:
			velocity.x = 0.0
		State.SLIDING:
			velocity.x = direction * slide_speed
			if is_on_wall():
				_reverse_direction()

	move_and_slide()


func _reverse_direction() -> void:
	direction *= -1
	floor_ray.position.x = abs(floor_ray.position.x) * direction
	sprite.flip_h = direction > 0


func _is_stomp(body: Node) -> bool:
	return body is Player and body.velocity.y > 0.0 and body.feet_global_y() < global_position.y


func _on_stomp_area_body_entered(body: Node) -> void:
	if not _is_stomp(body):
		return
	match state:
		State.WALK:
			_enter_shell()
		State.SHELL:
			_enter_sliding(body)
		State.SLIDING:
			_enter_shell()
	body.bounce()


func _on_hit_area_body_entered(body: Node) -> void:
	if not (body is Player) or _is_stomp(body):
		return
	match state:
		State.WALK:
			body.take_damage()
		State.SHELL:
			_enter_sliding(body)
		State.SLIDING:
			body.take_damage()


func _on_enemy_hit_area_body_entered(body: Node) -> void:
	# Score is awarded by each victim's defeat_by_shell(), not here, so a
	# defeat is worth the same no matter which shell delivered it.
	if state != State.SLIDING:
		return
	if body == self or not body.has_method("defeat_by_shell"):
		return
	body.defeat_by_shell()


func _enter_shell() -> void:
	state = State.SHELL
	velocity.x = 0.0
	sprite.play("shell")
	shell_timer.start()


func _enter_sliding(player: Player) -> void:
	state = State.SLIDING
	direction = 1 if player.global_position.x < global_position.x else -1
	sprite.play("shell")
	shell_timer.stop()
	# Enemies already overlapping when the shell is kicked never re-trigger
	# body_entered, so sweep the current overlaps once.
	for body in enemy_hit_area.get_overlapping_bodies():
		_on_enemy_hit_area_body_entered(body)


func defeat_by_shell() -> void:
	## Duck-typed defeat entrypoint: hit by another sliding shell.
	if _defeated:
		return
	_defeated = true
	Game.add_score(SHELL_DEFEAT_SCORE)
	shell_timer.stop()
	state = State.SHELL
	sprite.play("shell")
	sprite.flip_v = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	stomp_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitoring", false)
	enemy_hit_area.set_deferred("monitoring", false)
	get_tree().create_timer(0.4).timeout.connect(queue_free)


func _on_shell_timer_timeout() -> void:
	if state == State.SHELL:
		state = State.WALK
		sprite.play("walk")
