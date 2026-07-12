extends Node
## Autoload singleton ("Game") that drives the whole game flow:
## title -> stage select -> level -> clear/game over -> (stage select|title).
## Tracks score/lives (kept across level reloads within a run) and
## unlocked_level progress (persisted to disk across app restarts).

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over
signal level_cleared

const STARTING_LIVES: int = 3
const SAVE_PATH: String = "user://save.cfg"
const GAME_OVER_DELAY_SEC: float = 2.0
const LEVEL_CLEAR_DELAY_SEC: float = 2.5

const TITLE_SCENE: String = "res://scenes/title_screen.tscn"
const STAGE_SELECT_SCENE: String = "res://scenes/stage_select.tscn"

## Level registry: level number -> scene path. Only level 1 exists as of
## issue #6; level 2 is added in #8. `unlocked_level` is clamped against
## this registry, so stage 2 stays LOCKED in stage select until it is
## both unlocked *and* registered here.
const LEVELS: Dictionary = {
	1: "res://scenes/level_1.tscn",
}

var score: int = 0
var lives: int = STARTING_LIVES
var current_level: int = 0
var unlocked_level: int = 1


func _ready() -> void:
	_load_progress()


func max_level() -> int:
	return LEVELS.size()


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func player_died() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives > 0:
		retry_level()
	else:
		game_over.emit()
		get_tree().create_timer(GAME_OVER_DELAY_SEC).timeout.connect(go_to_title)


func clear_level() -> void:
	level_cleared.emit()
	unlocked_level = clampi(maxi(unlocked_level, current_level + 1), 1, max_level())
	_save_progress()
	get_tree().create_timer(LEVEL_CLEAR_DELAY_SEC).timeout.connect(go_to_stage_select)


func start_level(n: int) -> void:
	if not LEVELS.has(n):
		push_warning("Game.start_level: level %d is not registered" % n)
		return
	if n > unlocked_level:
		push_warning("Game.start_level: level %d is not unlocked yet" % n)
		return
	current_level = n
	# Deferred: may be called from UI input during physics callbacks elsewhere,
	# and change_scene_to_file must never run mid-physics-step.
	get_tree().change_scene_to_file.call_deferred(LEVELS[n])


func retry_level() -> void:
	## Re-enter the current level after a death. Replaces the old
	## reload_current_scene() call so it stays in sync with the registry.
	if current_level == 0 or not LEVELS.has(current_level):
		go_to_title()
		return
	get_tree().change_scene_to_file.call_deferred(LEVELS[current_level])


func go_to_title() -> void:
	reset_run()
	current_level = 0
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func go_to_stage_select() -> void:
	current_level = 0
	get_tree().change_scene_to_file.call_deferred(STAGE_SELECT_SCENE)


func reset_run() -> void:
	score = 0
	lives = STARTING_LIVES
	score_changed.emit(score)
	lives_changed.emit(lives)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.save(SAVE_PATH)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var saved: int = int(config.get_value("progress", "unlocked_level", 1))
		unlocked_level = clampi(saved, 1, max_level())
