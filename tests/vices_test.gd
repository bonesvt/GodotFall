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
const ARMORY_PATH := "user://test_vices_armory.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARMORY_PATH))
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

	Vices.reset()
	ContentRating.set_rating(old_rating, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARMORY_PATH))
	print("vices_test: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(1 if failures > 0 else 0)


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
