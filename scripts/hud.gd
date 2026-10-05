extends CanvasLayer
## HUD: spread-aware crosshair with hitmarkers, speedometer, movement state,
## ability readouts, health, ammo, the grunt count, and stealth markers around
## the crosshair pointing at every grunt that is noticing the pilot.
## The reticle wears the pistol's story: around the spread ticks sits the
## ring of the old smart-lock, half its segments dead, flickering when the
## module glitches, and it still brackets enemies before failing to lock.
## Also hosts the enemy radio chatter popup and Eco's whispers (scripts/radio/).

const RadioChatter := preload("res://scripts/radio/radio_chatter.gd")
const EcoWhispers := preload("res://scripts/radio/eco_whispers.gd")

var player: Node
var level: Node
var weapon: Node
var crosshair: Control
var speed_label: Label
var info_label: Label
var help_label: Label
var ammo_label: Label
var health_label: Label
var enemy_label: Label
var message_label: Label
var hurt_rect: ColorRect
var radio: Node
var whispers: Node

var hitmarker_timer := 0.0
var hitmarker_color := Color.WHITE
var hitmarker_kind := "body"
var hurt_flash := 0.0
var message_timer := 0.0

const HITMARKER_TIME := 0.18
const HELP := """WASD  move (auto-sprint forward)
Space  jump / double jump / wall jump
C or Ctrl  crouch, slide when running
Q, E or right mouse  grapple (hold)
Left mouse  shoot    R  reload    I  inspect
Z or mouse thumb  knife (kills unaware grunts)
T  respawn    G  reset grunt arena
H  hide help    Middle mouse  1st / 3rd person    F1  tutorial hints    Esc  free mouse"""


func _ready() -> void:
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	add_child(hurt_rect)

	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
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

	ammo_label = _label(36)
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.offset_left = -300
	ammo_label.offset_top = -80
	ammo_label.offset_right = -30

	health_label = _label(36)
	health_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.offset_left = 30
	health_label.offset_top = -80
	health_label.offset_right = 640

	enemy_label = _label(22)
	enemy_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_label.offset_left = -300
	enemy_label.offset_right = -20
	enemy_label.offset_top = 20

	message_label = _label(30)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.offset_left = -400
	message_label.offset_right = 400
	message_label.offset_top = 140

	help_label = _label(18)
	help_label.position = Vector2(20, 20)
	help_label.text = HELP

	if player != null:
		weapon = player.get_node_or_null("Head/Camera3D/Weapon")
		if weapon != null:
			weapon.hit_confirmed.connect(_on_hit)
			weapon.inspected.connect(func(line: String): flash_message(line, 3.0))
		player.damaged.connect(_on_damaged)
		player.second_winded.connect(func(): flash_message("SECOND WIND", 1.5))
		radio = RadioChatter.new()
		radio.name = "Radio"
		radio.player = player
		add_child(radio)
		whispers = EcoWhispers.new()
		whispers.name = "Whispers"
		whispers.player = player
		whispers.weapon = weapon
		whispers.knife = player.get_node_or_null("Head/Camera3D/Knife")
		whispers.radio = radio
		add_child(whispers)


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


func flash_message(text: String, seconds := 2.0) -> void:
	message_label.text = text
	message_timer = seconds


func _on_hit(kind: String) -> void:
	hitmarker_timer = HITMARKER_TIME
	hitmarker_kind = kind
	match kind:
		"head":
			hitmarker_color = Color(1.0, 0.75, 0.1)
		"kill":
			hitmarker_color = Color(1.0, 0.2, 0.15)
			hitmarker_timer = HITMARKER_TIME * 2.0
		_:
			hitmarker_color = Color.WHITE


func _on_damaged(_amount: float, _from: Vector3) -> void:
	hurt_flash = 0.35


