extends CanvasLayer
## Autoload "PS2": switches the whole game between its two looks. F9 toggles.
##   PS3 (default): full resolution, high-res normal-mapped textures, GGX
##     highlights, sky reflections, SSAO, soft 4-split sun shadows, volumetric
##     haze and a gentle vignette.
##   PS2: the old look: half internal resolution, blurry textures, banded
##     lighting, 16-bit colour with dithering and interlace lines, and vertex
##     wobble if it is set in Project Settings > Shader Globals.
## Levels build their sky and light with ps2_assets.gd environment(), which
## applies the current look (look.gd); toggling re-applies it to every
## WorldEnvironment and sun in the tree.

const SCREEN_SHADER := preload("res://assets/shaders/ps2_screen.gdshader")
const Look := preload("res://scripts/ps2/look.gd")
const PS2_RENDER_SCALE := 0.5

## true = PS2 look, false = PS3 look.
var enabled := false
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
	set_enabled(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ps2_toggle"):
		set_enabled(not enabled)


func set_enabled(on: bool) -> void:
	enabled = on
	(_rect.material as ShaderMaterial).set_shader_parameter("ps2", on)
	get_viewport().scaling_3d_scale = PS2_RENDER_SCALE if on else 1.0
	RenderingServer.global_shader_parameter_set("ps2_vertex_snap", _snap if on else 0.0)
	RenderingServer.global_shader_parameter_set("ps3_look", 0.0 if on else 1.0)
	if not is_inside_tree():
		return
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if (node as WorldEnvironment).environment != null:
			Look.apply_env((node as WorldEnvironment).environment, not on)
	for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		Look.apply_sun(node as DirectionalLight3D, not on)
