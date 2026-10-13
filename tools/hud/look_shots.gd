extends SceneTree
## The HUD in its look (scripts/ui/hud_style.gd) over a real level, with every
## story element up at once: who Eco's with (HEART), what has a hold on her
## (HELD), a zone toast, a prompt, the radio intercept, one of her whispers,
## the fight panel, the titan build and the run status; then the same street
## with a dialogue caption and a tutorial card.
##   xvfb-run -a godot --audio-driver Dummy --path . -s res://tools/hud/look_shots.gd -- <out_dir> [--level=level2]
## Needs a renderer (not --headless). Writes <out_dir>/hud-run.png and
## hud-talk.png at the game's 1600x900. Only what is near the camera stays in
## the level, as in tools/procgen/shots.gd, so software renderers finish.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const Levels := preload("res://scripts/run/levels.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CULL := 140.0

var out := "user://hud_look_shots"
var level := "level2"
var run_node
var _parked: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	run_node.start_in_hub = false
	run_node.armory_path = "user://shots_hud_look_armory.cfg"
	run_node.npc_path = "user://shots_hud_look_npcs.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await process_frame
	run_node.tutorial.set_enabled(false)
	var plan = LevelPlan.make_level(101, Levels.spec(level))
	run_node._fresh_level("Zone")
	run_node.remove_child(run_node.zone_root)
	run_node.zone_info = ZoneGenerator.build_from_plan(run_node.zone_root, plan, plan.zone_index)
	var info: Dictionary = run_node.zone_info
	if Levels.spec(level).get("night", false):
		preload("res://scripts/run/procgen/biome.gd").night(run_node.zone_root, info)
	for n in run_node.zone_root.get_children():
		run_node.zone_root.remove_child(n)
		_parked.append(n)
	run_node.add_child(run_node.zone_root)
	run_node.set_physics_process(false)
	for g in info["grunts"]:
		g.passive = true
	# Eco a few steps into the level, looking up the street.
	var loud: int = plan.lane_of("loud")
	var z: float = plan.spawn_z - 6.0
	var feet := Vector3(plan.lane_x(loud, z), plan.ground(plan.lane_x(loud, z), z), z)
	var ahead := Vector3(plan.lane_x(loud, z - 40.0), feet.y, z - 40.0)
	await _cull(feet, ahead)
	var player: Node3D = run_node.player
	player.global_position = feet + Vector3.UP * 0.2
	player.look_at(Vector3(ahead.x, player.global_position.y, ahead.z), Vector3.UP)
	await _frames(30)
	_story()
	await _frames(40)
	await _save("hud-run")
	# The same street, mid-conversation, with a tutorial card up.
	_talk()
	await _frames(20)
	await _save("hud-talk")
	Hymn.reset()
	Hymn.save()
	Obsession.reset()
	Obsession.save()
	quit()


## Every story element on screen, as the run manager would write it.
func _story() -> void:
	var hud = run_node.hud
	var pilot = run_node.pilot_hud
	hud.set_relations("Ophelia   Crush   68/100\n   obsession 12%")
	Hymn.level = 34.0
	Hymn.gear = ["headphones", "cuff"]
	Obsession.keepsake = 40.0
	hud.toast(Levels.title(level), 999.0)
	hud.prompt_label.text = "[F] Open salvage"
	hud.status_label.text = "RUN 1234    LEVEL %d    PILOT 100    4:32    SCRAP 128  ALLOY 14  CIRCUITS 3  LOCK CORES 1" % Levels.spec(level)["number"]
	hud.build_label.text = "TITAN BUILD\nChassis: Stryder Frame\nWeapon: XO-16 Chaingun\nCore: No Core (scrap)\nKit: No Kit (scrap)"
	hud.build_label.visible = true
	var weapon = pilot.weapon
	if weapon != null:
		weapon.ammo = maxi(weapon.magazine_size - 2, 1)
	var radio = pilot.radio
	radio.process_mode = Node.PROCESS_MODE_DISABLED
	var popup = radio.popup
	popup.show_line("HOUND", "Six hours on this ridge and the scariest thing I've seen is a bird.", 1.0)
	popup.show_line("TOAD", "That bird stole Hollis's lunch. Respect the bird.", 0.75)
	popup.show_line("COMMAND", "Cut the chatter. Patrol quotas are up twelve percent.", 1.0, true)
	for e in popup.entries:
		e["shown"] = 999.0
	var whispers = pilot.whispers
	whispers.process_mode = Node.PROCESS_MODE_DISABLED
	whispers.caption.process_mode = Node.PROCESS_MODE_ALWAYS  # it fades in on its own clock
	whispers.caption.show_line("Mm-hm. And yet I'm the one on your frequency.")
	whispers.caption.shown = 99.0


## A dialogue caption (npc_talk.gd) and a tutorial card instead of the toast,
## prompt and radio.
func _talk() -> void:
	var hud = run_node.hud
	hud.toast("", 0.0)
	hud.prompt_label.text = ""
	run_node.pilot_hud.radio.popup.end_transmission()
	run_node.pilot_hud.radio.popup.quiet_time = 99.0
	run_node.pilot_hud.whispers.caption.end_line()
	var talk = run_node.npc_talk
	talk._name.text = "OPHELIA"
	talk._name.add_theme_color_override("font_color", talk.COLORS["ophelia"])
	if talk.get("_card") != null:
		talk._card.border_color = talk.COLORS["ophelia"]
	talk._hearts.fill = 3.5
	talk._hearts.visible = true
	talk._stage.text = "CRUSH"
	talk._stage.visible = true
	talk._text.text = "You came back. I counted the lamps along the wall while you were gone. Twice."
	talk._text.visible = true
	talk._text.visible_characters = -1
	talk._hint.text = "[F] next"
	talk._panel.visible = true
	var tut = run_node.tutorial
	tut._title.text = "SUPPLY CRATE"
	tut._title.add_theme_color_override("font_color", tut.AMBER)
	tut._body.text = tut._keys("Colony supplies. Press [F] to pry the lid off.\nInside is scrap, and sometimes circuits: the gunsmith's bench at the temple turns them into weapon upgrades.")
	tut._card.visible = true
	tut._card.modulate.a = 1.0


func _save(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(shot + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


## Puts back only what's near the shot (see tools/procgen/shots.gd).
func _cull(eye: Vector3, look: Vector3) -> void:
	var zr: Node3D = run_node.zone_root
	var keep := []
	for n in _parked:
		if not n is Node3D or n is WorldEnvironment or n is Light3D or n is MultiMeshInstance3D or String(n.name) == "Ground":
			keep.append(n)
			continue
		var p: Vector3 = (n as Node3D).position
		var flat := Vector2(p.x, p.z)
		if flat.distance_to(Vector2(eye.x, eye.z)) < CULL or flat.distance_to(Vector2(look.x, look.z)) < CULL * 0.6:
			keep.append(n)
	for n in keep:
		_parked.erase(n)
		zr.add_child(n)
	await process_frame
	for n in keep:
		var stack: Array = [n]
		while not stack.is_empty():
			var g: Node = stack.pop_back()
			stack.append_array(g.get_children())
			if g is GeometryInstance3D:
				for prop in g.get_property_list():
					var pn: String = prop["name"]
					if pn.begins_with("instance_shader_parameters/"):
						var key := pn.substr(27)
						g.set_instance_shader_parameter(key, g.get_instance_shader_parameter(key))
