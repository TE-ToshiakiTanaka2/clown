extends StaticBody2D
class_name SolidPlatform
## Runtime-sized static terrain used by the authored stage scenes.

@export var platform_size: Vector2 = Vector2(128.0, 16.0)
@export var platform_color: Color = Color("6b9e3f")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("solid_platforms")
	_apply_geometry(collision_shape, visual, platform_size, platform_color)


static func _apply_geometry(
	shape_node: CollisionShape2D,
	polygon_node: Polygon2D,
	size: Vector2,
	color: Color
) -> void:
	var safe_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var rectangle := RectangleShape2D.new()
	rectangle.size = safe_size
	shape_node.shape = rectangle
	var half := safe_size / 2.0
	polygon_node.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	polygon_node.color = color
