extends Node
## Tutorial hints for the first run through the three zones (the Pinewoods,
## Blackwater, the Boneyard) and the titan fight after them. Those zones are
## where the game teaches itself, a mechanic or two at a time, the first time
## each one comes up: a card on the right of the screen says what a thing is
## and what it's for, and the thing itself gets a pulsing outline, a ring and a
## floating tag you can see through the trees.
##
## Each hint ("beat") shows once per save (user://settings.cfg, [tutorial]).
## F1 turns hints off or back on; Shift+F1 forgets which ones you've seen.
##
## The run manager calls start_level() on every level load and event() when
## something happens that a beat waits for (a fall, loot spilling out, a
## salvage choice). Everything else the beats read off the manager directly.

const SETTINGS := "user://settings.cfg"
const SFX := preload("res://scripts/sfx.gd")
const GLOW := preload("res://assets/shaders/tutorial_glow.gdshader")
const OUTLINE := preload("res://assets/shaders/tutorial_outline.gdshader")

const AMBER := Color(1.0, 0.78, 0.25)
const RED := Color(1.0, 0.32, 0.22)
const BLUE := Color(0.4, 0.85, 1.0)
const GREEN := Color(0.5, 1.0, 0.45)
const ORANGE := Color(1.0, 0.55, 0.15)
const KEY_COLOR := "#ffcc55"

## A card stays up at least this long, even if its job is done at once.
const MIN_SHOW := 2.5
const DEFAULT_MAX := 12.0
## A beat tied to a place ends when the pilot wanders this far from it.
const WANDER := 45.0

static var settings_path := SETTINGS

## The run manager (scripts/run/run_manager.gd).
var run: Node
var enabled := true
## beat id -> true for every hint already shown on this save.
var seen := {}
## What the current level can still show, in priority order.
var beats: Array = []
## The beat on screen, or {}.
var current := {}
var level := ""
var level_time := 0.0
var _shown_for := 0.0
var _events := {}
var _marks: Array = []
var _overlaid: Array = []

var _layer: CanvasLayer
var _card: PanelContainer
var _title: Label
var _body: RichTextLabel
var _foot: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_build_card()


# --- settings -------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	enabled = bool(cfg.get_value("tutorial", "enabled", true))
	for id in cfg.get_value("tutorial", "seen", PackedStringArray()):
		seen[id] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # keep the other sections (dialogue rating)
	cfg.set_value("tutorial", "enabled", enabled)
	cfg.set_value("tutorial", "seen", PackedStringArray(seen.keys()))
	cfg.save(settings_path)


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_finish()
	_save()


## Forget every hint seen, so the next run teaches it all again.
func reset_seen() -> void:
	seen.clear()
	_save()
	start_level(level)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F1:
		return
	if key.shift_pressed:
		reset_seen()
		_flash("Tutorial hints reset: they'll all show again")
	else:
		set_enabled(not enabled)
		_flash("Tutorial hints %s  (F1)" % ("on" if enabled else "off"))


func _flash(text: String) -> void:
	var hud = run.get("pilot_hud") if run != null else null
	if hud != null and hud.has_method("flash_message"):
		hud.flash_message(text, 2.5)


# --- the run manager's side -----------------------------------------------------

## "zone0".."zone2", "arena", "hub" or anything else (no beats).
func start_level(which: String) -> void:
	_finish()
	level = which
	level_time = 0.0
	_events.clear()
	beats = []
	match which:
		"zone0":
			beats = _pinewoods() + _anywhere()
		"zone1":
			beats = _blackwater() + _anywhere()
		"zone2":
			beats = _boneyard() + _anywhere()
		"arena":
			beats = _arena()
		"hub":
			beats = _hub()
	var radio = _radio()
	if radio != null and not radio.line_started.is_connected(_on_radio):
		radio.line_started.connect(_on_radio)


func event(name: String) -> void:
	_events[name] = true


func _on_radio(_callsign: String, _text: String, _category: String) -> void:
	event("radio")


func _radio() -> Node:
	var hud = run.get("pilot_hud") if run != null else null
	return hud.get("radio") if hud != null else null


