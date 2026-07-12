extends Area2D
class_name Spring
## Launches a live player upward when touched.

@export var spring_size: Vector2 = Vector2(32.0, 12.0)
@export var spring_color: Color = Color("5ee66b")
@export_range(-1000.0, -100.0, 10.0) var launch_velocity: float = -560.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("springs")
	SolidPlatform._apply_geometry(collision_shape, visual, spring_size, spring_color)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.launch(launch_velocity)
