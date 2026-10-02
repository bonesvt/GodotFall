extends CanvasLayer
## Autoload "PS2": draws the full-screen PS2 filter (16-bit colour, dithering,
## interlace lines) under every HUD. F9 toggles the whole PS2 look on and off
## (filter, low internal resolution and vertex wobble) for comparison.

const SCREEN_SHADER := preload("res://assets/shaders/ps2_screen.gdshader")
const RENDER_SCALE := 0.5

var enabled := true
var _rect: ColorRect
var _snap := 0.0


func _ready() -> void:
	layer = -1  # after the 3D view, before any HUD layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	_rect.material = mat
	add_child(_rect)
	_snap = float(ProjectSettings.get_setting("shader_globals/ps2_vertex_snap", {}).get("value", 0.0))
	if not InputMap.has_action("ps2_toggle"):
		InputMap.add_action("ps2_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F9
		InputMap.action_add_event("ps2_toggle", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ps2_toggle"):
		set_enabled(not enabled)


func set_enabled(on: bool) -> void:
	enabled = on
	_rect.visible = on
	get_viewport().scaling_3d_scale = RENDER_SCALE if on else 1.0
	RenderingServer.global_shader_parameter_set("ps2_vertex_snap", _snap if on else 0.0)
