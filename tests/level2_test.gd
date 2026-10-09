extends SceneTree
## Headless test for Level 2 (levels.gd "level2", The Glass District): a
## night stealth run where Eco gets Ophelia out of the colony's holding block.
## Run: godot --headless --path . -s res://tests/level2_test.gd
## Plans many seeds and checks each is a city level with the holding block
## last and no titan clearing; builds one and checks the night (grunts with
## torches and shorter sight), the exfil back at the spawn, the cell with
## Ophelia chained inside in her prison rags; then plays it: the board stays
## locked until Level 1 is cleared, the exfil does nothing without her, F at
## the screen breaks her chains and she follows Eco, crouches with her, waits
## when told, grunts can spot her, and walking into the exfil with her close
## clears the level.

const Levels := preload("res://scripts/run/levels.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const Romance := preload("res://scripts/hub/romance.gd")

var failures := 0
var run_node
var player


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	_plan_checks()
	await _play_checks()
	print("level2 test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _plan_checks() -> void:
	var spec := Levels.spec("level2")
	_check("level 2 needs level 1, rescues Ophelia at night", spec["needs"] == "level1" and spec["rescue"] == "ophelia" and spec["night"] and Levels.ORDER == ["level1", "level2"], spec.get("needs", ""))
	var bad := []
	for s in range(1, 41):
		var plan = LevelPlan.make_level(s, spec)
		var kinds: Array = plan.sections.map(func(x): return x["kind"])
		if plan.zone_name != "THE GLASS DISTRICT" or plan.biome != "city":
			bad.append([s, "name/biome", plan.zone_name, plan.biome])
		if kinds.count("holding") != 1 or kinds[-2] != "holding" or kinds[-1] != "end" or "finale" in kinds or "depot" in kinds:
			bad.append([s, "sections", kinds])
		if kinds[-3] in LevelPlan.YARDS:
			bad.append([s, "yards side by side", kinds])
	_check("40 level plans: The Glass District, city, the holding block last, no clearing", bad.is_empty(), bad.slice(0, 6))


func _play_checks() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4242
	run_node.armory_path = "user://test_level2_armory.cfg"
	run_node.npc_path = "user://test_level2_npcs.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.npc_path))
	root.add_child(run_node)
	await _ticks(5)
	player = run_node.player
	run_node.tutorial.set_enabled(false)
	_check("no Ophelia in the hub before she's rescued", not run_node.hub_npcs.has("ophelia") and run_node.zone_info["interactables"].filter(func(i): return i.get("npc", "") == "ophelia").is_empty(), run_node.hub_npcs.keys())
	var affection_before: int = Romance.affection(run_node.npc_talk.state, "ophelia")

	# The mission table's Level 2 pin: locked until Level 1 is cleared.
	var spot: Dictionary = run_node.zone_info["interactables"].filter(func(i): return i.get("level", "") == "level2")[0]
	run_node.armory.mark_cleared("tutorial")
	run_node.dress_hub()
	_check("level 2 locked with only the tutorial won", spot["prompt"].contains("clear LEVEL 1") and run_node.zone_info["level_boards"][1]["label"].text.contains("locked"), spot["prompt"])
	await _use_spot(spot)
	_check("locked board doesn't start a run", run_node.phase == run_node.Phase.HUB, run_node.phase)
	run_node.armory.mark_cleared("level1")
	run_node.dress_hub()
	_check("level 2 opens once level 1 is cleared", spot["prompt"].contains("LEVEL 2: THE GLASS DISTRICT"), spot["prompt"])
	await _use_spot(spot)
	_check("board starts the level 2 run", run_node.phase == run_node.Phase.ZONE and run_node.run.level == "level2", [run_node.phase, run_node.run.level])
	run_node.tutorial.set_enabled(false)

	var info: Dictionary = run_node.zone_info
	_check("it's The Glass District, in the city", info.get("name", "") == "THE GLASS DISTRICT" and info["plan"].biome == "city" and run_node.hud.toast_label.text.contains("LEVEL 2"), info.get("name", ""))
	_check("a holding cell, no depot, no titan clearing", info.has("holding_cell") and not info.has("depot_cache") and not info.has("boss") and not info.has("arena"), info.keys())
	var beacon: Node3D = info["beacon"]
	_check("the exfil is back by the spawn", beacon != null and beacon.global_position.distance_to(info["spawn"]) < 10.0, beacon.global_position if beacon else null)
	var city: Array = info["set_pieces"].filter(func(p): return String(p["id"]).begins_with("city_"))
	_check("built from the city kit (%d pieces)" % city.size(), city.size() >= 10, city.size())
	var g0: Node = info["grunts"][0]
	_check("night: grunts carry torches and see less far", g0.get_node_or_null("Torch") != null and g0.sight_range < 40.0, g0.sight_range)
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("%d grunts, all standing on something" % info["grunts"].size(), info["grunts"].size() >= 14 and floating.is_empty(), floating)
	var cell: Node3D = info["holding_cell"]
	var oph: Node3D = cell.ophelia
	await _ticks(3)
	var ContentRating = preload("res://scripts/radio/content_rating.gd")
	var was: String = ContentRating.current()
	ContentRating.set_rating("M", false)
	await _frames(3)
	cell._hold()   # the gear only shows under Mature, and the rating was only just set
	await _frames(3)
	_check("Ophelia's in the trial frame in the Mature intake suit, in the white light", oph != null and oph.who == "ophelia" and oph.outfit == "colony_m" and oph.posed and cell._field.visible, oph.outfit)
	_check("she wears the trial's headphones, cuff, visor and neck band", cell.gear_on() == cell.TRIAL_GEAR, cell.gear_on())
	var wrists: Variant = cell.wrists_at()
	_check("her arms are held up over her head, wrists clamped together, ankles clamped", cell._clamps.size() == 6 and wrists != null and (wrists as Vector3).y > 1.6 and absf((wrists as Vector3).x - cell.COLUMN.x) < 0.15, [cell._clamps.size(), wrists])
	_check("she stands on the bay's floor, held still", absf(oph.position.y - cell.PAD_TOP) < 0.05 and oph._anim.speed_scale == 0.0, [oph.position.y, oph._anim.speed_scale])
	_check("a screen in front of her face flashes words at her", cell._feed != null and cell._feed_word.text in cell.FEED_WORDS, cell._feed_word.text if cell._feed_word else null)
	_check("two empty frames with their visors hung on them, the film tray and Marrow's Glass case", cell.find_children("HungVisor*", "", false, false).size() == 2 and cell.find_child("FilmTray", false, false) != null and cell.find_child("GlassCase", false, false) != null, cell.find_children("HungVisor*", "", false, false).size())
	_check("Mature face and messed-up hair", _face_tex(oph).ends_with("face_colony_m.png") and _blend(oph, "mess_colony") > 0.99, [_face_tex(oph), _blend(oph, "mess_colony")])
	_check("nothing shows through her suit (no chest nubs on a captive)", _hidden(oph, "Piercings"), _hidden(oph, "Piercings"))
	_check("the wall screen reads her trial: Bay 7, day 19", cell._manifest.text.contains("BAY 7") and cell._manifest.text.contains("DAY 19") and cell._log.text.contains("SOLACE"), cell._manifest.text)
	ContentRating.set_rating("T", false)
	await _frames(3)
	_check("Teen: the intake suit with its ID plate and its own face", oph.outfit == "colony" and _face_tex(oph).ends_with("face_colony.png"), [oph.outfit, _face_tex(oph)])
	ContentRating.set_rating(was, false)
	await _frames(3)
	_check("calm radio gossips about the prisoner", run_node.pilot_hud.radio.extra_rumor == "prisoner", run_node.pilot_hud.radio.extra_rumor)
	_check("the screen is solid", _screen_blocks(cell), true)

	# The exfil does nothing without her.
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("exfil without her doesn't end the run", run_node.phase == run_node.Phase.ZONE, run_node.phase)

	# Into the cell: the field drops, she follows.
	await _use_cell(cell)
	_check("F breaks her out: the light and her screen go out, the clamps open", cell.opened and run_node.rescued and not cell._field.visible and not _screen_blocks(cell) and cell._manifest.text == "" and cell._feed_word.text == "" and cell._clamps.is_empty() and cell._pose == null and oph._anim.speed_scale > 0.0, [cell._field.visible, _screen_blocks(cell), cell._manifest.text, cell._feed_word.text, cell._clamps.size(), oph._anim.speed_scale])
	_check("they talk", run_node.hud.toast_label.text.begins_with("OPHELIA"), run_node.hud.toast_label.text)
	_check("radio stops gossiping about her", run_node.pilot_hud.radio.extra_rumor == "", run_node.pilot_hud.radio.extra_rumor)
	var escort = run_node.escort
	_check("she's following", escort != null and escort.npc == oph and not escort.waiting, escort)
	ContentRating.set_rating("M", false)
	cell._hold()
	cell._unmask()
	_check("the visor, headphones and band come off her, the cuff stays", cell.gear_on() == cell.KEPT_GEAR, cell.gear_on())
	if escort == null:
		return
	# Walk off up the street: she comes after. (Grunts held passive for this,
	# so nobody shoots Eco back to a checkpoint mid-check.)
	for g in info["grunts"]:
		g.passive = true
		g.alerted = false
	var away: Vector3 = cell.global_transform * Vector3(0, 0.5, 12.0)
	_place(away)
	var start := oph.global_position.distance_to(player.global_position)
	await _ticks(int(6.0 * Engine.physics_ticks_per_second))
	var now := oph.global_position.distance_to(player.global_position)
	_check("she catches up (%.1f m -> %.1f m)" % [start, now], now < 5.0 and now < start, [start, now])
	Input.action_press("crouch")
	await _ticks(4)
	_check("she crouches when Eco does", escort.crouched, escort.crouched)
	Input.action_release("crouch")
	await _ticks(4)
	# Told to wait, she stays put.
	_place(oph.global_position + Vector3(0, 0.3, 1.5))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)
	_check("[F] by her: she waits", escort.waiting and run_node.hud.toast_label.text.begins_with("OPHELIA"), run_node.hud.toast_label.text)
	var held := oph.global_position
	_place(held + Vector3(12, 0.5, 0))
	await _ticks(int(2.0 * Engine.physics_ticks_per_second))
	_check("waiting, she stays put", oph.global_position.distance_to(held) < 0.5, oph.global_position.distance_to(held))
	# A grunt looking right at her notices her.
	var watcher: Node = null
	var spot_at := Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = run_node.get_world_3d().direct_space_state
	for g in info["grunts"]:
		if g.dead or g.patrol.size() >= 2:
			continue
		var ahead: Vector3 = -g.global_basis.z
		ahead.y = 0.0
		var at: Vector3 = g.global_position + ahead.normalized() * 5.0
		var q := PhysicsRayQueryParameters3D.create(g.global_position + g.EYE, at + Vector3.UP * 0.6, 1 | g.SIGHT_LAYER)
		q.exclude = [g.get_rid(), player.get_rid()]
		if space.intersect_ray(q).is_empty():
			watcher = g
			spot_at = at
			break
	watcher.passive = false
	var fwd: Vector3 = -watcher.global_basis.z
	fwd.y = 0.0
	oph.global_position = spot_at
	_place(watcher.global_position - fwd.normalized() * 30.0 + Vector3(0, 40, 0))
	watcher.detection = 0.0
	await _ticks(int(1.5 * Engine.physics_ticks_per_second))
	_check("a grunt facing her picks her up (%.2f)" % watcher.detection, watcher.detection > 0.15 or watcher.alerted, watcher.detection)

	# Out through the exfil together.
	escort.waiting = false
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	oph.global_position = beacon.global_position + Vector3(30, 0, 0)
	escort.set_physics_process(false)
	await _ticks(3)
	_check("exfil with her far behind doesn't end it", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("Not without Ophelia"), run_node.hud.toast_label.text)
	oph.global_position = beacon.global_position + Vector3(2, 0, 2)
	ContentRating.set_rating("M", false)
	await _ticks(3)
	_check("exfil with her close clears the level", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
	_check("level 2 marked cleared and saved", "level2" in load("res://scripts/hub/armory.gd").open(run_node.armory_path).cleared, run_node.armory.cleared)
	await _press("run_restart")
	await _ticks(3)
	_check("back to the temple", run_node.phase == run_node.Phase.HUB, run_node.phase)
	_check("Ophelia's in the hub once rescued", run_node.hub_npcs.has("ophelia"), run_node.hub_npcs.keys())
	var gained: int = Romance.affection(run_node.npc_talk.state, "ophelia") - affection_before
	_check("the rescue starts her romance on +%d" % run_node.RESCUE_AFFECTION, gained == run_node.RESCUE_AFFECTION, gained)
	run_node._rescue_bonus("level2")
	var HubGrip = preload("res://scripts/hub/hub_grip.gd")
	_check("she comes home still wearing the trial's dose cuff, Hymn in her", HubGrip.has("ophelia", "cuff") and HubGrip.level("ophelia") >= run_node.TRIAL_HYMN, [HubGrip.gear_of("ophelia"), HubGrip.level("ophelia")])
	ContentRating.set_rating(was, false)
	_check("the rescue bonus is given only once", Romance.affection(run_node.npc_talk.state, "ophelia") - affection_before == run_node.RESCUE_AFFECTION, Romance.affection(run_node.npc_talk.state, "ophelia"))


## Whether a ray from the street into the cell stops at the screen.
func _screen_blocks(cell: Node3D) -> bool:
	var from := cell.global_transform * Vector3(0, 1.2, 1.5)
	var to := cell.global_transform * Vector3(0, 1.2, -1.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = run_node.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and (cell.global_transform.affine_inverse() * hit["position"]).z > -0.3


func _use_spot(spot: Dictionary) -> void:
	_place(spot["pos"] + Vector3(0, 0.2, 0.3))
	await _ticks(2)
	await _press("interact")
	await _ticks(3)


func _use_cell(cell: Node3D) -> void:
	_place(cell.global_transform * Vector3(0, 0.3, 1.6))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "interact"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


func _ground_below(pos: Vector3, skip: RID) -> bool:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.5, 0), 1)
	q.exclude = [skip]
	return not run_node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Waits out idle frames (the cell re-dresses her in _process).
func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The texture on Ophelia's face material now.
func _face_tex(npc: Node) -> String:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
			if mat != null and mat.resource_name == "npc_ophelia_face":
				var mine := mi.get_surface_override_material(i) as ShaderMaterial
				var tex: Texture2D = (mine if mine != null else mat).get_shader_parameter("albedo_tex")
				return tex.resource_path if tex != null else ""
	return ""


func _hidden(npc: Node, prefix: String) -> bool:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with(prefix) and mi.visible:
			return false
	return true


func _blend(npc: Node, shape: String) -> float:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var b: int = mi.find_blend_shape_by_name(shape)
		if b >= 0:
			return mi.get_blend_shape_value(b)
	return -1.0


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
