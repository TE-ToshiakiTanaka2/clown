extends AnimatableBody2D
class_name FallingPlatform
## Starts falling after the player steps on it, then returns to its spawn.

enum State { READY, WARNING, FALLING }

@export var platform_size: Vector2 = Vector2(80.0, 16.0)
@export var platform_color: Color = Color("d56b47")
@export_range(0.05, 5.0, 0.05) var trigger_delay_sec: float = 0.45
@export_range(0.2, 10.0, 0.1) var reset_delay_sec: float = 2.5
@export_range(20.0, 1000.0, 10.0) var fall_speed: float = 260.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual
@onready var trigger_area: Area2D = $TriggerArea
@onready var trigger_shape: CollisionShape2D = $TriggerArea/CollisionShape2D
@onready var trigger_timer: Timer = $TriggerTimer
@onready var reset_timer: Timer = $ResetTimer

var state: State = State.READY
var _origin: Vector2


func _ready() -> void:
	add_to_group("falling_platforms")
	_origin = position
	SolidPlatform._apply_geometry(collision_shape, visual, platform_size, platform_color)
	var trigger_rectangle := RectangleShape2D.new()
	trigger_rectangle.size = Vector2(maxf(platform_size.x, 1.0), 20.0)
	trigger_shape.shape = trigger_rectangle
	trigger_shape.position.y = -platform_size.y / 2.0 - 10.0
	trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	trigger_timer.timeout.connect(_on_trigger_timer_timeout)
	reset_timer.timeout.connect(_on_reset_timer_timeout)


func _physics_process(delta: float) -> void:
	if state == State.FALLING:
		position.y += fall_speed * delta


func _on_trigger_area_body_entered(body: Node) -> void:
	if state != State.READY or not body is Player:
		return
	state = State.WARNING
	visual.modulate = Color(1.0, 0.55, 0.55)
	trigger_timer.start(maxf(trigger_delay_sec, 0.05))


func _on_trigger_timer_timeout() -> void:
	if state != State.WARNING:
		return
	state = State.FALLING
	reset_timer.start(maxf(reset_delay_sec, 0.2))


func _on_reset_timer_timeout() -> void:
	position = _origin
	state = State.READY
	visual.modulate = Color.WHITE
	# Toggle monitoring so a player standing on the reset platform can trigger
	# a fresh body-enter event on the next physics step.
	trigger_area.set_deferred("monitoring", false)
	trigger_area.set_deferred("monitoring", true)
