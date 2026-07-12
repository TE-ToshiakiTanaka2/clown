extends StaticBody2D
class_name QuestionBlock
## Classic "?" block: bounces and spawns its content when hit from below by
## a jumping player, then goes "used" once its content is exhausted.

enum Content { COIN, MUSHROOM, ONE_UP }

const MUSHROOM_SCENE: PackedScene = preload("res://scenes/mushroom.tscn")
const COIN_POP_TEXTURE: Texture2D = preload("res://assets/sprites/coin_0.png")
const COIN_SCORE: int = 100
const BOUNCE_DISTANCE: float = 4.0
const BOUNCE_DURATION: float = 0.06
const COIN_POP_DISTANCE: float = 16.0
const COIN_POP_DURATION: float = 0.4

@export var content: Content = Content.COIN
@export var count: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $HitArea

var _remaining: int = 0
var _used: bool = false
var _rest_position: Vector2


func _ready() -> void:
	_remaining = count
	_rest_position = position
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	if _remaining <= 0:
		push_warning("QuestionBlock: count <= 0, starting already used")
		_set_used()
		return
	sprite.play("question")


func _on_hit_area_body_entered(body: Node) -> void:
	if _used or not (body is Player) or body.velocity.y >= 0.0:
		return
	_hit(body)


func _hit(_player: Player) -> void:
	_bounce()
	match content:
		Content.COIN:
			_spawn_coin_pop()
		Content.MUSHROOM:
			_spawn_item(Mushroom.Kind.SUPER)
		Content.ONE_UP:
			_spawn_item(Mushroom.Kind.ONE_UP)
	_remaining -= 1
	if _remaining <= 0:
		_set_used()


func _bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", _rest_position.y - BOUNCE_DISTANCE, BOUNCE_DURATION)
	tween.tween_property(self, "position:y", _rest_position.y, BOUNCE_DURATION)


func _spawn_coin_pop() -> void:
	Game.add_score(COIN_SCORE)
	var pop := Sprite2D.new()
	pop.texture = COIN_POP_TEXTURE
	pop.global_position = global_position + Vector2(0, -8)
	get_parent().add_child(pop)
	var tween := pop.create_tween()
	tween.tween_property(pop, "position:y", pop.position.y - COIN_POP_DISTANCE, COIN_POP_DURATION)
	tween.parallel().tween_property(pop, "modulate:a", 0.0, COIN_POP_DURATION)
	tween.tween_callback(pop.queue_free)


func _spawn_item(kind: Mushroom.Kind) -> void:
	var mushroom := MUSHROOM_SCENE.instantiate() as Mushroom
	mushroom.kind = kind
	mushroom.rise_from_block = true
	mushroom.position = position
	get_parent().add_child(mushroom)


func _set_used() -> void:
	_used = true
	hit_area.set_deferred("monitoring", false)
	sprite.play("used")
