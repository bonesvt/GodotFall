extends CanvasLayer
## The Velvet Ace's screen (downtown.gd): the Gilded Reels, Pip's slot
## machine. Bets come straight out of Eco's scrap and wins go straight back,
## like the Halo's Scrapjack. Mature only: under Teen the run manager gives
## Eco's lines at the door instead.
##   1-4 bet size   Space spin   F or Esc leave

const Armory := preload("res://scripts/hub/armory.gd")
const Downtown := preload("res://scripts/hub/downtown.gd")
const SFX := preload("res://scripts/sfx.gd")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const GOLD := Color(1.0, 0.78, 0.35)
const WINE := Color(0.95, 0.3, 0.45)
const GOOD := Color(0.55, 1.0, 0.6)

const HELLO := [
	"Pip: \"Little sister. The machines are honest. I'm not. Pick one of us.\"",
	"Pip: \"House rules: no crying on the felt, no titans in the lobby.\"",
	"Pip: \"Mom thinks you're birdwatching. I think you're losing my money.\"",
]
const WIN := "Pip: \"Look at that. Don't spend it all on bullets.\""
const BIG_WIN := "Pip: \"Starlings. All three. ...Fine. The house remembers that.\""
const LOSE := ["Pip: \"The house thanks you.\"", "Pip: \"Again? You get that from Dad.\"", "Pip: \"Close. Close doesn't pay.\""]
const BROKE := "Pip: \"Credit's for people I don't love. Come back with scrap.\""

var armory: Armory
var rng := RandomNumberGenerator.new()
var bet_index := 0
var reels: Array = ["starling", "starling", "starling"]
## Scrap won (or lost, negative) while the screen was open.
var net := 0
var spins := 0
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []

var _talk: Label
var _scrap: Label
var _reels: HBoxContainer
var _bet: Label
var _hint: Label


func _init(p_armory: Armory, seed_value := 0) -> void:
	armory = p_armory
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.02, 0.04, 0.74)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.16, 0.03, 0.06, 0.96), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_text("THE VELVET ACE", 30, GOLD))
	_talk = _wrap(_text(HELLO[randi() % HELLO.size()], 15, DIM))
	col.add_child(_talk)
	_scrap = _text("", 18, INK)
	col.add_child(_scrap)
	col.add_child(_text("THE GILDED REELS", 14, DIM))
	_reels = HBoxContainer.new()
	_reels.add_theme_constant_override("separation", 10)
	col.add_child(_reels)
	_bet = _text("", 17, GOLD)
	col.add_child(_bet)
	var pays := []
	for s in Downtown.SYMBOLS:
		pays.append("%s x%d" % [Downtown.SYMBOL_TEXT[s], Downtown.PAYS[s]])
	col.add_child(_wrap(_text("Three of a kind: " + "   ".join(pays) + "\nTwo cherries anywhere: your bet back.", 14, DIM)))
	_hint = _wrap(_text("1-4 bet   Space spin   F or Esc leave", 14, DIM))
	col.add_child(_hint)
	refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_bet(event.keycode - KEY_1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			spin()
		_:
			return
	get_viewport().set_input_as_handled()


func set_bet(index: int) -> void:
	bet_index = clampi(index, 0, Downtown.BETS.size() - 1)
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Pulls the lever on the picked bet. Returns what it paid (-1 if she
## couldn't cover the bet).
func spin() -> int:
	var bet: int = Downtown.BETS[bet_index]
	if armory.amount("scrap") < bet:
		_say(BROKE)
		SFX.play(self, "ui_error", -4.0)
		refresh()
		return -1
	armory.stash["scrap"] = armory.amount("scrap") - bet
	reels = Downtown.spin(rng)
	var back := Downtown.payout(reels, bet)
	armory.stash["scrap"] = armory.amount("scrap") + back
	armory.save()
	net += back - bet
	spins += 1
	if reels.count("starling") == 3:
		_say(BIG_WIN)
	elif back > bet:
		_say(WIN)
	else:
		_say(LOSE[spins % LOSE.size()])
	SFX.play(self, "ui_confirm" if back > bet else "cloth_2", -6.0)
	refresh()
	return back


func refresh() -> void:
	if _scrap == null:
		return
	_scrap.text = "SCRAP %d" % armory.amount("scrap")
	for c in _reels.get_children():
		c.queue_free()
	for s in reels:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(Color(0.95, 0.9, 0.8), 8, 8))
		p.custom_minimum_size = Vector2(150, 90)
		var l := _text(Downtown.SYMBOL_TEXT[s], 22, WINE if s in ["cherry", "starling"] else Color(0.12, 0.08, 0.08))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_reels.add_child(p)
	var tally := ""
	if net != 0:
		tally = "    Tonight: %s%d scrap" % ["+" if net > 0 else "", net]
	_bet.text = "Bet: %d scrap%s" % [Downtown.BETS[bet_index], tally]
	_bet.add_theme_color_override("font_color", GOOD if net > 0 else GOLD)


func _say(line: String) -> void:
	if _talk != null:
		_talk.text = line


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(552, 0)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
