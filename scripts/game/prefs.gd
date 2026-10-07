extends RefCounted
## Player settings: look, sound, video, gameplay and key bindings. Saved in
## user://settings.cfg next to the sections other scripts already keep there
## ([content] dialogue rating, content_rating.gd). Settings are per computer,
## not per save slot (saves.gd).
##
## Nothing here needs an autoload: the title screen (and the run scene, when
## it's played on its own from the editor) calls Prefs.apply_all() once, and the
## player and titan read look settings straight off this class.
##
##   Prefs.look_x(event.relative.x)    # mouse turn, sensitivity applied
##   Prefs.fov_offset()                # degrees added to every gameplay camera
##   Prefs.set_value("audio", "Effects", 0.8); Prefs.save()

## Tests point this elsewhere.
static var path := "user://settings.cfg"
const ContentRating := preload("res://scripts/radio/content_rating.gd")

## Every setting and its default, by section.
const DEFAULTS := {
	"controls": {"sensitivity": 1.0, "invert_y": false, "fov": 90.0},
	"audio": {"Master": 0.9, "Effects": 1.0, "Ambience": 1.0, "Voices": 1.0},
	"video": {"display": "windowed", "vsync": true, "max_fps": 0, "look": "anime", "film_grain": 0.4, "ps2_look": false},
	"game": {"third_person": false, "jiggle_style": "classic", "body_jiggle": false,
		"tp_distance": 1.7, "shoulder_swap": true, "hub_nudge": true, "hub_nudge_x": 0.0, "hub_nudge_y": 0.0},
}
## The FOV the cameras were tuned at; the FOV setting shifts every camera by
## its difference from this.
const BASE_FOV := 90.0
const GAME_NAME := "GodotFall"
const DISPLAY_MODES := ["windowed", "borderless", "fullscreen"]

## Rebindable actions, in the order the settings screen lists them.
const BINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"],
	["move_left", "Move left"], ["move_right", "Move right"],
	["jump", "Jump / wall jump"], ["crouch", "Crouch / slide"], ["sprint", "Sprint / titan dash"],
	["grapple", "Grapple"], ["fire", "Shoot"], ["reload", "Reload"],
	["melee", "Knife (tap: strike, hold: draw it)"], ["swap_weapon", "Switch knife / gun"], ["inspect", "Inspect weapon"], ["interact", "Interact / embark"],
	["titan_core", "Call titan / core"], ["reset", "Respawn"],
	["toggle_view", "First / third person"], ["swap_shoulder", "Swap shoulder (third person)"],
	["cam_nudge_up", "Hub camera up"], ["cam_nudge_down", "Hub camera down"],
	["cam_nudge_left", "Hub camera left"], ["cam_nudge_right", "Hub camera right"],
	["ps2_toggle", "Change look (Anime / PS3 / PS2)"],
]

static var _cfg: ConfigFile
static var _applied := false
## action -> its default events, captured before any saved binding replaced them.
static var _default_keys := {}


static func cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)
	return _cfg


static func get_value(section: String, key: String) -> Variant:
	return cfg().get_value(section, key, DEFAULTS[section][key])


static func set_value(section: String, key: String, value: Variant) -> void:
	cfg().set_value(section, key, value)


static func save() -> void:
	# Re-read first so sections other scripts wrote since (tutorial, rating) survive.
	var disk := ConfigFile.new()
	disk.load(path)
	for section in DEFAULTS.keys() + ["keys"]:
		if not cfg().has_section(section):
			continue
		for key in cfg().get_section_keys(section):
			disk.set_value(section, key, cfg().get_value(section, key))
	if disk.has_section("keys"):
		for key in disk.get_section_keys("keys"):
			if not cfg().has_section("keys") or not cfg().has_section_key("keys", key):
				disk.erase_section_key("keys", key)
	disk.save(path)


## Puts everything saved into effect. Safe to call again; only the first call
## per launch does the work unless `force`.
static func apply_all(force := false) -> void:
	if _applied and not force:
		return
	_applied = true
	# The project keeps its old name so user:// (and everyone's saves) stays put;
	# the window shows the game's name.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(GAME_NAME)
	apply_audio()
	apply_video()
	apply_keys()
	load("res://scripts/view_camera.gd").prefer_third_person = bool(get_value("game", "third_person"))
	apply_camera()


# --- third person camera ----------------------------------------------------------

## Hands the third person settings to the camera (view_camera.gd keeps them as
## statics, so every player camera picks them up, now and after a respawn).
static func apply_camera() -> void:
	var view = load("res://scripts/view_camera.gd")
	view.distance_setting = float(get_value("game", "tp_distance"))
	view.shoulder_swap_key = bool(get_value("game", "shoulder_swap"))
	view.hub_nudge_keys = bool(get_value("game", "hub_nudge"))
	view.hub_nudge = Vector2(float(get_value("game", "hub_nudge_x")), float(get_value("game", "hub_nudge_y")))


# --- look ---------------------------------------------------------------------

static func sensitivity() -> float:
	return float(get_value("controls", "sensitivity"))


## Mouse turn (radians per pixel already scaled by the caller's base rate).
static func look_x(relative: float) -> float:
	return relative * sensitivity()


static func look_y(relative: float) -> float:
	return relative * sensitivity() * (-1.0 if bool(get_value("controls", "invert_y")) else 1.0)


static func fov_offset() -> float:
	return float(get_value("controls", "fov")) - BASE_FOV


# --- sound --------------------------------------------------------------------

