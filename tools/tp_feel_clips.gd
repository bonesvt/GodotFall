extends SceneTree
## A short scripted fight in third person, to compare the feel presets
## (scripts/tp_feel.gd) as clips: turning on the spot, strafing and shooting,
## backpedalling, running and stopping to shoot, a jump, and taking hits.
##   godot --path . --fixed-fps 30 --write-movie out/fluid.avi -s res://tools/tp_feel_clips.gd -- --preset=fluid
## Needs a renderer (not --headless). A caption names the preset and the move.

var preset := "fluid"
var player
var weapon
var caption: Label


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preset="):
			preset = a.trim_prefix("--preset=")
	root.size = Vector2i(1280, 720)
	_go.call_deferred()


func _secs(t: float) -> void:
	for i in int(round(t * 30.0)):
		await process_frame


func _say(text: String) -> void:
	caption.text = "%s   ·   %s" % [preset.to_upper(), text]


func _shoot() -> void:
	weapon.ammo = maxi(weapon.ammo, 4)
	weapon.cooldown = 0.0
	weapon.fire()


## Turns her by `deg` over `t` seconds, easing in and out like a mouse flick.
func _turn(deg: float, t: float) -> void:
	var from: float = player.rotation.y
	var n := int(round(t * 30.0))
	for i in n:
		player.rotation.y = from + deg_to_rad(deg) * smoothstep(0.0, 1.0, float(i + 1) / n)
		await process_frame


## Holds a move for `t` seconds, shooting every `every` seconds (0 = no shots).
func _move(action: String, t: float, every := 0.0) -> void:
	if action != "":
		Input.action_press(action)
	var n := int(round(t * 30.0))
	var gap := int(round(every * 30.0)) if every > 0.0 else 0
	for i in n:
		if gap > 0 and i % gap == gap / 2:
			_shoot()
		await process_frame
	if action != "":
		Input.action_release(action)


func _go() -> void:
	var level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	await _secs(0.5)
	player = level.get_node("Player")
	weapon = player.get_node("Head/Camera3D/Weapon")
	var stance = player.get_node("EcoBody").stance
	stance.idle_twirl_after = 1000.0
	player.get_node("ViewCam").set_third_person(true)
	player.get_node("TpFeel").apply_preset(preset)
	# a clear patch of ground with a few targets to shoot at
	var at := Vector3(-55, 0.1, 45)
	for x in [-6.0, 0.0, 6.0]:
		level._box(at + Vector3(x, 1.0, -18), Vector3(1.2, 2.0, 1.2), Color(0.85, 0.25, 0.25))
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = deg_to_rad(-4.0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 660)
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(caption)
	_say("standing")
	await _secs(1.0)

	_say("small turn (feet planted), then a big turn")
	await _turn(35.0, 0.45)
	await _secs(0.7)
	await _turn(-110.0, 0.6)
	await _secs(0.9)
	await _turn(75.0, 0.4)
	await _secs(0.5)

	_say("strafe right and shoot")
	await _move("move_right", 1.4, 0.28)
	_say("strafe left and shoot")
	await _move("move_left", 1.4, 0.28)

	_say("backpedal and shoot")
	await _move("move_back", 1.5, 0.3)

	_say("run, stop, shoot")
	await _move("move_forward", 1.3)
	await _secs(0.15)
	await _move("", 0.8, 0.2)
	await _secs(0.5)

	_say("jump and land")
	Input.action_press("jump")
	await _secs(0.1)
	Input.action_release("jump")
	await _secs(1.4)

	_say("hit from the left, then the right")
	player.take_damage(12.0, player.global_position - player.global_basis.x * 6.0)
	await _secs(0.7)
	player.take_damage(12.0, player.global_position + player.global_basis.x * 6.0)
	await _secs(1.0)
	quit()
