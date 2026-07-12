extends Node
## Lightweight headless regression suite. Run with:
## godot --headless --path game res://tests/test_runner.tscn

var _checks: int = 0
var _failures: Array[String] = []
var _projectile_expired_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_test_registry_and_progression()
	_test_save_compatibility()
	await _test_player_damage_rules()
	_test_enemy_scene_contract()
	await _test_turtle_state_rules()
	await _test_new_enemy_state_rules()
	await _test_projectile_bounds()
	await _test_spiny_wall_recovery()
	await _test_enemy_removal_safety()
	await _test_physics_contact_resolution()
	await _test_gimmick_behavior()
	await _test_level_scene_contracts()
	_test_sprite_contracts()

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


func _test_save_compatibility() -> void:
	var original_unlocked: int = Game.unlocked_level
	var test_path := "user://issue14-test-save-%d.cfg" % Time.get_ticks_usec()
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", 2)
	_assert_equal(config.save(test_path), OK, "temporary legacy save is writable")
	Game._load_progress(test_path)
	_assert_equal(Game.unlocked_level, 2, "two-stage legacy save remains valid")
	config.set_value("progress", "unlocked_level", 99)
	_assert_equal(config.save(test_path), OK, "temporary out-of-range save is writable")
	Game._load_progress(test_path)
	_assert_equal(Game.unlocked_level, 4, "out-of-range save clamps to stage 4")
	config.set_value("progress", "unlocked_level", -5)
	_assert_equal(config.save(test_path), OK, "temporary negative save is writable")
	Game._load_progress(test_path)
	_assert_equal(Game.unlocked_level, 1, "negative save clamps to stage 1")
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	_assert_equal(remove_error, OK, "temporary save is removed")
	Game.unlocked_level = original_unlocked


