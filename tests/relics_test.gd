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
	var mature_only: Array = Relics.ORDER.filter(func(id): return Relics.RELICS[id].get("mature", false))
	_check("Teen: no Mature-only relics listed", not "violet_coin" in Relics.listed() and Relics.listed().size() == Relics.ORDER.size() - mature_only.size()
			and mature_only.size() == 6, mature_only)
	_check("Teen: Teen names", Relics.relic_name("moms_locket") == "Mom's Locket", Relics.relic_name("moms_locket"))
	_check("Teen: shrines only offer Teen ones", not "censer" in Relics.missing("precursor"), Relics.missing("precursor"))
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
	for id: String in Relics.MATURE:
		_check("%s's Mature side is a known relic" % id, Relics.RELICS.has(id), id)

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

	_mature()

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


## Under Mature: the darker sides, and the Mature-only relics.
func _mature() -> void:
	ContentRating.set_rating("M", false)
	Vices.reset()
	for id in Relics.ORDER:
		Relics.gain(id)
	_check("Mature: everything listed", Relics.listed().size() == Relics.ORDER.size(), Relics.listed().size())
	_check("Mature: darker names", Relics.relic_name("moms_locket") == "Mom's Rosary Flask" and Relics.relic_name("ophelias_watch") == "Ophelia's Lighter", "")
	var state := ConfigFile.new()
	state.set_value("ophelia", "affection", 50)
	state.set_value("mom", "bond", 50)

	# Biggie's flask starts her two drinks in; Sal's kit puts a stim on her belt.
	Relics.worn = ["biggies_tags", "sals_scale"]
	Relics.run_started()
	_check("Biggie's flask: buzzed from the start", is_equal_approx(Vices.buzz, Relics.FLASK_BUZZ) and Relics.damage_in() == Relics.TAGS_DAMAGE_M, Vices.buzz)
	_check("Sal's kit: a free stim", Vices.belt.size() == 1 and not Relics.jams(0.0) and Relics.loot_amount(3) == 3, Vices.belt)
	Vices.jab()
	Relics.tick(0.1)
	Relics.run_over(state, 60.0)
	_check("Sal's kit: a jab costs extra dependence", is_equal_approx(Vices.dependence, 2.0), Vices.dependence)
	Vices.reset()

	# The flask: when it saves her, a long pull, and Mom notices.
	Relics.worn = ["moms_locket"]
	Relics.run_started()
	_check("Mom's flask saves her", Relics.cheat_death() and is_equal_approx(Vices.buzz, Relics.FLASK_BUZZ), Vices.buzz)
	var notes := Relics.run_over(state, 60.0)
	_check("Mom finds it empty", int(state.get_value("mom", "bond")) == 50 - Relics.FLASK_BOND and notes.size() == 1, notes)
	Vices.reset()

	# Ophelia's lighter: works while she smokes, burns them fast, and she wants it lit.
	Relics.worn = ["ophelias_watch"]
	Relics.run_started()
	Relics.note_headshot()
	_check("lighter: no smoke, no slow-mo", not Relics.headshot, "")
	Relics.run_over(state, 60.0)
	_check("lighter: never lit, Ophelia's cold", int(state.get_value("ophelia", "affection")) == 50 - Relics.LIGHTER_COST, state.get_value("ophelia", "affection"))
	Relics.run_started()
	Vices.smokes = 1
	Vices.light_up()
	var left := Vices.smoke_left
	Vices.tick(1.0)
	Relics.tick(1.0)
	_check("lighter: smokes burn twice as fast", is_equal_approx(Vices.smoke_left, left - 2.0), Vices.smoke_left)
	Relics.note_headshot()
	_check("lighter: smoking, headshots slow", Relics.headshot and Relics.spread_scale() < 1.0, Relics.spread_scale())
	Relics.headshot = false
	var aff := int(state.get_value("ophelia", "affection"))
	Relics.run_over(state, 60.0)
	_check("lighter: lit up, she's happy", int(state.get_value("ophelia", "affection")) == aff, "")
	Vices.reset()

	# Heartstone: a fever for the next run.
	Relics.worn = ["heartstone"]
	Relics.run_started()
	Relics.run_over(state, 60.0)
	Relics.worn = []
	Relics.run_started()
	_check("fever carries into the next run", Relics.feverish and Relics.health_scale() == Relics.FEVER and Relics.carry_line().contains("fever"), Relics.health_scale())
	Relics.run_over(state, 60.0)
	Relics.run_started()
	_check("then it breaks", not Relics.feverish and Relics.health_scale() == 1.0, "")
	Relics.run_over(state, 60.0)

	# The Tooth's bloodlust.
	Relics.worn = ["idols_tooth"]
	Relics.run_started()
	_check("Tooth: fed, steady", not Relics.bloodlust() and Relics.sway(1.0) == Vector2.ZERO, "")
	Relics.tick(Relics.TOOTH_THIRST + 1.0)
	_check("Tooth: hungry, shaking", Relics.bloodlust() and Relics.sway(1.0) != Vector2.ZERO and Relics.spread_scale() > 1.0, Relics.sway(1.0))
	Relics.on_kill()
	_check("Tooth: a kill settles it", not Relics.bloodlust(), "")
	Relics.run_over(state, 60.0)

	# Imani's pills build a habit.
	Relics.worn = ["imanis_kit"]
	for i in Relics.PILL_HABIT:
		Relics.run_started()
		_check("pills soften hits", Relics.damage_in() == Relics.PILL_DAMAGE, Relics.damage_in())
		Relics.run_over(state, 60.0)
	Relics.worn = []
	Relics.run_started()
	_check("no pills: the shakes", Relics.pill_craving() and Relics.sway(2.0) != Vector2.ZERO, Relics.pills)
	Relics.run_over(state, 60.0)
	_check("a run without wears it down", Relics.pills == Relics.PILL_HABIT - 1, Relics.pills)

	# The censer's smoke, Rook's glass, Dutch's deck.
	Vices.reset()
	Relics.worn = ["censer", "rooks_glass"]
	Relics.run_started()
	Relics.tick(0.1)
	_check("Rook's glass: never sober", Vices.buzz >= Relics.ROOK_FLOOR and Relics.notice_scale() < 1.0, Vices.buzz)
	var sober_hit := Relics.damage_out()
	Relics.tick(120.0)
	_check("censer: the buzz climbs", Vices.buzz > Relics.ROOK_FLOOR and Vices.buzz <= Relics.CENSER_MAX + 0.01, Vices.buzz)
	_check("Rook's glass: drunker hits harder", Relics.damage_out() > sober_hit, [sober_hit, Relics.damage_out()])
	Relics.run_over(state, 60.0)
	_check("Rook's tab", Relics.scrap_owed == Relics.ROOK_TAB, Relics.scrap_owed)
	Vices.reset()
	Relics.worn = ["dutchs_deck"]
	Relics.deck_runs = 0
	var kept := []
	for i in Relics.DECK_TURN:
		Relics.run_started()
		_check("deck: luck leans her way", Relics.loot_amount(4) == 5, Relics.loot_amount(4))
		Relics.run_over(state, 60.0)
		kept.append(Relics.haul_keep)
	_check("deck: every third run it turns", kept == [1.0, 1.0, Relics.DECK_CUT], kept)

	# Beads: grunts start wary. The injector, once.
	Relics.worn = ["prayer_beads", "stim_injector"]
	Relics.run_started()
	_check("beads: grunts start wary", Relics.grunt_wariness() > 0.0, "")
	_check("injector: not while she's fine", not Relics.auto_jab(0.9), "")
	_check("injector: fires when she's nearly down", Relics.auto_jab(0.1) and Vices.stim == "ironskin" and Vices.dependence == 1.0, Vices.stim)
	Vices.stim = ""
	_check("injector: once a run", not Relics.auto_jab(0.1), "")
	Relics.run_over(state, 60.0)

	# Givers under Mature: Rook and Dutch at the bar.
	var runs_was := Relics.runs
	Relics.owned.erase("rooks_glass")
	Relics.owned.erase("dutchs_deck")
	Relics.runs = 10
	_check("Rook gives first at the bar", Relics.giver_at({"id": "shop_bar"}, state) == "rook", "")
	Relics.gain("rooks_glass")
	_check("then Dutch", Relics.giver_at({"id": "shop_bar"}, state) == "dutch", "")
	Relics.runs = runs_was

	# Teen again: the Mature-only ones do nothing.
	Relics.worn = ["rooks_glass", "censer"]
	ContentRating.set_rating("T", false)
	Vices.reset()
	Relics.run_started()
	_check("Teen: Mature-only relics do nothing", Relics.notice_scale() == 1.0 and Relics.damage_out() == 1.0 and Relics.hud_text() == "", Relics.hud_text())
	Relics.run_over(state, 60.0)
	_check("Teen: no tab", Relics.scrap_owed == 0, Relics.scrap_owed)
	Relics.worn = []
	Relics.fever = false
	Relics.pills = 0


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
	await _ticks(1)
	_check("HUD names them", run_node.hud.build_label.text.contains("MOM'S LOCKET"), run_node.hud.build_label.text)
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
