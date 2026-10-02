extends CanvasLayer
## Run HUD: run status, titan build, prompts, the salvage choice and the summary.
## The run manager writes the text; this only lays it out.

var status_label: Label
var build_label: Label
var prompt_label: Label
var toast_label: Label
var fight_label: Label
var crosshair: Label
var choice_panel: PanelContainer
var choice_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var _toast_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status_label = _label(20)
	status_label.position = Vector2(20, 150)

	build_label = _label(18)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_label.offset_left = -520
	build_label.offset_right = -20
	build_label.offset_top = 20

	prompt_label = _centered(26, 60)
	toast_label = _centered(30, -220)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fight_label = _centered(24, -170)
	fight_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fight_label.offset_left = -500
	fight_label.offset_right = 500
	fight_label.offset_top = -200

	crosshair = _centered(28, 0)
	crosshair.text = "+"
	crosshair.visible = false

	choice_label = Label.new()
	choice_label.add_theme_font_size_override("font_size", 22)
	choice_panel = _panel(choice_label)
	summary_label = Label.new()
	summary_label.add_theme_font_size_override("font_size", 26)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_panel = _panel(summary_label)


func toast(text: String, seconds := 2.5) -> void:
	toast_label.text = text
	_toast_time = seconds


func _process(delta: float) -> void:
	_toast_time -= delta
	toast_label.visible = _toast_time > 0.0


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _centered(size: int, y: float) -> Label:
	var l := _label(size)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_left = -500
	l.offset_right = 500
	l.offset_top = y - 20
	l.offset_bottom = y + 20
	return l


func _panel(content: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	style.border_color = Color(1.0, 0.75, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	add_child(panel)
	return panel
