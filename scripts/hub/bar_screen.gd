extends CanvasLayer
## The Rusted Halo's screen (vices.gd): drinks at the bar from Rook, and
## Scrapjack (scrapjack.gd) against Dutch at the back table. Everything costs
## scrap from Eco's stash (armory.gd); Scrapjack winnings go straight back in.
## Mature only: the run manager only opens it under content rating "M".
## Opened like a workbench (pausing the hub), closed on F or Esc.
##   Tab               drinks / cards
##   Drinks:  W/S pick   Space order
##   Cards:   1-4 bet size   Space deal   H hit   S stand   D double down

const Armory := preload("res://scripts/hub/armory.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const Scrapjack := preload("res://scripts/hub/scrapjack.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const AMBER := Color(1.0, 0.72, 0.35)
const MAGENTA := Color(1.0, 0.4, 0.75)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const BETS := [5, 15, 30, 60]
const TABS := ["drinks", "cards"]
## The bar menu: Rook's drinks, then a pack of smokes.
static var MENU: Array = Vices.ORDER + ["smokes"]

const ROOK_HELLO := [
	"Rook: \"Eco. You look like hell. Sit.\"",
	"Rook: \"Your dad drank Rust Buckets. Two, never three. Then he'd go home.\"",
	"Rook: \"Colony boys were in earlier. I spat in every one of their drinks. Not yours.\"",
	"Rook: \"No tab. No credit. No crying at my bar. ...Okay, a little crying.\"",
]
const ROOK_POUR := {
	"lager": ["Rook: \"Halo Lager. Don't ask what's in it, and I won't ask where you got the scrap.\"", "Rook: \"Lager. Cold as I could get it, which isn't very.\""],
	"rust_bucket": ["Rook: \"A Rust Bucket. Your old man's drink. Don't make that face.\"", "Rook: \"Rust Bucket. Sip it. It bites back.\""],
	"shine": ["Rook: \"Shine. You'll see the Precursors in a minute. Say hi for me.\"", "Rook: \"That glow? Don't worry about the glow.\""],
	"water": ["Rook: \"Water. Smartest thing you've ordered all night.\"", "Rook: \"Drink it all. Slowly.\""],
}
const ROOK_CUT_OFF := "Rook: \"No. Hell no. You can barely find your own face. Water or the door.\""
const ROOK_SMOKES := "Rook: \"Night Owls. Your mother would kill me. B to light one, kid.\""
const ROOK_SMOKES_FULL := "Rook: \"You've got enough on you to smoke out a titan bay. Come back when you're low.\""
const ROOK_BROKE := "Rook: \"Scrap first, kid. This isn't a charity, it's a bar.\""
const DUTCH := {
	"deal": "Dutch: \"Cards are honest. People aren't. Place your bet.\"",
	"natural": "Dutch: \"Blackjack. Damn it, kid.\"",
	"win": "Dutch: \"Yours. Don't get used to it.\"",
	"dealer_bust": "Dutch: \"Bust. Hell. Take it.\"",
	"push": "Dutch: \"Push. Nobody bleeds.\"",
	"lose": "Dutch: \"House takes it. House always takes it.\"",
	"bust": "Dutch: \"Over. Greedy. Like her father.\"",
	"broke": "Dutch: \"Come back when your pockets rattle.\"",
}

var armory: Armory
var kind := "bar"
var game: Scrapjack
var tab := "drinks"
var selected := 0
var bet_index := 0
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []
## Scrap Eco won (or lost, negative) at the table while the screen was open.
var net := 0

var _stash: HBoxContainer
var _buzz: Label
var _tabs: HBoxContainer
var _drinks: VBoxContainer
var _cards: VBoxContainer
var _talk: Label
var _detail: Label
var _hint: Label
var _dealer_row: HBoxContainer
var _player_row: HBoxContainer
var _dealer_total: Label
var _player_total: Label
var _bet: Label
var _buttons: HBoxContainer


func _init(p_armory: Armory, seed_value := 0) -> void:
	armory = p_armory
	game = Scrapjack.new(seed_value)
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.09, 0.04, 0.03, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.17, 0.08, 0.06, 0.96), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(640, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("THE RUSTED HALO", 30, AMBER))
	_talk = _wrap(_text(ROOK_HELLO[randi() % ROOK_HELLO.size()], 15, DIM))
	col.add_child(_talk)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_buzz = _text("", 16, MAGENTA)
	col.add_child(_buzz)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	col.add_child(_tabs)

	_drinks = VBoxContainer.new()
	_drinks.add_theme_constant_override("separation", 2)
	col.add_child(_drinks)

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	col.add_child(_cards)
	_cards.add_child(_text("DUTCH", 14, DIM))
	_dealer_row = HBoxContainer.new()
	_dealer_row.add_theme_constant_override("separation", 6)
	_dealer_row.custom_minimum_size = Vector2(0, 92)
	_cards.add_child(_dealer_row)
	_dealer_total = _text("", 15, DIM)
	_cards.add_child(_dealer_total)
	_cards.add_child(_text("ECO", 14, DIM))
	_player_row = HBoxContainer.new()
	_player_row.add_theme_constant_override("separation", 6)
	_player_row.custom_minimum_size = Vector2(0, 92)
	_cards.add_child(_player_row)
	_player_total = _text("", 15, INK)
	_cards.add_child(_player_total)
	_bet = _text("", 17, AMBER)
	_cards.add_child(_bet)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_cards.add_child(_buttons)

	_detail = _wrap(_text("", 16, INK))
	_detail.custom_minimum_size.y = 44
	col.add_child(_detail)
	_hint = _wrap(_text("", 14, DIM))
	col.add_child(_hint)
	refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		set_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
	elif tab == "drinks":
		match event.keycode:
			KEY_W, KEY_UP:
				select(selected - 1)
			KEY_S, KEY_DOWN:
				select(selected + 1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				order(MENU[selected])
			_:
				return
	else:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_bet(event.keycode - KEY_1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				deal()
			KEY_H:
				hit()
			KEY_S:
				stand()
			KEY_D:
				double_down()
			_:
				return
	get_viewport().set_input_as_handled()


func set_tab(t: String) -> void:
	tab = t
	SFX.play(self, "ui_hover", -10.0)
	refresh()


func select(index: int) -> void:
	selected = posmod(index, MENU.size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


# --- drinks -------------------------------------------------------------------

## Orders a drink: pays for it and pours it. Returns whether it went down.
func order(id: String) -> bool:
	if id == "smokes":
		return buy_smokes()
	var ok := false
	if Vices.DRINKS[id]["buzz"] > 0.0 and Vices.cut_off():
		_say(ROOK_CUT_OFF)
	elif not armory.can_afford(Vices.cost(id)):
		_say(ROOK_BROKE)
	else:
		armory._spend(Vices.cost(id))
		armory.save()
		Vices.drink(id)
		var lines: Array = ROOK_POUR[id]
		_say(lines[Vices.drinks_had % lines.size()])
		ok = true
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	refresh()
	return ok


## A pack of Night Owls. Returns whether she bought one.
func buy_smokes() -> bool:
	var ok := false
	if Vices.smokes >= Vices.MAX_SMOKES:
		_say(ROOK_SMOKES_FULL)
	elif not armory.can_afford(Vices.PACK["cost"]):
		_say(ROOK_BROKE)
	else:
		armory._spend(Vices.PACK["cost"])
		armory.save()
		Vices.buy_pack()
		_say(ROOK_SMOKES)
		ok = true
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	refresh()
	return ok


# --- Scrapjack ----------------------------------------------------------------

func set_bet(index: int) -> void:
	if game.state == Scrapjack.State.PLAYING:
		return
	bet_index = clampi(index, 0, BETS.size() - 1)
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Deals a new hand on the picked bet. Returns false if she can't cover it.
func deal() -> bool:
	if game.state == Scrapjack.State.PLAYING:
		return false
	var amount: int = BETS[bet_index]
	if armory.amount("scrap") < amount:
		_say(DUTCH["broke"])
		SFX.play(self, "ui_error", -4.0)
		refresh()
		return false
	_take(amount)
	game.deal(amount)
	SFX.play(self, "cloth_2", -6.0)
	_after_move()
	return true


func hit() -> void:
	if game.state != Scrapjack.State.PLAYING:
		return
	game.hit()
	SFX.play(self, "cloth_2", -8.0)
	_after_move()


func stand() -> void:
	if game.state != Scrapjack.State.PLAYING:
		return
	game.stand()
	_after_move()


func double_down() -> void:
	if not game.can_double() or armory.amount("scrap") < game.bet:
		return
	_take(game.bet)
	game.double_down()
	SFX.play(self, "cloth_2", -6.0)
	_after_move()


func _after_move() -> void:
	if game.state == Scrapjack.State.DONE:
		var back := game.payout()
		if back > 0:
			armory.stash["scrap"] = armory.amount("scrap") + back
			armory.save()
		net += back
		_say(DUTCH[game.outcome])
		SFX.play(self, "ui_confirm" if back > game.bet else "ui_hover", -6.0)
	else:
		_say(DUTCH["deal"])
	refresh()


## Scrap on the table: straight out of the stash (not armory.bank, so her
## lifetime haul is untouched).
func _take(amount: int) -> void:
	armory.stash["scrap"] = armory.amount("scrap") - amount
	armory.save()
	net -= amount


# --- view ---------------------------------------------------------------------

func refresh() -> void:
	if _stash == null:
		return
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m]))
	var state := Vices.state_name()
	_buzz.text = "Sober" if state == "" else "%s  %s  (wears off in about %d min)" % [state, _meter(), ceili(Vices.buzz / Vices.WEAR_OFF / 60.0)]
	for c in _tabs.get_children():
		c.queue_free()
	for t in TABS:
		_tabs.add_child(_tab_view(t))
	_drinks.visible = tab == "drinks"
	_cards.visible = tab == "cards"
	if tab == "drinks":
		_refresh_drinks()
		_hint.text = "W/S pick   Space order   Tab cards   F or Esc leave\nDrinks blur her eyes and shake her aim, but dull the pain. They wear off as she goes, run or no run."
	else:
		_refresh_cards()
		_hint.text = "1-4 bet   Space deal   H hit   S stand   D double down   Tab drinks   F or Esc leave"


