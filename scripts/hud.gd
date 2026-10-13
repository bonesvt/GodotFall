extends CanvasLayer
## HUD: spread-aware crosshair with hitmarkers and stealth markers around it
## pointing at every grunt that is noticing the pilot, and one clean panel in the
## bottom left corner for the fight: health and armour bars, the magazine,
## movement state, double jump, grapple, speed and grunts left. The controls
## list stays off screen (H shows it).
## The reticle wears the pistol's story: around the spread ticks sits the
## ring of the old smart-lock, half its segments dead, flickering when the
## module glitches, and it still brackets enemies before failing to lock.
## Also hosts the enemy radio chatter popup and Eco's whispers (scripts/radio/).

const SFX := preload("res://scripts/sfx.gd")
const Style := preload("res://scripts/ui/hud_style.gd")
const RadioChatter := preload("res://scripts/radio/radio_chatter.gd")
const EcoWhispers := preload("res://scripts/radio/eco_whispers.gd")

var player: Node
var level: Node
var weapon: Node
var crosshair: Control
## The combat panel, bottom left: health, armour, magazine, movement (_draw_panel).
var panel: Control
var help_label: Label
var message_label: Label
var hurt_rect: ColorRect
var radio: Node
var whispers: Node

var hitmarker_timer := 0.0
var hitmarker_color := Color.WHITE
var hitmarker_kind := "body"
var hurt_flash := 0.0
## Seconds to the next heartbeat while she's badly hurt.
var _heart := 0.0
var message_timer := 0.0

