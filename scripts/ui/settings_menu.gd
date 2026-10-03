extends Control
## The settings screen, shared by the title screen and the pause menu. Every
## change takes effect at once and is saved straight away (prefs.gd).
##   Controls  mouse sensitivity, invert Y, field of view
##   Keys      rebind every action (primary and secondary), reset to defaults
##   Sound     master, effects, ambience, voices
##   Video     window / borderless / fullscreen, vsync, frame cap, PS3 or PS2 look
##   Game      dialogue rating, tutorial hints, start in third person
## Esc or Back closes it (emits `closed`).

signal closed

const UI := preload("res://scripts/ui/ui_theme.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const RadioLines := preload("res://scripts/radio/radio_lines.gd")
const Tutorial := preload("res://scripts/run/tutorial.gd")

const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240]

## The live tutorial (run_manager.gd's), so toggling hints here works mid-game.
var tutorial: Node
## [action, slot, button] while waiting for a key press to bind.
var _waiting := []
var _key_buttons := {}
var tabs: TabContainer


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 700)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_child(UI.heading("SETTINGS", 36))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var back := UI.button("Back", close)
	back.name = "Back"
	top.add_child(back)
	col.add_child(top)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	_controls_tab()
	_keys_tab()
	_sound_tab()
	_video_tab()
	_game_tab()
	UI.focus(back)


func close() -> void:
	_waiting = []
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not _waiting.is_empty():
		_capture(event)
		return
	if UI.is_back(event):
		get_viewport().set_input_as_handled()
		close()


# --- tabs -----------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_right", 30)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func _row(box: VBoxContainer, title: String, control: Control, hint := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UI.label(title)
	l.custom_minimum_size.x = 300
	if hint != "":
		l.tooltip_text = hint
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	box.add_child(row)
	return row


## A slider with its value printed beside it.
func _slider(box: VBoxContainer, title: String, lo: float, hi: float, step: float, value: float, fmt: Callable, on_change: Callable) -> HSlider:
	var wrap := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 26
	var shown := UI.label(fmt.call(value), 22, UI.AMBER)
	shown.custom_minimum_size.x = 90
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		shown.text = fmt.call(v)
		on_change.call(v))
	wrap.add_child(s)
	wrap.add_child(shown)
	_row(box, title, wrap)
	return s


