extends CanvasLayer
## Esc in the hub, the town or a run: pauses the game and opens this menu.
##   Resume          (Esc again does the same)
##   Settings        settings_menu.gd
##   Abandon run     only during a run: ends it like a loss (half the carried
##                   materials bank) and shows the run summary
##   Quit to title   a run in progress is abandoned first
##   Quit game       same, then closes the game
## It doesn't open over a workbench, the paint shop or the salvage choice:
## those already pause the game and Esc closes them.

const UI := preload("res://scripts/ui/ui_theme.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const TITLE_SCENE := "res://scenes/title.tscn"

## The run manager (scripts/run/run_manager.gd).
var run: Node
var is_open := false
var _root: Control
var _menu: Control
var _abandon: Button
var _quit_title: Button
var _settings: Control
var _mouse_before := Input.MOUSE_MODE_CAPTURED
## The game's HUD layers hidden while the menu is up, and whether each was showing.
var _hidden := {}


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 160)
	_root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size.x = 420
	margin.add_child(col)
	_menu = col
	col.add_child(UI.heading("PAUSED", 56))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	col.add_child(gap)
	col.add_child(UI.button("Resume", close))
	col.add_child(UI.button("Settings", open_settings))
	_abandon = UI.button("Abandon run", abandon_run)
	col.add_child(_abandon)
	_quit_title = UI.button("Quit to title", quit_to_title)
	col.add_child(_quit_title)
	col.add_child(UI.button("Quit game", quit_game))


## Whether Esc may open the menu right now.
func can_open() -> bool:
	if is_open or get_tree().paused:
		return false
	return run == null or not run.has_method("menu_blocked") or not run.menu_blocked()


func _input(event: InputEvent) -> void:
	if not UI.is_back(event):
		return
	if is_open:
		get_viewport().set_input_as_handled()
		if _settings == null:
			close()
		elif _settings._waiting.is_empty():
			_settings.close()
	elif can_open():
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	is_open = true
	_mouse_before = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var in_run: bool = run != null and run.has_method("in_run") and run.in_run()
	_abandon.visible = in_run
	_quit_title.text = "Abandon run and quit to title" if in_run else "Quit to title"
	_root.visible = true
	_menu.visible = true
	_hide_hud(true)
	UI.focus(_menu.get_child(2) as Button)


func close() -> void:
	if _settings != null:
		_settings.close()
	is_open = false
	_root.visible = false
	_hide_hud(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The HUD, help text and tutorial card would show through the menu.
func _hide_hud(hide: bool) -> void:
	if run == null:
		return
	if hide:
		_hidden = {}
		for key in ["hud", "pilot_hud", "tutorial"]:
			var layer = run.get(key)
			if layer is CanvasLayer or layer is CanvasItem:
				_hidden[layer] = layer.visible
				layer.visible = false
			elif layer is Node:
				for c in layer.get_children():
					if c is CanvasLayer:
						_hidden[c] = c.visible
						c.visible = false
	else:
		for layer in _hidden:
			if is_instance_valid(layer):
				layer.visible = _hidden[layer]
		_hidden = {}


func open_settings() -> void:
	_menu.visible = false
	_settings = SettingsMenu.new()
	_settings.tutorial = run.get("tutorial") if run != null else null
	_settings.closed.connect(func() -> void:
		_settings = null
		_menu.visible = true
		UI.focus(_menu.get_child(3) as Button))
	_root.add_child(_settings)


func abandon_run() -> void:
	close()
	if run != null and run.has_method("abandon_run"):
		run.abandon_run()


func quit_to_title() -> void:
	_leave()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func quit_game() -> void:
	_leave()
	get_tree().quit()


## Wraps up before leaving: a run in progress is abandoned (so its haul
## banks), and the time played is written to the save slot.
func _leave() -> void:
	if run != null and run.has_method("in_run") and run.in_run():
		run.abandon_run()
	var Saves = load("res://scripts/game/saves.gd")
	Saves.flush()
