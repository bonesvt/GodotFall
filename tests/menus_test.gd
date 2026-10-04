extends SceneTree
## Headless test for the menus: settings save and apply, key rebinding, save
## slots (and moving an old save into slot 1), the title screen loading a slot
## into the game, and the Esc pause menu (resume, settings, abandon a run, quit
## to the title).
## Run: godot --headless --path . -s res://tests/menus_test.gd

const Prefs := preload("res://scripts/game/prefs.gd")
const Saves := preload("res://scripts/game/saves.gd")
const Armory := preload("res://scripts/hub/armory.gd")

const TEST_SETTINGS := "user://test_menus_settings.cfg"
const TEST_SAVES := "user://test_menus_saves/"
const TEST_LEGACY := "user://test_menus_legacy/"

var failures := 0


func _initialize() -> void:
	# Everything goes to test files so a run never touches your own settings or saves.
	Prefs.path = TEST_SETTINGS
	Saves.dir = TEST_SAVES
	Saves.settings_path = TEST_SETTINGS
	Saves.legacy_dir = TEST_LEGACY
	_clean()
	_run.call_deferred()


func _run() -> void:
	_prefs()
	_looks()
	_keys()
	_slots()
	await _title_and_pause()
	_clean()
	print("menus test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _prefs() -> void:
	Prefs._cfg = null
	Prefs.apply_all(true)
	_check("sensitivity defaults to 1x", is_equal_approx(Prefs.look_x(10.0), 10.0), Prefs.look_x(10.0))
	Prefs.set_value("controls", "sensitivity", 2.0)
	Prefs.set_value("controls", "invert_y", true)
	Prefs.set_value("controls", "fov", 100.0)
	Prefs.set_value("audio", "Effects", 0.0)
	Prefs.save()
	Prefs._cfg = null  # read back from disk
	Prefs.apply_audio()
	_check("sensitivity saved and applied", is_equal_approx(Prefs.look_x(10.0), 20.0), Prefs.look_x(10.0))
	_check("invert Y", Prefs.look_y(10.0) < 0.0, Prefs.look_y(10.0))
	_check("FOV shifts the cameras", is_equal_approx(Prefs.fov_offset(), 10.0), Prefs.fov_offset())
	var fx := AudioServer.get_bus_index("Effects")
	_check("effects bus exists and mutes at 0", fx > 0 and AudioServer.is_bus_mute(fx), fx)
	for bus in ["Ambience", "Voices"]:
		_check("%s bus exists" % bus, AudioServer.get_bus_index(bus) > 0, bus)
	Prefs.set_value("audio", "Effects", 1.0)
	Prefs.set_value("controls", "sensitivity", 1.0)
	Prefs.set_value("controls", "invert_y", false)
	Prefs.set_value("controls", "fov", 90.0)
	Prefs.save()
	Prefs.apply_audio()


func _looks() -> void:
	var ps2 = root.get_node_or_null("PS2")
	Prefs._cfg = null
	_check("the Anime look is the default", Prefs.look() == "anime", Prefs.look())
	if ps2 != null:
		Prefs.apply_video()
		_check("the autoload starts in the Anime look", ps2.look() == "anime", ps2.look())
	# A settings file from before the Anime look that only saved ps2_look.
	Prefs.set_value("video", "ps2_look", true)
	_check("old PS2 setting keeps PS2", Prefs.look() == "ps2", Prefs.look())
	Prefs.remember_look("ps3")
	Prefs._cfg = null
	_check("F9's look is remembered", Prefs.look() == "ps3" and not bool(Prefs.get_value("video", "ps2_look")), Prefs.look())
	if ps2 != null:
		Prefs.apply_video()
		_check("F9's look is applied", ps2.look() == "ps3" and not ps2.anime, ps2.look())
	Prefs.set_value("video", "film_grain", 0.5)
	Prefs.remember_look("anime")
	Prefs.apply_video()
	if ps2 != null:
		var grain: float = ps2._post.material_override.get_shader_parameter("grain")
		_check("film grain slider sets the screen pass", is_equal_approx(grain, 0.5 * ps2.MAX_GRAIN), grain)
	Prefs.set_value("video", "film_grain", 0.4)
	Prefs.save()


func _keys() -> void:
	var j := InputEventKey.new()
	j.physical_keycode = KEY_J
	Prefs.rebind("jump", 0, j)
	_check("jump rebound to J", _has_key("jump", KEY_J) and not _has_key("jump", KEY_SPACE), Prefs.bindings("jump"))
	Prefs.rebind("crouch", 1, j)
	_check("binding J to crouch takes it off jump", _has_key("crouch", KEY_J) and not _has_key("jump", KEY_J), [Prefs.bindings("jump"), Prefs.bindings("crouch")])
	_check("crouch keeps C as its primary", _has_key("crouch", KEY_C), Prefs.bindings("crouch"))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	Prefs.rebind("grapple", 1, mb)
	Prefs.save()
	Prefs._cfg = null
	Prefs.reset_keys()   # back to defaults in memory, then the saved file puts them back
	Prefs._cfg = null
	Prefs.apply_keys()
	_check("rebinds survive a restart", _has_key("crouch", KEY_J) and Prefs.bindings("grapple").size() == 2, [Prefs.bindings("crouch"), Prefs.bindings("grapple")])
	Prefs.rebind("crouch", 1, null)
	_check("Backspace clears the second binding", Prefs.bindings("crouch").size() == 1, Prefs.bindings("crouch"))
	Prefs.reset_keys()
	Prefs.save()
	_check("reset puts the defaults back", _has_key("jump", KEY_SPACE) and _has_key("crouch", KEY_CTRL) and Prefs.bindings("grapple").size() == 3, Prefs.bindings("grapple"))
	var saved := ConfigFile.new()
	saved.load(TEST_SETTINGS)
	_check("reset clears the saved keys", not saved.has_section("keys") or saved.get_section_keys("keys").is_empty(), saved.encode_to_text())
	_check("keys read nicely", Prefs.event_name(Prefs.bindings("fire")[0]) == "Left mouse", Prefs.event_name(Prefs.bindings("fire")[0]))


func _slots() -> void:
	# An old save from before slots: it becomes slot 1.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_LEGACY))
	var old := Armory.new(TEST_LEGACY + "armory.cfg")
	old.suit_tier = 2
	old.save()
	var legacy_settings := ConfigFile.new()
	legacy_settings.set_value("tutorial", "seen", PackedStringArray(["grapple"]))
	legacy_settings.save(TEST_SETTINGS)
	Saves.migrate_legacy()
	_check("old save moves into slot 1", Saves.exists(1) and Saves.info(1)["level"] == 3, Saves.info(1))
	var progress := ConfigFile.new()
	progress.load(Saves.path(1, "progress.cfg"))
	_check("old tutorial progress moves too", "grapple" in progress.get_value("tutorial", "seen", []), progress.encode_to_text())
	Saves.migrate_legacy()  # only once
	_check("slot 2 starts empty", not Saves.exists(2) and Saves.info(2).is_empty(), Saves.info(2))
	Saves.new_game(2)
	Saves.use(2)
	Saves.tick(90.0)
	Saves.record_run(true)
	Saves.record_run(false)
	var info := Saves.info(2)
	_check("slot counts runs, wins and time", info["runs"] == 2 and info["wins"] == 1 and info["seconds"] >= 90.0, info)
	_check("continue picks the slot played last", Saves.last_slot() == 2, Saves.last_slot())
	_check("slot paths", Saves.armory_path() == TEST_SAVES + "slot2/armory.cfg", Saves.armory_path())
	Saves.erase(2)
	_check("erase empties a slot", not Saves.exists(2) and Saves.active == 0, Saves.exists(2))
	_check("continue falls back to a slot that exists", Saves.last_slot() == 1, Saves.last_slot())


func _title_and_pause() -> void:
	var title = load("res://scenes/title.tscn").instantiate()
	title.backdrop = false
	root.add_child(title)
	current_scene = title
	await _ticks(3)
	_check("title offers Continue with a save", title.continue_button.visible and title.main_menu.visible, title.continue_button.visible)
	title._show_slots("new")
	await _ticks(1)
	_check("new game lists every slot", title.slot_list.get_child_count() == Saves.SLOTS, title.slot_list.get_child_count())
	title._pick_slot(1)
	_check("new game on a used slot asks first", title.confirm.visible and Saves.exists(1), title.confirm.visible)
	title.confirm.visible = false
	title._show_slots("load")
	await _ticks(1)
	_check("load game can't pick an empty slot", (title.slot_list.get_child(2) as Button).disabled, "")
	title.open_settings()
	await _ticks(1)
	_check("settings opens from the title", title._settings != null and title._settings.tabs.get_tab_count() == 5, "")
	await _esc()
	_check("Esc closes settings", title._settings == null and title.main_menu.visible, "")

	title.continue_game()
	await _ticks(90)
	var run_node = current_scene
	_check("continue loads the game in the hub", run_node != null and run_node.name == "Run" and run_node.phase == run_node.Phase.HUB, run_node)
	_check("the game uses slot 1's saves", run_node.armory_path == TEST_SAVES + "slot1/armory.cfg" and run_node.armory.suit_tier == 2, run_node.armory_path)
	var menu = run_node.pause_menu
	await _esc()
	_check("Esc pauses", menu.is_open and paused and menu._root.visible, paused)
	_check("the HUD hides under the pause menu", not run_node.hud.visible and not run_node.pilot_hud.visible, "")
	await _esc()
	_check("Esc again resumes", not menu.is_open and not paused, paused)
	_check("the HUD comes back", run_node.hud.visible and run_node.pilot_hud.visible, "")
	await _esc()
	menu.open_settings()
	await _ticks(1)
	_check("settings opens over the pause menu", menu._settings != null and not menu._menu.visible, "")
	await _esc()
	_check("Esc in settings goes back to the pause menu", menu._settings == null and menu.is_open and menu._menu.visible, "")
	menu.close()

	run_node.start_run(4242)
	await _ticks(30)
	_check("Esc during a run offers Abandon", run_node.in_run(), run_node.phase)
	await _esc()
	_check("abandon shows during a run", menu._abandon.visible, "")
	menu.abandon_run()
	await _ticks(2)
	_check("abandoning ends the run", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN ABANDONED" and not paused, run_node.result)
	_check("the run counts on the slot", Saves.info(1)["runs"] == 1, Saves.info(1))
	run_node.bench = Node.new()  # a workbench open: Esc belongs to it
	_check("no pause menu over a workbench", not menu.can_open(), "")
	run_node.bench.free()
	run_node.bench = null
	menu.open()
	menu.quit_to_title()
	await _ticks(5)
	_check("quit to title", current_scene != null and current_scene.name == "Title", current_scene)


func _esc() -> void:
	# Straight to the viewport, like a real key press (Input.parse_input_event
	# can sit in the input buffer headless on newer Godot builds).
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	await _ticks(2)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await _ticks(2)


func _has_key(action: String, code: Key) -> bool:
	for e in Prefs.bindings(action):
		if e is InputEventKey and e.physical_keycode == code:
			return true
	return false


func _clean() -> void:
	for n in range(1, Saves.SLOTS + 1):
		Saves.erase(n)
	for p in [TEST_SETTINGS, TEST_LEGACY + "armory.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for d in [TEST_SAVES, TEST_LEGACY]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(d))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
