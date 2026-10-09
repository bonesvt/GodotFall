extends "res://scripts/run/story/level_story.gd"
## Level 3, Blackwater Line (levels.gd): the colony's fuel line across the
## marsh, and a barge being loaded at its end. Next to the fuel there's a
## stack of crates under a colony seal, addressed to a cellar in Solace: Glass
## on its way to Marrow, and the first proof someone in town works for the
## colony. How it plays depends on his Hold (level_story.gd stage):
##   CLEAN   cut the fuel line and burn the crates, both before she can leave.
##   HOOKED  cut the fuel line. At the crates his voice tells her to let them
##           through: leave them and they go on to Solace (Glass.shipped: the
##           Chorus comes sooner; obeyed, his Hold a notch tighter); burn them
##           and the swirls take her where she stands (refused, a notch
##           looser).
##   HIS     the errand is the mission: mark the crates for his drop so they
##           go on to Solace. The fuel line is hers to cut or not.

const Z := preload("res://scripts/run/zone_kit.gd")
const Glass := preload("res://scripts/hub/glass.gd")

## Where his voice reaches her on the way to the crates (m).
const ORDER_RANGE := 5.0
const SEAL := Color(0.72, 0.32, 1.0)
const CRATE_LABEL := "COLONY SEAL\nDO NOT OPEN\nDELIVER: CELLAR, SOLACE"

var fuel_cut := false
var crates_burned := false
var crates_sent := false
## HOOKED: he's told her to let them through.
var ordered := false
## Holds his order back while the valve's line is still up on the HUD.
var _busy := 0.0
var _crates: Array = []
var _fires: Array = []
var _t := 0.0


