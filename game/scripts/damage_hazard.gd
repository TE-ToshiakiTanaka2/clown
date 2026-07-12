extends Area2D
class_name DamageHazard
## Spikes use normal SMALL/SUPER damage; lava can be configured as instant miss.

@export var hazard_size: Vector2 = Vector2(96.0, 16.0)
@export var hazard_color: Color = Color("ef3f3f")
@export var instant_kill: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("damage_hazards")
	add_to_group("instant_hazards" if instant_kill else "spike_hazards")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(maxf(hazard_size.x, 1.0), maxf(hazard_size.y, 1.0))
	collision_shape.shape = rectangle
	_apply_visual()
	body_entered.connect(_on_body_entered)


func _apply_visual() -> void:
	var half := hazard_size / 2.0
	if instant_kill:
		visual.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
	else:
		var points := PackedVector2Array([Vector2(-half.x, half.y)])
		var teeth := maxi(1, ceili(hazard_size.x / 16.0))
		for i in range(teeth * 2 + 1):
			var x := -half.x + hazard_size.x * float(i) / float(teeth * 2)
			var y := -half.y if i % 2 == 1 else half.y
			points.append(Vector2(x, y))
		points.append(Vector2(half.x, half.y))
		visual.polygon = points
	visual.color = hazard_color


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	if instant_kill:
		body.die()
	else:
		body.take_damage()
