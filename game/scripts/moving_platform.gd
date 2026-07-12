extends AnimatableBody2D
class_name MovingPlatform
## Periodic platform that carries physics bodies along a configurable vector.

@export var platform_size: Vector2 = Vector2(96.0, 16.0)
@export var platform_color: Color = Color("e0a840")
@export var travel: Vector2 = Vector2(128.0, 0.0)
@export_range(0.2, 30.0, 0.1) var cycle_sec: float = 3.0
@export_range(0.0, 1.0, 0.01) var phase: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual

var _origin: Vector2
var _elapsed: float = 0.0


func _ready() -> void:
	add_to_group("moving_platforms")
	_origin = position
	_elapsed = phase * maxf(cycle_sec, 0.2)
	SolidPlatform._apply_geometry(collision_shape, visual, platform_size, platform_color)
	var should_sync := sync_to_physics
	sync_to_physics = false
	_update_position()
	sync_to_physics = should_sync
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var safe_cycle := maxf(cycle_sec, 0.2)
	_elapsed = fmod(_elapsed + delta, safe_cycle)
	_update_position()


func _update_position() -> void:
	var safe_cycle := maxf(cycle_sec, 0.2)
	var progress := _elapsed / safe_cycle
	var eased_progress := 0.5 - 0.5 * cos(TAU * progress)
	position = _origin + travel * eased_progress
