extends CanvasLayer
## Pip's booth at the Undertow (downtown.gd): secrets for the next run, one at
## a time, paid from Eco's stash. Every secret turns a page of Pip's ledger,
## the story of what Downtown knows. Opened like a workbench, closed on F or Esc.
##   W/S or Up/Down   pick   Space or Enter   buy   Tab   secrets / ledger

const Armory := preload("res://scripts/hub/armory.gd")
const Downtown := preload("res://scripts/hub/downtown.gd")
const SFX := preload("res://scripts/sfx.gd")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const MAGENTA := Color(1.0, 0.35, 0.8)
const CYAN := Color(0.4, 0.95, 1.0)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)

const HELLO := [
	"Pip: \"Booth's private. Sit, little sister. Everything here costs, even the music.\"",
	"Pip: \"I don't sell lies. Lies are free. You're paying for the truth, and it's priced like it.\"",
	"Pip: \"You came to the club and didn't dance. You really are Mom's.\"",
]
const SOLD := "Pip: \"Memorise it, then forget where you heard it.\""
const CARRYING := "Pip: \"One secret per run. You'll get yourself killed juggling two.\""
const SHORT := "Pip: \"Short. I don't do tabs. Not even for family. Especially not for family.\""

var armory: Armory
var selected := 0
## The ledger tab is open instead of the secrets.
var ledger := false
## What she bought while it was open, for the toast after.
var bought := ""
## Which screen this is (the run manager and hub test read it off any bench).
var kind := "club"
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []

var _talk: Label
var _stash: Label
var _list: VBoxContainer
var _detail: Label


func _init(p_armory: Armory) -> void:
	armory = p_armory
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.02, 0.08, 0.74)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.03, 0.12, 0.96), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("THE UNDERTOW", 30, MAGENTA))
	_talk = _wrap(_text(HELLO[randi() % HELLO.size()], 15, DIM))
	col.add_child(_talk)
	_stash = _text("", 17, INK)
	col.add_child(_stash)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)
	_detail = _wrap(_text("", 16, INK))
	_detail.custom_minimum_size.y = 64
	col.add_child(_detail)
	col.add_child(_wrap(_text("W/S pick   Space buy   Tab secrets / ledger   F or Esc leave", 14, DIM)))
	refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			move(-1)
		KEY_S, KEY_DOWN:
			move(1)
		KEY_TAB, KEY_Q, KEY_E:
			ledger = not ledger
			selected = 0
			SFX.play(self, "ui_hover", -10.0)
			refresh()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			buy()
		_:
			return
	get_viewport().set_input_as_handled()


func move(step: int) -> void:
	var count: int = Downtown.SECRET_ORDER.size() if not ledger else maxi(Downtown.pages(), 1)
	selected = posmod(selected + step, count)
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Buys the picked secret. Returns whether it sold.
func buy() -> bool:
	if ledger:
		return false
	var id: String = Downtown.SECRET_ORDER[selected]
	if Downtown.secret() != "":
		_say(CARRYING)
	elif not Downtown.buy_secret(armory, id):
		_say(SHORT)
	else:
		bought = id
		_say(SOLD)
		SFX.play(self, "ui_confirm", -6.0)
		refresh()
		return true
	SFX.play(self, "ui_error", -4.0)
	refresh()
	return false


func refresh() -> void:
	if _list == null:
		return
	_stash.text = "SCRAP %d    ALLOY %d    CIRCUITS %d" % [armory.amount("scrap"), armory.amount("alloy"), armory.amount("circuits")]
	for c in _list.get_children():
		c.queue_free()
	var carrying := Downtown.secret()
	if ledger:
		var pages := Downtown.pages()
		if pages == 0:
			_detail.text = "Pip keeps her ledger shut. Buy a secret and she turns a page."
			return
		for i in pages:
			_list.add_child(_text(("> " if i == selected else "   ") + "Page %d" % (i + 1), 18, MAGENTA if i == selected else INK))
		_detail.text = "Pip: \"%s\"" % Downtown.LEDGER[selected]
		return
	for i in Downtown.SECRET_ORDER.size():
		var id: String = Downtown.SECRET_ORDER[i]
		var s: Dictionary = Downtown.SECRETS[id]
		var tag := "   (carrying)" if id == carrying else ""
		var color := CYAN if i == selected else (GOOD if id == carrying else INK)
		_list.add_child(_text(("> " if i == selected else "   ") + "%s   %s%s" % [s["name"], cost_text(s["cost"]), tag], 18, color))
	var pick: Dictionary = Downtown.SECRETS[Downtown.SECRET_ORDER[selected]]
	_detail.text = pick["blurb"]
	if carrying != "" and carrying != Downtown.SECRET_ORDER[selected]:
		_detail.text += "\nYou're already carrying the %s." % Downtown.SECRETS[carrying]["name"].to_lower()


static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)


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