func build(gen, plan, info: Dictionary, keep_out: Array, s: Dictionary, c: float, side: float,
		squad: Array, zone_index: int, _dress: RandomNumberGenerator) -> void:
	var at := Vector2(c + side * 8.5, float(s["z1"]) + 17.0)
	position = gen._on(plan, at.x, at.y)
	gen._occupy(info, keep_out, at, Vector2(12.0, 30.0))
	# The barge run in along the bank, the fuel line out to it on trestles,
	# the tank it's pumped from at the far end.
	Z.barge(self, Vector3(side * 3.5, 1.5, 0.0), 90.0)
	Z.pipe_run(self, Vector3(side * 0.5, 0.0, -9.0), 90.0)
	Z.storage_tank(self, Vector3(side * 1.0, 0.0, -14.5))
	# The valve at the pipe's near end: a red wheel on a stand.
	box(Vector3(-side * 0.6, 0.6, -3.2), Vector3(0.5, 1.2, 0.5), Color(0.3, 0.32, 0.3))
	var wheel := box(Vector3(-side * 0.6, 1.25, -2.9), Vector3(0.7, 0.7, 0.08), Color(0.75, 0.12, 0.08))
	wheel.name = "Valve"
	spots["valve"] = {"at": Vector3(-side * 0.6, 0.0, -2.4), "prompt": "[F] Cut the fuel line"}
	# The crates on the bank, waiting to go aboard, each under the seal.
	for k in 3:
		var crate := box(Vector3(-side * 0.8, 0.45 + (0.9 if k == 2 else 0.0), 3.0 + (k % 2) * 1.0), Vector3(0.9, 0.9, 0.9), Color(0.42, 0.36, 0.3))
		crate.name = "SealedCrate%d" % k
		var seal := box(Vector3(0, 0, 0.46), Vector3(0.5, 0.5, 0.02), SEAL, crate)
		seal.material_override = Kit.glow(SEAL)
		_crates.append(crate)
	var tag := sign_text(Vector3(-side * 0.8, 2.4, 3.5), CRATE_LABEL, 28, Color(0.85, 0.75, 1.0))
	tag.name = "CrateLabel"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spots["crates"] = {"at": Vector3(-side * 1.8, 0.0, 3.5), "prompt": ""}
	sign_text(Vector3(side * 1.0, 7.4, -14.5), "BLACKWATER LINE", 72, Color(1.0, 0.75, 0.4)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The loaders: one by the valve, one at the crates.
	squad.append(gen._grunt(get_parent(), info, to_global(Vector3(-side * 2.5, 0.0, -4.0)), zone_index, 1.2, Vector3(-side, 0, 0)))
	squad.append(gen._grunt(get_parent(), info, to_global(Vector3(-side * 3.0, 0.0, 5.5)), zone_index, 1.2, Vector3(-side, 0, 0)))


func _usable(id: String) -> bool:
	match id:
		"valve":
			return not fuel_cut
		"crates":
			return not crates_burned and not crates_sent
	return false


func prompt(pos: Vector3) -> String:
	if near(pos) == "crates":
		return "[F] Mark the crates for his drop" if stage == HIS else "[F] Burn the crates"
	return super(pos)


func _use(id: String) -> void:
	match id:
		"valve":
			_cut_fuel()
		"crates":
			if stage == HIS:
				_send_crates()
			else:
				_burn_crates()


func tick(delta: float) -> void:
	_t += delta
	_busy = maxf(_busy - delta, 0.0)
	for f in _fires:
		(f as OmniLight3D).light_energy = 2.2 + 0.6 * sin(_t * 13.0 + f.position.z)
	if rm == null or rm.player == null:
		return
	if stage == HOOKED and not ordered and not crates_burned and _busy <= 0.0:
		var at := to_global(spots["crates"]["at"])
		if rm.player.global_position.distance_to(at) < ORDER_RANGE:
			ordered = true
			SFX.play(rm.player, "radio_squelch_on", -6.0)
			say([
				"Marrow's voice, the way the Hush carries it: \"Those crates are mine, little bird.\"",
				"Marrow: \"Let them through. Cut his fuel if it makes you feel brave. Leave my crates alone.\"",
			])


func _begin() -> void:
	match stage:
		HIS:
			say(["Marrow's voice, warm in her head: \"There's a barge at the end of the fuel line. Crates with my name on them.\"",
				"Marrow: \"See them on their way to me. The fuel's yours, if you still care.\""])
		_:
			say(["The colony's fuel line runs out across Blackwater to a barge. Cut it.",
				"The radio says the barge is carrying something else too. Something under a seal."])


func _cut_fuel() -> void:
	fuel_cut = true
	SFX.play_at(self, to_global(spots["valve"]["at"]), "explosion_metal", 0.0, 0.9)
	_fire(spots["valve"]["at"] + Vector3(0, 1.5, -2.0))
	var wheel := find_child("Valve", false, false) as Node3D
	if wheel != null:
		wheel.rotation.z = PI * 0.5
	rm.hud.toast("The valve shears off and the line goes up behind it. The colony's fuel isn't going anywhere.", 3.5)
	_busy = 3.6
	if rm.get("tutorial") != null:
		rm.tutorial.event("fuel_cut")


func _burn_crates() -> void:
	crates_burned = true
	_fire(spots["crates"]["at"] + Vector3(0, 1.0, 0))
	SFX.play_at(self, to_global(spots["crates"]["at"]), "flare", 0.0, 0.9)
	for crate in _crates:
		(crate as MeshInstance3D).material_override.albedo_color = Color(0.08, 0.07, 0.07)
	var lbl := find_child("CrateLabel", false, false) as Label3D
	if lbl != null:
		lbl.text = "CELLAR, SOLACE"
	if stage == HOOKED and ordered:
		rm.tether.punish()
		say_once("burned", ["The seal cracks in the heat. Violet smoke, sweet and wrong. Glass, a whole barge of it, going to someone in Solace."])
	else:
		say_once("burned", [
			"The seal cracks in the heat. Violet smoke, sweet and wrong. Glass, crates of it.",
			"Eco: \"Cellar, Solace. Someone in town's taking deliveries from the colony.\"",
		])


func _send_crates() -> void:
	crates_sent = true
	SFX.play(rm.player, "paper_1", -4.0)
	for crate in _crates:
		var mark := box(Vector3(0, 0.2, -0.46), Vector3(0.4, 0.4, 0.02), SEAL, crate)
		mark.material_override = Kit.glow(SEAL)
	say([
		"She chalks his spiral on each crate, the way he showed her. Nobody on this barge will touch them now.",
		"Marrow: \"Good girl. They'll be in Solace before you are.\"",
	])


## The barge goes on without her: whatever's still on it reaches Solace.
func _ship() -> void:
	if crates_burned:
		return
	Glass.shipped += 1
	if stage == HOOKED and ordered:
		Glass.obeyed()
	Glass.save()


func can_leave() -> bool:
	match stage:
		CLEAN:
			return fuel_cut and crates_burned
		HOOKED:
			return fuel_cut
		HIS:
			return crates_sent
	return true


func leave_nag() -> String:
	if stage == HIS:
		return "Marrow: \"My crates, little bird. Mark them first.\""
	if not fuel_cut:
		return "Not yet. The fuel line's still running."
	return "Not yet. Those sealed crates are still sitting on the bank."


func finish() -> String:
	_ship()
	if crates_burned:
		return "Fuel line cut, and the colony's crates burned on the bank."
	if crates_sent:
		return "His crates are on their way to Solace." + (" The fuel line's down too." if fuel_cut else "")
	return "Fuel line cut. The barge went on with his crates."


func _fire(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 9.0
	light.light_energy = 2.2
	add_child(light)
	light.position = at
	_fires.append(light)
	var flame := box(at + Vector3(0, -0.4, 0), Vector3(0.8, 1.2, 0.8), Color(1.0, 0.5, 0.1))
	flame.material_override = Kit.glow(Color(1.0, 0.45, 0.1))
