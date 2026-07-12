extends CharacterBody2D
class_name Mushroom
## Power-up pickup that walks along the ground, flipping at walls and
## falling off ledges. Spawned by question_block.gd on top of a hit block,
## rising into place before it starts moving (see _start_rise()).

enum Kind { SUPER, ONE_UP }

const MUSHROOM_TEXTURE: Texture2D = preload("res://assets/sprites/mushroom.png")
const ONE_UP_TEXTURE: Texture2D = preload("res://assets/sprites/one_up.png")

@export var kind: Kind = Kind.SUPER
@export var walk_speed: float = 60.0
@export var rise_distance: float = 16.0
@export var rise_duration: float = 0.5
@export var score_value: int = 1000

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea

var direction: int = 1
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	sprite.texture = ONE_UP_TEXTURE if kind == Kind.ONE_UP else MUSHROOM_TEXTURE
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	_start_rise()


func _start_rise() -> void:
	## Rise from inside the spawning block up to its resting spot, physics
	## disabled for the duration so it doesn't fall/react mid-animation.
	set_physics_process(false)
	var target_y: float = position.y - rise_distance
	var tween := create_tween()
	tween.tween_property(self, "position:y", target_y, rise_duration)
	tween.tween_callback(_finish_rise)


func _finish_rise() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	velocity.y += _gravity * delta
	velocity.x = direction * walk_speed
	move_and_slide()
	if is_on_wall():
		direction *= -1


func _on_pickup_area_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	match kind:
		Kind.SUPER:
			body.power_up()
			Game.add_score(score_value)
		Kind.ONE_UP:
			Game.add_life()
	queue_free()