func _refresh_drinks() -> void:
	for c in _drinks.get_children():
		c.queue_free()
	for i in MENU.size():
		_drinks.add_child(_drink_row(i))
	var id: String = MENU[selected]
	_detail.text = Vices.PACK["blurb"] if id == "smokes" else Vices.DRINKS[id]["blurb"]


func _drink_row(i: int) -> PanelContainer:
	var id: String = MENU[i]
	var on := i == selected
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.72, 0.35, 0.2) if on else Color(0, 0, 0, 0), 10, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var smokes := id == "smokes"
	var label := _text(Vices.PACK["name"] if smokes else Vices.drink_name(id), 17, AMBER if on else INK)
	label.custom_minimum_size = Vector2(260, 0)
	line.add_child(label)
	var b: float = 0.0 if smokes else Vices.DRINKS[id]["buzz"]
	var kick := _text("have %d" % Vices.smokes if smokes else (("+" if b > 0 else "") + "%.1f buzz" % b), 15, DIM if smokes else (MAGENTA if b > 0 else GOOD))
	kick.custom_minimum_size = Vector2(110, 0)
	line.add_child(kick)
	var cost: Dictionary = Vices.PACK["cost"] if smokes else Vices.cost(id)
	var r := _text("on the house" if cost.is_empty() else Armory.cost_text(cost), 15, GOOD if armory.can_afford(cost) else BAD)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(r)
	panel.gui_input.connect(_on_drink_input.bind(i))
	return panel


