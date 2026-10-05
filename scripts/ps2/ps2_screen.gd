extends CanvasLayer
## Autoload "PS2": switches the whole game between its three looks. F9 cycles
## Anime -> PS3 -> PS2.
##   Anime (default, Bones's pick 2026-10-04): the PS3 look's light and haze,
##     but the set is painted to match the toon-shaded characters (flat
##     colour, cel light, lavender shadows; ps2_surface anime_look) and a
##     screen pass adds painted backgrounds, ink lines and a late-90s anime
##     finish with film grain (anime_post.gdshader on a quad that rides the
##     current camera). Grain strength is a setting (Settings > Video).
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
const Prefs := preload("res://scripts/game/prefs.gd")
const ANIME_POST := preload("res://assets/shaders/anime_post.gdshader")
const PS2_RENDER_SCALE := 0.5
const LOOKS := ["anime", "ps3", "ps2"]
## Film grain at the slider's full strength (Prefs video/film_grain 0..1).
const MAX_GRAIN := 0.06

## true = PS2 look, false = PS3 or Anime look.
var enabled := false
## true = Anime look (only while the PS2 look is off).
var anime := true
var _rect: ColorRect
var _snap := 0.0
var _post: MeshInstance3D
var _grain := 0.4


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
	_post = _make_post()
	_snap = float(ProjectSettings.get_setting("shader_globals/ps2_vertex_snap", {}).get("value", 0.0))
	if not InputMap.has_action("ps2_toggle"):
		InputMap.add_action("ps2_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F9
		InputMap.action_add_event("ps2_toggle", ev)
	set_enabled(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ps2_toggle"):
		set_look(LOOKS[(LOOKS.find(look()) + 1) % LOOKS.size()])
		Prefs.remember_look(look())


## "anime", "ps3" or "ps2".
func look() -> String:
	return "ps2" if enabled else ("anime" if anime else "ps3")


func set_look(name: String) -> void:
	anime = name == "anime"
	set_enabled(name == "ps2")


## Film grain, 0 (off) to 1 (strongest).
func set_grain(amount: float) -> void:
	_grain = clampf(amount, 0.0, 1.0)
	if not is_instance_valid(_post):
		_post = _make_post()
	(_post.material_override as ShaderMaterial).set_shader_parameter("grain", _grain * MAX_GRAIN)


func _make_post() -> MeshInstance3D:
	var post := MeshInstance3D.new()
	post.name = "AnimePost"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	post.mesh = quad
	post.extra_cull_margin = 16384.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var pm := ShaderMaterial.new()
	pm.shader = ANIME_POST
	# It reads the opaque scene's screen copy, so it must draw before every other
	# transparent (labels, smoke, glass, hair) or it paints over them.
	pm.render_priority = Material.RENDER_PRIORITY_MIN
	pm.set_shader_parameter("grain", _grain * MAX_GRAIN)
	post.material_override = pm
	return post


## Keeps the Anime screen pass on whatever camera is drawing.
func _process(_delta: float) -> void:
	if not is_instance_valid(_post):
		_post = _make_post()  # it went with a camera that was freed
	var on := anime and not enabled
	var cam := get_viewport().get_camera_3d() if on else null
	if _post.get_parent() != cam:
		if _post.get_parent() != null:
			_post.get_parent().remove_child(_post)
		if cam != null:
			cam.add_child(_post)


func set_enabled(on: bool) -> void:
	enabled = on
	(_rect.material as ShaderMaterial).set_shader_parameter("ps2", on)
	get_viewport().scaling_3d_scale = PS2_RENDER_SCALE if on else 1.0
	RenderingServer.global_shader_parameter_set("ps2_vertex_snap", _snap if on else 0.0)
	RenderingServer.global_shader_parameter_set("ps3_look", 0.0 if on else 1.0)
	var a := anime and not on
	RenderingServer.global_shader_parameter_set("anime_look", 1.0 if a else 0.0)
	# The Anime pass brings its own vignette and grain.
	_rect.visible = not a
	if not is_instance_valid(_post):
		_post = _make_post()
	if not a and _post.get_parent() != null:
		_post.get_parent().remove_child(_post)
	if not is_inside_tree():
		return
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if (node as WorldEnvironment).environment != null:
			Look.apply_env((node as WorldEnvironment).environment, not on, a)
	for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		Look.apply_sun(node as DirectionalLight3D, not on)


func _exit_tree() -> void:
	if is_instance_valid(_post) and _post.get_parent() == null:
		_post.free()