func _test_player_damage_rules() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_assert_not_null(player_scene, "player scene loads")
	if player_scene == null:
		return

	var player := player_scene.instantiate() as Player
	get_tree().root.add_child(player)
	player.set_physics_process(false)
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
	player._last_descending_physics_frame = Engine.get_physics_frames()
	player._do_jump()
	_assert_equal(
		player.classify_enemy_contact(player.feet_global_y() + 1.0),
		Player.ContactOutcome.DAMAGE,
		"upward jump clears recent falling history"
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
	_assert_equal(
		small_player.classify_enemy_contact(small_player.feet_global_y() + 1.0),
		Player.ContactOutcome.IGNORE,
		"dead player contact is ignored"
	)
	small_player.queue_free()
	await get_tree().process_frame

	Game._level_ending = false

	var goomba_scene := load("res://scenes/goomba.tscn") as PackedScene
	_assert_not_null(goomba_scene, "simultaneous-contact enemy scene loads")
	var simultaneous_fixture := Node2D.new()
	var simultaneous_player := player_scene.instantiate() as Player
	var enemy_a := goomba_scene.instantiate()
	var enemy_b := goomba_scene.instantiate()
	simultaneous_player.position = Vector2(20.0, 0.0)
	enemy_a.position = Vector2.ZERO
	enemy_b.position = Vector2.ZERO
	simultaneous_fixture.add_child(enemy_a)
	simultaneous_fixture.add_child(enemy_b)
	simultaneous_fixture.add_child(simultaneous_player)
	Game.lives = 1
	Game.current_level = 4
	get_tree().root.add_child(simultaneous_fixture)
	enemy_a.set_physics_process(false)
	enemy_b.set_physics_process(false)
	simultaneous_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(Game.lives, 0, "two simultaneous enemies consume only one life")
	_assert_true(simultaneous_player.is_dead(), "simultaneous contact accepts one death")
	simultaneous_fixture.queue_free()
	await get_tree().process_frame
	Game._flow_epoch += 1
	Game._level_ending = false
	Game.current_level = 0
	Game.reset_run()

	# Exercise the last-life rule without waiting for or allowing its delayed
	# title transition to mutate the test tree.
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
	for scene_path in [
		"res://scenes/goomba.tscn",
		"res://scenes/turtle.tscn",
		"res://scenes/swoop_bat.tscn",
		"res://scenes/spiny.tscn",
		"res://scenes/cannon.tscn",
	]:
		var packed := load(scene_path) as PackedScene
		_assert_not_null(packed, "%s loads" % scene_path)
		if packed == null:
			continue
		var enemy := packed.instantiate()
		_assert_true(enemy.has_node("ContactArea"), "%s has one ContactArea" % scene_path)
		_assert_false(enemy.has_node("StompArea"), "%s has no competing StompArea" % scene_path)
		_assert_false(enemy.has_node("HitArea"), "%s has no competing HitArea" % scene_path)
		enemy.free()
	_assert_true(ResourceLoader.exists("res://scenes/enemy_projectile.tscn"), "projectile scene exists")


func _test_turtle_state_rules() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var turtle_scene := load("res://scenes/turtle.tscn") as PackedScene
	if player_scene == null or turtle_scene == null:
		_failures.append("Turtle state fixtures load")
		return

	Game._level_ending = true
	var fixture := Node2D.new()
	var turtle := turtle_scene.instantiate() as Turtle
	var side_player := player_scene.instantiate() as Player
	turtle.position = Vector2.ZERO
	side_player.position = Vector2(-20.0, 0.0)
	side_player.power_state = Player.PowerState.SUPER
	fixture.add_child(turtle)
	fixture.add_child(side_player)
	get_tree().root.add_child(fixture)
	turtle.set_physics_process(false)
	side_player.set_physics_process(false)
	turtle._enter_shell()
	turtle._on_contact_area_body_entered(side_player)
	_assert_equal(turtle.state, Turtle.State.SLIDING, "stationary shell side contact starts sliding")
	_assert_equal(turtle.direction, 1, "shell moves away from player")
	turtle._on_contact_area_body_entered(side_player)
	_assert_equal(side_player.power_state, Player.PowerState.SMALL, "sliding shell side contact damages SUPER")

	var top_player := player_scene.instantiate() as Player
	top_player.position = Vector2(0.0, -25.0)
	top_player.velocity.y = 100.0
	fixture.add_child(top_player)
	top_player.set_physics_process(false)
	turtle._on_contact_area_body_entered(top_player)
	_assert_equal(turtle.state, Turtle.State.SHELL, "sliding shell top contact stops shell")
	_assert_true(top_player.velocity.y < 0.0, "sliding shell stomp bounces player")
	fixture.queue_free()
	await get_tree().process_frame
	Game._level_ending = false


func _test_new_enemy_state_rules() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var bat_scene := load("res://scenes/swoop_bat.tscn") as PackedScene
	var spiny_scene := load("res://scenes/spiny.tscn") as PackedScene
	var cannon_scene := load("res://scenes/cannon.tscn") as PackedScene
	if null in [player_scene, bat_scene, spiny_scene, cannon_scene]:
		_failures.append("new enemy state fixtures load")
		return

	Game._level_ending = true
	var fixture := Node2D.new()
	var player := player_scene.instantiate() as Player
	player.position = Vector2.ZERO
	player.power_state = Player.PowerState.SUPER
	var bat := bat_scene.instantiate() as SwoopBat
	bat.position = Vector2(80.0, -40.0)
	var spiny := spiny_scene.instantiate() as Spiny
	spiny.position = Vector2(120.0, 0.0)
	var cannon := cannon_scene.instantiate() as Cannon
	cannon.position = Vector2(1880.0, 0.0)
	cannon.max_active_projectiles = 1
	fixture.add_child(player)
	fixture.add_child(bat)
	fixture.add_child(spiny)
	fixture.add_child(cannon)
	get_tree().root.add_child(fixture)
	player.set_physics_process(false)
	bat.set_physics_process(false)
	spiny.set_physics_process(false)
	cannon.set_process(false)
	await get_tree().process_frame
	_assert_true(player.is_in_group("player"), "player registers one cached-target group")

	bat._start_dive()
	_assert_equal(bat.state, SwoopBat.State.DIVE, "Bat enters DIVE inside detection range")
	bat._state_elapsed = bat.dive_duration
	bat._physics_process(0.0)
	_assert_equal(bat.state, SwoopBat.State.RETURN, "Bat dive is duration bounded")
	bat.global_position = bat._home
	bat._physics_process(0.0)
	_assert_equal(bat.state, SwoopBat.State.PATROL, "Bat returns to PATROL at home")

	spiny._enter_windup()
	_assert_equal(spiny.state, Spiny.State.WINDUP, "Spiny telegraphs before charge")
	spiny._state_elapsed = spiny.windup_sec
	spiny._physics_process(0.0)
	_assert_equal(spiny.state, Spiny.State.CHARGE, "Spiny enters timed CHARGE")
	spiny._state_elapsed = spiny.charge_sec
	spiny._physics_process(0.0)
	_assert_equal(spiny.state, Spiny.State.PATROL, "Spiny charge returns to PATROL")
	player.position = Vector2(120.0, -25.0)
	player.velocity.y = 100.0
	spiny._on_contact_area_body_entered(player)
	_assert_equal(player.power_state, Player.PowerState.SMALL, "Spiny stomp damages instead of defeating")
	_assert_false(spiny._defeated, "Spiny survives a top contact")
	_assert_true(player.velocity.y < 0.0, "surviving Spiny stomp bounces player away")

	player.position = Vector2(1700.0, 0.0)
	cannon._process(0.0)
	_assert_equal(cannon.state, Cannon.State.WARNING, "Cannon visibly warns before firing")
	cannon._state_elapsed = cannon.warning_sec
	cannon._process(0.0)
	_assert_equal(cannon.state, Cannon.State.COOLDOWN, "Cannon enters cooldown after firing")
	_assert_equal(cannon.active_projectile_count(), 1, "Cannon tracks its live projectile")
	var live_projectile := cannon._active_projectiles[0]
	_assert_equal(
		live_projectile._origin,
		cannon.muzzle.global_position,
		"far-stage Cannon captures muzzle as projectile distance origin"
	)
	live_projectile._physics_process(0.1)
	_assert_false(live_projectile.is_queued_for_deletion(), "far-stage shot survives its first movement tick")
	cannon._enter_idle()
	cannon._process(0.0)
	_assert_equal(cannon.state, Cannon.State.IDLE, "projectile cap prevents another warning")
	live_projectile.expire()
	_assert_equal(cannon.active_projectile_count(), 0, "expired shot immediately releases Cannon slot")

	player.queue_free()
	await get_tree().process_frame
	bat._enter_patrol()
	bat._physics_process(0.0)
	spiny._enter_patrol()
	spiny._physics_process(0.0)
	cannon._enter_idle()
	cannon._process(0.0)
	_assert_equal(bat.state, SwoopBat.State.PATROL, "Bat tolerates a freed cached target")
	_assert_equal(spiny.state, Spiny.State.PATROL, "Spiny tolerates a freed cached target")
	_assert_equal(cannon.state, Cannon.State.IDLE, "Cannon tolerates a freed cached target")

	bat.defeat_by_shell()
	spiny.defeat_by_shell()
	cannon.defeat_by_shell()
	_assert_equal(bat.state, SwoopBat.State.DEFEATED, "shell defeats Bat")
	_assert_equal(spiny.state, Spiny.State.DEFEATED, "shell defeats Spiny")
	_assert_equal(cannon.state, Cannon.State.DEFEATED, "shell defeats Cannon")
	bat.defeat_by_shell()
	spiny.defeat_by_shell()
	cannon.defeat_by_shell()
	_assert_true(bat._defeated and spiny._defeated and cannon._defeated, "new shell defeats are idempotent")

	fixture.queue_free()
	await get_tree().process_frame
	Game._level_ending = false


func _test_projectile_bounds() -> void:
	var projectile_scene := load("res://scenes/enemy_projectile.tscn") as PackedScene
	if projectile_scene == null:
		_failures.append("projectile bound fixture loads")
		return
	var projectile := projectile_scene.instantiate() as EnemyProjectile
	projectile.lifetime_sec = 0.05
	projectile.initialize(Vector2.ZERO)
	get_tree().root.add_child(projectile)
	_assert_equal(projectile.direction, Vector2.LEFT, "zero projectile direction has safe fallback")
	_projectile_expired_count = 0
	projectile.expired.connect(_on_test_projectile_expired)
	projectile._physics_process(0.06)
	projectile.expire()
	_assert_equal(_projectile_expired_count, 1, "projectile emits expired exactly once")
	_assert_true(projectile.is_queued_for_deletion(), "lifetime-bounded projectile queues removal")
	await get_tree().process_frame

	var wall_fixture := Node2D.new()
	var wall := _make_test_wall(Vector2(28.0, 0.0), Vector2(8.0, 48.0))
	var wall_shot := projectile_scene.instantiate() as EnemyProjectile
	wall_shot.position = Vector2.ZERO
	wall_fixture.add_child(wall)
	wall_fixture.add_child(wall_shot)
	get_tree().root.add_child(wall_fixture)
	wall_shot.initialize(Vector2.RIGHT)
	for _frame in 20:
		await get_tree().physics_frame
		if wall_shot.is_queued_for_deletion():
			break
	_assert_true(wall_shot.is_queued_for_deletion(), "projectile expires on physical world impact")
	wall_fixture.queue_free()
	await get_tree().process_frame

	Game._level_ending = true
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var hit_fixture := Node2D.new()
	var hit_player := player_scene.instantiate() as Player
	hit_player.position = Vector2(32.0, 0.0)
	hit_player.power_state = Player.PowerState.SUPER
	var player_shot := projectile_scene.instantiate() as EnemyProjectile
	player_shot.position = Vector2.ZERO
	hit_fixture.add_child(hit_player)
	hit_fixture.add_child(player_shot)
	get_tree().root.add_child(hit_fixture)
	hit_player.set_physics_process(false)
	player_shot.initialize(Vector2.RIGHT)
	for _frame in 20:
		await get_tree().physics_frame
		if player_shot.is_queued_for_deletion():
			break
	_assert_equal(hit_player.power_state, Player.PowerState.SMALL, "projectile physical impact damages Player")
	_assert_true(player_shot.is_queued_for_deletion(), "projectile expires on Player impact")
	hit_fixture.queue_free()
	await get_tree().process_frame
	Game._level_ending = false


func _test_spiny_wall_recovery() -> void:
	var spiny_scene := load("res://scenes/spiny.tscn") as PackedScene
	var fixture := Node2D.new()
	var wall := _make_test_wall(Vector2(36.0, 0.0), Vector2(8.0, 64.0))
	var spiny := spiny_scene.instantiate() as Spiny
	spiny.position = Vector2.ZERO
	fixture.add_child(wall)
	fixture.add_child(spiny)
	get_tree().root.add_child(fixture)
	spiny._gravity = 0.0
	spiny.direction = 1
	spiny._enter_charge()
	for _frame in 30:
		await get_tree().physics_frame
		if spiny.state == Spiny.State.STUNNED:
			break
	_assert_equal(spiny.state, Spiny.State.STUNNED, "Spiny wall collision enters STUNNED")
	spiny.set_physics_process(false)
	spiny._state_elapsed = spiny.stunned_sec
	spiny._physics_process(0.0)
	_assert_equal(spiny.state, Spiny.State.PATROL, "Spiny recovers from STUNNED to PATROL")
	fixture.queue_free()
	await get_tree().process_frame


func _test_enemy_removal_safety() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var cannon_scene := load("res://scenes/cannon.tscn") as PackedScene
	var fixture := Node2D.new()
	var player := player_scene.instantiate() as Player
	player.position = Vector2(1700.0, 0.0)
	var cannon := cannon_scene.instantiate() as Cannon
	cannon.position = Vector2(1880.0, 0.0)
	fixture.add_child(player)
	fixture.add_child(cannon)
	get_tree().root.add_child(fixture)
	player.set_physics_process(false)
	cannon.set_process(false)
	await get_tree().process_frame
	cannon._fire()
	_assert_equal(cannon.active_projectile_count(), 1, "removal fixture Cannon creates one shot")
	var orphaned_shot := cannon._active_projectiles[0]
	cannon.queue_free()
	await get_tree().process_frame
	orphaned_shot.expire()
	_assert_true(orphaned_shot.is_queued_for_deletion(), "shot expires safely after owner Cannon is freed")
	fixture.queue_free()
	await get_tree().process_frame


func _make_test_wall(wall_position: Vector2, wall_size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	shape_node.shape = rectangle
	wall.add_child(shape_node)
	return wall


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
	stomp_player.position = Vector2(0.0, -60.0)
	stomp_fixture.add_child(stomp_goomba)
	stomp_fixture.add_child(stomp_player)
	get_tree().root.add_child(stomp_fixture)
	stomp_goomba.set_physics_process(false)
	for _frame in 30:
		await get_tree().physics_frame
		if stomp_goomba.get("_squashed") or stomp_player.is_dead():
			break
	_assert_true(
		stomp_goomba.get("_squashed"),
		"physical top contact squashes Goomba"
	)
	_assert_false(stomp_player.is_dead(), "natural falling stomp does not damage player")
	_assert_true(stomp_player.velocity.y < 0.0, "physical stomp bounces player")
	stomp_fixture.queue_free()
	await get_tree().process_frame

	var turtle_fixture := Node2D.new()
	var turtle := turtle_scene.instantiate() as Turtle
	var turtle_player := player_scene.instantiate() as Player
	turtle.position = Vector2.ZERO
	turtle_player.position = Vector2(0.0, -60.0)
	turtle_fixture.add_child(turtle)
	turtle_fixture.add_child(turtle_player)
	get_tree().root.add_child(turtle_fixture)
	turtle.set_physics_process(false)
	for _frame in 30:
		await get_tree().physics_frame
		if turtle.state != Turtle.State.WALK or turtle_player.is_dead():
			break
	_assert_equal(turtle.state, Turtle.State.SHELL, "physical top contact shells Turtle")
	_assert_false(turtle_player.is_dead(), "natural Turtle stomp does not damage player")
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

	var phased_moving := moving_scene.instantiate() as MovingPlatform
	phased_moving.travel = Vector2(100.0, 0.0)
	phased_moving.cycle_sec = 2.0
	phased_moving.phase = 0.5
	get_tree().root.add_child(phased_moving)
	_assert_equal(phased_moving.position, Vector2(100.0, 0.0), "moving platform applies phase in ready")
	var phased_start := phased_moving.position
	await get_tree().physics_frame
	_assert_true(
		phased_moving.position.distance_to(phased_start) < 1.0,
		"phased moving platform does not teleport on first tick"
	)
	phased_moving.queue_free()
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
	trigger_player.position = Vector2(1000.0, 0.0)
	await get_tree().physics_frame
	falling._on_reset_timer_timeout()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_equal(falling.position, Vector2.ZERO, "falling platform returns to origin")
	_assert_equal(falling.state, FallingPlatform.State.READY, "falling platform re-arms")
	_assert_true(falling.trigger_area.monitoring, "falling platform trigger monitoring re-arms")
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
		if level_number == 1:
			_assert_equal(get_tree().get_nodes_in_group("swoop_bats").size(), 0, "stage 1 keeps baseline enemies")
			_assert_equal(get_tree().get_nodes_in_group("spinies").size(), 0, "stage 1 has no stomp exception")
			_assert_equal(get_tree().get_nodes_in_group("cannons").size(), 0, "stage 1 has no projectiles")
		if level_number == 2:
			_assert_group_count_at_least("swoop_bats", 2, "stage 2 introduces Bats")
			_assert_group_count_at_least("spinies", 1, "stage 2 introduces one Spiny")
		if level_number == 3:
			_assert_group_count_at_least("moving_platforms", 3, "stage 3 moving platforms")
			_assert_group_count_at_least("falling_platforms", 5, "stage 3 falling platforms")
			_assert_group_count_at_least("springs", 2, "stage 3 springs")
			_assert_group_count_at_least("swoop_bats", 3, "stage 3 Bat pressure")
			_assert_group_count_at_least("spinies", 2, "stage 3 Spiny islands")
		if level_number == 4:
			_assert_group_count_at_least("moving_platforms", 5, "stage 4 moving platforms")
			_assert_group_count_at_least("falling_platforms", 3, "stage 4 falling platforms")
			_assert_group_count_at_least("springs", 1, "stage 4 spring")
			_assert_group_count_at_least("spike_hazards", 4, "stage 4 spike hazards")
			_assert_group_count_at_least("instant_hazards", 3, "stage 4 lava hazards")
			_assert_group_count_at_least("swoop_bats", 1, "stage 4 mixed Bat")
			_assert_group_count_at_least("spinies", 3, "stage 4 Spiny pressure")
			_assert_group_count_at_least("cannons", 3, "stage 4 Cannon battery")
		level.queue_free()
		await get_tree().process_frame


func _test_sprite_contracts() -> void:
	for path in [
		"res://assets/sprites/player_idle.png",
		"res://assets/sprites/player_run_0.png",
		"res://assets/sprites/goomba_walk_0.png",
		"res://assets/sprites/turtle_walk_0.png",
		"res://assets/sprites/bat_fly_0.png",
		"res://assets/sprites/spiny_walk_0.png",
		"res://assets/sprites/cannon_idle.png",
	]:
		_assert_sprite_contract(path, Vector2i(24, 24), true)
	for path in [
		"res://assets/sprites/super_idle.png",
		"res://assets/sprites/super_run_0.png",
	]:
		_assert_sprite_contract(path, Vector2i(24, 32), true)
	for path in [
		"res://assets/sprites/coin_0.png",
		"res://assets/sprites/mushroom.png",
		"res://assets/sprites/one_up.png",
	]:
		_assert_sprite_contract(path, Vector2i(16, 16), true)
	_assert_sprite_contract("res://assets/sprites/flag.png", Vector2i(16, 48), true)
	_assert_sprite_contract("res://assets/sprites/tiles.png", Vector2i(128, 32), false)
	_assert_sprite_frames_differ(
		"res://assets/sprites/ember_0.png",
		"res://assets/sprites/ember_1.png",
		"projectile animation changes silhouette"
	)

	var animation_contracts := {
		"res://scenes/player.tscn": ["run", 4],
		"res://scenes/goomba.tscn": ["walk", 3],
		"res://scenes/turtle.tscn": ["walk", 3],
		"res://scenes/swoop_bat.tscn": ["fly", 3],
		"res://scenes/spiny.tscn": ["walk", 3],
		"res://scenes/cannon.tscn": ["warning", 2],
	}
	for scene_path: String in animation_contracts:
		var packed := load(scene_path) as PackedScene
		var actor := packed.instantiate()
		var sprite := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
		var contract: Array = animation_contracts[scene_path]
		_assert_equal(
			sprite.sprite_frames.get_frame_count(contract[0]),
			contract[1],
			"%s has authored %s frame count" % [scene_path, contract[0]]
		)
		actor.free()


func _assert_sprite_contract(path: String, size: Vector2i, transparent_corner: bool) -> void:
	var texture := load(path) as Texture2D
	_assert_not_null(texture, "%s loads as texture" % path)
	if texture == null:
		return
	var image := texture.get_image()
	_assert_false(image.is_empty(), "%s loads as image" % path)
	if image.is_empty():
		return
	_assert_equal(image.get_size(), size, "%s keeps designed dimensions" % path)
	if transparent_corner:
		_assert_equal(image.get_pixel(0, 0).a, 0.0, "%s has transparent silhouette padding" % path)


func _assert_sprite_frames_differ(first_path: String, second_path: String, label: String) -> void:
	var first := (load(first_path) as Texture2D).get_image().get_data()
	var second := (load(second_path) as Texture2D).get_image().get_data()
	_assert_true(first != second, label)


func _on_test_projectile_expired(_projectile: EnemyProjectile) -> void:
	_projectile_expired_count += 1


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