# --- the loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if run == null or run.player == null:
		return
	level_time += delta
	if not current.is_empty():
		_shown_for += delta
		if _over(current):
			_finish()
	if not enabled or level_time < 0.5:
		return
	for beat in beats:
		if seen.has(beat["id"]):
			continue
		if not current.is_empty() and not (beat.get("urgent", false) and not current.get("urgent", false)):
			continue
		if _safe_call(beat["when"]):
			_show(beat)
			break


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for m in _marks:
		if is_instance_valid(m) and m.has_meta("bob"):
			m.position.y = float(m.get_meta("bob")) + sin(t * 3.0) * 0.18
		if is_instance_valid(m) and m.has_meta("ring"):
			var s := 1.0 + 0.08 * sin(t * 5.0)
			m.scale = Vector3(s, 1.0, s)


func _safe_call(c: Variant) -> bool:
	if c == null:
		return false
	return bool((c as Callable).call())


func _over(beat: Dictionary) -> bool:
	if _shown_for < MIN_SHOW:
		return false
	if _safe_call(beat.get("done")):
		return true
	if beat.has("at"):
		var at: Vector3 = beat["at"]
		if is_finite(at.x) and run.player.global_position.distance_to(at) > WANDER:
			return true
	return _shown_for > float(beat.get("max", DEFAULT_MAX))


func _show(beat: Dictionary) -> void:
	_finish()
	current = beat
	_shown_for = 0.0
	seen[beat["id"]] = true
	_save()
	_title.text = beat["title"]
	_title.add_theme_color_override("font_color", beat.get("color", AMBER))
	(_card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = beat.get("color", AMBER)
	_body.text = _keys(beat["body"])
	_card.visible = true
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)
	var targets: Variant = beat.get("targets")
	if targets is Callable:
		targets = (targets as Callable).call()
	for t in (targets if targets is Array else []):
		highlight(t)
	_ping()


## The card and every highlight go away.
func _finish() -> void:
	current = {}
	if _card != null:
		_card.visible = false
	for pair in _overlaid:
		if is_instance_valid(pair[0]):
			pair[0].material_overlay = pair[1]
	_overlaid.clear()
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()


func _ping() -> void:
	if run != null and run.player != null and run.player.is_inside_tree():
		SFX.play_at(run.player, run.player.global_position, "lock_on", -10.0, 0.8)


## "[F] pry" -> the key drawn in amber. Everything else is plain text.
func _keys(text: String) -> String:
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var out := ""
	var last := 0
	for m in re.search_all(text):
		out += text.substr(last, m.get_start() - last)
		out += "[color=%s][lb]%s[rb][/color]" % [KEY_COLOR, m.get_string(1)]
		last = m.get_end()
	return out + text.substr(last)


# --- highlights -----------------------------------------------------------------

