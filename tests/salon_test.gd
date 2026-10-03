extends SceneTree
## The hair salon (scripts/hub/hair.gd, salon_screen.gd, town.gd's Cut & Chrome):
## every haircut loads and swaps onto Eco's and Ophelia's skeletons with their
## own hair materials, follows the head when it moves, the choice is saved and
## re-cuts every model of them, and the salon is in town with Juno at it.
## Run: godot --headless --path . -s tests/salon_test.gd

const Hair := preload("res://scripts/hub/hair.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const SalonScreen := preload("res://scripts/hub/salon_screen.gd")
const ECO := preload("res://assets/models/eco.tscn")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")

var failures := 0


func _check(label: String, ok: bool, detail = null) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label, "  ", detail)


func _initialize() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Hair.save_path = "user://test_salon.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Hair.save_path))
	var stage := Node3D.new()
	root.add_child(stage)

	_check("Eco and Ophelia have five haircuts besides their own", Hair.style_ids("eco").size() == 6 and Hair.style_ids("ophelia").size() == 6)
	_check("nobody's been to the salon: own hair", Hair.current("eco") == "bob" and Hair.current("ophelia") == "choppy")

	var eco = ECO.instantiate()
	stage.add_child(eco)
	var oph := HubNpc.create("ophelia", Vector3(3, 0, 0), 0.0)
	stage.add_child(oph)
	await _ticks(2)
	var oph_model: Node = oph.get_node("Model")
	for spec in [[eco, "eco"], [oph_model, "ophelia"]]:
		var model: Node = spec[0]
		var who: String = spec[1]
		var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var own := skel.get_node("Hair") as MeshInstance3D
		_check("%s wears their own hair" % who, own.visible and skel.get_node_or_null(Hair.SALON_HAIR) == null)
		for style in Hair.style_ids(who).slice(1):
			Hair.apply(model, who, style)
			var cut := skel.get_node_or_null(Hair.SALON_HAIR) as MeshInstance3D
			var ok: bool = cut != null and not own.visible and cut.skin != null and cut.get_node(cut.skeleton) == skel
			_check("%s: %s swaps in, skinned to their skeleton" % [who, style], ok, cut)
			if cut == null:
				continue
			var bare := []
			for i in cut.mesh.get_surface_count():
				var m := cut.get_surface_override_material(i)
				if m == null or not (m is ShaderMaterial):
					bare.append(i)
			_check("%s: %s has their hair's toon materials" % [who, style], bare.is_empty(), bare)
			# the haircut sits on the head: its bounds round the head bone
			var head := skel.find_bone("J_Bip_C_Head")
			var head_at := skel.global_transform * skel.get_bone_global_pose(head).origin
			var box := cut.global_transform * cut.get_aabb()
			_check("%s: %s sits on their head" % [who, style], box.grow(0.05).has_point(head_at) and box.end.y > head_at.y + 0.1, [box, head_at])
		Hair.apply(model, who, Hair.default_style(who))
		_check("%s back to their own hair" % who, own.visible and skel.get_node_or_null(Hair.SALON_HAIR) == null)

	# The haircut is skinned to the head and hair bones by name, so it moves with them.
	Hair.apply(eco, "eco", "ponytail")
	var skel := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	var cut := skel.get_node(Hair.SALON_HAIR) as MeshInstance3D
	var names := []
	for i in cut.skin.get_bind_count():
		names.append(String(cut.skin.get_bind_name(i)))
	_check("ponytail bound by name to the head and the back hair chains", names.has("J_Bip_C_Head") and names.has("J_Sec_Hair3_01") and skel.find_bone("J_Sec_Hair3_01") >= 0, names.size())

	# Choosing saves it and re-cuts every model of them, new ones included.
	Hair.choose(self, "eco", "undercut")
	Hair.choose(self, "ophelia", "braids")
	_check("choice saved", Hair.current("eco") == "undercut" and Hair.current("ophelia") == "braids")
	var eco_cut := skel.get_node_or_null(Hair.SALON_HAIR)
	_check("Eco's model re-cut", eco_cut != null and eco_cut.get_meta("style") == "undercut", eco_cut)
	var eco2 = ECO.instantiate()
	stage.add_child(eco2)
	await _ticks(1)
	var cut2 = eco2.find_child("Skeleton3D", true, false).get_node_or_null(Hair.SALON_HAIR)
	_check("a new Eco wears the saved haircut", cut2 != null and cut2.get_meta("style") == "undercut", cut2)
	var oph_cut = oph_model.find_child("Skeleton3D", true, false).get_node_or_null(Hair.SALON_HAIR)
	_check("Ophelia re-cut", oph_cut != null and oph_cut.get_meta("style") == "braids", oph_cut)

	# The salon screen: browse, cut, switch to Ophelia.
	var screen := SalonScreen.new()
	root.add_child(screen)
	await _ticks(2)
	_check("screen opens on Eco's current haircut", screen.who() == "eco" and Hair.style_ids("eco")[screen.selected] == "undercut", screen.selected)
	screen.select(Hair.style_ids("eco").find("pixie"))
	_check("browsing doesn't cut", Hair.current("eco") == "undercut")
	_check("cut it", screen.confirm() and Hair.current("eco") == "pixie" and screen.cut == [["eco", "pixie"]], screen.cut)
	_check("cutting what she has does nothing", not screen.confirm())
	screen.switch_client(1)
	_check("Ophelia's turn", screen.who() == "ophelia" and Hair.style_ids("ophelia")[screen.selected] == "braids", screen.selected)
	screen.queue_free()

	# The salon is in town, with Juno and her chair.
	var hub := Node3D.new()
	root.add_child(hub)
	var info: Dictionary = HubBuilder.build(hub)
	var spot := {}
	for s in info["interactables"]:
		if s["id"] == "salon":
			spot = s
	_check("Cut & Chrome is in town and opens the salon screen", spot.get("screen") == "salon" and spot["pos"].z > 160.0, spot)
	var juno: Array = info["npcs"].filter(func(n): return n["who"] == "stylist")
	_check("Juno works there", juno.size() == 1 and juno[0]["pos"].distance_to(spot["pos"]) < 3.0, juno)
	_check("Juno has a model", ResourceLoader.exists("res://assets/models/npc/stylist.glb"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Hair.save_path))
	print("salon_test: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
