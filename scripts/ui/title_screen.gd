extends Node3D
## The title screen (scenes/title.tscn, the game's main scene). Eco stands on
## the steps of her temple while the camera drifts past; the menu sits on the
## left:
##   Continue    the last save slot played, straight into the temple
##   New game    pick a slot (asks before writing over one)
##   Load game   pick a slot
##   Settings    settings_menu.gd
##   Quit
## Picking a slot points every save file at it (saves.gd) and loads
## scenes/run.tscn.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const Saves := preload("res://scripts/game/saves.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

const GAME_SCENE := "res://scenes/run.tscn"
## The camera's slow drift in front of the temple: from, to, what it looks at.
## It stays between the porch posts (x +-3.4) so they frame the door rather
## than sweeping across Eco.
const CAM_FROM := Vector3(-2.2, 2.4, 18.5)
const CAM_TO := Vector3(2.4, 3.0, 17.5)
const CAM_LOOK := Vector3(0.3, 2.6, 8.5)
const DRIFT_SECONDS := 40.0
## Where Eco stands: on the top step in front of the door, facing out.
const ECO_AT := Vector3(0.6, 1.2, 9.3)

## Skip the 3D backdrop (headless tests).
@export var backdrop := true

var ui: Control
var cam: Camera3D
var main_menu: VBoxContainer
var slot_page: VBoxContainer
var slot_list: VBoxContainer
var slot_title: Label
var confirm: PanelContainer
var confirm_label: Label
var continue_button: Button
var load_button: Button
## "new" or "load" while the slot page is up.
var slot_mode := ""
var _confirm_slot := 0
var _settings: Control
var _t := 0.0


func _ready() -> void:
	get_tree().paused = false
	Prefs.apply_all()
	Saves.active = 0
	Saves.migrate_legacy()
	if backdrop:
		_build_backdrop()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.theme = UI.theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


func _process(delta: float) -> void:
	if cam == null:
		return
	_t += delta
	var k := 0.5 - 0.5 * cos(_t / DRIFT_SECONDS * TAU)
	cam.position = CAM_FROM.lerp(CAM_TO, k)
	cam.look_at(CAM_LOOK)


func _input(event: InputEvent) -> void:
	if not UI.is_back(event):
		return
	if _settings != null:
		if is_instance_valid(_settings) and not _settings._waiting.is_empty():
			return  # it's binding a key; Esc cancels that there
		_settings.close()
	elif confirm.visible:
		confirm.visible = false
	elif slot_page.visible:
		_show_main()
	get_viewport().set_input_as_handled()


# --- backdrop -------------------------------------------------------------------

func _build_backdrop() -> void:
	var world := Node3D.new()
	world.name = "Temple"
	add_child(world)
	HubBuilder.build(world)
	var eco := Art.model("eco")
	eco.position = ECO_AT
	eco.rotation.y = deg_to_rad(200.0)
	world.add_child(eco)
	var anim := eco.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		for name in ["idle", "Idle", "stand"]:
			if anim.has_animation(name):
				anim.play(name)
				break
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	cam.position = CAM_FROM
	cam.look_at(CAM_LOOK)


# --- menus ----------------------------------------------------------------------

