extends Node
## Autoload singleton ("Game") that tracks score/lives and drives level flow.
## Survives scene reloads so score and lives persist across player deaths.

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over
signal level_cleared

const STARTING_LIVES: int = 3

var score: int = 0
var lives: int = STARTING_LIVES


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func player_died() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives > 0:
		get_tree().reload_current_scene()
	else:
		game_over.emit()


func clear_level() -> void:
	level_cleared.emit()


func reset_run() -> void:
	score = 0
	lives = STARTING_LIVES
	score_changed.emit(score)
	lives_changed.emit(lives)
	get_tree().reload_current_scene()