## Linear 0..1 slider value to the bus; 0 mutes it.
static func apply_audio() -> void:
	for bus_name in DEFAULTS["audio"]:
		var i := AudioServer.get_bus_index(bus_name)
		if i < 0:
			continue
		var v := clampf(float(get_value("audio", bus_name)), 0.0, 1.0)
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# --- video --------------------------------------------------------------------

static func apply_video() -> void:
	if DisplayServer.get_name() != "headless":
		match String(get_value("video", "display")):
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			"borderless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_:
				if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("video", "vsync")) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("video", "max_fps"))
	var ps2 = Engine.get_main_loop().root.get_node_or_null("PS2") if Engine.get_main_loop() is SceneTree else null
	if ps2 != null:
		if ps2.look() != look():
			ps2.set_look(look())
		ps2.set_grain(float(get_value("video", "film_grain")))


## "anime", "ps3" or "ps2". Settings from before the Anime look only saved
## ps2_look; a PS2 player keeps PS2.
static func look() -> String:
	if not cfg().has_section_key("video", "look") and bool(get_value("video", "ps2_look")):
		return "ps2"
	return String(get_value("video", "look"))


## F9 changes the look outside the menu; remember it.
static func remember_look(name: String) -> void:
	if look() == name:
		return
	set_value("video", "look", name)
	set_value("video", "ps2_look", name == "ps2")
	save()


# --- jiggle style ---------------------------------------------------------------

## Eco's jiggle style (eco_model.gd JIGGLE_STYLES): "classic", "anime" or "realistic".
const JIGGLE_STYLES := ["classic", "anime", "realistic"]


static func jiggle_style() -> String:
	var style := String(get_value("game", "jiggle_style"))
	return style if style in JIGGLE_STYLES else "classic"


## Saves the style and puts it on every Eco that follows the setting.
static func set_jiggle_style(style: String) -> void:
	set_value("game", "jiggle_style", style if style in JIGGLE_STYLES else "classic")
	save()
	if Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).call_group("eco_jiggle", "follow_jiggle_setting")


## Full body jiggle (experimental, eco_flesh.gd): her stomach, thighs, upper
## arms and calves get soft springs too.
static func body_jiggle() -> bool:
	return bool(get_value("game", "body_jiggle"))


## Saves it and puts it on every Eco that follows the jiggle settings.
static func set_body_jiggle(on: bool) -> void:
	set_value("game", "body_jiggle", on)
	save()
	if Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).call_group("eco_jiggle", "follow_jiggle_setting")


# --- dialogue rating ------------------------------------------------------------

static func rating() -> String:
	return ContentRating.current()


static func set_rating(r: String) -> void:
	ContentRating.set_rating(r)
	load("res://scripts/radio/dialogue_bank.gd").reload()  # picks up edits to dialogue/*.txt
	_cfg = null  # content_rating.gd wrote the file itself


# --- keys -----------------------------------------------------------------------

## Makes sure every game action exists (with its default keys), remembers the
## defaults, then swaps in any saved bindings.
static func apply_keys() -> void:
	load("res://scripts/player.gd").ensure_input_actions()
	load("res://scripts/run/run_manager.gd").ensure_input_actions()
	if not InputMap.has_action("ps2_toggle"):
		InputMap.add_action("ps2_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F9
		InputMap.action_add_event("ps2_toggle", ev)
	for pair in BINDABLE:
		var action: String = pair[0]
		if not _default_keys.has(action):
			_default_keys[action] = InputMap.action_get_events(action).duplicate()
	for pair in BINDABLE:
		var action: String = pair[0]
		if not cfg().has_section_key("keys", action):
			continue
		var saved = cfg().get_value("keys", action)
		if saved is Array:
			_set_events(action, saved.map(func(code): return decode(code)).filter(func(e): return e != null))


static func bindings(action: String) -> Array:
	return InputMap.action_get_events(action) if InputMap.has_action(action) else []


## Replaces binding `slot` (0 primary, 1 secondary: everything after the
## primary) of an action. A null event clears the secondary.
static func rebind(action: String, slot: int, event: InputEvent) -> void:
	var events: Array = bindings(action).duplicate()
	if slot == 0:
		if events.is_empty():
			events.append(event)
		elif event != null:
			events[0] = event
	else:
		events = events.slice(0, 1)
		if event != null:
			events.append(event)
	# A key used here comes off any other action it was on, so one press never does two things.
	if event != null:
		for pair in BINDABLE:
			var other: String = pair[0]
			if other == action:
				continue
			var kept := bindings(other).filter(func(e): return not _same(e, event))
			if kept.size() != bindings(other).size():
				_set_events(other, kept)
				_store(other)
	_set_events(action, events)
	_store(action)


static func reset_keys() -> void:
	for action in _default_keys:
		_set_events(action, _default_keys[action])
	if cfg().has_section("keys"):
		cfg().erase_section("keys")


static func _store(action: String) -> void:
	cfg().set_value("keys", action, bindings(action).map(func(e): return encode(e)).filter(func(s): return s != ""))


static func _set_events(action: String, events: Array) -> void:
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return encode(a) != "" and encode(a) == encode(b)


## "key:<physical keycode>" or "mouse:<button index>".
static func encode(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return "key:%d" % code
	if e is InputEventMouseButton:
		return "mouse:%d" % e.button_index
	return ""


static func decode(s: String) -> InputEvent:
	var parts := s.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null


## How a binding reads on screen: "W", "Space", "Right mouse".
static func event_name(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if DisplayServer.get_name() != "headless" else code)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		return "Mouse %d" % e.button_index
	return "?"
