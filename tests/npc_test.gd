extends SceneTree
## Headless test for the people in the hub (Mom, Ophelia, Biggie): each stands
## in their tent, Eco can walk in through the door, F starts a talk that opens
## with their intro, F moves it on, walking off ends it, a finished run gets a
## reaction, and every line babbles in its speaker's voice.
## Run: godot --headless --path . -s res://tests/npc_test.gd

const Rooms := preload("res://scripts/hub/hub_rooms.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Babble := preload("res://scripts/hub/babble.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const WHO := ["mom", "ophelia", "biggie"]
## Where Eco stands on each tent's porch to walk in, and which way is in.
var DOORS := {"mom": Rooms.doorstep("mom"), "ophelia": Rooms.doorstep("ophelia"), "biggie": Rooms.doorstep("biggie")}

var run_node
var player
var failures := 0


func _initialize() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_npc_armory.cfg"
	run_node.npc_path = "user://test_npcs.cfg"
	Wardrobe.save_path = "user://test_npc_wardrobe.cfg"   # not the player's own picks
	for p in [run_node.armory_path, run_node.npc_path, Wardrobe.save_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var info: Dictionary = run_node.zone_info
	var rooms := {"mom": Rooms.MOM_ROOM, "ophelia": Rooms.OPHELIA_ROOM, "biggie": Rooms.BIGGIE_ROOM}

	for who in WHO:
		var npc = run_node.hub_npcs.get(who)
		_check("%s is in the hub" % who, npc != null and npc.is_inside_tree(), npc)
		if npc == null:
			continue
		var p: Vector3 = npc.global_position
		_check("%s stands in their room" % who, rooms[who].has_point(Vector2(p.x, p.z)), p)
		_check("%s has a model that idles" % who, npc.get_node_or_null("Model") != null and npc._anim != null and npc._anim.current_animation == "idle", npc._anim)
		var bare := []
		for mi in npc.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
				var tex := "res://assets/textures/npc/%s/%s.png" % [who, mat.resource_name.trim_prefix("npc_%s_" % who)] if mat else ""
				if mat == null or (ResourceLoader.exists(tex) and mat.get_shader_parameter("albedo_tex") == null):
					bare.append("%s/%s" % [mi.name, mat.resource_name if mat else "?"])
		_check("%s is fully textured" % who, bare.is_empty(), bare)

	_check("Ophelia starts in her tee", run_node.hub_npcs["ophelia"].outfit == "tee", run_node.hub_npcs["ophelia"].outfit)
	for who in ["mom", "ophelia"]:
		var list: Array = run_node.hub_npcs[who].OUTFITS[who]
		var gone := []
		for i in range(1, list.size()):
			if not ResourceLoader.exists("res://assets/textures/npc/%s/body_%s.png" % [who, list[i]]):
				gone.append(list[i])
		_check("%s has all %d outfits" % [who, list.size()], gone.is_empty() and list.has("night"), gone)
		# nightwear meshes show only at night, and the boots come off
		var npc: Node = run_node.hub_npcs[who]
		var before: String = npc.outfit
		var meshes: Array = npc.find_children("Outfit_night_*", "MeshInstance3D", true, false)
		var boots: Array = npc.find_children("Boots*", "MeshInstance3D", true, false)
		npc.wear("night")
		_check("%s's nightwear meshes show at night" % who, not meshes.is_empty() and meshes.all(func(m): return m.visible) and boots.all(func(b): return not b.visible), [meshes.size(), boots.size()])
		npc.wear(list[0])
		_check("%s's nightwear meshes hide by day" % who, meshes.all(func(m): return not m.visible) and boots.all(func(b): return b.visible), npc.outfit)
		npc.wear(before)

	# Ophelia's piercings: only with the rating on Mature
	var oph_p: Node = run_node.hub_npcs["ophelia"]
	var bars: Array = oph_p.find_children("Piercings*", "MeshInstance3D", true, false)
	var was := ContentRating.current()
	ContentRating.set_rating("T", false)
	oph_p._process(0.0)
	_check("Ophelia's piercings hidden on Teen", not bars.is_empty() and bars.all(func(b): return not b.visible), bars.size())
	ContentRating.set_rating("M", false)
	oph_p._process(0.0)
	_check("Ophelia's piercings show on Mature", not bars.is_empty() and bars.all(func(b): return b.visible), bars.size())
	ContentRating.set_rating(was, false)
	oph_p._process(0.0)

	# Every line in every conversation babbles, one beat per character.
	var missing := []
	var count := 0
	for who in WHO:
		var b: Dictionary = run_node.npc_talk.bank(who)
		_check("%s has intro, won, lost and chat" % who, b.has("intro") and b.has("won") and b.has("lost") and b["any"].size() >= 3, b.keys())
		var convs: Array = b["any"].duplicate()
		for tag in ["intro", "won", "lost"]:
			convs.append(b.get(tag, []))
		for conv in convs:
			for line in conv:
				count += 1
				var babble: Dictionary = Babble.make(line[0], line[1])
				if babble["stream"].data.size() < 2000 or babble["times"].size() != line[1].length() + 1:
					missing.append(line)
	_check("every line babbles (%d lines)" % count, missing.is_empty() and count > 60, missing.slice(0, 3))
	var low: float = Babble.VOICES["biggie"]["pitch"]
	_check("each has their own voice", low < Babble.VOICES["mom"]["pitch"] and Babble.VOICES["mom"]["pitch"] < Babble.VOICES["eco"]["pitch"], low)

	for who in WHO:
		var npc = run_node.hub_npcs[who]
		# Walk in through the door from the porch until they're in talking range.
		var door: Array = DOORS[who]
		_place(door[0] + Vector3(0, 0.3, 0))
		await _ticks(20)
		var walked := await _walk_to(npc.global_position, 2.0, 600)
		_check("walk through the door to %s" % who, walked, player.global_position)
		var spot: Dictionary = run_node.nearest_hub_spot()
		_check("talk prompt by %s" % who, spot.get("npc") == who and run_node.hud.prompt_label.text.begins_with("[F] Talk to"), run_node.hud.prompt_label.text)
		await _ticks(40)
		_check("%s turns to face Eco" % who, _facing(npc, player.global_position) > 0.8, _facing(npc, player.global_position))

		# F: their intro, first line first.
		await _press("interact")
		await _ticks(2)
		var intro: Array = run_node.npc_talk.bank(who)["intro"]
		var first := "%s: %s" % intro[0].slice(0, 2)
		_check("%s opens with their intro" % who, run_node.npc_talk.active() and run_node.npc_talk.current_line() == first, run_node.npc_talk.current_line())
		_check("prompt hidden while talking", run_node.hud.prompt_label.text == "", run_node.hud.prompt_label.text)
		if intro[0][0] != "eco":
			_check("%s plays talk anim and voice" % who, npc._anim.current_animation == "talk" and npc.voice.playing, npc._anim.current_animation)
		_check("%s's caption types out" % who, run_node.npc_talk._text.visible_characters >= 0 and run_node.npc_talk._text.visible_characters < intro[0][1].length(), run_node.npc_talk._text.visible_characters)
		await _press("interact")
		await _ticks(2)
		_check("F finishes %s's line" % who, run_node.npc_talk._text.visible_characters == -1 and run_node.npc_talk.current_line() == first, run_node.npc_talk._text.visible_characters)
		await _press("interact")
		await _ticks(2)
		_check("F moves %s's talk on" % who, run_node.npc_talk.current_line() == "%s: %s" % intro[1].slice(0, 2), run_node.npc_talk.current_line())
		# Lines play out on their own too.
		var at: int = run_node.npc_talk.index
		await _ticks(int(run_node.npc_talk.line_left * 120.0) + 30)
		_check("%s's talk runs on by itself" % who, run_node.npc_talk.index > at or not run_node.npc_talk.active(), run_node.npc_talk.index)
		# Walking off ends it.
		_place(npc.global_position + Vector3(0, 0.3, 0) + (door[0] - npc.global_position).normalized() * 6.5)
		await _ticks(10)
		_check("walking away from %s ends the talk" % who, not run_node.npc_talk.active() and not npc.talking, run_node.npc_talk.active())

	# They only turn so far after her: with Eco behind them, they hold at the limit.
	for who in WHO:
		var npc = run_node.hub_npcs[who]
		var ahead := Vector3(-sin(npc.home_yaw), 0, -cos(npc.home_yaw))
		_place(npc.global_position + Vector3(0, 0.3, 0) - ahead * 1.6 + ahead.cross(Vector3.UP) * 0.3)
		await _ticks(90)
		var off := rad_to_deg(absf(angle_difference(npc.home_yaw, npc.rotation.y)))
		_check("%s turns no further than %d degrees" % [who, int(npc.MAX_TURN)], off <= npc.MAX_TURN + 1.0 and off > 20.0, off)

	# Mom's and Ophelia's chests and glutes jiggle (spring bones), Biggie has none.
	for who in WHO:
		var npc = run_node.hub_npcs[who]
		var springs = npc.get_node_or_null("Springs")
		if who == "biggie":
			_check("Biggie has no jiggle springs", springs == null, springs)
			continue
		_check("%s has chest and glute springs" % who, springs != null and springs.springs.size() == 4, springs.springs.size() if springs != null else 0)
		if springs == null:
			continue
		var eco: Node3D = npc.look_target
		npc.look_target = null
		await _ticks(30)
		npc.rotation.y += 0.6   # a sharp turn sets them swinging
		await _ticks(4)
		_check("%s jiggles when she turns" % who, springs.swing_deg() > 0.5, springs.swing_deg())
		npc.look_target = eco

	# Second talk with Mom: one of her ordinary conversations, not the intro.
	var mom = run_node.hub_npcs["mom"]
	_place(mom.global_position + Vector3(1.5, 0.3, 0))
	await _ticks(10)
	run_node.talk_to("mom")
	await _ticks(2)
	var any0: Array = run_node.npc_talk.bank("mom")["any"][0]
	_check("Mom moves on from her intro", run_node.npc_talk.current_line() == "%s: %s" % any0[0].slice(0, 2), run_node.npc_talk.current_line())
	run_node.npc_talk.stop()

	# After a lost run, they've heard; once.
	run_node.start_run(7)
	await _ticks(3)
	run_node.end_run("PILOT KIA", "test")
	await _ticks(2)
	await _press("run_restart")
	await _ticks(30)
	_check("back in the hub after the run", run_node.phase == run_node.Phase.HUB and run_node.hub_npcs.has("mom"), run_node.phase)
	var oph = run_node.hub_npcs["ophelia"]
	var body_tex = null
	for mi in oph.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var o := mi.get_surface_override_material(i) as ShaderMaterial
			if o != null and o.resource_name == "npc_ophelia_body":
				body_tex = o.get_shader_parameter("albedo_tex")
	_check("Ophelia changes outfit after a run", oph.outfit == "hoodie" and body_tex != null and body_tex.resource_path.ends_with("body_hoodie.png"), [oph.outfit, body_tex])
	mom = run_node.hub_npcs["mom"]
	_place(mom.global_position + Vector3(1.5, 0.3, 0))
	await _ticks(10)
	run_node.talk_to("mom")
	await _ticks(2)
	var lost: Array = run_node.npc_talk.bank("mom")["lost"]
	_check("Mom reacts to the lost run", run_node.npc_talk.current_line() == "%s: %s" % lost[0].slice(0, 2), run_node.npc_talk.current_line())
	run_node.npc_talk.stop()
	run_node.talk_to("mom")
	await _ticks(2)
	_check("only once per run", run_node.npc_talk.current_line() != "%s: %s" % lost[0].slice(0, 2), run_node.npc_talk.current_line())
	run_node.npc_talk.stop()

	# What they've said is remembered between sessions.
	var saved := ConfigFile.new()
	saved.load(run_node.npc_path)
	_check("talks are saved", saved.get_value("mom", "met", false) and saved.get_value("biggie", "met", false), saved.get_sections())

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Steers Eco toward `to` by holding forward; true once within `reach` (m).
func _walk_to(to: Vector3, reach: float, max_ticks: int) -> bool:
	for i in max_ticks:
		var d: Vector3 = to - player.global_position
		if Vector2(d.x, d.z).length() < reach:
			Input.action_release("move_forward")
			await _ticks(30)
			return true
		player.rotation.y = atan2(-d.x, -d.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	return false


func _facing(npc: Node3D, at: Vector3) -> float:
	var d := at - npc.global_position
	d.y = 0.0
	return (-npc.global_basis.z).dot(d.normalized())


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "interact"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
