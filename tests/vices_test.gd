extends SceneTree
## Headless test for the Rusted Halo's vices (vices.gd, scrapjack.gd,
## bar_screen.gd): drinks cost scrap and add buzz, Rook cuts Eco off, water
## sobers her up, buzz wears off over time, effects (blur, sway, spread,
## numbness) only show under Mature and grow with the buzz, and Scrapjack
## counts hands right, settles every outcome and moves the scrap both ways.
## Run: godot --headless --path . -s res://tests/vices_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Scrapjack := preload("res://scripts/hub/scrapjack.gd")
const BarScreen := preload("res://scripts/hub/bar_screen.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const StimScreen := preload("res://scripts/hub/stim_screen.gd")
const HushScreen := preload("res://scripts/hub/hush_screen.gd")
const ARMORY_PATH := "user://test_vices_armory.cfg"
const VICES_PATH := "user://test_vices.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for p in [ARMORY_PATH, VICES_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Vices.open(VICES_PATH)
	var old_rating := ContentRating.current()
	ContentRating.set_rating("M", false)
	Vices.reset()

	# Catalogue.
	for id in Vices.ORDER:
		_check("%s is on the menu" % id, Vices.DRINKS.has(id), id)
		var cost := Vices.cost(id)
		_check("%s costs only scrap" % id, cost.keys().all(func(m): return m == "scrap"), cost)
	_check("water is free and sobers", Vices.cost("water").is_empty() and Vices.DRINKS["water"]["buzz"] < 0.0, Vices.DRINKS["water"])

	# Sober: no effects.
	_check("sober: no effect", Vices.effect() == 0.0, Vices.effect())
	_check("sober: no sway", Vices.sway(3.0) == Vector2.ZERO, Vices.sway(3.0))
	_check("sober: full damage", Vices.damage_scale() == 1.0, Vices.damage_scale())

	# Drinking.
	Vices.drink("lager")
	var one := Vices.effect()
	_check("a lager adds buzz", is_equal_approx(Vices.buzz, 1.0), Vices.buzz)
	_check("a lager is a light haze", one > 0.0 and one < 0.4, one)
	Vices.drink("shine")
	var three := Vices.effect()
	_check("more drink, more effect", three > one, [one, three])
	_check("numb when drunk", Vices.damage_scale() < 1.0 and Vices.damage_scale() >= 1.0 - Vices.NUMB, Vices.damage_scale())
	var peak := 0.0
	for i in 200:
		peak = maxf(peak, Vices.sway(i * 0.1).length())
	_check("aim drifts when drunk", peak > 0.5, peak)
	_check("drift stays within a few degrees", peak < Vices.SWAY_DEG.length() * 1.5, peak)
	_check("named state", Vices.state_name() != "", Vices.state_name())

	# Teen hides it all.
	ContentRating.set_rating("T", false)
	_check("teen: bar closed", not Vices.allowed(), Vices.allowed())
	_check("teen: no effect while buzzed", Vices.effect() == 0.0 and Vices.sway(2.0) == Vector2.ZERO, Vices.effect())
	_check("teen: full damage", Vices.damage_scale() == 1.0, Vices.damage_scale())
	ContentRating.set_rating("M", false)

	# Cut off.
	Vices.drink("shine")
	_check("cut off near the top", Vices.cut_off(), Vices.buzz)
	_check("Rook won't pour more", not Vices.drink("lager"), Vices.buzz)
	_check("buzz capped", Vices.buzz <= Vices.MAX_BUZZ, Vices.buzz)
	var before := Vices.buzz
	_check("water still pours", Vices.drink("water") and Vices.buzz < before, Vices.buzz)

	# Wears off.
	Vices.tick(1.0 / Vices.WEAR_OFF)
	_check("a minute takes a drink off", is_equal_approx(Vices.buzz, before - 1.0 - 1.0), Vices.buzz)
	Vices.tick(3600.0)
	_check("wears off to sober", Vices.buzz == 0.0 and Vices.effect() == 0.0, Vices.buzz)

	# Hand totals.
	var c := func(r: String) -> Dictionary: return {"rank": r, "suit": "♠"}
	_check("A+K is 21", Scrapjack.total([c.call("A"), c.call("K")]) == 21, 0)
	_check("A+A+9 is 21", Scrapjack.total([c.call("A"), c.call("A"), c.call("9")]) == 21, Scrapjack.total([c.call("A"), c.call("A"), c.call("9")]))
	_check("A+9+5 is 15", Scrapjack.total([c.call("A"), c.call("9"), c.call("5")]) == 15, 0)
	_check("K+Q+5 busts", Scrapjack.total([c.call("K"), c.call("Q"), c.call("5")]) == 25, 0)
	_check("A+K natural", Scrapjack.is_natural([c.call("A"), c.call("K")]), 0)

	# Payouts.
	var g := Scrapjack.new(7)
	g.bet = 10
	for pair in [["natural", 25], ["win", 20], ["dealer_bust", 20], ["push", 10], ["lose", 0], ["bust", 0]]:
		g.outcome = pair[0]
		_check("%s pays %d" % pair, g.payout() == pair[1], g.payout())

	# A full deck, and many hands: every one settles legally.
	_check("52 cards", g.deck.size() == 52, g.deck.size())
	var seen := {}
	for i in 400:
		g.deal(10)
		if i % 3 == 0 and g.can_double():
			g.double_down()
		while g.state == Scrapjack.State.PLAYING:
			if Scrapjack.total(g.player) < 15:
				g.hit()
			else:
				g.stand()
		seen[g.outcome] = true
		if g.outcome in ["win", "push", "lose"]:
			_check_quiet("dealer stands on 17+", Scrapjack.total(g.dealer) >= Scrapjack.DEALER_STANDS and Scrapjack.total(g.dealer) <= 21, g.dealer)
		if g.outcome == "bust":
			_check_quiet("bust is over 21", Scrapjack.total(g.player) > 21, g.player)
	for o in ["natural", "win", "push", "lose", "bust", "dealer_bust"]:
		_check("outcome %s happens" % o, seen.has(o), seen.keys())

	# The bar screen moves scrap.
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash["scrap"] = 100
	var bar := BarScreen.new(armory, 11)
	root.add_child(bar)
	Vices.reset()
	_check("order a lager", bar.order("lager") and armory.amount("scrap") == 100 - 6, armory.amount("scrap"))
	_check("lager went down", Vices.buzz > 0.0, Vices.buzz)
	bar.set_tab("cards")
	bar.set_bet(1)
	var start: int = armory.amount("scrap")
	_check("deal takes the bet", bar.deal(), start)
	if bar.game.state == Scrapjack.State.PLAYING:
		_check("bet on the table", armory.amount("scrap") == start - 15, armory.amount("scrap"))
		bar.stand()
	_check("hand settled", bar.game.state == Scrapjack.State.DONE, bar.game.state)
	_check("scrap settles with the payout", armory.amount("scrap") == start - 15 + bar.game.payout(), [armory.amount("scrap"), bar.game.payout()])
	_check("net tracks the table", bar.net == bar.game.payout() - 15, bar.net)
	_check("saved", Armory.open(ARMORY_PATH).amount("scrap") == armory.amount("scrap"), Armory.open(ARMORY_PATH).amount("scrap"))
	armory.stash["scrap"] = 3
	_check("can't bet what she hasn't got", not bar.deal(), armory.amount("scrap"))
	_check("can't buy a drink broke", not bar.order("shine"), armory.amount("scrap"))
	_check("water's still free", bar.order("water"), 0)
	bar.free()

	_smokes_and_stims()
	_hush()

	Vices.reset()
	ContentRating.set_rating(old_rating, false)
	for p in [ARMORY_PATH, VICES_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("vices_test: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(1 if failures > 0 else 0)


## Smokes from the bar, stims from Sal's hatch: effects, crash, cravings, saving.
func _smokes_and_stims() -> void:
	Vices.reset()
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash = {"scrap": 200, "alloy": 20, "circuits": 2, "lock_cores": 0}
	var bar := BarScreen.new(armory, 3)
	root.add_child(bar)
	_check("no smokes, can't light", not Vices.light_up(), Vices.smokes)
	_check("buy a pack", bar.order("smokes") and Vices.smokes == 5 and armory.amount("scrap") == 190, [Vices.smokes, armory.amount("scrap")])
	bar.free()
	_check("light up", Vices.light_up() and Vices.calm() and Vices.smokes == 4, Vices.smokes)
	_check("one at a time", not Vices.light_up(), Vices.smokes)
	_check("smoking slows healing", Vices.regen_scale() < 1.0, Vices.regen_scale())
	_check("smoking tightens the cone", Vices.spread_scale() < 1.0, Vices.spread_scale())
	_check("Mom will smell it", Vices.smoked, Vices.smoked)
	Vices.buzz = 3.0
	var calm_sway := 0.0
	for i in 100:
		calm_sway = maxf(calm_sway, Vices.sway(i * 0.1).length())
	Vices.smoke_left = 0.0
	var raw_sway := 0.0
	for i in 100:
		raw_sway = maxf(raw_sway, Vices.sway(i * 0.1).length())
	_check("a smoke steadies drunk aim", calm_sway < raw_sway * 0.6, [calm_sway, raw_sway])
	Vices.buzz = 0.0

	var hatch := StimScreen.new(armory)
	root.add_child(hatch)
	_check("buy redline", hatch.buy("redline") and Vices.belt == ["redline"], Vices.belt)
	_check("buy ironskin", hatch.buy("ironskin") and armory.amount("alloy") == 15, armory.amount("alloy"))
	_check("buy deadeye", hatch.buy("deadeye"), Vices.belt)
	_check("belt holds three", not hatch.buy("redline") and Vices.belt.size() == Vices.BELT_SIZE, Vices.belt)
	hatch.free()

	Vices.open(VICES_PATH)
	_check("smokes and belt saved", Vices.smokes == 4 and Vices.belt == ["redline", "ironskin", "deadeye"], [Vices.smokes, Vices.belt])

	_check("jab redline", Vices.jab() == "redline" and Vices.speed_scale() > 1.2, Vices.speed_scale())
	_check("one stim at a time", Vices.jab() == "", Vices.stim)
	Vices.tick(Vices.STIMS["redline"]["time"] + 0.1)
	_check("crash after", Vices.crashing() and Vices.speed_scale() < 1.0 and Vices.damage_scale() > 1.0, [Vices.speed_scale(), Vices.damage_scale()])
	_check("crash hazes the view", Vices.haze() > 0.0, Vices.haze())
	_check("jab ironskin through the crash", Vices.jab() == "ironskin" and not Vices.crashing() and Vices.damage_scale() < 0.7, Vices.damage_scale())
	Vices.tick(20.0)
	_check("deadeye steadies everything", Vices.jab() == "deadeye" and Vices.sway(1.0) == Vector2.ZERO and Vices.spread_scale() < 0.5, Vices.spread_scale())
	Vices.tick(40.0)
	_check("crash wears off", not Vices.crashing() and Vices.stim == "", Vices.crash_left)
	_check("three jabs, three dependence", is_equal_approx(Vices.dependence, 3.0), Vices.dependence)
	_check("the shakes", Vices.craving() > 0.0 and Vices.haze() > 0.0 and Vices.state_name().contains("Shakes"), Vices.state_name())
	Vices.run_over()
	_check("no clean-run credit for a jabbed run", is_equal_approx(Vices.dependence, 3.0), Vices.dependence)
	Vices.run_over()
	_check("a clean run wears it down", Vices.dependence < 3.0 and Vices.craving() == 0.0, Vices.dependence)

	ContentRating.set_rating("T", false)
	Vices.belt = ["redline"]
	Vices.smoke_left = 0.0
	_check("teen: no jabs", Vices.jab() == "", Vices.stim)
	_check("teen: no smokes", not Vices.light_up(), Vices.smokes)
	_check("teen: nothing on the HUD", Vices.pockets_text() == "" and Vices.state_name() == "", Vices.pockets_text())
	ContentRating.set_rating("M", false)
	_check("mature: pockets on the HUD", Vices.pockets_text().contains("[B]") and Vices.pockets_text().contains("[N]"), Vices.pockets_text())


## Marrow's Hush: bonuses, his Hold, the trance, Ophelia and Mom paying for
## it, and walking away.
func _hush() -> void:
	Vices.reset()
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash = {"scrap": 400, "alloy": 20, "circuits": 10, "lock_cores": 0}
	var talks := ConfigFile.new()
	talks.set_value("ophelia", "affection", 40)
	talks.set_value("mom", "bond", 30)
	var den := HushScreen.new(armory, talks)
	root.add_child(den)
	_check("a dose", den.take() and Vices.dosed and is_equal_approx(Vices.hold, Vices.HOLD_PER_DOSE), Vices.hold)
	_check("costs scrap and a circuit", armory.amount("scrap") == 360 and armory.amount("circuits") == 9, armory.stash)
	_check("Ophelia feels it", int(talks.get_value("ophelia", "affection")) == 40 + Vices.DOSE_ROMANCE, talks.get_value("ophelia", "affection"))
	_check("Mom feels it", int(talks.get_value("mom", "bond")) == 30 + Vices.DOSE_BOND, talks.get_value("mom", "bond"))
	_check("one dose waiting at a time", not den.take(), Vices.hold)
	_check("no bonus before the run", Vices.damage_out() == 1.0, Vices.damage_out())
	Vices.run_started()
	_check("Hush in her on the run", Vices.hush() > 0.0 and not Vices.dosed, Vices.hush())
	_check("hits harder", Vices.damage_out() > 1.2, Vices.damage_out())
	_check("heals faster", Vices.regen_scale() > 1.0, Vices.regen_scale())
	_check("harder to notice", Vices.notice_scale() < 0.8, Vices.notice_scale())
	_check("HUD says Hushed", Vices.state_name().contains("Hushed"), Vices.state_name())
	Vices.run_over()
	_check("a Hush run ends at his place", Vices.trance and Vices.hush() == 0.0, Vices.trance)
	_check("his hold stays after a Hush run", is_equal_approx(Vices.hold, Vices.HOLD_PER_DOSE), Vices.hold)
	Vices.trance = false
	Vices.run_started()
	Vices.run_over()
	_check("a clean run: home, hold loosens", not Vices.trance and Vices.hold < Vices.HOLD_PER_DOSE, Vices.hold)

	# Deep in: four more doses.
	for i in 4:
		Vices.dosed = false
		den.take()
	_check("deep hold", Vices.hold >= Vices.TRANCE_HOLD, Vices.hold)
	Vices.dosed = false
	Vices.run_started()
	Vices.run_over()
	_check("deep hold: his place even after a clean run", Vices.trance, Vices.hold)
	Vices.trance = false
	Vices.dosed = false
	den.take()
	talks.set_value("ophelia", "affection", 20)
	talks.set_value("mom", "bond", 10)
	_check("too deep to walk away alone", not Vices.can_walk_away(talks) and not den.walk_away(), Vices.hold)
	talks.set_value("ophelia", "affection", Vices.STRONG_BOND)
	var before := int(talks.get_value("ophelia", "affection"))
	_check("Ophelia pulls her out", den.walk_away() and Vices.hold == 0.0 and den.freed and not Vices.trance, Vices.hold)
	_check("walking away wins her back", int(talks.get_value("ophelia", "affection")) == before + Vices.FREE_ROMANCE, talks.get_value("ophelia", "affection"))
	den.free()
	Vices.open(VICES_PATH)
	_check("hold saved", Vices.hold == 0.0 and Vices.walked_away, [Vices.hold, Vices.walked_away])

	ContentRating.set_rating("T", false)
	_check("teen: no Hush", not Vices.dose(talks) and Vices.hush() == 0.0, Vices.dosed)
	ContentRating.set_rating("M", false)


func _check(label: String, ok: bool, got) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s (got %s)" % [label, str(got)])


func _check_quiet(label: String, ok: bool, got) -> void:
	if not ok:
		failures += 1
		print("  FAIL %s (got %s)" % [label, str(got)])
