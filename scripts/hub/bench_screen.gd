extends CanvasLayer
## The hub's workbench screens, over a turntable preview. One screen, two
## benches, each with its own tabs (armory.gd holds the rules and prices; the
## gunsmith has its own screen, gunsmith_screen.gd):
##   rack       SIDEARMS      buy guns and pick the one you head out with
##   workshop   LOADOUT       the titan parts a run starts with (Mk I) instead of scrap
##              REFITS        upgrade any part you own, salvaged copies included
## The run manager opens it (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down    pick a row       A/D or Left/Right    browse a row's options
##   Space or Enter    buy / fit / pick                Tab or Q/E    switch tab

const Armory := preload("res://scripts/hub/armory.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")

const TITLES := {"rack": "WEAPON RACK", "workshop": "TITAN WORKSHOP"}
const SUBTITLES := {
	"rack": "Pick what goes in your hand on the next run.",
	"workshop": "Start runs with real parts, and make every copy of a part better.",
}
const TABS := {"rack": ["SIDEARMS"], "workshop": ["LOADOUT", "REFITS"]}
const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const ACCENT := Color(1.0, 0.72, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const SPIN_SPEED := 0.4

var armory: Armory
var kind := "rack"
## What a purchase sounds like at each bench (recordings in assets/audio/sfx).
const CONFIRM_SOUND := {"rack": "reload_in", "workshop": "workbench_ratchet"}
var tab := 0
var selected := 0
## The gun in hand (the rack's preview falls back to it).
var weapon := ""
## Rows: {label, value, note, cost (Dictionary or null), confirm: Callable, step: Callable, preview: Callable}
var rows: Array = []
## Workshop loadout being browsed: slot -> part id.
var browse_parts := {}

var _title: Label
var _tab_label: Label
var _stash: HBoxContainer
## "LEVEL 3   Next: Auto Handgun at level 6", gold for a moment on a level up.
var _level: Label
var _level_flash := 0.0
## Guns unlocked by level ups while this screen was open (for the HUD after).
var unlocked := []
var _list: VBoxContainer
var _detail: Label
var _hint: Label
var _turntable: Node3D
var _camera: Camera3D
var _preview_key := ""
var _spin_hold := 0.0


func _init(p_armory: Armory, p_kind := "rack") -> void:
	armory = p_armory
	kind = p_kind
	weapon = armory.equipped
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.05, 0.6)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 640
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.13, 0.1, 0.08, 0.95), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = _text(TITLES[kind], 30, ACCENT)
	col.add_child(_title)
	col.add_child(_text(SUBTITLES[kind], 15, DIM))
	_level = _text("", 18, ACCENT)
	col.add_child(_level)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_tab_label = _text("", 20, INK)
	col.add_child(_tab_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(552, 96)
	col.add_child(_detail)
	_hint = _text("", 14, DIM)
	col.add_child(_hint)
	refresh()


func _process(delta: float) -> void:
	_spin_hold -= delta
	if _spin_hold <= 0.0 and _turntable != null:
		_turntable.rotate_y(delta * SPIN_SPEED)
	if _level_flash > 0.0:
		_level_flash -= delta
		_level.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.2, 0.5), clampf(_level_flash, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_A, KEY_LEFT:
			step(-1)
		KEY_D, KEY_RIGHT:
			step(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		KEY_TAB:
			if not event.echo:
				switch_tab(1)
		KEY_Q:
			if not event.echo:
				switch_tab(-1)
		KEY_E:
			if not event.echo:
				switch_tab(1)
		_:
			return
	get_viewport().set_input_as_handled()


# --- actions ----------------------------------------------------------------------

func select(index: int) -> void:
	if rows.is_empty():
		return
	selected = posmod(index, rows.size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


func step(dir: int) -> void:
	if rows.is_empty() or not rows[selected].has("step"):
		return
	rows[selected]["step"].call(dir)
	SFX.play(self, "ui_switch", -8.0)
	refresh()


## Buys / fits / picks the selected row. Returns whether it went through.
func confirm() -> bool:
	if rows.is_empty() or not rows[selected].has("confirm"):
		return false
	var before: int = armory.pilot_level()
	var ok: bool = rows[selected]["confirm"].call()
	SFX.play(self, CONFIRM_SOUND[kind] if ok else "ui_error", -4.0)
	var after: int = armory.pilot_level()
	if after > before:
		_level_flash = 1.6
		SFX.play(self, "ui_confirm", -2.0)
		unlocked.append_array(Armory.unlocks_between(before, after))
	refresh()
	return ok


func switch_tab(dir: int) -> void:
	var tabs: Array = TABS[kind]
	tab = posmod(tab + dir, tabs.size())
	selected = 0
	refresh()


# --- rows -------------------------------------------------------------------------

func refresh() -> void:
	rows = _rows()
	selected = clampi(selected, 0, maxi(rows.size() - 1, 0))
	var tabs: Array = TABS[kind]
	var tab_text := "   ".join(tabs.map(func(t): return ("[ %s ]" % t) if t == tabs[tab] else t))
	_tab_label.text = tab_text
	_draw_stash()
	_draw_level()
	for c in _list.get_children():
		c.queue_free()
	for i in rows.size():
		_list.add_child(_row_view(i))
	var row: Dictionary = rows[selected] if not rows.is_empty() else {}
	_detail.text = row.get("note", "")
	_hint.text = "W/S pick   A/D browse   Space buy/fit   %s   F or Esc done" % ("Q/E section" if TABS[kind].size() > 1 else "")
	_update_preview(row)


func _rows() -> Array:
	match [kind, TABS[kind][tab]]:
		["rack", "SIDEARMS"]:
			return _sidearm_rows()
		["workshop", "LOADOUT"]:
			return _loadout_rows()
		["workshop", "REFITS"]:
			return _refit_rows()
	return []


func _sidearm_rows() -> Array:
	var out := []
	for id in Armory.WEAPONS:
		var w: Dictionary = Armory.WEAPONS[id]
		var owned := armory.owns_weapon(id)
		var locked: bool = armory.level_locked(id)
		var p := armory.weapon_profile(id)
		var row := {
			"label": w["name"],
			"value": "",
			"cost": null if owned or locked else w["cost"],
			"state": "IN HAND" if id == armory.equipped else ("OWNED" if owned else ("LEVEL %d" % Armory.unlock_level(id) if locked else "")),
			"note": "%s\n%s" % [w["desc"], _stat_line(p)],
			"confirm": func(): return armory.buy_weapon(id) and armory.equip(id),
			"profile": p,
		}
		if locked:
			row["note"] = "Unlocks at level %d (you're level %d). Every upgrade you buy raises your level.\n%s" % [
				Armory.unlock_level(id), armory.pilot_level(), row["note"]]
		out.append(row)
	return out


func _loadout_rows() -> Array:
	var out := []
	for slot in TitanParts.SLOTS:
		var id: String = browse_parts.get(slot, armory.titan_loadout[slot])
		var owned := armory.owns_part(slot, id)
		var base := Armory.catalog_part(slot, id)
		var desc := "Scrap: nothing salvaged yet. Caches out there will do better." if id == "scrap" \
				else "%s  Mk I: %s." % [base["desc"], TitanParts.describe(TitanParts.make_part(slot, base, 1))]
		out.append({
			"label": TitanParts.SLOT_NAMES[slot],
			"value": base["name"] + ("" if owned else "  (locked)"),
			"cost": null if owned else Armory.TITAN_PART_COST[slot],
			"state": "STARTS RUNS" if armory.titan_loadout[slot] == id else ("OWNED" if owned else ""),
			"note": desc,
			"step": func(dir): _browse_part(slot, dir),
			"confirm": func(): return armory.set_start_part(slot, id),
		})
	return out


func _browse_part(slot: String, dir: int) -> void:
	var ids: Array = ["scrap"] + TitanParts.CATALOG[slot].map(func(p): return p["id"])
	var at := ids.find(browse_parts.get(slot, armory.titan_loadout[slot]))
	var id: String = ids[posmod(at + dir, ids.size())]
	browse_parts[slot] = id
	if armory.owns_part(slot, id):
		armory.set_start_part(slot, id)


func _refit_rows() -> Array:
	var out := []
	for slot in TitanParts.SLOTS:
		for id in ["scrap"] + TitanParts.CATALOG[slot].map(func(p): return p["id"]):
			if not armory.owns_part(slot, id):
				continue
			var level := armory.refit_level(slot, id)
			var maxed := level >= Armory.MAX_LEVEL
			out.append({
				"label": "%s: %s" % [TitanParts.SLOT_NAMES[slot], Armory.catalog_part(slot, id)["name"]],
				"value": "■".repeat(level) + "□".repeat(Armory.MAX_LEVEL - level),
				"cost": null if maxed else armory.refit_cost(slot, id),
				"note": "+%d%% armour, damage or power on every copy you install, salvaged ones too. Now +%d%%." % [roundi(Armory.REFIT_STEP * 100), roundi(Armory.REFIT_STEP * 100 * level)],
				"confirm": func(): return armory.buy_refit(slot, id),
				"slot": slot, "part": id,
			})
	return out


static func _stat_line(p: Dictionary) -> String:
	var s: Dictionary = p["stats"]
	var line := "Damage %.1f (head x%.2f)   Mag %d   Reload %.2f s   %d shots/s" % [
		s["damage"], s["headshot_multiplier"], s["magazine_size"], s["reload_time"], roundi(1.0 / s["fire_interval"])]
	if s.get("smart_fraction", 0.0) > 0.0:
		line += "\nSmart rounds: %d of every %d" % [roundi(s["smart_fraction"] * s["magazine_size"]), s["magazine_size"]]
	return line


## What changes between two profiles' stats, as "+12% range, -1 mag".
static func _stat_diff(a: Dictionary, b: Dictionary) -> String:
	var names := {"falloff_end": "range", "fire_interval": "time between shots", "recoil_kick": "kick", "bloom_per_shot": "bloom",
			"move_spread": "spread moving", "air_spread": "spread in the air", "magazine_size": "mag", "reload_time": "reload time",
			"base_spread": "base spread", "bloom_recovery": "bloom recovery"}
	var bits := []
	for key in names:
		var x: float = a["stats"][key]
		var y: float = b["stats"][key]
		if is_equal_approx(x, y):
			continue
		if key == "magazine_size":
			bits.append("%+d %s" % [int(y - x), names[key]])
		else:
			bits.append("%+d%% %s" % [roundi((y / x - 1.0) * 100.0), names[key]])
	return "No change from what's fitted." if bits.is_empty() else "vs fitted: " + ", ".join(bits)


# --- drawing ----------------------------------------------------------------------

func _draw_level() -> void:
	var text := "LEVEL %d" % armory.pilot_level()
	for id in unlocked:
		text += "   %s UNLOCKED AT THE RACK" % Armory.WEAPONS[id]["short"]
	var next: String = armory.next_unlock()
	if next != "" and unlocked.is_empty():
		text += "   Next: %s at level %d. Every upgrade raises your level." % [Armory.WEAPONS[next]["name"], Armory.unlock_level(next)]
	_level.text = text


func _draw_stash() -> void:
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		var l := _text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m])
		_stash.add_child(l)


func _row_view(i: int) -> PanelContainer:
	var row: Dictionary = rows[i]
	var on := i == selected
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.72, 0.35, 0.2) if on else Color(0, 0, 0, 0), 10, 6))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var label := _text(row["label"], 18, ACCENT if on else INK)
	label.custom_minimum_size = Vector2(210, 0)
	line.add_child(label)
	var value := _text(row.get("value", ""), 18, INK)
	value.custom_minimum_size = Vector2(200, 0)
	line.add_child(value)
	var right := ""
	var color := DIM
	if row.get("cost") != null:
		var cost: Dictionary = row["cost"]
		right = Armory.cost_text(cost)
		color = GOOD if armory.can_afford(cost) else BAD
	elif row.has("state"):
		right = row["state"]
		color = ACCENT if right in ["FITTED", "IN HAND", "STARTS RUNS"] else DIM
	elif row.has("cost"):
		right = "MAX"
	var r := _text(right, 15, color)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(r)
	panel.gui_input.connect(_on_row_input.bind(i))
	return panel


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if index == selected:
				confirm()
			else:
				select(index)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(index)
			step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(index)
			step(1)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(event.relative.x * 0.01)
		_spin_hold = 3.0