func _toggle(box: VBoxContainer, title: String, on: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.text = "On" if on else "Off"
	c.toggled.connect(func(v: bool) -> void:
		c.text = "On" if v else "Off"
		on_change.call(v))
	_row(box, title, c)
	return c


func _options(box: VBoxContainer, title: String, labels: Array, selected: int, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.select(maxi(selected, 0))
	o.item_selected.connect(on_change)
	_row(box, title, o)
	return o


func _save_pref(section: String, key: String, value: Variant) -> void:
	Prefs.set_value(section, key, value)
	Prefs.save()


func _controls_tab() -> void:
	var box := _page("Controls")
	_slider(box, "Mouse sensitivity", 0.1, 3.0, 0.05, Prefs.sensitivity(),
		func(v): return "%.2fx" % v,
		func(v): _save_pref("controls", "sensitivity", v))
	_toggle(box, "Invert mouse Y", bool(Prefs.get_value("controls", "invert_y")),
		func(v): _save_pref("controls", "invert_y", v))
	_slider(box, "Field of view", 70.0, 120.0, 1.0, float(Prefs.get_value("controls", "fov")),
		func(v): return "%d°" % int(v),
		func(v): _save_pref("controls", "fov", v))
	box.add_child(UI.label("Field of view is for first person; third person and the titan shift by the same amount.", 18, UI.MUTED))


func _keys_tab() -> void:
	var box := _page("Keys")
	box.add_child(UI.label("Click a binding, then press a key or mouse button.  Esc cancels, Backspace clears the second binding.", 18, UI.MUTED))
	for pair in Prefs.BINDABLE:
		var action: String = pair[0]
		if not InputMap.has_action(action):
			continue
		var wrap := HBoxContainer.new()
		wrap.add_theme_constant_override("separation", 10)
		var buttons := []
		for slot in 2:
			var b := Button.new()
			b.custom_minimum_size = Vector2(220, 0)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_stylebox_override("normal", UI._box(UI.FIELD, 4, Color(1, 1, 1, 0.12)))
			b.add_theme_font_size_override("font_size", 20)
			b.pressed.connect(_start_capture.bind(action, slot, b))
			wrap.add_child(b)
			buttons.append(b)
		_key_buttons[action] = buttons
		_row(box, pair[1], wrap)
	var reset := UI.button("Reset all keys to defaults", func() -> void:
		Prefs.reset_keys()
		Prefs.save()
		_refresh_keys())
	box.add_child(reset)
	_refresh_keys()


func _refresh_keys() -> void:
	for action in _key_buttons:
		var events: Array = Prefs.bindings(action)
		var buttons: Array = _key_buttons[action]
		buttons[0].text = Prefs.event_name(events[0]) if events.size() > 0 else "-"
		var rest: Array = events.slice(1).map(func(e): return Prefs.event_name(e))
		buttons[1].text = ", ".join(rest) if not rest.is_empty() else "-"


func _start_capture(action: String, slot: int, b: Button) -> void:
	_refresh_keys()
	_waiting = [action, slot, b]
	b.text = "press a key..."


func _capture(event: InputEvent) -> void:
	var picked: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if UI.is_back(event):
			get_viewport().set_input_as_handled()
			_waiting = []
			_refresh_keys()
			return
		if event.physical_keycode in [KEY_BACKSPACE, KEY_DELETE] and _waiting[1] == 1:
			Prefs.rebind(_waiting[0], 1, null)
		else:
			picked = InputEventKey.new()
			(picked as InputEventKey).physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	elif event is InputEventMouseButton and event.pressed:
		picked = InputEventMouseButton.new()
		(picked as InputEventMouseButton).button_index = event.button_index
	else:
		return
	get_viewport().set_input_as_handled()
	if picked != null:
		Prefs.rebind(_waiting[0], _waiting[1], picked)
	Prefs.save()
	_waiting = []
	_refresh_keys()


func _sound_tab() -> void:
	var box := _page("Sound")
	for pair in [["Master", "Master volume"], ["Effects", "Effects (guns, steps, titans)"], ["Ambience", "Ambience"], ["Voices", "Voices (radio, Eco, people)"]]:
		var bus: String = pair[0]
		_slider(box, pair[1], 0.0, 1.0, 0.01, float(Prefs.get_value("audio", bus)),
			func(v): return "%d%%" % roundi(v * 100.0),
			func(v):
				Prefs.set_value("audio", bus, v)
				Prefs.apply_audio()
				Prefs.save())


func _video_tab() -> void:
	var box := _page("Video")
	_options(box, "Display", ["Windowed", "Borderless fullscreen", "Fullscreen"],
		Prefs.DISPLAY_MODES.find(String(Prefs.get_value("video", "display"))),
		func(i): _set_video("display", Prefs.DISPLAY_MODES[i]))
	_toggle(box, "VSync", bool(Prefs.get_value("video", "vsync")), func(v): _set_video("vsync", v))
	_options(box, "Frame rate cap", FPS_CAPS.map(func(f): return "Unlimited" if f == 0 else "%d fps" % f),
		FPS_CAPS.find(int(Prefs.get_value("video", "max_fps"))),
		func(i): _set_video("max_fps", FPS_CAPS[i]))
	_options(box, "Look", ["PS3 (sharp, detailed)", "PS2 (retro, F9)"],
		1 if bool(Prefs.get_value("video", "ps2_look")) else 0,
		func(i): _set_video("ps2_look", i == 1))


func _set_video(key: String, value: Variant) -> void:
	Prefs.set_value("video", key, value)
	Prefs.apply_video()
	Prefs.save()


func _game_tab() -> void:
	var box := _page("Game")
	var ratings: Array = Prefs.ContentRating.RATINGS
	_options(box, "Dialogue rating (O)", ratings.map(func(r): return RadioLines.RATING_NAMES[r]),
		ratings.find(Prefs.rating()),
		func(i): Prefs.set_rating(ratings[i]))
	box.add_child(UI.label("How rough the militia radio and Eco's whispers get.", 18, UI.MUTED))
	# Hints are kept per save slot, so they're only offered with a game going.
	if tutorial != null:
		_toggle(box, "Tutorial hints (F1)", _hints_on(), _set_hints)
	_toggle(box, "Start in third person (F5)", bool(Prefs.get_value("game", "third_person")),
		func(v):
			_save_pref("game", "third_person", v)
			load("res://scripts/view_camera.gd").prefer_third_person = v)


func _hints_on() -> bool:
	if tutorial != null and is_instance_valid(tutorial):
		return bool(tutorial.enabled)
	var cfg := ConfigFile.new()
	cfg.load(Tutorial.settings_path)
	return bool(cfg.get_value("tutorial", "enabled", true))


func _set_hints(on: bool) -> void:
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.set_enabled(on)
		return
	var cfg := ConfigFile.new()
	cfg.load(Tutorial.settings_path)
	cfg.set_value("tutorial", "enabled", on)
	cfg.save(Tutorial.settings_path)