func _build_ui() -> void:
	# A dark fade behind the menu so it reads over the scene.
	var fade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.82))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	fade.texture = tex
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.anchor_bottom = 1.0
	fade.anchor_right = 0.6
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 70)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	col.add_child(UI.heading("GODOTFALL", 92))
	var tag := UI.label("SCRAP TITAN", 26, UI.TEXT)
	tag.add_theme_constant_override("outline_size", 0)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 60
	col.add_child(gap)

	main_menu = VBoxContainer.new()
	main_menu.custom_minimum_size.x = 420
	main_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_menu.add_theme_constant_override("separation", 6)
	col.add_child(main_menu)
	continue_button = UI.button("Continue", continue_game)
	main_menu.add_child(continue_button)
	main_menu.add_child(UI.button("New game", func(): _show_slots("new")))
	load_button = UI.button("Load game", func(): _show_slots("load"))
	main_menu.add_child(load_button)
	main_menu.add_child(UI.button("Settings", open_settings))
	main_menu.add_child(UI.button("Quit", func(): get_tree().quit()))

	slot_page = VBoxContainer.new()
	slot_page.custom_minimum_size.x = 620
	slot_page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot_page.add_theme_constant_override("separation", 10)
	col.add_child(slot_page)
	slot_title = UI.heading("NEW GAME", 32)
	slot_page.add_child(slot_title)
	slot_list = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 8)
	slot_page.add_child(slot_list)
	slot_page.add_child(UI.button("Back", _show_main))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var hint := UI.label("Esc pauses in game.  F1 hints  ·  F5 camera  ·  F9 change look", 18, UI.MUTED)
	col.add_child(hint)

	# Overwrite check for New game on a used slot.
	confirm = PanelContainer.new()
	confirm.set_anchors_preset(Control.PRESET_CENTER)
	confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm.custom_minimum_size = Vector2(560, 0)
	ui.add_child(confirm)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 14)
	confirm.add_child(cbox)
	confirm_label = UI.label("", 22)
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cbox.add_child(confirm_label)
	var row := HBoxContainer.new()
	row.add_child(UI.button("Start over", func(): _start_slot(_confirm_slot, true)))
	row.add_child(UI.button("Cancel", func(): confirm.visible = false))
	cbox.add_child(row)
	confirm.visible = false


func _show_main() -> void:
	slot_page.visible = false
	confirm.visible = false
	main_menu.visible = true
	var has_save := Saves.last_slot() != 0
	continue_button.visible = has_save
	load_button.visible = has_save
	UI.focus(continue_button if has_save else main_menu.get_child(1) as Button)


func _show_slots(mode: String) -> void:
	slot_mode = mode
	slot_title.text = "NEW GAME: PICK A SLOT" if mode == "new" else "LOAD GAME"
	for c in slot_list.get_children():
		c.queue_free()
	var first: Button = null
	for n in range(1, Saves.SLOTS + 1):
		var info := Saves.info(n)
		var text := "Slot %d    " % n
		if info.is_empty():
			text += "Empty"
		else:
			text += "Pilot level %d  ·  %d run%s, %d won  ·  %s played  ·  %s" % [
				info["level"], info["runs"], "" if info["runs"] == 1 else "s", info["wins"],
				Saves.play_time_text(info["seconds"]), _date(info["last_played"])]
		var b := UI.button(text, _pick_slot.bind(n))
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = mode == "load" and info.is_empty()
		slot_list.add_child(b)
		if first == null and not b.disabled:
			first = b
	main_menu.visible = false
	slot_page.visible = true
	if first != null:
		UI.focus(first)


func _pick_slot(n: int) -> void:
	if slot_mode == "new" and Saves.exists(n):
		_confirm_slot = n
		confirm_label.text = "Slot %d already has a game in it. Start over and lose it?" % n
		confirm.visible = true
		UI.focus(confirm.get_child(0).get_child(1).get_child(1) as Button)
		return
	_start_slot(n, slot_mode == "new")


func continue_game() -> void:
	var n := Saves.last_slot()
	if n != 0:
		_start_slot(n, false)


func _start_slot(n: int, fresh: bool) -> void:
	if fresh:
		Saves.new_game(n)
	Saves.use(n)
	get_tree().change_scene_to_file(GAME_SCENE)


func open_settings() -> void:
	main_menu.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(func() -> void:
		_settings = null
		_show_main())
	ui.add_child(_settings)


static func _date(unix: int) -> String:
	if unix <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %02d:%02d" % [d["day"], MONTHS[d["month"] - 1], d["hour"], d["minute"]]
