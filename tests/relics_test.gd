extends SceneTree
## Relics (relics.gd, relic_fx.gd, relic_shrine.gd, relic_screen.gd): the
## catalogue, finding and wearing them (two at most), every perk and catch
## doing nothing off a run and the right thing on one, the keepsakes' givers,
## Marrow's coin staying Mature only, what lands at a run's end, saving, and
## the run manager's side: the idol's reliquary, a gift handed over, a
## shrine in a zone, Mom's locket and the end-of-run notes.
##   godot --headless --path . -s res://tests/relics_test.gd

const Relics := preload("res://scripts/hub/relics.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const RelicScreen := preload("res://scripts/hub/relic_screen.gd")
const RelicShrine := preload("res://scripts/run/relic_shrine.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const PATH := "user://test_relics.cfg"
const ARMORY_PATH := "user://test_relics_armory.cfg"
const TALK_PATH := "user://test_relics_npcs.cfg"

var failures := 0
var run_node


func _initialize() -> void:
	for p in [PATH, ARMORY_PATH, TALK_PATH, "user://test_relics_armory_relics.cfg", "user://test_relics_armory_vices.cfg",
			"user://test_relics_armory_vices_glass.cfg", "user://test_relics_settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_run.call_deferred()


func _run() -> void:
	var old_rating := ContentRating.current()
	ContentRating.set_rating("T", false)
	_unit()
	await _game()
	ContentRating.set_rating(old_rating, false)
	print("relics_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _unit() -> void:
	Relics.open(PATH)
	Vices.reset()
	# Catalogue.
	_check("every relic is in the order", Relics.ORDER.size() == Relics.RELICS.size() and Relics.ORDER.all(func(id): return Relics.RELICS.has(id)), Relics.ORDER.size())
	for id: String in Relics.ORDER:
		var r: Dictionary = Relics.RELICS[id]
		var ok := ["name", "source", "perk", "curse", "blurb", "carry"].all(func(k): return r.has(k)) and Relics.SOURCES.has(r["source"])
		ok = ok and Relics.HINTS.has(r.get("giver", r["source"]))
		ok = ok and (r["source"] != "npc" or (r.has("gift") and Relics.GIVERS.has(r["giver"]) and Relics.GIVERS[r["giver"]]["relic"] == id))
		_check("%s is complete" % id, ok, r.keys())
	for source in ["precursor", "npc", "colony"]:
		_check("there are %s relics" % source, Relics.ORDER.any(func(id): return Relics.RELICS[id]["source"] == source), source)

	# Teen: Marrow's coin isn't there.
	_check("Teen: no coin listed", not "violet_coin" in Relics.listed() and Relics.listed().size() == Relics.ORDER.size() - 1, Relics.listed().size())
	Relics.gain("violet_coin")
	_check("Teen: the coin can't go on", not Relics.toggle("violet_coin") and not Relics.wearing("violet_coin"), Relics.worn)
	Relics.owned.erase("violet_coin")

	# Finding and wearing.
	_check("nothing owned at first", Relics.owned.is_empty() and Relics.worn.is_empty(), Relics.owned)
	_check("can't wear what she hasn't got", not Relics.toggle("idols_tooth"), Relics.worn)
	_check("found: new", Relics.gain("idols_tooth"), Relics.owned)
	_check("found again: not new", not Relics.gain("idols_tooth"), Relics.owned)
	Relics.gain("sunless_mask")
	Relics.gain("heartstone")
	Relics.toggle("idols_tooth")
	Relics.toggle("sunless_mask")
	_check("two on", Relics.worn == ["idols_tooth", "sunless_mask"], Relics.worn)
	Relics.toggle("heartstone")
	_check("a third pushes the oldest off", Relics.worn == ["sunless_mask", "heartstone"], Relics.worn)
	Relics.toggle("heartstone")
	_check("taken off", Relics.worn == ["sunless_mask"], Relics.worn)
	_check("missing precursor ones", Relics.missing("precursor") == ["builder_eye"], Relics.missing("precursor"))

	# Off a run nothing applies.
	for id in Relics.ORDER:
		Relics.gain(id)
	Relics.worn = ["idols_tooth", "biggies_tags"]
	_check("off a run: no perks", Relics.damage_out() == 1.0 and Relics.damage_in() == 1.0 and Relics.wallrun_scale() == 1.0, [Relics.damage_out(), Relics.damage_in()])
	_check("off a run: no catch", Relics.kill_health() == 0.0, Relics.kill_health())

	# On a run, each relic does its thing.
	var expect := {
		"idols_tooth": func(): return Relics.damage_out() == Relics.TOOTH_DAMAGE and Relics.kill_health() == -Relics.TOOTH_PRICE,
		"heartstone": func(): return Relics.regen_scale() == Relics.HEART_REGEN,
		"sunless_mask": func(): return Relics.notice_scale() == Relics.MASK_NOTICE,
		"biggies_tags": func(): return Relics.damage_in() == Relics.TAGS_DAMAGE and Relics.wallrun_scale() < 1.0 and Relics.slide_friction_scale() > 1.0,
		"sals_scale": func(): return Relics.loot_amount(3) == 5 and Relics.jams(0.0) and not Relics.jams(0.99),
		"imanis_kit": func(): return Relics.numb() and Relics.kill_health() == Relics.KIT_HEAL,
		"prayer_beads": func(): return Relics.damage_in() == Relics.BEADS_DAMAGE,
		"target_lens": func(): return Relics.spread_scale() == Relics.LENS_SPREAD,
		"phase_harness": func(): return Relics.speed_scale() == Relics.HARNESS_SPEED,
		"iff_tag": func(): return Relics.notice_scale() == Relics.IFF_NOTICE and Relics.damage_in() == Relics.IFF_DAMAGE,
	}
	for id: String in expect:
		Relics.worn = [id]
		Relics.run_started()
		_check("on a run: %s works" % id, expect[id].call(), id)
		Relics.on_run = false

	# Heartstone drains her max health over the run, down to half.
	Relics.worn = ["heartstone"]
	Relics.run_started()
	_check("Heartstone: full at the start", Relics.health_scale() == 1.0, Relics.health_scale())
	Relics.tick(Relics.HEART_DRAIN_TIME * 0.5)
	_check("Heartstone: part way down", Relics.health_scale() < 1.0 and Relics.health_scale() > Relics.HEART_FLOOR, Relics.health_scale())
	Relics.tick(Relics.HEART_DRAIN_TIME * 3.0)
	_check("Heartstone: stops at half", is_equal_approx(Relics.health_scale(), Relics.HEART_FLOOR), Relics.health_scale())

	# Mom's locket: once a run.
	Relics.worn = ["moms_locket"]
	Relics.run_started()
	_check("locket saves her once", Relics.cheat_death() and not Relics.cheat_death(), Relics.locket_used)
	Relics.run_started()
	_check("locket's back next run", Relics.cheat_death(), "")

	# The watch notes headshots only when worn.
	Relics.worn = []
	Relics.note_headshot()
	_check("no watch: no slow-mo", not Relics.headshot, "")
	Relics.worn = ["ophelias_watch"]
	Relics.note_headshot()
	_check("watch: a headshot slows things", Relics.headshot, "")
	Relics.headshot = false

	# The end of a run.
	var state := ConfigFile.new()
	state.set_value("ophelia", "affection", 30)
	Relics.worn = ["ophelias_watch", "prayer_beads"]
	Relics.run_started()
	var runs_before := Relics.runs
	var notes := Relics.run_over(state, 60.0)
	_check("a quick run: Ophelia doesn't mind", int(state.get_value("ophelia", "affection")) == 30, notes)
	_check("beads: the town talks", Relics.town_talk == 1 and notes.size() == 1, [Relics.town_talk, notes])
	_check("runs counted", Relics.runs == runs_before + 1 and not Relics.on_run, Relics.runs)
	Relics.run_started()
	notes = Relics.run_over(state, Relics.WATCH_LIMIT + 1.0)
	_check("a long run: Ophelia's cold", int(state.get_value("ophelia", "affection")) == 30 - Relics.WATCH_COST, notes)

	# Marrow's coin under Mature.
	ContentRating.set_rating("M", false)
	Vices.reset()
	Vices.hold = 20.0
	Relics.worn = ["violet_coin"]
	Relics.run_started()
	_check("Mature: coin gives Hush perks", Relics.damage_out() > 1.0 and Relics.notice_scale() < 1.0 and Relics.regen_scale() > 1.0, Relics.damage_out())
	Relics.run_over(state, 60.0)
	_check("coin tightens his Hold", is_equal_approx(Vices.hold, 20.0 + Relics.COIN_HOLD), Vices.hold)
	ContentRating.set_rating("T", false)
	Vices.reset()

	# Givers.
	Relics.owned = []
	Relics.worn = []
	Relics.runs = 0
	var talk := ConfigFile.new()
	_check("Mom: not yet", Relics.gift_due("mom", talk) == "", "")
	talk.set_value("mom", "bond", 45)
	_check("Mom: close enough", Relics.gift_due("mom", talk) == "moms_locket", "")
	talk.set_value("ophelia", "affection", 45)
	_check("Ophelia: fond enough", Relics.gift_due("ophelia", talk) == "ophelias_watch", "")
	_check("Sal: not after no runs", Relics.gift_due("sal", talk) == "", "")
	Relics.runs = 5
	_check("Sal, Imani, Tobin and Rosa after a few runs", ["sal", "imani", "townsfolk"].all(func(w): return Relics.gift_due(w, talk) != ""), "")
	Vices.hold = 90.0
	_check("Teen: Marrow gives nothing", Relics.gift_due("marrow", talk) == "", "")
	Vices.reset()
	_check("spots map to givers", Relics.giver_at({"npc": "mom"}) == "mom" and Relics.giver_at({"id": "shop_salvage"}) == "sal" and Relics.giver_at({"id": "idol"}) == "", "")
	Relics.gain("moms_locket")
	_check("given once", Relics.gift_due("mom", talk) == "", "")

	# Saved.
	Relics.gain("heartstone")
	Relics.toggle("heartstone")
	var owned := Relics.owned.duplicate()
	Relics.open(PATH)
	_check("saved and loaded", Relics.owned == owned and Relics.worn == ["heartstone"] and Relics.runs == 5, [Relics.owned, Relics.worn, Relics.runs])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _game() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_relics_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4321
	run_node.start_in_hub = true
	run_node.armory_path = ARMORY_PATH
	run_node.npc_path = TALK_PATH
	root.add_child(run_node)
	await _ticks(8)
	_check("fresh save: no relics", Relics.owned.is_empty() and Relics.save_path == "user://test_relics_armory_relics.cfg", Relics.save_path)

	# The idol is the reliquary.
	var idol: Array = run_node.zone_info["interactables"].filter(func(s): return s["id"] == "idol")
	_check("the idol opens the reliquary", idol.size() == 1 and idol[0].get("screen", "") == "relics", idol)
	run_node.open_bench("relics")
	await _ticks(2)
	var screen = run_node.bench
	_check("reliquary open", screen is RelicScreen, screen)
	_check("nothing to wear yet", not screen.toggle_selected(), Relics.worn)
	run_node.close_bench()
	await _ticks(2)

	# Mom gives her the locket.
	run_node.npc_talk.state.set_value("mom", "bond", 60)
	_check("Mom hands over the locket", run_node._relic_gift({"npc": "mom", "id": "mom_tent"}) and Relics.owns("moms_locket"), Relics.owned)
	_check("only once", not run_node._relic_gift({"npc": "mom", "id": "mom_tent"}), "")
	Relics.gain("idols_tooth")
	run_node.open_bench("relics")
	await _ticks(2)
	screen = run_node.bench
	screen.selected = Relics.listed().find("moms_locket")
	_check("wear the locket at the idol", screen.toggle_selected() and Relics.wearing("moms_locket"), Relics.worn)
	screen.selected = Relics.listed().find("idols_tooth")
	screen.toggle_selected()
	run_node.close_bench()
	await _ticks(2)

	# A run with them on.
	run_node.start_run(4321)
	await _ticks(4)
	_check("on a run", Relics.on_run and Relics.active("moms_locket") and Relics.active("idols_tooth"), Relics.worn)
	_check("HUD names them", run_node._vices_text().contains("MOM'S LOCKET"), run_node._vices_text())
	var player = run_node.player
	player.health = 5.0
	player.untouchable_timer = 0.0
	player.second_wind_ready = false
	player.take_damage(50.0)
	_check("the locket keeps her up", is_equal_approx(player.health, player.max_health * 0.5), player.health)
	var downs: int = run_node.run.downs
	player.untouchable_timer = 0.0
	player.health = 5.0
	player.take_damage(50.0)
	await _ticks(2)
	_check("only once a run", run_node.run.downs == downs + 1, run_node.run.downs)
	player.health = 50.0
	run_node.relic_fx.on_kill()
	_check("the Tooth's price on a kill", is_equal_approx(player.health, 50.0 - Relics.TOOTH_PRICE), player.health)

	# A shrine in the zone.
	var shrine = null
	for i in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		shrine = RelicShrine.scatter(run_node.zone_root, run_node.zone_info, rng)
		if shrine != null:
			break
	_check("a shrine can stand in a zone", shrine != null and Relics.RELICS[shrine.relic]["source"] == "precursor" and shrine in run_node.zone_info["loot"], shrine)
	if shrine != null:
		await _ticks(2)
		var id: String = shrine.relic
		shrine.open()
		run_node._take_relic(id)
		_check("its relic is hers", Relics.owns(id) and shrine.opened and not shrine.in_range(shrine.global_position), id)

	run_node.end_run("PILOT KIA", "Test.")
	_check("run over: off", not Relics.on_run and Relics.runs == 1, Relics.runs)
	run_node.queue_free()
	await _ticks(2)
	for p in [ARMORY_PATH, TALK_PATH, "user://test_relics_armory_relics.cfg", "user://test_relics_armory_vices.cfg",
			"user://test_relics_armory_vices_glass.cfg", "user://test_relics_settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
