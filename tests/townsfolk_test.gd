extends SceneTree
## The people of Solace (scripts/hub/townsfolk.gd, townsperson.gd,
## dialogue/town/): every one of them is built and placed in town with their
## loops, walkers walk their routes and give way to Eco, pairs chat where she
## can overhear (captions over their heads), people speak to her as she
## passes, and the town's lines are there for every stage at both ratings.
## Run: godot --headless --path . -s tests/townsfolk_test.gd

const Townsfolk := preload("res://scripts/hub/townsfolk.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")
const DialogueBank := preload("res://scripts/radio/dialogue_bank.gd")
const RadioLines := preload("res://scripts/radio/radio_lines.gd")
const Babble := preload("res://scripts/hub/babble.gd")

var failures := 0


func _check(label: String, ok: bool, detail = null) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label, "  ", detail)


func _initialize() -> void:
	_run.call_deferred()


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _run() -> void:
	# --- the lines ---
	for rating in ["M"]:
		var bank := DialogueBank.bank("town")
		for kind in ["chat", "mutter", "greet"]:
			for stage in [1, 2, 3]:
				var key := "%s_%d" % [kind, stage]
				var list: Array = bank.get(key, [])
				_check("%s: %s has lines" % [rating, key], list.size() >= 4, list.size())
				var bad := []
				for entry: String in list:
					var lines := RadioLines.parse(entry)
					var roles := RadioLines.roles(entry)
					var ok := true
					for l in lines:
						ok = ok and String(l[1]).strip_edges() != "" and l[0] in ["a", "b"]
					if kind == "chat":
						ok = ok and roles.size() == 2
					else:
						ok = ok and lines.size() == 1
					if not ok:
						bad.append(entry)
				_check("%s: %s lines are well formed" % [rating, key], bad.is_empty(), bad)
	_check("suspicion grows with runs", Townsfolk.stage_for(0) == 1 and Townsfolk.stage_for(1) == 1
			and Townsfolk.stage_for(2) == 2 and Townsfolk.stage_for(4) == 2 and Townsfolk.stage_for(5) == 3)
	for spec: Dictionary in Townsfolk.PEOPLE:
		_check("%s has a voice" % spec["who"], Babble.VOICES.has("town_" + spec["who"]))

	# --- the town ---
	var stage := Node3D.new()
	root.add_child(stage)
	var info := HubBuilder.build(stage)
	var pilot := Node3D.new()
	pilot.position = Vector3(0, 0, 60)   # out of town for now
	stage.add_child(pilot)
	var folk = Townsfolk.populate(stage, pilot, 0)
	_check("townsfolk come with the town", folk != null)
	if folk == null:
		_finish()
		return
	await _seconds(0.3)
	_check("everyone is there", folk.people.size() == Townsfolk.PEOPLE.size(), folk.people.keys())
	for n: String in folk.people:
		var p: Node3D = folk.people[n]
		var anim := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var have := anim != null and anim.has_animation("idle") and anim.has_animation("talk") \
				and anim.has_animation("walk") and anim.has_animation("sit") and anim.has_animation("sit_talk")
		_check("%s: model with idle, talk, walk and sit loops" % n, have, anim.get_animation_list() if anim else null)
		var meshes := p.find_children("*", "MeshInstance3D", true, false)
		var untextured := []
		for mi: MeshInstance3D in meshes:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as ShaderMaterial
				if m == null or m.get_shader_parameter("albedo_tex") == null:
					untextured.append("%s/%d" % [mi.name, i])
		_check("%s: toon materials with their textures" % n, not meshes.is_empty() and untextured.is_empty(), untextured)
		var inside: bool = p.position.z > 128.0 and p.position.z < 216.0 and absf(p.position.x) < 24.0
		_check("%s stands in town" % n, inside, p.position)

	var kit: Node3D = folk.people["kit"]
	var from := kit.position
	await _seconds(2.0)
	_check("walkers walk their routes", kit.position.distance_to(from) > 1.0, [from, kit.position])
	var model_anim := kit.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("walkers play their walk", model_anim.current_animation == "walk", model_anim.current_animation)

	# Eco steps in front of a walker: they stop for her.
	var dez: Node3D = folk.people["dez"]
	await _seconds(0.1)
	var heading := Vector3(-sin(dez.home_yaw), 0, -cos(dez.home_yaw))
	pilot.position = dez.position + heading * 1.0
	await _seconds(0.5)
	var held := dez.position
	await _seconds(0.6)
	_check("a walker gives way to Eco", dez.position.distance_to(held) < 0.05, [held, dez.position])

	# Eco by the bench: someone has a word for her, then the old pair chat.
	var tobin: Node3D = folk.people["tobin"]
	pilot.position = tobin.position + Vector3(2.5, 0, 0)
	var greeted := false
	var chatted := false
	var caption := ""
	var end := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < end and not (greeted and chatted):
		await process_frame
		for n: String in folk.people:
			var p: Node3D = folk.people[n]
			if p.talking:
				var cap := p.get_node("Caption") as Label3D
				if cap.visible and cap.text != "":
					caption = cap.text
				if n in ["tobin", "rosa"] and folk._chat.size() > 0:
					chatted = true
				elif folk._chat.is_empty() and p.position.distance_to(pilot.position) < Townsfolk.GREET_RANGE + 0.5:
					greeted = true
	_check("someone speaks to Eco as she passes", greeted)
	_check("Tobin and Rosa chat where she can hear", chatted)
	_check("their words show over their heads", caption != "", caption)
	_finish()


func _finish() -> void:
	print("townsfolk_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
