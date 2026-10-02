extends CanvasLayer
## Minimal HUD: crosshair, speedometer, movement state, ability readouts.

var player: Node
var speed_label: Label
var info_label: Label
var help_label: Label

const HELP := """WASD  move (auto-sprint forward)
Space  jump / double jump / wall jump
C or Ctrl  crouch, slide when running
Q, E or right mouse  grapple (hold)
R  respawn    H  hide help    Esc  free mouse"""


func _ready() -> void:
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(crosshair)

	speed_label = _label(40)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.offset_top = -120
	speed_label.offset_left = -200
	speed_label.offset_right = 200

	info_label = _label(20)
	info_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.offset_top = -60
	info_label.offset_left = -300
	info_label.offset_right = 300

	help_label = _label(18)
	help_label.position = Vector2(20, 20)
	help_label.text = HELP


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		help_label.visible = not help_label.visible


func _process(_delta: float) -> void:
	if player == null:
		return
	speed_label.text = "%.1f m/s" % player.horizontal_speed()
	var grapple := "READY" if player.grapple_ready_in() <= 0.0 else "%.1fs" % player.grapple_ready_in()
	info_label.text = "%s    double jump: %s    grapple: %s" % [
		player.state_name(),
		"READY" if player.air_jumps_left > 0 else "used",
		grapple,
	]
