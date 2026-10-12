extends RefCounted
## Eco's battle damage: dirt, scuffs, a torn suit, fresh cuts and suit worn
## through by sliding, built up over a run and washed off when she gets home
## (run_manager.gd resets it in the hub and at the start of every run).
##
## Five levels, 0..1, the same for every copy of her (her body, her
## first-person arms, her shadow), pushed to shader globals that her toon
## shader compares with the maps tools/eco/bake_damage.py baked
## (assets/shaders/eco_toon.gdshaderinc, damage_kind): each texel turns at
## its own level, so the damage spreads as the level rises. The Battle damage
## setting (Game tab) turns it all off.

const Prefs := preload("res://scripts/game/prefs.gd")
const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState

## Seconds out in a zone for her to get fully filthy on time alone.
const GRIME_SECONDS := 480.0
## Per point of damage she takes (her pilot health is 100).
const HIT := {"grime": 1.0 / 1500.0, "scuffs": 1.0 / 500.0, "tears": 1.0 / 450.0, "scars": 1.0 / 700.0}
## Going down (second wind gone, health out) and falling off the map.
const DOWN := {"grime": 0.08, "scuffs": 0.1, "tears": 0.12, "scars": 0.15}
const FALL := {"grime": 0.1, "scuffs": 0.05}
## Per second of sliding (on her knees and hip; "slide" wears through the
## outsides of her thighs, the outer parts of her glutes and her hips: about a
## minute and a half of sliding over a run opens all of it) and of wallrunning.
const SLIDE := {"grime": 0.02, "scuffs": 0.012, "slide": 0.012}
const WALLRUN := {"grime": 0.004}

static var grime := 0.0
static var scuffs := 0.0
static var tears := 0.0
static var scars := 0.0
static var slide := 0.0
## What the shader globals were last set to (grime, scuffs, tears, scars), and eco_slide.
static var _pushed := Vector4(-1, -1, -1, -1)
static var _pushed_slide := -1.0


## Clean again (back home, or a fresh run).
static func reset() -> void:
	grime = 0.0
	scuffs = 0.0
	tears = 0.0
	scars = 0.0
	slide = 0.0
	apply()


## Every level at once (the showcase's --damage, tests).
static func set_all(level: float) -> void:
	grime = clampf(level, 0.0, 1.0)
	scuffs = grime
	tears = grime
	scars = grime
	slide = grime
	apply()


static func add(amounts: Dictionary, times := 1.0) -> void:
	grime = minf(grime + float(amounts.get("grime", 0.0)) * times, 1.0)
	scuffs = minf(scuffs + float(amounts.get("scuffs", 0.0)) * times, 1.0)
	tears = minf(tears + float(amounts.get("tears", 0.0)) * times, 1.0)
	scars = minf(scars + float(amounts.get("scars", 0.0)) * times, 1.0)
	slide = minf(slide + float(amounts.get("slide", 0.0)) * times, 1.0)


## She took `amount` damage (player.gd damaged).
static func on_hit(amount: float) -> void:
	add(HIT, maxf(amount, 0.0))


static func on_down() -> void:
	add(DOWN)


static func on_fall() -> void:
	add(FALL)


## A frame of her being out on a run: dirt from the air and the ground, more
## while she slides or runs along walls.
static func tick(delta: float, player: Node) -> void:
	add({"grime": 1.0 / GRIME_SECONDS}, delta)
	var state = player.get("state") if player != null else null
	if state == PlayerState.SLIDE:
		add(SLIDE, delta)
	elif state == PlayerState.WALLRUN:
		add(WALLRUN, delta)


## The levels drawn now: nothing with the setting off.
static func shown() -> Vector4:
	if not Prefs.battle_damage():
		return Vector4.ZERO
	return Vector4(grime, scuffs, tears, scars)


## How far sliding has worn her suit through, as drawn now.
static func shown_slide() -> float:
	return slide if Prefs.battle_damage() else 0.0


## Pushes the levels to the shader globals (cheap to call every frame: only
## sends what changed).
static func apply() -> void:
	var v := shown()
	var s := shown_slide()
	if v.is_equal_approx(_pushed) and is_equal_approx(s, _pushed_slide):
		return
	_pushed = v
	_pushed_slide = s
	RenderingServer.global_shader_parameter_set(&"eco_slide", s)
	RenderingServer.global_shader_parameter_set(&"eco_grime", v.x)
	RenderingServer.global_shader_parameter_set(&"eco_scuffs", v.y)
	RenderingServer.global_shader_parameter_set(&"eco_tears", v.z)
	RenderingServer.global_shader_parameter_set(&"eco_scars", v.w)
