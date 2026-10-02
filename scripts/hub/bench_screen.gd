extends CanvasLayer
## The hub's workbench screens, over a turntable preview. One screen, three
## benches, each with its own tabs (armory.gd holds the rules and prices):
##   gunsmith   UPGRADES      the gun in hand's own upgrade tracks
##              ATTACHMENTS   muzzle, mag and grip (each a trade-off), and finish
##   rack       SIDEARMS      buy guns and pick the one you head out with
##   workshop   LOADOUT       the titan parts a run starts with (Mk I) instead of scrap
##              REFITS        upgrade any part you own, salvaged copies included
##   suit       SUIT          Eco's suit upgrades, bought in order (armour, a
##                            passive and armour you can see on her, per tier)
## The run manager opens it (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down    pick a row       A/D or Left/Right    browse a row's options
##   Space or Enter    buy / fit / pick                Tab or Q/E    switch tab / gun

const Armory := preload("res://scripts/hub/armory.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")

const TITLES := {"gunsmith": "ECO'S GUNSMITH BENCH", "rack": "WEAPON RACK", "workshop": "TITAN WORKSHOP", "suit": "SUIT LOCKER"}
const SUBTITLES := {
	"gunsmith": "Small steps. Dad's pistol was never about the numbers.",
	"rack": "Pick what goes in your hand on the next run.",
	"workshop": "Start runs with real parts, and make every copy of a part better.",
	"suit": "Armour from the scrap pile. Every tier keeps the last.",
}
const TABS := {"gunsmith": ["UPGRADES", "ATTACHMENTS"], "rack": ["SIDEARMS"], "workshop": ["LOADOUT", "REFITS"], "suit": ["SUIT"]}
const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const ACCENT := Color(1.0, 0.72, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const SPIN_SPEED := 0.4

var armory: Armory
var kind := "gunsmith"
## What a purchase sounds like at each bench (recordings in assets/audio/sfx).
const CONFIRM_SOUND := {"gunsmith": "workbench_tools", "rack": "reload_in", "workshop": "workbench_ratchet", "suit": "workbench_ratchet"}
const ECO := preload("res://assets/models/eco.tscn")
var tab := 0
var selected := 0
## The gun the gunsmith works on (owned guns only).
var weapon := ""
## Rows: {label, value, note, cost (Dictionary or null), confirm: Callable, step: Callable, preview: Callable}
var rows: Array = []
## Gunsmith attachments being browsed: slot -> attachment id (not yet fitted if not owned).
var browse := {}
## Workshop loadout being browsed: slot -> part id.
var browse_parts := {}

var _title: Label
var _tab_label: Label
var _stash: HBoxContainer
var _list: VBoxContainer
var _detail: Label
var _hint: Label
var _turntable: Node3D
var _camera: Camera3D
var _preview_key := ""
var _spin_hold := 0.0


func _init(p_armory: Armory, p_kind := "gunsmith") -> void:
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
				switch_weapon(-1) if kind == "gunsmith" else switch_tab(-1)
		KEY_E:
			if not event.echo:
				switch_weapon(1) if kind == "gunsmith" else switch_tab(1)
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
	var ok: bool = rows[selected]["confirm"].call()
	SFX.play(self, CONFIRM_SOUND[kind] if ok else "ui_error", -4.0)
	refresh()
	return ok


func switch_tab(dir: int) -> void:
	var tabs: Array = TABS[kind]
	tab = posmod(tab + dir, tabs.size())
	selected = 0
	refresh()


func switch_weapon(dir: int) -> void:
	var owned: Array = Armory.WEAPONS.keys().filter(func(id): return armory.owns_weapon(id))
	weapon = owned[posmod(owned.find(weapon) + dir, owned.size())]
	browse.clear()
	refresh()


# --- rows -------------------------------------------------------------------------

func refresh() -> void:
	rows = _rows()
	selected = clampi(selected, 0, maxi(rows.size() - 1, 0))
	var tabs: Array = TABS[kind]
	var tab_text := "   ".join(tabs.map(func(t): return ("[ %s ]" % t) if t == tabs[tab] else t))
	if kind == "gunsmith":
		tab_text = "%s      Q/E  %s" % [tab_text, Armory.WEAPONS[weapon]["name"]]
	_tab_label.text = tab_text
	_draw_stash()
	for c in _list.get_children():
		c.queue_free()
	for i in rows.size():
		_list.add_child(_row_view(i))
	var row: Dictionary = rows[selected] if not rows.is_empty() else {}
	_detail.text = row.get("note", "")
	_hint.text = "W/S pick   A/D browse   Space buy/fit   %s   F or Esc done" % ("Tab section   Q/E gun" if kind == "gunsmith" else ("Q/E section" if TABS[kind].size() > 1 else ""))
	_update_preview(row)


func _rows() -> Array:
	match [kind, TABS[kind][tab]]:
		["gunsmith", "UPGRADES"]:
			return _upgrade_rows()
		["gunsmith", "ATTACHMENTS"]:
			return _attachment_rows()
		["rack", "SIDEARMS"]:
			return _sidearm_rows()
		["workshop", "LOADOUT"]:
			return _loadout_rows()
		["workshop", "REFITS"]:
			return _refit_rows()
		["suit", "SUIT"]:
			return _suit_rows()
	return []


func _upgrade_rows() -> Array:
	var out := []
	var now := armory.weapon_profile(weapon)
	for track in Armory.upgrade_tracks(weapon):
		var level := armory.upgrade_level(weapon, track)
		var most := Armory.max_level(track)
		var maxed := level >= most
		var cost: Dictionary = armory.upgrade_cost(weapon, track)
		var info: Dictionary = Armory.UPGRADES[track]
		out.append({
			"label": info["name"],
			"value": "■".repeat(level) + "□".repeat(most - level),
			"cost": null if maxed else cost,
			"note": "%s.\n%s\nLook: tier %d of %d." % [info["desc"], _stat_line(now), now["tier"], Armory.MODEL_TIERS],
			"confirm": func(): return armory.buy_upgrade(weapon, track),
		})
	return out


func _attachment_rows() -> Array:
	var out := []
	var now := armory.weapon_profile(weapon)
	for slot in Armory.ATTACHMENT_SLOTS:
		var id: String = browse.get(slot, armory.fitted_attachment(weapon, slot))
		var a := Armory.attachment(slot, id)
		var owned := armory.owns_attachment(id)
		var fitted := armory.fitted_attachment(weapon, slot) == id
		var after := _with_attachment(slot, id)
		out.append({
			"label": Armory.SLOT_NAMES[slot],
			"value": a["name"] + ("" if owned else "  (locked)"),
			"cost": null if owned else a["cost"],
			"state": "FITTED" if fitted else ("OWNED" if owned else ""),
			"note": "%s\n%s" % [a["desc"], _stat_diff(now, after)],
			"step": func(dir): _browse_attachment(slot, dir),
			"confirm": func(): return _fit(slot, id),
			"profile": after,
		})
	var fin := armory.finish_of(weapon)
	out.append({
		"label": "Finish",
		"value": Armory.finish(fin)["name"],
		"note": "Paint. Free, and it doesn't change a thing about how it shoots.",
		"step": func(dir): _step_finish(dir),
	})
	return out


func _browse_attachment(slot: String, dir: int) -> void:
	var options: Array = Armory.ATTACHMENTS[slot]
	var at: int = options.map(func(a): return a["id"]).find(browse.get(slot, armory.fitted_attachment(weapon, slot)))
	var id: String = options[posmod(at + dir, options.size())]["id"]
	browse[slot] = id
	# Owned pieces go straight on; locked ones wait for Space.
	if armory.owns_attachment(id):
		armory.fit(weapon, slot, id)


func _fit(slot: String, id: String) -> bool:
	if armory.fitted_attachment(weapon, slot) == id:
		return true
	return armory.fit(weapon, slot, id)


func _step_finish(dir: int) -> void:
	var ids: Array = Armory.FINISHES.map(func(f): return f["id"])
	armory.set_finish(weapon, ids[posmod(ids.find(armory.finish_of(weapon)) + dir, ids.size())])


func _sidearm_rows() -> Array:
	var out := []
	for id in Armory.WEAPONS:
		var w: Dictionary = Armory.WEAPONS[id]
		var owned := armory.owns_weapon(id)
		var p := armory.weapon_profile(id)
		out.append({
			"label": w["name"],
			"value": "",
			"cost": null if owned else w["cost"],
			"state": "IN HAND" if id == armory.equipped else ("OWNED" if owned else ""),
			"note": "%s\n%s" % [w["desc"], _stat_line(p)],
			"confirm": func(): return armory.buy_weapon(id) and armory.equip(id),
			"profile": p,
		})
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


func _suit_rows() -> Array:
	var out := []
	for i in Armory.SUIT_TIERS.size():
		var t: Dictionary = Armory.SUIT_TIERS[i]
		var tier := i + 1
		var owned := armory.suit_tier >= tier
		var next := armory.suit_tier == tier - 1
		var row := {
			"label": "%d  %s" % [tier, t["name"]],
			"value": "%d armour" % t["armor"],
			"note": "%s: %s\nLooks: %s\n\"%s\"" % [t["passive"], t["passive_desc"], t["look"], t["line"]],
			"suit_tier": tier,
			"confirm": func(): return armory.buy_suit_tier() if next else owned,
		}
		if owned:
			row["state"] = "WEARING" if tier == armory.suit_tier else "OWNED"
		elif next:
			row["cost"] = t["cost"]
		else:
			row["state"] = "NEEDS TIER %d" % (tier - 1)
		out.append(row)
	return out


func _with_attachment(slot: String, id: String) -> Dictionary:
	var saved: Dictionary = armory.fitted.get(weapon, {}).duplicate()
	if not armory.fitted.has(weapon):
		armory.fitted[weapon] = {}
	armory.fitted[weapon][slot] = id
	var p := armory.weapon_profile(weapon)
	armory.fitted[weapon] = saved
	return p


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
	_frame_camera(kind)
	lamp.position = _camera.position * 0.6 + Vector3(0, 1, 0)
	return sub


func _frame_camera(bench_kind: String) -> void:
	if bench_kind == "workshop":
		_camera.fov = 38.0
		_camera.look_at_from_position(Vector3(-7.5, 5.8, -15.5), Vector3(0, 3.7, 0))
	elif bench_kind == "suit":
		_camera.fov = 30.0
		_camera.look_at_from_position(Vector3(0.0, 1.0, 3.6), Vector3(0, 0.88, 0))
	else:
		_camera.fov = 30.0
		_camera.look_at_from_position(Vector3(0.0, 0.08, 1.15), Vector3(0, -0.02, 0))


## Shows what the selected row is about: the gun (with the browsed attachment
## on) or the titan you'd start with. Rebuilt only when it changes.
func _update_preview(row: Dictionary) -> void:
	var key := ""
	var make: Callable
	if kind == "suit":
		var tier: int = row.get("suit_tier", armory.suit_tier)
		key = "suit/%d" % tier
		make = func():
			var eco = ECO.instantiate()
			eco.suit_tier = tier
			eco.rotation.y = PI  # she faces -Z; turn her to the camera
			var holder := Node3D.new()
			holder.add_child(eco)
			return holder
	elif kind == "workshop":
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
