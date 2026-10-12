extends Node
## Pip's Velvet on a run (hub/velvet.gd), Mature only: the drop. On a run with a
## check-up's dose in her, every so often (Velvet.DROP_EVERY, a roll each time,
## likelier the more it's built up and far likelier mixed with Hush or Glass)
## her body just stops: frozen where she stands for Velvet.DROP_TIME, the view
## washed violet and black, and a cut of her max health gone. On its own it
## leaves her on 1 at worst; mixed, it can kill her.
## The run manager ticks it on runs (run_tick) and stops it going home (stop).

const Velvet := preload("res://scripts/hub/velvet.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const SFX := preload("res://scripts/sfx.gd")

const DARK := Color(0.12, 0.0, 0.2)

var rm: Node
var drop_left := 0.0
var _next := Velvet.FIRST_DROP
var _lines := 0
var _veil: ColorRect
var rng := RandomNumberGenerator.new()


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "VelvetRun"
	rng.randomize()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(DARK, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func busy() -> bool:
	return drop_left > 0.0


func active() -> bool:
	return busy() or _next != Velvet.FIRST_DROP


## A run's tick. `free`: she's on foot and nothing else has her.
func run_tick(delta: float, free: bool) -> void:
	if busy():
		drop_left -= delta
		_veil.color.a = clampf(drop_left / Velvet.DROP_TIME, 0.0, 1.0) * (0.75 + 0.15 * sin(Time.get_ticks_msec() * 0.01))
		if drop_left <= 0.0:
			_end_drop()
		return
	if not Velvet.on() or not free:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = Velvet.DROP_EVERY
	if rng.randf() < Velvet.drop_chance():
		drop()


## The drop takes her: frozen, washed out, hurt. Mixed with Hush or Glass it
## can kill; otherwise it leaves her on 1 at worst.
func drop() -> void:
	var player: Node = rm.player
	var mixed := Velvet.mixed()
	Velvet.drops += 1
	Velvet.save()
	drop_left = Velvet.DROP_TIME
	Vices.entranced = true
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	var hurt: float = player.max_health * Velvet.drop_hurt()
	if mixed:
		hurt *= 1.6
	var health: float = player.health
	if not mixed:
		hurt = minf(hurt, health - 1.0)
	if hurt >= health:
		# mixed, and it's enough: the way any killing blow goes (Dad's Colours and all)
		player.armor = 0.0
		player.take_damage(health * 100.0)
	elif hurt > 0.0:
		player.health = health - hurt
	rm.hud.toast(Velvet.MIXED_LINE if mixed else Velvet.DROP_LINES[_lines % Velvet.DROP_LINES.size()], Velvet.DROP_TIME + 1.0)
	_lines += 1
	SFX.play(player, "heartbeat", -2.0)


func _end_drop() -> void:
	drop_left = 0.0
	_veil.color.a = 0.0
	var tether: Node = rm.get("tether")
	if tether != null and tether.busy():
		return  # Marrow's swirls still have her
	Vices.entranced = false
	rm.player.set("entranced", false)


## Off the run: nothing pending.
func stop() -> void:
	_next = Velvet.FIRST_DROP
	if busy():
		_end_drop()
	if _veil != null:
		_veil.color.a = 0.0