func _process(delta: float) -> void:
	if player == null:
		return
	hitmarker_timer -= delta
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	message_timer -= delta
	message_label.visible = message_timer > 0.0

	speed_label.text = "%.1f m/s" % player.horizontal_speed()
	var grapple := "READY" if player.grapple_ready_in() <= 0.0 else "%.1fs" % player.grapple_ready_in()
	info_label.text = "%s    double jump: %s    grapple: %s" % [
		player.state_name(),
		"READY" if player.air_jumps_left > 0 else "used",
		grapple,
	]

	var hp_frac: float = player.health / player.max_health
	health_label.text = "HP %d" % ceili(player.health)
	if player.max_armor > 0.0:
		health_label.text += "   ARMOUR %d" % ceili(player.armor)
	health_label.add_theme_color_override("font_color", Color.WHITE.lerp(Color(1, 0.25, 0.2), 1.0 - hp_frac))
	hurt_rect.color.a = (1.0 - hp_frac) * 0.3 + hurt_flash * 0.5

	if weapon != null:
		ammo_label.text = "RELOADING" if weapon.is_reloading() else "%d / %d" % [weapon.ammo, weapon.magazine_size]
	if level != null:
		enemy_label.text = "Grunts left: %d" % level.grunts_alive()
	# no crosshair under the hub/town orbit camera: it isn't aiming, it's looking at her
	var view := player.get_node_or_null("ViewCam")
	crosshair.visible = view == null or not view.orbiting
	crosshair.queue_redraw()


func _draw_crosshair() -> void:
	var center := crosshair.size * 0.5
	var gap := 4.0
	if weapon != null:
		# Gap matches the real spread cone on screen.
		var cam: Camera3D = player.camera
		var half_fov := deg_to_rad(cam.fov) * 0.5
		gap = maxf(tan(deg_to_rad(weapon.current_spread())) / tan(half_fov) * center.y, 3.0)
	var length := 8.0
	var col := Color(1, 1, 1, 0.9)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		crosshair.draw_line(center + d * gap, center + d * (gap + length), Color.BLACK, 4.0)
		crosshair.draw_line(center + d * gap, center + d * (gap + length), col, 2.0)
	crosshair.draw_circle(center, 1.5, col)

	if weapon != null:
		_draw_dead_lock_ring(center, gap)
		_draw_lock_attempt()
		_draw_ammo_pips()
	_draw_detection(center)

	if hitmarker_timer > 0.0:
		var c := hitmarker_color
		var k := clampf(hitmarker_timer / HITMARKER_TIME, 0.0, 1.0)
		c.a = k
		# Pops out big and settles; heads and kills hit harder.
		var pop := 1.0 + k * k * (0.6 if hitmarker_kind != "body" else 0.3)
		var inner := 7.0 * pop
		var outer := (15.0 if hitmarker_kind == "body" else 19.0) * pop
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			crosshair.draw_line(center + d * inner, center + d * outer, Color(0, 0, 0, c.a * 0.8), 5.0)
			crosshair.draw_line(center + d * inner, center + d * outer, c, 3.0)
		if hitmarker_kind == "kill":
			crosshair.draw_arc(center, 26.0 + (1.0 - k) * 30.0, 0.0, TAU, 32, Color(c, k * 0.8), 2.0)


## The smart pistol's old lock ring. Some segments are dead for good; the rest
## flicker out whenever the module glitches.
func _draw_dead_lock_ring(center: Vector2, gap: float) -> void:
	const SEGMENTS := 12
	const DEAD := [1, 4, 5, 9]
	var radius := gap + 18.0
	var g: float = weapon.glitch
	var jitter := Vector2(randf_range(-2, 2), randf_range(-1, 1)) * g
	for i in SEGMENTS:
		if i in DEAD:
			continue
		if g > 0.2 and randf() < g * 0.5:
			continue
		var a0 := TAU * i / SEGMENTS + 0.08
		var a1 := TAU * (i + 1) / SEGMENTS - 0.08
		var c := Color(0.45, 0.85, 1.0, 0.45 + g * 0.4)
		crosshair.draw_arc(center + jitter, radius, a0, a1, 4, Color(0, 0, 0, c.a * 0.5), 3.5)
		crosshair.draw_arc(center + jitter, radius, a0, a1, 4, c, 1.5)


