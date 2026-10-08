extends SceneTree
## Marrow's trigger words (trigger_words.gd) and the craving on screen
## (craving_screen.gd, the HUD bar): a phrase locks her up, F taps shake it off,
## a miss costs Hold (and a minute on the pull clock at full Hold) in the hub or
## guard-down time on a run; the craving builds with the clock and shows.
##   godot --headless --path . -s res://tests/trigger_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const TriggerWords := preload("res://scripts/hub/trigger_words.gd")
const CravingScreen := preload("res://scripts/ui/craving_screen.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	Vices.save_path = "user://test_trigger_vices.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_trigger_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var pull: Node = run_node.hush_pull
	var tw: Node = pull.triggers

	# Below TRANCE_HOLD his words don't reach her.
	Vices.hold = Vices.TRANCE_HOLD - 1.0
	_check("not below the trance hold", not TriggerWords.can_trigger(), Vices.hold)
	Vices.hold = Vices.TRANCE_HOLD
	_check("from the trance hold up", TriggerWords.can_trigger(), Vices.hold)
	_check("deeper hold, more often", TriggerWords.gap() > 100.0 and is_equal_approx((func(): Vices.hold = Vices.MAX_HOLD; return TriggerWords.gap()).call(), TriggerWords.GAP_DEEP), TriggerWords.gap())

	# One fires in the hub: she's locked, the phrase is up, F shakes it off.
	Vices.hold = 70.0
	Vices.errand = "x"  # keep the pull clock out of it
	tw.fire(false)
	await _ticks(2)
	_check("it takes her", tw.busy() and pull.busy() and player.entranced and Vices.entranced, tw.step)
	_check("the phrase on screen", run_node.hud.trigger_label.visible and run_node.hud.trigger_label.text.begins_with(tw.phrase.to_upper()), run_node.hud.trigger_label.text)
	_check("where she heard it", run_node.hud.toast_label.text.contains(tw.phrase), run_node.hud.toast_label.text)
	var pos := player.global_position
	Input.action_press("move_forward")
	await _ticks(30)
	Input.action_release("move_forward")
	_check("she can't move while it has her", player.global_position.distance_to(pos) < 0.3, player.global_position.distance_to(pos))
	for i in TriggerWords.TAPS:
		await _press("interact")
	await _ticks(2)
	_check("five taps shake it off", not tw.busy() and not player.entranced and not Vices.entranced and not run_node.hud.trigger_label.visible, tw.step)
	_check("no cost when she shakes it", Vices.hold == 70.0, Vices.hold)

	# Miss it in the hub: his Hold deepens.
	tw.fire(false)
	await _ticks(int(Engine.physics_ticks_per_second * (TriggerWords.WINDOW + 0.3)))
	_check("a miss lets go", not tw.busy() and not Vices.entranced, tw.step)
	_check("a miss deepens his hold", Vices.hold == 70.0 + TriggerWords.FAIL_HOLD, Vices.hold)

	# At full Hold a miss also runs the pull clock on a minute.
	Vices.hold = Vices.MAX_HOLD
	Vices.errand = ""
	Vices.pulled = false
	Vices.dosed = false
	pull.roam = 10.0
	tw.fire(false)
	await _ticks(int(Engine.physics_ticks_per_second * (TriggerWords.WINDOW + 0.3)))
	_check("full hold: the clock jumps a minute", pull.roam >= 10.0 + Vices.ROLL_EVERY and pull.roam < Vices.PULL_DEADLINE, pull.roam)

	# The craving builds with the clock, and shows.
	pull.roam = Vices.PULL_DEADLINE * 0.5
	pull.tick(0.0, true)
	await _ticks(2)
	_check("craving follows the clock", absf(Vices.crave_level() - (0.25 + 0.75 * 0.5)) < 0.01, Vices.crave_level())
	var screen: CanvasLayer = run_node.get_node("CravingScreen")
	_check("the screen closes in", screen._rect.visible, screen._rect.visible)
	_check("the craving bar shows", run_node.hud.crave_bar.visible and run_node.hud._crave_fill.size.x > 50.0, run_node.hud._crave_fill.size)
	_check("heartbeat thumps twice a beat", CravingScreen.heartbeat(0.05) > 0.95 and CravingScreen.heartbeat(0.28) > 0.6 and CravingScreen.heartbeat(0.6) < 0.05, CravingScreen.heartbeat(0.28))
	Vices.errand = "x"
	pull.tick(0.016, true)
	await _ticks(2)
	_check("on an errand it eases off", Vices.crave_level() == 0.0 and not run_node.hud.crave_bar.visible, Vices.crave_level())

	# Teen: none of it.
	ContentRating.set_rating("T", false)
	_check("teen: no triggers", not TriggerWords.can_trigger(), Vices.allowed())
	_check("teen: no craving", Vices.crave_level() == 0.0, Vices.crave_level())
	ContentRating.set_rating("M", false)
	Vices.errand = ""
	Vices.hold = 0.0

	print("trigger_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
