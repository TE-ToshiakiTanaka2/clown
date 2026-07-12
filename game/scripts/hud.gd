extends CanvasLayer
## HUD overlay: score/lives display plus centered status messages.

@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var lives_label: Label = $Margin/VBox/LivesLabel
@onready var message_label: Label = $MessageLabel

var _game_over: bool = false


func _ready() -> void:
	Game.score_changed.connect(_on_score_changed)
	Game.lives_changed.connect(_on_lives_changed)
	Game.game_over.connect(_on_game_over)
	Game.level_cleared.connect(_on_level_cleared)

	_on_score_changed(Game.score)
	_on_lives_changed(Game.lives)
	message_label.text = ""


func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "LIVES: %d" % new_lives


func _on_game_over() -> void:
	_game_over = true
	message_label.text = "GAME OVER\nPress Jump to Retry"


func _on_level_cleared() -> void:
	message_label.text = "COURSE CLEAR!"


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event.is_action_pressed("jump"):
		_game_over = false
		message_label.text = ""
		Game.reset_run()