func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.1, 0.09, 0.11), Color(0.3, 0.25, 0.22))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 30.0
	stage.add_child(lamp)
	_turntable = Node3D.new()
	_turntable.rotation.y = 0.6
	stage.add_child(_turntable)
	_camera = Camera3D.new()
	stage.add_child(_camera)
	_frame_camera(kind == "workshop")
	lamp.position = _camera.position * 0.6 + Vector3(0, 1, 0)
	return sub


func _frame_camera(titan: bool) -> void:
	if titan:
		_camera.fov = 38.0
		_camera.look_at_from_position(Vector3(-7.5, 5.8, -15.5), Vector3(0, 3.7, 0))
	else:
		_camera.fov = 30.0
		_camera.look_at_from_position(Vector3(0.0, 0.08, 1.15), Vector3(0, -0.02, 0))


## Shows what the selected row is about: the gun (with the browsed attachment
## on) or the titan you'd start with. Rebuilt only when it changes.
func _update_preview(row: Dictionary) -> void:
	var key := ""
	var make: Callable
	if kind == "workshop":
		var chassis: String = browse_parts.get("chassis", armory.titan_loadout["chassis"])
		var gun: String = browse_parts.get("weapon", armory.titan_loadout["weapon"])
		if row.has("slot"):
			if row["slot"] == "chassis":
				chassis = row["part"]
			elif row["slot"] == "weapon":
				gun = row["part"]
		key = chassis + "/" + gun
		make = func():
			var t := Art.titan(chassis, gun)
			TitanStyle.apply(t, chassis, TitanStyle.load_style(chassis))
			return t
	else:
		var p: Dictionary = row.get("profile", armory.weapon_profile(weapon))
		key = "%s/%s/%s/%d" % [p["id"], p["attachments"], p["finish"]["id"], p["tier"]]
		make = func():
			var g := Weapon.gun_model(p)
			g.position = Vector3(0, 0, -0.06)
			return g
	if key == _preview_key:
		return
	_preview_key = key
	for c in _turntable.get_children():
		c.free()
	_turntable.add_child(make.call())


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
