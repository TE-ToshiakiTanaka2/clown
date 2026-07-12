extends Node
## Lightweight headless regression suite. Run with:
## godot --headless --path game res://tests/test_runner.tscn

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_test_registry_and_progression()
	await _test_player_damage_rules()
	_test_enemy_scene_contract()
	await _test_physics_contact_resolution()
	await _test_gimmick_behavior()
	await _test_level_scene_contracts()

	if _failures.is_empty():
		print("TEST_PASS: %d checks" % _checks)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("TEST_FAIL: %s" % failure)
	print("TEST_FAILED: %d of %d checks" % [_failures.size(), _checks])
	get_tree().quit(1)


func _test_registry_and_progression() -> void:
	_assert_equal(Game.LEVELS.size(), 4, "four levels are registered")
	_assert_equal(Game.max_level(), 4, "registry maximum is stage 4")
	for level_number in range(1, 5):
		_assert_true(Game.LEVELS.has(level_number), "stage %d has a registry entry" % level_number)
		_assert_true(ResourceLoader.exists(Game.LEVELS[level_number]), "stage %d scene exists" % level_number)

	var original_level: int = Game.current_level
	Game.current_level = 3
	_assert_false(Game.is_final_level(), "stage 3 is not final")
	Game.current_level = 4
	_assert_true(Game.is_final_level(), "stage 4 is final")
	Game.current_level = original_level
	_assert_equal(Game._unlocked_after_clear(1, 1), 2, "stage 1 unlocks only stage 2")
	_assert_equal(Game._unlocked_after_clear(2, 2), 3, "stage 2 unlocks only stage 3")
	_assert_equal(Game._unlocked_after_clear(3, 3), 4, "stage 3 unlocks only stage 4")
	_assert_equal(Game._unlocked_after_clear(4, 4), 4, "stage 4 unlock stays clamped")


func _test_player_damage_rules() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_assert_not_null(player_scene, "player scene loads")
	if player_scene == null:
		return

	var player := player_scene.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2.ZERO
	player.velocity.y = 100.0
	_assert_equal(
		player.classify_enemy_contact(player.feet_global_y() + 1.0),
		Player.ContactOutcome.STOMP,
		"descending top contact is a stomp"
	)
	player.velocity.y = 0.0
	_assert_equal(
		player.classify_enemy_contact(player.feet_global_y() + 1.0),
		Player.ContactOutcome.DAMAGE,
		"non-descending contact is damage"
	)

	Game._level_ending = true
	player.power_state = Player.PowerState.SUPER
	_assert_true(player.take_damage(), "SUPER accepts the first hit")
	_assert_equal(player.power_state, Player.PowerState.SMALL, "SUPER shrinks to SMALL")
	_assert_true(player.is_invincible(), "SUPER hit starts invincibility")
	_assert_false(player.take_damage(), "invincibility rejects a repeated hit")
	_assert_equal(
		player.classify_enemy_contact(player.feet_global_y() + 1.0),
		Player.ContactOutcome.IGNORE,
		"invincible contact is ignored"
	)
	player.queue_free()
	await get_tree().process_frame

	var small_player := player_scene.instantiate() as Player
	get_tree().root.add_child(small_player)
	await get_tree().process_frame
	_assert_true(small_player.take_damage(), "SMALL accepts a hit")
	_assert_true(small_player.is_dead(), "SMALL hit is a miss")
	_assert_false(small_player.take_damage(), "dead player rejects repeated damage")
	_assert_false(small_player.die(), "death notification is idempotent")
	small_player.queue_free()
	await get_tree().process_frame

	# Exercise the last-life rule without waiting for or allowing its delayed
	# title transition to mutate the test tree.
	Game._level_ending = false
	Game.lives = 1
	Game.current_level = 4
	Game.player_died()
	_assert_equal(Game.lives, 0, "last accepted death consumes exactly one life")
	_assert_true(Game._level_ending, "zero lives enters game-over state")
	Game._flow_epoch += 1
	Game._level_ending = false
	Game.current_level = 0
	Game.reset_run()