func _on_drink_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == selected:
			order(MENU[index])
		else:
			select(index)


func _refresh_cards() -> void:
	for row in [_dealer_row, _player_row]:
		for c in row.get_children():
			c.queue_free()
	var playing := game.state == Scrapjack.State.PLAYING
	if game.player.is_empty():
		_dealer_total.text = ""
		_player_total.text = "No hand yet."
	else:
		for c in game.dealer_shown():
			_dealer_row.add_child(_card_view(c))
		if playing:
			_dealer_row.add_child(_card_back())
		for c in game.player:
			_player_row.add_child(_card_view(c))
		_dealer_total.text = "Shows %d" % Scrapjack.total(game.dealer_shown()) if playing else "Total %d" % Scrapjack.total(game.dealer)
		_player_total.text = "Total %d" % Scrapjack.total(game.player)
	if playing:
		_bet.text = "On the table: %d scrap%s" % [game.bet, "  (doubled)" if game.doubled else ""]
	else:
		var tally := ""
		if net != 0:
			tally = "    Tonight: %s%d scrap" % ["+" if net > 0 else "", net]
		_bet.text = "Bet: %d scrap%s" % [BETS[bet_index], tally]
	for c in _buttons.get_children():
		c.queue_free()
	if playing:
		_buttons.add_child(_button("Hit [H]", hit))
		_buttons.add_child(_button("Stand [S]", stand))
		if game.can_double() and armory.amount("scrap") >= game.bet:
			_buttons.add_child(_button("Double [D]", double_down))
	else:
		for i in BETS.size():
			_buttons.add_child(_button("%d" % BETS[i], set_bet.bind(i), i == bet_index))
		_buttons.add_child(_button("Deal [Space]", deal))
	_detail.text = "Blackjack pays 3 to 2. Dutch stands on 17." if game.player.is_empty() else ""


func _card_view(card: Dictionary) -> PanelContainer:
	var red: bool = card["suit"] in ["♥", "♦"]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.95, 0.91, 0.82), 6, 6))
	p.custom_minimum_size = Vector2(62, 88)
	var l := _text(Scrapjack.card_text(card), 24, Color(0.75, 0.1, 0.12) if red else Color(0.08, 0.06, 0.06))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _card_back() -> PanelContainer:
	var p := PanelContainer.new()
	var box := _box(Color(0.45, 0.1, 0.22), 6, 6)
	box.border_color = AMBER
	box.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(62, 88)
	return p


func _tab_view(t: String) -> PanelContainer:
	var on := t == tab
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(1.0, 0.72, 0.35, 0.28) if on else Color(1, 1, 1, 0.05), 8, 6))
	p.add_child(_text("BAR" if t == "drinks" else "SCRAPJACK", 16, AMBER if on else DIM))
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			set_tab(t))
	return p


func _meter() -> String:
	var n := int(round(Vices.buzz))
	return "●".repeat(n) + "○".repeat(int(Vices.MAX_BUZZ) - n)


func _say(line: String) -> void:
	if _talk != null:
		_talk.text = line


func _button(text: String, call: Callable, on := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	if on:
		b.add_theme_color_override("font_color", AMBER)
	b.pressed.connect(call)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(592, 0)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
