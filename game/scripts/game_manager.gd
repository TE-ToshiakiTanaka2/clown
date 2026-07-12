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

## Level registry: level number -> scene path. `unlocked_level` is clamped
## against this registry, so a level stays LOCKED in stage select until it
## is both unlocked *and* registered here.
const LEVELS: Dictionary[int, String] = {
	1: "res://scenes/level_1.tscn",
	2: "res://scenes/level_2.tscn",
}

var score: int = 0
var lives: int = STARTING_LIVES
var current_level: int = 0
var unlocked_level: int = 1

# True while a terminal level outcome (game over / clear) is being staged;
# makes death and clear mutually exclusive and accepted only once per level.
var _level_ending: bool = false
# Bumped on every flow transition so stale delayed-transition timers
# (e.g. a clear timer surviving into the title screen) become no-ops.
var _flow_epoch: int = 0


func _ready() -> void:
	_load_progress()


func max_level() -> int:
	## Highest registered level number (not the registry size, so a gap in
	## the numbering can never break final-level detection or unlock clamping).
	var highest: int = 0
	for level_number in LEVELS:
		highest = maxi(highest, level_number)
	return highest


func is_final_level() -> bool:
	## True while playing (or just having cleared) the last registered level.
	## Used by the HUD to swap "COURSE CLEAR!" for a whole-game clear message.
	return current_level == max_level()


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func add_life() -> void:
	lives += 1
	lives_changed.emit(lives)


func player_died() -> void:
	if _level_ending:
		return
	lives -= 1
	lives_changed.emit(lives)
	if lives > 0:
		retry_level()
	else:
		_level_ending = true
		game_over.emit()
		_delayed_transition(GAME_OVER_DELAY_SEC, go_to_title)


func clear_level() -> void:
	if _level_ending:
		return
	_level_ending = true
	level_cleared.emit()
	unlocked_level = clampi(maxi(unlocked_level, current_level + 1), 1, max_level())
	_save_progress()
	_delayed_transition(LEVEL_CLEAR_DELAY_SEC, go_to_stage_select)


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
	_begin_transition()
	get_tree().change_scene_to_file.call_deferred(LEVELS[n])


func retry_level() -> void:
	## Re-enter the current level after a death. Replaces the old
	## reload_current_scene() call so it stays in sync with the registry.
	if current_level == 0 or not LEVELS.has(current_level):
		go_to_title()
		return
	_begin_transition()
	get_tree().change_scene_to_file.call_deferred(LEVELS[current_level])


func go_to_title() -> void:
	reset_run()
	current_level = 0
	_begin_transition()
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func go_to_stage_select() -> void:
	current_level = 0
	_begin_transition()
	get_tree().change_scene_to_file.call_deferred(STAGE_SELECT_SCENE)


func _begin_transition() -> void:
	## Invalidate any pending delayed transition and re-arm outcome handling
	## for the scene being entered.
	_flow_epoch += 1
	_level_ending = false


func _delayed_transition(delay_sec: float, action: Callable) -> void:
	var epoch := _flow_epoch
	get_tree().create_timer(delay_sec).timeout.connect(func() -> void:
		if epoch == _flow_epoch:
			action.call())


func reset_run() -> void:
	score = 0
	lives = STARTING_LIVES
	score_changed.emit(score)
	lives_changed.emit(lives)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Game: failed to save progress to %s (error %d)" % [SAVE_PATH, err])


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var saved: int = int(config.get_value("progress", "unlocked_level", 1))
		unlocked_level = clampi(saved, 1, max_level())
