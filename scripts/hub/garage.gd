extends CanvasLayer
## Eco's paint shop in the hub: pick a chassis, then its paint job, colours,
## lamps and small part tweaks (titan_style.gd), on a turntable preview.
## Every change is saved at once; titan.gd paints every titan you drop with it.
## The run manager opens it (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down    pick a row        A/D or Left/Right    change it
##   Q/E               switch chassis    drag the preview     turn the titan

signal chassis_changed(chassis: String)

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")

## The weapon each chassis holds in the preview.
const PREVIEW_WEAPON := {"atlas": "xo16", "ogre": "tracker", "stryder": "splitter", "scrap": "scrap"}
const INK := Color(0.98, 0.94, 0.86)
const ACCENT := Color(1.0, 0.62, 0.78)
const SPIN_SPEED := 0.35

var chassis := "atlas"
var style := {}
var selected := 0
var preview: Node3D

var _chassis_label: Label
var _rows: Array[Dictionary] = []
var _turntable: Node3D
var _spin_hold := 0.0


func _init(start_chassis := "atlas") -> void:
	if start_chassis in TitanStyle.CHASSIS:
		chassis = start_chassis
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.06, 0.55)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 600
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.09, 0.13, 0.94), 18, 26))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	screen.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)

	var title := _text("ECO'S PAINT SHOP", 30, ACCENT)
	list.add_child(title)
	list.add_child(_text("Make it yours. Changes save as you go.", 16, INK.darkened(0.3)))
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 10)
	pick.alignment = BoxContainer.ALIGNMENT_CENTER
	pick.add_child(_arrow("Q", func(): switch_chassis(-1)))
	_chassis_label = _text("", 28, INK)
	_chassis_label.custom_minimum_size = Vector2(240, 0)
	_chassis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_child(_chassis_label)
	pick.add_child(_arrow("E", func(): switch_chassis(1)))
	list.add_child(pick)

	for i in TitanStyle.OPTIONS.size():
		list.add_child(_row(i))
	list.add_child(_text("W/S pick   A/D change   Q/E chassis   F or Esc done", 15, INK.darkened(0.35)))
	_load_chassis()


func _process(delta: float) -> void:
	_spin_hold -= delta
	if _spin_hold <= 0.0:
		_turntable.rotate_y(delta * SPIN_SPEED)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_A, KEY_LEFT:
			change(-1)
		KEY_D, KEY_RIGHT:
			change(1)
		KEY_Q:
			if not event.echo:
				switch_chassis(-1)
		KEY_E:
			if not event.echo:
				switch_chassis(1)
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = posmod(index, _rows.size())
	_refresh_rows()


## Steps the selected row (or `key`) and saves.
func change(dir: int, key := "") -> void:
	if key == "":
		key = TitanStyle.OPTIONS[selected]["key"]
	TitanStyle.step(style, key, dir)
	TitanStyle.save_style(chassis, style)
	_refresh_rows()
	_rebuild_preview()


func switch_chassis(dir: int) -> void:
	var all := TitanStyle.CHASSIS
	chassis = all[posmod(all.find(chassis) + dir, all.size())]
	_load_chassis()
	chassis_changed.emit(chassis)


func _load_chassis() -> void:
	style = TitanStyle.load_style(chassis)
	_chassis_label.text = chassis.to_upper()
	_refresh_rows()
	_rebuild_preview()


func _rebuild_preview() -> void:
	if preview != null:
		preview.free()
	preview = Art.titan(chassis, PREVIEW_WEAPON[chassis])
	TitanStyle.apply(preview, chassis, style)
	_turntable.add_child(preview)


func _refresh_rows() -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var key: String = row["key"]
		var value: String = style[key]
		if value == "":
			value = "paint job"
		elif key == "stripe" and value == "none":
			value = "body colour"
		row["value"].text = value
		var color = TitanStyle.swatch(chassis, style, key)
		# Rows with no colour keep an empty swatch so the arrows line up.
		row["swatch"].color = color if color != null else Color(0, 0, 0, 0)
		var on := i == selected
		row["panel"].add_theme_stylebox_override("panel", _box(Color(1.0, 0.62, 0.78, 0.22) if on else Color(0, 0, 0, 0), 10, 6))
		row["label"].add_theme_color_override("font_color", ACCENT if on else INK)


# --- building the screen ----------------------------------------------------------

func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.3, 0.4, 0.62), Color(0.86, 0.74, 0.72))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	# A paint-shop floor: a round pad under the titan.
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 6.0
	floor_mesh.bottom_radius = 6.2
	floor_mesh.height = 0.3
	var pad := MeshInstance3D.new()
	pad.mesh = floor_mesh
	pad.position.y = -0.15
	pad.material_override = Art.MATERIALS["concrete"]
	stage.add_child(pad)
	_turntable = Node3D.new()
	_turntable.rotation.y = 0.5
	stage.add_child(_turntable)
	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(-6.0, 5.4, -12.5)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 3.9, 0))
	return sub


func _row(index: int) -> PanelContainer:
	var option: Dictionary = TitanStyle.OPTIONS[index]
	var panel := PanelContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var label := _text(option["label"], 19, INK)
	label.custom_minimum_size = Vector2(200, 0)
	line.add_child(label)
	line.add_child(_arrow("<", _pick.bind(index, -1)))
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(swatch)
	var value := _text("", 19, INK)
	value.custom_minimum_size = Vector2(170, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(value)
	line.add_child(_arrow(">", _pick.bind(index, 1)))
	panel.gui_input.connect(_on_row_input.bind(index))
	_rows.append({"key": option["key"], "panel": panel, "label": label, "value": value, "swatch": swatch})
	return panel


func _arrow(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 32)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.08), 8, 4))
	b.add_theme_stylebox_override("hover", _box(Color(1.0, 0.62, 0.78, 0.35), 8, 4))
	b.add_theme_stylebox_override("pressed", _box(Color(1.0, 0.62, 0.78, 0.55), 8, 4))
	b.pressed.connect(pressed)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box


func _pick(index: int, dir: int) -> void:
	select(index)
	change(dir)


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		select(index)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(event.relative.x * 0.01)
		_spin_hold = 3.0
