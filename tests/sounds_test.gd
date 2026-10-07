extends SceneTree
## Headless check of the second sound pass: the new recordings load, the
## Distant bus is there, the run's distant battle and the home's soundscape
## play, footsteps know water, rugs and stone, and the body contact sounds
## fire on a model shaped like eco_model.gd's springs.
## Run: godot --headless --path . -s res://tests/sounds_test.gd

const SFX := preload("res://scripts/sfx.gd")
const Soundscape := preload("res://scripts/soundscape.gd")
const L := preload("res://scripts/run/laid_out.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const EcoContactSounds := preload("res://scripts/ps2/eco_contact_sounds.gd")
const PLAYER := preload("res://scenes/player.tscn")

var failures := 0


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("%s  %s  (%s)" % ["ok   " if ok else "FAIL ", what, str(detail)])
	if not ok:
		failures += 1


func _init() -> void:
	for id in ["upgrade_gun", "upgrade_rack", "upgrade_knife", "upgrade_titan", "upgrade_suit", "level_up",
			"bench_open", "bench_close", "wardrobe_open", "wardrobe_close", "shop_bell", "outfit_change",
			"haircut", "coins", "map_open", "map_close", "sit_down", "bed_creak", "far_shell", "far_dropship",
			"far_siren", "cache_unlock", "mag_drop", "shell_casing", "knife_sheathe", "heartbeat", "grunt_hey"]:
		var s := SFX.stream(id)
		_check(s is AudioStreamOggVorbis and s.get_length() > 0.05, "recording for " + id, s)
	for base in ["step_stone", "step_water", "step_mud", "step_rug", "step_gravel", "chime", "bird", "far_shot",
			"paper", "contact_wall", "contact_self", "grunt_yell"]:
		var id := SFX.variant(base)
		_check(id.begins_with(base + "_") and SFX.has_recording(id), "variant of " + base, id)

	var bus := AudioServer.get_bus_index("Distant")
	_check(bus >= 0, "Distant bus exists")
	_check(AudioServer.get_bus_send(bus) == &"Ambience", "Distant goes through the Ambience slider", AudioServer.get_bus_send(bus))
	_check(AudioServer.get_bus_effect_count(bus) == 2, "Distant is muffled and echoes", AudioServer.get_bus_effect_count(bus))

	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	await process_frame

	# The war over the hills: every kind of happening lines up sounds that play on the Distant bus.
	var battle := Soundscape.battle(world, "city")
	_check(battle.gap.y < 14.0, "the city is busier", battle.gap)
	for kind in Soundscape.BATTLE:
		battle._queue.clear()
		var before := battle.get_child_count()
		battle.happen(kind)
		# a flyby starts at once and moves; everything else waits its turn in the queue
		_check(not battle._queue.is_empty() or battle.get_child_count() > before, "battle: %s lines up sounds" % kind, battle._queue.size())
		for item: Array in battle._queue:
			_check(SFX.stream(item[1]) != null, "battle: %s sound %s" % [kind, item[1]])
	battle._queue.clear()
	battle.happen("rifles")
	await process_frame
	await process_frame
	var players := battle.find_children("*", "AudioStreamPlayer3D", false, false)
	_check(not players.is_empty() and (players[0] as AudioStreamPlayer3D).bus == &"Distant", "battle sounds play on Distant", players.size())
	if not players.is_empty():
		var far: float = (players[0] as AudioStreamPlayer3D).global_position.distance_to(cam.global_position)
		_check(far > 50.0, "battle sounds are far away", far)
	battle.queue_free()

	# Home: positional beds from info["sound_spots"] and soft happenings.
	var info := {"interactables": []}
	K.sound(info, "fireplace", Vector3(3, 0, 0), -4.0, 3.0)
	K.sound(info, "town_murmur", Vector3(0, 0, 30), -8.0, 14.0)
	K.sound(info, "not_a_bed", Vector3.ZERO)
	var home := Soundscape.hub(world, info)
	await process_frame
	var spots := world.find_children("Spot_*", "AudioStreamPlayer3D", false, false)
	_check(spots.size() == 2, "home: a loop for each spot with a recording", spots.size())
	for p: AudioStreamPlayer3D in spots:
		_check(p.playing and (p.stream as AudioStreamOggVorbis).loop, "home: %s loops" % p.name)
	for kind in Soundscape.HOME:
		home._queue.clear()
		home.happen(kind)
		_check(not home._queue.is_empty(), "home: %s lines up sounds" % kind)
	home.queue_free()

	# Footsteps: wading, a rug, then the floor's own surface.
	var floor_body := Kit.box(world, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.5, 0.5, 0.5))
	floor_body.set_meta("surface", "stone")
	var player := PLAYER.instantiate()
	world.add_child(player)
	# only her body: no gun, knife or camera rig running in a bare test world
	player.set_physics_process(false)
	player.set_process(false)
	for child in player.get_children():
		if not child is CollisionShape3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0, 0.05, 0)
	await physics_frame
	player.velocity = Vector3(0, -20.0, 0)
	player.move_and_slide()
	_check(player._surface() == "stone", "steps: the floor's surface", player._surface())
	_check(player._step_sound().begins_with("step_stone_"), "steps: a stone take", player._step_sound())
	K.patch(world, Vector3(0, 0, 0), Vector2(2, 3), "rug", 30.0)
	_check(player._surface() == "rug", "steps: on the rug", player._surface())
	L.water(world, Vector3(0, 0.3, 0), Vector2(10, 10), Color(0.1, 0.2, 0.2, 0.9))
	_check(player._surface() == "water", "steps: wading", player._surface())
	player.global_position = Vector3(8, 0.05, 8)
	player.velocity = Vector3(0, -20.0, 0)
	player.move_and_slide()
	_check(player._surface() == "stone", "steps: out of the water and off the rug", player._surface())
	floor_body.set_meta("surface", "lava_glass")
	_check(player._step_sound().begins_with("step_concrete_"), "steps: an unknown surface sounds like concrete", player._step_sound())
	_check(player.get_node_or_null("ContactSounds") != null, "the player listens for body contact")
	player.queue_free()

	# Body contact against a stand-in shaped like eco_model.gd's springs.
	var fake_src := GDScript.new()
	fake_src.source_code = "extends Node3D\nvar jiggle_collide := true\nvar _springs: Array = []\nfunc nudge(_p: Vector3) -> void:\n\tpass\n"
	fake_src.reload()
	var body_root := Node3D.new()
	body_root.name = "EcoBody"
	world.add_child(body_root)
	var fake: Node3D = fake_src.new()
	body_root.add_child(fake)
	var wall := Kit.box(world, Vector3(5.0, 1.0, 0), Vector3(0.2, 2.0, 2.0), Color(0.5, 0.5, 0.5))
	var glute := {"bone": 1, "ready": true, "base": {"group": "glute"}, "touch": 0.045,
			"tip": Vector3(4.8, 1.0, 0), "prev": Vector3(4.8, 1.0, 0), "pairs": []}
	var thigh_l := {"bone": 2, "ready": true, "base": {"group": "thigh"}, "touch": 0.075,
			"tip": Vector3(0, 1.0, 0), "prev": Vector3(0, 1.0, 0), "pairs": []}
	var thigh_r := {"bone": 3, "ready": true, "base": {"group": "thigh"}, "touch": 0.075,
			"tip": Vector3(0.3, 1.0, 0), "prev": Vector3(0.3, 1.0, 0), "pairs": [[thigh_l, false]]}
	var hair := {"bone": 4, "ready": true, "base": {"group": "hair"}, "touch": 0.015,
			"tip": Vector3(4.85, 1.2, 0), "prev": Vector3(4.6, 1.2, 0), "pairs": []}
	fake._springs = [glute, thigh_l, thigh_r, hair]
	var contact := EcoContactSounds.new()
	world.add_child(contact)
	contact.model = EcoContactSounds.find_model(body_root)
	_check(contact.model == fake, "contact: finds the model under EcoBody")
	for i in 3:
		await physics_frame
	_check(contact.played["wall"] == 0 and contact.played["self"] == 0, "contact: quiet while nothing touches", contact.played)
	# Swing the glute into the wall and the right thigh into the left.
	glute["prev"] = Vector3(4.82, 1.0, 0)
	glute["tip"] = Vector3(4.88, 1.0, 0)
	thigh_r["prev"] = Vector3(0.2, 1.0, 0)
	thigh_r["tip"] = Vector3(0.14, 1.0, 0)
	for i in 3:
		await physics_frame
	_check(contact.played["wall"] == 1, "contact: a part swung into a wall pats it once", contact.played)
	_check(contact.played["self"] == 1, "contact: thighs swinging together rustle once", contact.played)
	fake.jiggle_collide = false
	glute["tip"] = Vector3(4.0, 1.0, 0)
	for i in 3:
		await physics_frame
	glute["prev"] = Vector3(4.82, 1.0, 0)
	glute["tip"] = Vector3(4.88, 1.0, 0)
	for i in 3:
		await physics_frame
	_check(contact.played["wall"] == 1, "contact: silent with body collision off", contact.played)
	wall.queue_free()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
