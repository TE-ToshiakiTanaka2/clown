extends Control
## Stage select screen: choose a stage with left/right and confirm to start.
## Locked stages show "LOCKED" and cannot be entered (ui_cancel returns
## to the title screen instead).

@onready var panels: Array[PanelContainer] = [
	$Panels/Stage1,
	$Panels/Stage2,
	$Panels/Stage3,
	$Panels/Stage4,
]
@onready var lock_labels: Array[Label] = [
	$Panels/Stage1/VBox/LockLabel,
	$Panels/Stage2/VBox/LockLabel,
	$Panels/Stage3/VBox/LockLabel,
	$Panels/Stage4/VBox/LockLabel,
]
@onready var score_label: Label = $Bottom/ScoreLabel
@onready var lives_label: Label = $Bottom/LivesLabel

var _selected: int = 0


func _ready() -> void:
	Game.score_changed.connect(_on_score_changed)
	Game.lives_changed.connect(_on_lives_changed)
	_on_score_changed(Game.score)
	_on_lives_changed(Game.lives)
	_refresh()


func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES: %d" % new_lives


func _refresh() -> void:
	for i in panels.size():
		var level_number: int = i + 1
		var locked: bool = level_number > Game.unlocked_level
		lock_labels[i].visible = locked
		panels[i].modulate = Color(0.45, 0.45, 0.45) if locked else Color(1.0, 1.0, 1.0)
		panels[i].scale = Vector2(1.15, 1.15) if i == _selected else Vector2.ONE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_confirm_selection()
	elif event.is_action_pressed("ui_cancel"):
		Game.go_to_title()


func _move_selection(direction: int) -> void:
	_selected = clampi(_selected + direction, 0, panels.size() - 1)
	_refresh()


func _confirm_selection() -> void:
	var level_number: int = _selected + 1
	if level_number > Game.unlocked_level:
		return
	Game.start_level(level_number)
