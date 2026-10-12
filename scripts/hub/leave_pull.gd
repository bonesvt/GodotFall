extends CanvasLayer
## Leaving Marrow's storeroom (hush_den.gd STORE_*): she locked herself back in
## and the key's in her hand. Hold [F] to leave: her hand turns the key while
## the Hush in her drags her view down to the violet glow under the door, a
## violet dark closing in from the edges. Let go and it slips back. Deep in his
## pull (Hush Hold from STORE_CANT_FROM) she can't finish: it stops short at
## CANT_REACH, and Marrow speaks through the door; once he's gone back up the
## stairs she can. The run manager opens it on the door's spot and lets her out
## when done().

const Vices := preload("res://scripts/hub/vices.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")

## Seconds of holding to turn the key, how fast it slips back, and how far it
## gets deep in his pull.
const HOLD_TIME := 3.5
const SLIP := 0.6
const CANT_REACH := 0.8
const VIGNETTE := "shader_type canvas_item;
uniform float pull = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.62);
	float d = length(p * vec2(1.6, 1.0));
	float edge = smoothstep(0.75 - 0.55 * pull, 0.15, d);
	COLOR = vec4(0.12, 0.02, 0.2, (1.0 - edge) * (0.25 + 0.65 * pull));
}"

var rm: Node
var progress := 0.0
var finished := false
## Deep in his pull, and he hasn't spoken through the door yet.
var blocked := false
var _spoke := false
var _look_from := Vector2.ZERO
var _rect: ColorRect
var _label: Label
var _bar: ColorRect


func _init(run_manager: Node) -> void:
	rm = run_manager
	layer = 4
	name = "LeavePull"
	blocked = Vices.hold >= HushDen.STORE_CANT_FROM


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE
	var m := ShaderMaterial.new()
	m.shader = sh
	_rect.material = m
	add_child(_rect)
	_label = Label.new()
	_label.text = "Hold [F] to leave"
	_label.add_theme_font_size_override("font_size", 26)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position.y -= 150
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Color(0.85, 0.75, 1.0, 0.85)
	_bar.size = Vector2(0, 6)
	add_child(_bar)
	var p: Node = rm.player
	_look_from = Vector2(p.rotation.y, p.head.rotation.x)
	p.set("entranced", true)
	p.set("trance_dir", Vector3.ZERO)


func _process(delta: float) -> void:
	if finished:
		return
	var holding := Input.is_action_pressed("interact")
	var reach := CANT_REACH if blocked else 1.0
	if holding:
		progress = minf(progress + delta / HOLD_TIME, reach)
	else:
		progress = maxf(progress - delta * SLIP, 0.0)
	# the Hush drags her view down to the glow under the door, harder the
	# further she gets and the deeper his Hold
	var pull := clampf(progress * (0.6 + Vices.hold / 100.0 * 0.6), 0.0, 1.0)
	_aim(pull, delta)
	(_rect.material as ShaderMaterial).set_shader_parameter("pull", pull)
	var w := get_viewport().get_visible_rect().size
	_bar.size = Vector2(320.0 * progress, 6)
	_bar.position = Vector2(w.x * 0.5 - 160.0, w.y - 120.0)
	if blocked and progress >= reach - 0.001 and holding and not _spoke:
		_spoke = true
		rm.hud.toast(HushDen.STORE_THROUGH_DOOR, 6.0)
		get_tree().create_timer(HushDen.STORE_HE_GOES).timeout.connect(_he_goes)
	if progress >= 1.0:
		finished = true
		var p: Node = rm.player
		p.set("entranced", false)
		rm.store_left()
		queue_free()


## Looks her down toward the glow under the door, `pull` of the way.
func _aim(pull: float, _delta: float) -> void:
	var p: Node = rm.player
	var glow := HushDen.STORE_DOOR_OUT + Vector3(0.3, 0.0, 0.0)
	var to := glow - (p.head as Node3D).global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	# set outright each frame: her trance (player.gd) would level her eyes
	p.rotation.y = lerp_angle(_look_from.x, yaw, pull)
	p.head.rotation.x = lerpf(_look_from.y, pitch, pull)


## He's gone back up the stairs: now she can finish.
func _he_goes() -> void:
	if finished:
		return
	blocked = false
	rm.hud.toast(HushDen.STORE_HE_LEAVES, 4.0)


## Stops it without her leaving (the hub was left under it, say).
func cancel() -> void:
	finished = true
	rm.player.set("entranced", false)
	queue_free()