const HITMARKER_TIME := 0.18
## The fight panel's width (it stops short of the dialogue caption, npc_talk.gd),
## and its height with the armour row.
const PANEL_W := 396.0
const PANEL_H := 156.0
const ARMOR_ROW := 30.0
const MARGIN := 22.0
const PANEL_LINE := Color(1, 1, 1, 0.18)
const INK := Style.INK
const DIM := Style.DIM
const HP_COL := Style.YELLOW
const LOW_COL := Style.RED
const ARMOR_COL := Color(1, 1, 1)
const AMMO_COL := Color(1.0, 0.85, 0.54)
const SMART_COL := Color(1.0, 0.5, 0.75)
const HELP := """WASD  move (auto-sprint forward)
Space  jump / double jump / wall jump
C or Ctrl  crouch, slide when running
Q, E or right mouse  grapple (hold)
Left mouse  shoot    R  reload    I  inspect
Z or mouse thumb  tap: knife strike (kills unaware grunts)   hold 1 s: draw the knife
Wheel, R or Z again  back to the gun
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

	# Everything about the fight in one panel, bottom left (_draw_panel): health
	# and armour bars, the magazine, movement, grapple, grunts left.
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = MARGIN
	panel.offset_right = MARGIN + PANEL_W
	panel.offset_top = -MARGIN - PANEL_H
	panel.offset_bottom = -MARGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.draw.connect(_draw_panel)
	add_child(panel)

	message_label = _label(28)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.offset_left = -400
	message_label.offset_right = 400
	message_label.offset_top = 140

	# The controls, off screen until H.
	help_label = _label(17)
	help_label.add_theme_font_override("font", Style.saira(500))
	help_label.position = Vector2(20, 20)
	help_label.text = HELP
	help_label.visible = false
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
	var l := Style.style(Label.new(), size)
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

	var hp_frac: float = player.health / player.max_health
	_heartbeat(delta, hp_frac)
	hurt_rect.color.a = (1.0 - hp_frac) * 0.3 + hurt_flash * 0.5
	panel.offset_top = -MARGIN - _panel_height()
	panel.queue_redraw()
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
		var font := Style.saira(700, false, 1)
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
		var font := Style.saira(700, false, 1)
		crosshair.draw_string(font, p + Vector2(-size * 0.5, size * 0.5 + 16), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)


## The combat panel: a card in the bottom left corner (hud_style.gd).
##   100  /////////////////////      health, yellow, red when low
##   40   /////////////             armour (only with a suit that has it)
##   8 / 8  ||||||||    GRUNTS LEFT 4   (one pip a round: smart rounds pink, the last red)
##   GROUND  ·  2x jump READY  ·  grapple READY  ·  5.2 m/s
func _draw_panel() -> void:
	var w := PANEL_W
	var armored: bool = player.max_armor > 0.0
	panel.draw_style_box(Style.card(HP_COL), Rect2(Vector2.ZERO, panel.size))
	var x := 16.0
	var num := Style.numbers()
	var bar_x := x + 62.0
	# health
	var hp_frac := clampf(player.health / player.max_health, 0.0, 1.0)
	var hp_col := HP_COL.lerp(LOW_COL, clampf((0.5 - hp_frac) * 2.5, 0.0, 1.0))
	Style.text(panel, num, Vector2(x, 41), str(ceili(player.health)), 30, hp_col)
	Style.bar(panel, Rect2(bar_x, 24, w - bar_x - 20.0, 13), hp_frac, hp_col, 40.0)
	var y := 41.0
	if armored:
		y += ARMOR_ROW
		Style.text(panel, num, Vector2(x, y), str(ceili(player.armor)), 30, ARMOR_COL)
		Style.bar(panel, Rect2(bar_x, y - 17, w - bar_x - 20.0, 13), player.armor / player.max_armor, ARMOR_COL, 40.0)
	y += 42.0
	# grunts left, right of the magazine
	var right := w - 16.0
	if level != null:
		var n := str(level.grunts_alive())
		Style.text(panel, num, Vector2(right - Style.width(num, n, 26), y), n, 26, Style.RED)
		var cap := Style.saira(700, false, 2)
		var cap_w := Style.width(cap, "GRUNTS LEFT", 11)
		right -= Style.width(num, n, 26) + 8.0
		Style.text(panel, cap, Vector2(right - cap_w, y - 2), "GRUNTS LEFT", 11, INK)
		right -= cap_w + 14.0
	# the magazine
	if weapon != null:
		var reloading: bool = weapon.is_reloading()
		var after := x
		if reloading:
			var f := Style.saira(700, false, 2)
			Style.text(panel, f, Vector2(x, y - 3), "RELOADING", 15, DIM)
			after += Style.width(f, "RELOADING", 15)
		else:
			var shown := str(weapon.ammo)
			var of := " / %d" % weapon.magazine_size
			Style.text(panel, num, Vector2(x, y), shown, 38, INK)
			var sw := Style.width(num, shown, 38)
			Style.text(panel, num, Vector2(x + sw, y), of, 22, DIM)
			after += sw + Style.width(num, of, 22)
		_draw_ammo_pips(after + 14.0, right, y - 2.0)
	# movement
	panel.draw_line(Vector2(x, y + 12), Vector2(w - 16, y + 12), PANEL_LINE, 1.0)
	var grapple := "READY" if player.grapple_ready_in() <= 0.0 else "%.1fs" % player.grapple_ready_in()
	var jump := "READY" if player.air_jumps_left > 0 else "used"
	var parts := [[player.state_name(), INK], ["  ·  2x jump ", DIM], [jump, Style.CYAN if jump == "READY" else DIM],
		["  ·  grapple ", DIM], [grapple, Style.CYAN if grapple == "READY" else DIM],
		["  ·  %.1f m/s" % player.horizontal_speed(), DIM]]
	var font := Style.saira(500)
	var mx := x
	for p in parts:
		Style.text(panel, font, Vector2(mx, y + 32), p[0], 13, p[1])
		mx += Style.width(font, p[0], 13)


## How tall the panel is: the armour row only shows with armour on.
func _panel_height() -> float:
	return PANEL_H if player != null and player.max_armor > 0.0 else PANEL_H - ARMOR_ROW


## One leaning pip per round between x0 and x1, feet on `foot`; the last round
## glows red. Smart rounds (the top of the mag, fired first) are pink.
func _draw_ammo_pips(x0: float, x1: float, foot: float) -> void:
	var n: int = weapon.magazine_size
	var step := minf(11.0, (x1 - x0) / maxf(n, 1))
	var w := maxf(minf(8.0, step - 3.0), 2.0)
	var h := 22.0
	for i in n:
		var x := x0 + i * step
		var pip := Style.lean(x, x + w, foot - h, h)
		var loaded: bool = i < weapon.ammo and not weapon.is_reloading()
		var c := AMMO_COL if weapon.ammo > 1 else LOW_COL
		if i >= weapon.ammo - weapon.smart_left:
			c = SMART_COL
		if loaded:
			panel.draw_colored_polygon(pip, c)
		else:
			pip.append(pip[0])
			panel.draw_polyline(pip, Color(1, 1, 1, 0.35), 1.0)


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


## Under a third of her health, her heart thumps in her ears, faster the
## lower it gets.
func _heartbeat(delta: float, hp_frac: float) -> void:
	if hp_frac >= 0.33 or player.health <= 0.0:
		_heart = 0.0
		return
	_heart -= delta
	if _heart <= 0.0:
		_heart = lerpf(0.8, 1.3, hp_frac / 0.33)
		SFX.play(self, "heartbeat", lerpf(-6.0, -14.0, hp_frac / 0.33))