func _test_enemy_scene_contract() -> void:
	for scene_path in ["res://scenes/goomba.tscn", "res://scenes/turtle.tscn"]:
		var packed := load(scene_path) as PackedScene
		_assert_not_null(packed, "%s loads" % scene_path)
		if packed == null:
			continue
		var enemy := packed.instantiate()
		_assert_true(enemy.has_node("ContactArea"), "%s has one ContactArea" % scene_path)
		_assert_false(enemy.has_node("StompArea"), "%s has no competing StompArea" % scene_path)
		_assert_false(enemy.has_node("HitArea"), "%s has no competing HitArea" % scene_path)
		enemy.free()


func _test_physics_contact_resolution() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var goomba_scene := load("res://scenes/goomba.tscn") as PackedScene
	var turtle_scene := load("res://scenes/turtle.tscn") as PackedScene
	if player_scene == null or goomba_scene == null or turtle_scene == null:
		_failures.append("physics contact fixtures load")
		return

	Game._level_ending = true
	var side_fixture := Node2D.new()
	var side_goomba := goomba_scene.instantiate()
	var side_player := player_scene.instantiate() as Player
	side_goomba.position = Vector2.ZERO
	side_player.position = Vector2(20.0, 0.0)
	side_player.power_state = Player.PowerState.SUPER
	side_fixture.add_child(side_goomba)
	side_fixture.add_child(side_player)
	get_tree().root.add_child(side_fixture)
	side_goomba.set_physics_process(false)
	side_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(side_player.power_state, Player.PowerState.SMALL, "physical side contact applies damage")
	side_fixture.queue_free()
	await get_tree().process_frame

	var stomp_fixture := Node2D.new()
	var stomp_goomba := goomba_scene.instantiate()
	var stomp_player := player_scene.instantiate() as Player
	stomp_goomba.position = Vector2.ZERO
	stomp_player.position = Vector2(0.0, -25.0)
	stomp_player.velocity.y = 100.0
	stomp_fixture.add_child(stomp_goomba)
	stomp_fixture.add_child(stomp_player)
	get_tree().root.add_child(stomp_fixture)
	stomp_goomba.set_physics_process(false)
	stomp_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_true(stomp_goomba.get("_squashed"), "physical top contact squashes Goomba")
	_assert_true(stomp_player.velocity.y < 0.0, "physical stomp bounces player")
	stomp_fixture.queue_free()
	await get_tree().process_frame

	var turtle_fixture := Node2D.new()
	var turtle := turtle_scene.instantiate() as Turtle
	var turtle_player := player_scene.instantiate() as Player
	turtle.position = Vector2.ZERO
	turtle_player.position = Vector2(0.0, -25.0)
	turtle_player.velocity.y = 100.0
	turtle_fixture.add_child(turtle)
	turtle_fixture.add_child(turtle_player)
	get_tree().root.add_child(turtle_fixture)
	turtle.set_physics_process(false)
	turtle_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(turtle.state, Turtle.State.SHELL, "physical top contact shells Turtle")
	_assert_true(turtle_player.velocity.y < 0.0, "Turtle stomp bounces player")
	turtle_fixture.queue_free()
	await get_tree().process_frame
	Game._level_ending = false