## When the crosshair sits on an enemy the module brackets it, the brackets
## jitter and fail to close, and it throws a LOCK ERR.
func _draw_lock_attempt() -> void:
	var t = weapon.lock_target
	if not is_instance_valid(t):
		return
	var cam: Camera3D = player.camera
	var at: Vector3 = t.global_position + Vector3.UP * 1.0
	if cam.is_position_behind(at):
		return
	var p: Vector2 = cam.unproject_position(at)
	var lt: float = weapon.lock_time
	if weapon.smart_ready():
		_draw_smart_lock(p, weapon.lock_progress())
		return
	# Brackets close in for a moment, then spring back open as the lock fails.
	var close := clampf(lt / 0.35, 0.0, 1.0)
	var fail := clampf((lt - 0.35) / 0.15, 0.0, 1.0)
	var size := lerpf(60.0, 26.0, close) + fail * 14.0 + randf_range(-2, 2) * (1.0 + fail * 2.0)
	var blink := fail < 1.0 or fmod(lt, 0.5) < 0.3
	if not blink:
		return
	var c := Color(0.45, 0.85, 1.0, 0.8).lerp(Color(1.0, 0.25, 0.2, 0.85), fail)
	var arm := 9.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var k: Vector2 = p + corner * size * 0.5
		crosshair.draw_line(k, k - Vector2(corner.x * arm, 0), c, 2.0)
		crosshair.draw_line(k, k - Vector2(0, corner.y * arm), c, 2.0)
	if fail > 0.0:
		var font := ThemeDB.fallback_font
		crosshair.draw_string(font, p + Vector2(-size * 0.5, size * 0.5 + 16), "LOCK ERR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)


## A smart round is chambered and the lock works: the brackets close, turn
## pink and lock solid, with a diamond on the target.
func _draw_smart_lock(p: Vector2, close: float) -> void:
	var locked := close >= 1.0
	var size := lerpf(64.0, 30.0, close * close)
	var c := Color(0.45, 0.85, 1.0, 0.85).lerp(Color(1.0, 0.45, 0.75, 1.0), 1.0 if locked else close * 0.5)
	var arm := 10.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var k: Vector2 = p + corner * size * 0.5
		for w in [[4.0, Color(0, 0, 0, 0.5)], [2.0, c]]:
			crosshair.draw_line(k, k - Vector2(corner.x * arm, 0), w[1], w[0])
			crosshair.draw_line(k, k - Vector2(0, corner.y * arm), w[1], w[0])
	if locked:
		var d := 6.0
		crosshair.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), c)
		var font := ThemeDB.fallback_font
		crosshair.draw_string(font, p + Vector2(-size * 0.5, size * 0.5 + 16), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)


## One pip per round above the ammo counter; the last round glows red. Smart
## rounds (the top of the mag, fired first) are pink.
func _draw_ammo_pips() -> void:
	var n: int = weapon.magazine_size
	var right := Vector2(crosshair.size.x - 32.0, crosshair.size.y - 88.0)
	for i in n:
		var x := right.x - (n - 1 - i) * 11.0
		var rect := Rect2(x - 3.0, right.y - 18.0, 6.0, 18.0)
		var loaded: bool = i < weapon.ammo and not weapon.is_reloading()
		var c := Color(1.0, 0.85, 0.45) if weapon.ammo > 1 else Color(1.0, 0.3, 0.2)
		if i >= weapon.ammo - weapon.smart_left:
			c = Color(1.0, 0.45, 0.75)
		crosshair.draw_rect(rect, Color(0, 0, 0, 0.6), true)
		if loaded:
			crosshair.draw_rect(rect.grow(-1.0), c, true)
		else:
			crosshair.draw_rect(rect.grow(-1.0), Color(1, 1, 1, 0.25), false, 1.0)


const DETECT_RING := 90.0

## One arc per grunt that is noticing the pilot, on a ring around the
## crosshair in the grunt's direction (top is straight ahead, bottom behind).
## It grows and goes from yellow to red as the grunt's detection meter fills.
func _draw_detection(center: Vector2) -> void:
	var cam: Camera3D = player.camera
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	for g in get_tree().get_nodes_in_group("enemies"):
		if not ("detection" in g) or g.passive or g.target != player:
			continue
		var amount: float = g.detection
		if amount < 0.02:
			continue
		var to: Vector3 = g.global_position - player.global_position
		var ang := atan2(to.dot(right), to.dot(Vector3(fwd.x, 0.0, fwd.z).normalized()))
		var a := ang - PI / 2.0  # screen angle, 0 = up
		var alerted: bool = g.alerted
		var col := Color(1.0, 0.85, 0.25).lerp(Color(1.0, 0.25, 0.1), amount)
		if alerted:
			col = Color(1.0, 0.1, 0.05)
		var span := lerpf(0.12, 0.45, amount)
		var width := 8.0 if alerted else lerpf(3.0, 6.0, amount)
		col.a = 0.9 if alerted else lerpf(0.4, 0.95, amount)
		crosshair.draw_arc(center, DETECT_RING, a - span * 0.5, a + span * 0.5, 12, Color(0, 0, 0, col.a * 0.6), width + 3.0)
		crosshair.draw_arc(center, DETECT_RING, a - span * 0.5, a + span * 0.5, 12, col, width)
