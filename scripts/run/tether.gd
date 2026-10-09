extends Node
## Marrow's Glass on a run (hub/glass.gd), Mature only:
##   - L cracks a vial: a few real seconds of focus, the world slowed
##     (Engine.time_scale), the view tinted violet, her shots harder;
##   - with his earpiece in (the Tether), every so often an order in her ear.
##     Done: scrap, a patch-up, his Hold a notch tighter. Failed, or tuned
##     out with K: the swirls take her where she stands for a moment, and his
##     Hold loosens a notch.
## The run manager ticks it on runs (run_tick) and stops it going home (stop).

const Glass := preload("res://scripts/hub/glass.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const SFX := preload("res://scripts/sfx.gd")

const TINT := Color(0.42, 0.12, 0.62)

var rm: Node
## The order he's given ("" none), seconds left on it, and its progress.
var order := ""
var left := 0.0
var _kills_at := 0
var _used_at := 0
var _hit := false
var _still := 0.0
var _next := Glass.FIRST_ORDER
var punish_left := 0.0
var _lines := 0
var _slowed := false
var _veil: ColorRect
var rng := RandomNumberGenerator.new()


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "Tether"
	rng.randomize()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(TINT, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func busy() -> bool:
	return punish_left > 0.0


## Anything running that stop() should end.
func active() -> bool:
	return _slowed or order != "" or busy() or Glass.focus_left > 0.0


## A run's tick (delta is game time: slowed while she's focused). `free`:
## she's on foot and nothing else has her.
func run_tick(delta: float, free: bool) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if free and not busy() and Input.is_action_just_pressed("focus"):
		focus()
	if free and order != "" and not busy() and Input.is_action_just_pressed("tune_out"):
		rm.hud.toast(Glass.TUNE_OUT_LINE, 2.5)
		_fail()
	Glass.tick_focus(real)
	_set_slow(Glass.focusing())
	_veil.color.a = (0.22 + 0.04 * sin(Time.get_ticks_msec() * 0.008)) if Glass.focusing() else 0.0
	if busy():
		punish_left -= real
		if punish_left <= 0.0:
			_end_punish()
		return
	if not Glass.tethered() or not free:
		return
	if order == "":
		_next -= delta
		if _next <= 0.0:
			give_order(_pick())
		return
	left -= delta
	_check_order(delta)


## Cracks a vial. Returns whether she had one.
func focus() -> bool:
	if not Glass.use_vial():
		if Glass.vials <= 0 and Glass.earpiece:
			rm.hud.toast("No Glass left. Marrow would sell you more.", 2.0)
		return false
	rm.player.refresh_glass()
	SFX.play(rm.player, "titan_hiss_short", -8.0, 2.0)
	rm.hud.toast("Glass. Everything slows down and goes sharp. Her skin goes cold where it's spreading.", 2.5)
	return true


## One of his orders, at random (a vial only when she has one).
func _pick() -> String:
	var ids := Glass.ORDERS.keys().filter(func(id): return id != "glass" or Glass.vials > 0)
	return ids[rng.randi() % ids.size()]


func give_order(id: String) -> void:
	order = id
	left = Glass.ORDERS[id]["time"]
	_kills_at = rm.run.kills if rm.run != null else 0
	_used_at = Glass.used
	_hit = false
	_still = 0.0
	_listen()
	rm.hud.toast(Glass.ORDERS[id]["say"], 3.5)
	SFX.play(rm.player, "radio_squelch_on", -6.0)


func _listen() -> void:
	var player: Node = rm.player
	if not player.damaged.is_connected(_on_hit):
		player.damaged.connect(_on_hit)


func _on_hit(_amount: float, _from: Vector3) -> void:
	_hit = true


func _check_order(delta: float) -> void:
	match order:
		"kills":
			if kills_left() <= 0:
				_obey()
				return
		"untouched":
			if _hit:
				_fail()
				return
		"moving":
			var v: Vector3 = rm.player.velocity
			_still = _still + delta if Vector2(v.x, v.z).length() < 2.0 else 0.0
			if _still > 1.0:
				_fail()
				return
		"glass":
			if Glass.used > _used_at:
				_obey()
				return
	if left <= 0.0:
		if order in ["untouched", "moving"]:
			_obey()  # she held out the whole time
		else:
			_fail()


func kills_left() -> int:
	var done: int = (rm.run.kills if rm.run != null else 0) - _kills_at
	return int(Glass.ORDERS["kills"]["need"]) - done


func _obey() -> void:
	order = ""
	_next = Glass.ORDER_EVERY
	Glass.obeyed()
	if rm.run != null:
		rm.run.materials["scrap"] = int(rm.run.materials.get("scrap", 0)) + Glass.OBEY_SCRAP
	var player: Node = rm.player
	player.health = minf(player.health + Glass.OBEY_HEAL, player.max_health)
	rm.hud.toast("%s  (+%d scrap, patched up)" % [Glass.OBEY_LINES[_lines % Glass.OBEY_LINES.size()], Glass.OBEY_SCRAP], 3.0)
	_lines += 1


## She didn't do it (or wouldn't): the swirls take her for a moment.
func _fail() -> void:
	order = ""
	_next = Glass.ORDER_EVERY
	Glass.refused()
	punish_left = Glass.PUNISH_TIME
	Vices.entranced = true
	var player: Node = rm.player
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	rm.hud.toast(Glass.PUNISH_LINES[_lines % Glass.PUNISH_LINES.size()], Glass.PUNISH_TIME + 0.5)
	_lines += 1
	SFX.play(player, "heartbeat", -4.0)


func _end_punish() -> void:
	punish_left = 0.0
	Vices.entranced = false
	rm.player.set("entranced", false)


## What the HUD says about his order, or "".
func hud_text() -> String:
	if order == "" or not Glass.tethered():
		return ""
	var what: String = Glass.ORDERS[order]["hud"]
	if order == "kills":
		what = what % maxi(kills_left(), 0)
	return "MARROW: %s %ds  [K] tune him out" % [what, ceili(maxf(left, 0.0))]


func _set_slow(on: bool) -> void:
	if on == _slowed:
		return
	_slowed = on
	Engine.time_scale = Glass.FOCUS_SCALE if on else 1.0


## Off the run: the world at speed, no order, no trance.
func stop() -> void:
	Glass.focus_left = 0.0
	_set_slow(false)
	if _veil != null:
		_veil.color.a = 0.0
	order = ""
	_next = Glass.FIRST_ORDER
	if busy():
		_end_punish()