func _test_gimmick_behavior() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var moving_scene := load("res://scenes/moving_platform.tscn") as PackedScene
	var falling_scene := load("res://scenes/falling_platform.tscn") as PackedScene
	var spring_scene := load("res://scenes/spring.tscn") as PackedScene
	var hazard_scene := load("res://scenes/damage_hazard.tscn") as PackedScene
	if null in [player_scene, moving_scene, falling_scene, spring_scene, hazard_scene]:
		_failures.append("gimmick fixtures load")
		return

	var moving := moving_scene.instantiate() as MovingPlatform
	moving.travel = Vector2(100.0, 0.0)
	moving.cycle_sec = 1.0
	get_tree().root.add_child(moving)
	var moving_origin := moving.position
	for _frame in 8:
		await get_tree().physics_frame
	_assert_true(moving.position.x > moving_origin.x, "moving platform advances along travel vector")
	moving.queue_free()
	await get_tree().process_frame

	var spring_fixture := Node2D.new()
	var spring := spring_scene.instantiate() as Spring
	var spring_player := player_scene.instantiate() as Player
	spring.launch_velocity = -600.0
	spring_player.position = Vector2.ZERO
	spring_fixture.add_child(spring)
	spring_fixture.add_child(spring_player)
	get_tree().root.add_child(spring_fixture)
	spring_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(spring_player.velocity.y, -600.0, "spring applies configured launch velocity")
	spring_fixture.queue_free()
	await get_tree().process_frame

	var falling := falling_scene.instantiate() as FallingPlatform
	var trigger_player := player_scene.instantiate() as Player
	falling.trigger_delay_sec = 0.05
	falling.reset_delay_sec = 1.0
	get_tree().root.add_child(falling)
	get_tree().root.add_child(trigger_player)
	falling._on_trigger_area_body_entered(trigger_player)
	_assert_equal(falling.state, FallingPlatform.State.WARNING, "falling platform enters warning state")
	await get_tree().create_timer(0.08).timeout
	_assert_equal(falling.state, FallingPlatform.State.FALLING, "falling platform starts after delay")
	var fall_y := falling.position.y
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_true(falling.position.y > fall_y, "falling platform moves downward")
	falling._on_reset_timer_timeout()
	await get_tree().physics_frame
	_assert_equal(falling.position, Vector2.ZERO, "falling platform returns to origin")
	_assert_equal(falling.state, FallingPlatform.State.READY, "falling platform re-arms")
	falling.queue_free()
	trigger_player.queue_free()
	await get_tree().process_frame

	Game._level_ending = true
	var spike_fixture := Node2D.new()
	var spike := hazard_scene.instantiate() as DamageHazard
	var spike_player := player_scene.instantiate() as Player
	spike_player.power_state = Player.PowerState.SUPER
	spike_fixture.add_child(spike)
	spike_fixture.add_child(spike_player)
	get_tree().root.add_child(spike_fixture)
	spike_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(spike_player.power_state, Player.PowerState.SMALL, "spikes apply normal power-state damage")
	_assert_false(spike_player.is_dead(), "SUPER survives spike damage")
	spike_fixture.queue_free()
	await get_tree().process_frame

	var lava_fixture := Node2D.new()
	var lava := hazard_scene.instantiate() as DamageHazard
	var lava_player := player_scene.instantiate() as Player
	lava.instant_kill = true
	lava_player.power_state = Player.PowerState.SUPER
	lava_fixture.add_child(lava)
	lava_fixture.add_child(lava_player)
	get_tree().root.add_child(lava_fixture)
	lava_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_true(lava_player.is_dead(), "lava is an instant miss even while SUPER")
	lava_fixture.queue_free()
	await get_tree().process_frame
	Game._level_ending = false


func _test_level_scene_contracts() -> void:
	for level_number in range(1, 5):
		var packed := load(Game.LEVELS[level_number]) as PackedScene
		_assert_not_null(packed, "stage %d loads as PackedScene" % level_number)
		if packed == null:
			continue
		var level := packed.instantiate()
		get_tree().root.add_child(level)
		await get_tree().process_frame
		for required_path in ["Player", "Player/Camera2D", "Flag", "KillZone", "HUD"]:
			_assert_true(level.has_node(required_path), "stage %d has %s" % [level_number, required_path])
		if level_number == 3:
			_assert_group_count_at_least("moving_platforms", 3, "stage 3 moving platforms")
			_assert_group_count_at_least("falling_platforms", 5, "stage 3 falling platforms")
			_assert_group_count_at_least("springs", 2, "stage 3 springs")
		if level_number == 4:
			_assert_group_count_at_least("moving_platforms", 5, "stage 4 moving platforms")
			_assert_group_count_at_least("falling_platforms", 3, "stage 4 falling platforms")
			_assert_group_count_at_least("springs", 1, "stage 4 spring")
			_assert_group_count_at_least("spike_hazards", 4, "stage 4 spike hazards")
			_assert_group_count_at_least("instant_hazards", 3, "stage 4 lava hazards")
		level.queue_free()
		await get_tree().process_frame


func _assert_group_count_at_least(group: StringName, expected: int, label: String) -> void:
	var actual := get_tree().get_nodes_in_group(group).size()
	_assert_true(actual >= expected, "%s (expected >= %d, got %d)" % [label, expected, actual])


func _assert_true(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures.append(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_not_null(value: Variant, label: String) -> void:
	_assert_true(value != null, label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [label, expected, actual])