## t is {"node": Node3D, "tag": String, "color": Color} (outline, ring and tag),
## {"pos": Vector3, ...} (ring and tag on a spot) or {"area": Area3D, ...}
## (a glowing frame round a patch of cover).
func highlight(t: Dictionary) -> void:
	var color: Color = t.get("color", AMBER)
	var tag: String = t.get("tag", "")
	if t.has("node"):
		var node: Node3D = t["node"]
		if node == null or not is_instance_valid(node):
			return
		var box := _bounds(node)
		var mat := _overlay(color)
		for gi in _meshes(node):
			_overlaid.append([gi, gi.material_overlay])
			gi.material_overlay = mat
		var local_top := node.to_local(box.position + Vector3(box.size.x * 0.5, box.size.y, box.size.z * 0.5))
		if tag != "":
			_tag(node, local_top + Vector3(0, 0.9, 0), tag, color)
		if t.get("ring", true):
			var r := clampf(maxf(box.size.x, box.size.z) * 0.5 + 0.6, 1.0, 6.0)
			# On the ground under it (the node's origin), not the bottom of a half-buried model.
			_ring(node, node.to_local(Vector3(box.get_center().x, maxf(box.position.y, node.global_position.y) + 0.15, box.get_center().z)), r, color)
	elif t.has("area"):
		var area: Area3D = t["area"]
		if area == null or not is_instance_valid(area):
			return
		var size := Vector3(4, 1, 4)
		for c in area.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D:
				size = c.shape.size
		var y := -size.y * 0.5 + 0.15
		for side in [[Vector3(0, y, size.z * 0.5), Vector3(size.x, 0.08, 0.14)], [Vector3(0, y, -size.z * 0.5), Vector3(size.x, 0.08, 0.14)],
				[Vector3(size.x * 0.5, y, 0), Vector3(0.14, 0.08, size.z)], [Vector3(-size.x * 0.5, y, 0), Vector3(0.14, 0.08, size.z)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = side[1]
			bm.material = _glow_mat(color)
			mi.mesh = bm
			mi.position = side[0]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			area.add_child(mi)
			_marks.append(mi)
		if tag != "":
			_tag(area, Vector3(0, size.y * 0.5 + 0.8, 0), tag, color)
	elif t.has("pos"):
		var holder := Node3D.new()
		run.zone_root.add_child(holder)
		holder.global_position = t["pos"]
		_marks.append(holder)
		if t.get("ring", true):
			_ring(holder, Vector3(0, 0.08, 0), float(t.get("radius", 2.0)), color)
		if tag != "":
			_tag(holder, Vector3(0, float(t.get("height", 2.5)), 0), tag, color)


func _overlay(color: Color) -> ShaderMaterial:
	var glow := ShaderMaterial.new()
	glow.shader = GLOW
	glow.set_shader_parameter("color", color)
	glow.render_priority = 1
	var edge := ShaderMaterial.new()
	edge.shader = OUTLINE
	edge.set_shader_parameter("color", color)
	glow.next_pass = edge
	return glow


func _glow_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


## A floating, always-on-top label (readable through foliage) with a chevron under it.
func _tag(parent: Node3D, at: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text + "\n▼"
	l.font_size = 40
	l.outline_size = 12
	l.pixel_size = 0.0011
	l.fixed_size = true
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = at
	l.set_meta("bob", at.y)
	parent.add_child(l)
	_marks.append(l)


func _ring(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.14
	torus.rings = 48
	torus.material = _glow_mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("ring", true)
	parent.add_child(mi)
	_marks.append(mi)


func _meshes(node: Node) -> Array:
	var out := []
	if node is GeometryInstance3D and not node is Label3D:
		out.append(node)
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		if not c is Label3D and not c is GPUParticles3D and c.visible:
			out.append(c)
	return out


## World-space box round everything visible under `node`.
func _bounds(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	var first := true
	for vi in _meshes(node):
		if not vi is VisualInstance3D:
			continue
		var b: AABB = vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- the card -------------------------------------------------------------------

func _build_card() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.86)
	style.border_color = AMBER
	style.border_width_left = 6
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_right = 1
	style.set_content_margin_all(18)
	style.content_margin_left = 22
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_card.offset_left = -470
	_card.offset_right = -24
	_card.offset_top = -40
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_card.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 4)
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(420, 0)
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_body)
	_foot = Label.new()
	_foot.text = "TUTORIAL    F1 hide hints"
	_foot.add_theme_font_size_override("font_size", 14)
	_foot.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	col.add_child(_foot)
	_card.visible = false
	_layer.add_child(_card)


# --- what the beats look at -----------------------------------------------------

func _pos() -> Vector3:
	return run.player.global_position


func _near(at: Vector3, r: float) -> bool:
	return _pos().distance_to(at) < r


func _info() -> Dictionary:
	return run.zone_info


## The zone's first crate or node (loot.gd places a zone's fixed first ones first).
func _first_loot(is_node: bool) -> Node3D:
	for n in _info().get("loot", []):
		if is_instance_valid(n) and n.has_method("mine") == is_node:
			return n
	return null


func _closest(list: Array, r: float, ok := Callable()) -> Node3D:
	var best: Node3D = null
	var best_d := r
	for n in list:
		if not is_instance_valid(n) or (ok.is_valid() and not ok.call(n)):
			continue
		var d := _pos().distance_to(n.global_position)
		if d < best_d:
			best = n
			best_d = d
	return best


## An unaware, living grunt within r that the pilot can actually see.
func _seen_grunt(r: float) -> Node3D:
	return _closest(_info().get("grunts", []), r, func(g): return not g.dead and g.is_unaware() and _in_view(g))


func _in_view(n: Node3D) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := _pos() + Vector3(0, 1.6, 0)
	var to := n.global_position + Vector3(0, 1.2, 0)
	if cam != null and (-cam.global_basis.z).dot((to - eye).normalized()) < 0.5:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, to, 1)
	q.exclude = [run.player.get_rid()]
	var hit: Dictionary = run.player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == n or (hit.collider as Node).is_ancestor_of(n) or n.is_ancestor_of(hit.collider)


func _cache(locked: bool, r: float) -> Node3D:
	return _closest(_info().get("caches", []), r, func(c): return not c.opened and c.locked == locked)


func _grass(r: float) -> Area3D:
	return _closest(_info().get("stealth_cover", []), r) as Area3D


func _in_area(area: Area3D) -> bool:
	for c in area.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			var local := area.to_local(_pos() + Vector3(0, 0.5, 0))
			var h: Vector3 = c.shape.size * 0.5
			return absf(local.x) < h.x and absf(local.z) < h.z and absf(local.y) < h.y + 1.0
	return false


## The crossing's pieces as highlight targets.
func _crossing_targets(which: Array) -> Array:
	var cr: Dictionary = _info().get("crossing", {})
	var spec := {
		"wallrun": ["WALLRUN", BLUE], "grapple": ["GRAPPLE  [Q] / [E]", ORANGE],
		"pillars": ["HOP ACROSS", AMBER], "log": ["QUIET WAY", GREEN],
	}
	var out := []
	for key in which:
		var nodes: Array = cr.get(key, [])
		for i in nodes.size():
			out.append({"node": nodes[i], "tag": spec[key][0] if i == 0 else "", "color": spec[key][1], "ring": key == "grapple"})
	return out


func _crossed() -> bool:
	var cr: Dictionary = _info().get("crossing", {})
	return cr.has("lip") and _pos().z < (cr["lip"] as Vector3).z - 40.0


func _lip() -> Vector3:
	return _info().get("crossing", {}).get("lip", Vector3.INF)


# --- the beats ------------------------------------------------------------------
# Each beat: id, title, body ("[F]"-style keys get coloured), when (Callable ->
# bool), optional done (Callable -> bool), targets (Array or Callable -> Array
# of highlight dicts, read when it shows), at (where it happens), max seconds,
# color, urgent (replaces a non-urgent card).

## Zone 1: moving, looting, the first grunts, hiding, the ravine.
func _pinewoods() -> Array:
	var node := _first_loot(true)
	var crate := _first_loot(false)
	var out := [
		{"id": "welcome", "title": "THE PINEWOODS", "max": 9.0, "at": _info()["spawn"],
			"body": "The first three zones teach you the ropes, one thing at a time.\n[WASD] move, [Space] jump and jump again in the air, [C] slides when you're running, hold [Q] or [E] to grapple.",
			"when": func(): return true,
			"done": func(): return not _near(_info()["spawn"], 7.0)},
	]
	if node != null:
		out.append({"id": "alloy_node", "title": "ALLOY NODE", "color": BLUE, "max": 40.0, "at": node.global_position,
			"body": "A titan wreck half sunk in the ground, raw alloy glowing through the cracks. Walk up and hold [F] to mine it with your breaker bar.\nAlloy is what titan parts and refits cost at the workshop back at the temple.",
			"targets": func(): return [{"node": node, "tag": "ALLOY NODE  hold F", "color": BLUE}],
			"when": func(): return is_instance_valid(node) and not node.depleted and _near(node.global_position, 30.0),
			"done": func(): return not is_instance_valid(node) or node.depleted})
	out.append(_materials_beat())
	if crate != null:
		out.append({"id": "supply_crate", "title": "SUPPLY CRATE", "max": 25.0, "at": crate.global_position,
			"body": "Militia supplies. Press [F] to pry the lid off.\nInside is scrap, and sometimes circuits: the gunsmith's bench at the temple turns them into weapon upgrades.",
			"targets": func(): return [{"node": crate, "tag": "SUPPLY CRATE", "color": AMBER}],
			"when": func(): return is_instance_valid(crate) and not crate.opened and _near(crate.global_position, 14.0),
			"done": func(): return not is_instance_valid(crate) or crate.opened})
	out.append_array([
		_grunt_beat(),
		_grass_beat(),
		{"id": "ravine", "title": "THE RAVINE", "max": 30.0, "at": _lip(),
			"body": "The bridge is down. Four ways over:\nWallrun the blue blast shield: jump at it and hold forward.\nGrapple the orange anchor: look at it, hold [Q] or [E].\nHop the rock pillars, or walk the fallen pine upstream where nobody's watching.",
			"targets": func(): return _crossing_targets(["wallrun", "grapple", "pillars", "log"]),
			"when": func(): return _near(_lip(), 30.0),
			"done": _crossed},
		_extract_beat("EXTRACT", "Step into the beam to move on to the next zone. Anything still lying around stays behind."),
	])
	return out


## Zone 2: routes, being noticed, the radio, the knife, grappling.
func _blackwater() -> Array:
	var routes: Array = _info().get("routes", [])
	return [
		{"id": "routes", "title": "BLACKWATER", "max": 10.0,
			"body": "Every zone has three ways through. The road is loud and guarded. The reeds are quiet. The pipeline and the rooftops are high and fast. Pick one, or switch partway.",
			"targets": func(): return _route_tags(routes),
			"when": func(): return level_time > 1.0},
		{"id": "detection", "title": "BEING NOTICED", "color": RED, "max": 10.0,
			"body": "Someone's noticed something. The arcs round your crosshair fill as a grunt makes you out. A ? over him means he's suspicious: break line of sight or get into the grass. A ! means you've been seen, and he'll call his squad in.",
			"targets": func(): return _noticing().map(func(g): return {"node": g, "tag": "", "color": RED, "ring": false}),
			"when": func(): return not _noticing().is_empty(),
			"done": func(): return _noticing().is_empty()},
		{"id": "radio", "title": "MILITIA RADIO", "color": RED, "max": 8.0,
			"body": "Eco's patched into the militia's squad net. Their chatter tells you when they've spotted something, and who's coming. [O] changes how filthy it gets.",
			"when": func(): return _events.has("radio")},
		_knife_beat(),
		{"id": "grapple", "title": "GRAPPLE ANCHORS", "color": ORANGE, "max": 25.0, "at": _lip(),
			"body": "Orange anchors always take your grapple. Look at it and hold [Q] or [E], let go at the top of the swing and double jump to carry the speed.\nOr wallrun the barge, hop the old piers, or creep along the drowned titan's back.",
			"targets": func(): return _crossing_targets(["grapple", "wallrun", "pillars", "log"]),
			"when": func(): return _near(_lip(), 30.0),
			"done": _crossed},
		{"id": "circuits", "title": "CIRCUITS", "color": BLUE, "max": 8.0,
			"body": "Rarer than scrap. Grunts drop one now and then, crates more often. The better upgrades at the temple's benches want them.",
			"when": func(): return int(run.run.materials.get("circuits", 0)) > 0},
		_materials_beat(),
		_extract_beat("EXTRACT", "On to the Boneyard."),
	]


## Zone 3: the titan you're building, wallrunning properly, what's next.
func _boneyard() -> Array:
	return [
		{"id": "titan_build", "title": "YOUR TITAN", "max": 11.0,
			"body": "Top right is the titan you're putting together from scrap: chassis, weapon, core and kit. Every salvage cache swaps in one part. A slot you never fill fights with junk, so open the caches.",
			"when": func(): return level_time > 1.0},
		{"id": "wallrun", "title": "WALLRUNNING", "color": BLUE, "max": 25.0, "at": _lip(),
			"body": "Hit the dead titan's shield at an angle and keep holding forward to run along it. [Space] kicks you off, and you get your double jump back. Chain wall to wall and you never touch the ground.",
			"targets": func(): return _crossing_targets(["wallrun", "grapple", "pillars", "log"]),
			"when": func(): return _near(_lip(), 30.0),
			"done": _crossed},
		_materials_beat(),
		_extract_beat("TITANFALL", "Past this beacon is the forest's edge and their titan. You'll call yours down with [V], climb in with [F], and fight it. Whatever you've bolted on is what you get."),
	]


## Hints that can turn up in any of the three zones, after that zone's own.
func _anywhere() -> Array:
	return [
		{"id": "salvage_cache", "title": "SALVAGE CACHE", "max": 20.0,
			"body": "Titan parts, hidden by the militia. Open it with [F] and keep one part for the titan you'll call in at the end of the run.",
			"targets": func(): return _target_for(_cache(false, 25.0), "SALVAGE", AMBER),
			"when": func(): return _cache(false, 25.0) != null,
			"done": func(): return _cache(false, 30.0) == null},
		{"id": "locked_cache", "title": "GUARDED CACHE", "color": RED, "max": 16.0,
			"body": "This cache is locked down while its squad is alive. Kill every guard (they're outlined) and it opens. Sneak in and the first one goes down easy.",
			"targets": func(): return _locked_targets(),
			"when": func(): return _cache(true, 30.0) != null or _events.has("locked"),
			"done": func(): return _cache(true, 40.0) == null},
		{"id": "salvage_choice", "title": "PICK ONE PART", "urgent": true, "max": 30.0,
			"body": "Keep one with [1], [2] or [3], or [X] to leave them. Each shows what it would replace; Mk II and Mk III parts hit harder. Time's stopped while you think.",
			"when": func(): return _events.has("choosing"),
			"done": func(): return run.phase != run.Phase.CHOOSING},
		{"id": "fall", "title": "FALLING", "color": RED, "urgent": true, "max": 8.0,
			"body": "A fall costs 25 integrity and puts you back at the last checkpoint. Run out of integrity and the run is over.",
			"when": func(): return _events.has("fell")},
		{"id": "downed", "title": "DOWNED", "color": RED, "urgent": true, "max": 8.0,
			"body": "Gunned down: 25 integrity gone and back to the checkpoint. Health comes back on its own once nobody's hitting you, so break contact and let it.",
			"when": func(): return _events.has("downed")},
	]


func _arena() -> Array:
	return [
		{"id": "call_titan", "title": "TITANFALL", "color": GREEN, "max": 20.0,
			"body": "Press [V] to call your titan down. It drops where you're looking, so give it room.",
			"when": func(): return level_time > 1.0,
			"done": func(): return run.titan != null},
		{"id": "embark", "title": "EMBARK", "color": GREEN, "max": 20.0,
			"body": "Get to your titan and press [F] to climb in.",
			"targets": func(): return [{"node": run.titan, "tag": "YOUR TITAN", "color": GREEN}] if run.titan != null else [],
			"when": func(): return run.titan != null and not run.titan.dropping,
			"done": func(): return run.phase == run.Phase.FIGHT},
		{"id": "titan_fight", "title": "TITAN FIGHT", "color": RED, "max": 14.0,
			"body": "[Left mouse] fires. [Shift] dashes: when SLAM INCOMING shows, dash out. Your core charges as you deal damage; [V] fires it.",
			"when": func(): return run.phase == run.Phase.FIGHT},
		{"id": "evac", "title": "EVAC", "color": GREEN, "max": 20.0,
			"body": "Their titan's down and you pulled its lock core. Walk your titan into the evac beam to get home with everything.",
			"targets": func(): return [{"node": _info().get("evac_node"), "tag": "EVAC", "color": GREEN}],
			"when": func(): return run.evac_open},
	]


func _hub() -> Array:
	return [
		{"id": "hub_benches", "title": "SPEND IT", "max": 16.0,
			"body": "What you brought back is banked. The gunsmith's bench and the weapon rack take scrap and circuits for your guns; the titan workshop takes alloy for parts and refits. Lock cores from titans feed the smart pistol.",
			"targets": func(): return _bench_tags(),
			"when": func(): return run.last_result != "" and level_time > 3.0},
	]


func _materials_beat() -> Dictionary:
	return {"id": "materials", "title": "MATERIALS", "max": 9.0,
		"body": "Bits fly to you once you're close. You carry them for the whole run: extract and you bank all of it, die and you keep half. What you've got is on the readout top left.",
		"when": func(): return _events.has("loot")}


func _grunt_beat() -> Dictionary:
	return {"id": "grunts", "title": "MILITIA", "color": RED, "max": 12.0,
		"body": "He hasn't seen you. Unaware grunts take double damage, and the stiletto [Z] kills them outright. Get spotted and he calls his squad in.",
		"targets": func(): return _target_for(_seen_grunt(45.0), "UNAWARE", RED, false),
		"when": func(): return _seen_grunt(40.0) != null,
		"done": func(): return _seen_grunt(60.0) == null}


func _grass_beat() -> Dictionary:
	return {"id": "tall_grass", "title": "TALL GRASS", "color": GREEN, "max": 14.0,
		"body": "Crouch [C] in tall grass and grunts can't make you out past a few metres. The thick patches block their sight completely.",
		"targets": func(): return [{"area": _grass(18.0), "tag": "HIDE HERE", "color": GREEN}],
		"when": func(): return _grass(14.0) != null,
		"done": func(): return run.player.crouching and _grass(8.0) != null and _in_area(_grass(8.0))}


func _knife_beat() -> Dictionary:
	return {"id": "knife", "title": "STILETTO", "color": RED, "max": 12.0,
		"body": "Close in from behind and tap [Z]. The stiletto kills an unaware grunt instantly, and quietly. Hold [Z] to keep the blade out and stab with [Left mouse].",
		"targets": func(): return _target_for(_stab_target(14.0), "STAB  Z", RED, false),
		"when": func(): return _stab_target(12.0) != null,
		"done": func(): return _stab_target(25.0) == null}


func _extract_beat(tag: String, body: String) -> Dictionary:
	return {"id": "extract_%s" % level, "title": "EXTRACT", "color": GREEN, "max": 12.0,
		"body": body,
		"targets": func(): return [{"node": _info().get("beacon"), "tag": tag, "color": GREEN, "ring": false}],
		"when": func(): return _info().get("beacon") != null and _near(_info()["beacon"].global_position, 40.0)}


func _target_for(n: Node3D, tag: String, color: Color, ring := true) -> Array:
	return [] if n == null else [{"node": n, "tag": tag, "color": color, "ring": ring}]


func _locked_targets() -> Array:
	var cache := _cache(true, 60.0)
	if cache == null:
		return []
	var out := [{"node": cache, "tag": "LOCKED", "color": RED}]
	for obj in _info().get("objectives", []):
		if obj.cache == cache:
			for g in obj.grunts:
				if is_instance_valid(g) and not g.dead:
					out.append({"node": g, "tag": "", "color": RED, "ring": false})
	return out


## Grunts that are filling their meter on the pilot but haven't seen her yet.
func _noticing() -> Array:
	return _info().get("grunts", []).filter(func(g): return is_instance_valid(g) and not g.dead and g.detection > 0.15 and g.awareness != g.Awareness.ALERTED)


## An unaware grunt close by with his back (more or less) to the pilot.
func _stab_target(r: float) -> Node3D:
	return _closest(_info().get("grunts", []), r, func(g):
		if g.dead or not g.is_unaware():
			return false
		var to_pilot: Vector3 = (_pos() - g.global_position).normalized()
		return (-g.global_basis.z).dot(to_pilot) < 0.2 and _in_view(g))


func _route_tags(routes: Array) -> Array:
	var names := {"loud": ["LOUD", RED], "quiet": ["QUIET", BLUE], "high": ["HIGH", ORANGE]}
	var out := []
	for route in routes:
		var pts: PackedVector3Array = route["points"]
		if pts.size() < 3 or not names.has(route["kind"]):
			continue
		var p := pts[mini(3, pts.size() - 1)]
		out.append({"pos": p, "tag": names[route["kind"]][0], "color": names[route["kind"]][1], "radius": 1.5})
	return out


func _bench_tags() -> Array:
	var out := []
	var names := {"gunsmith": "GUNSMITH", "rack": "WEAPON RACK", "workshop": "TITAN WORKSHOP"}
	for spot in _info().get("interactables", []):
		var screen: String = spot.get("screen", "")
		if names.has(screen):
			out.append({"pos": spot["pos"], "tag": names[screen], "color": AMBER, "radius": 1.2})
	return out
