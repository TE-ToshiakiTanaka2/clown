extends Control
## Title screen: shows the game logo, a blinking "PRESS START" prompt, and a
## few decorative sprites. Any accept/jump input advances to stage select.

@onready var press_start: Label = $PressStart
@onready var blink_timer: Timer = $BlinkTimer


func _ready() -> void:
	blink_timer.timeout.connect(_on_blink_timeout)


func _on_blink_timeout() -> void:
	press_start.visible = not press_start.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		Game.go_to_stage_select()
