extends SceneTree
## Eco's hypno looks (scripts/hub/vice_looks.gd): each path's meter puts her in
## its look by stages, the deepest path wins, the wardrobe locks while one has
## her and keeps every stage she reached, the free endings' looks unlock, all
## of it is Mature only and saved, and her model wears a look (hair, eyes,
## crystals) and takes it back off.
## Run: godot --headless --path . -s tests/vice_looks_test.gd

const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const ECO := preload("res://assets/models/eco.tscn")

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


func _clean() -> void:
	for p in [ViceLooks.save_path, Wardrobe.save_path, Obsession.save_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	var rating := ContentRating.current()
	ContentRating.set_rating("M", false)
	Wardrobe.save_path = "user://test_looks_wardrobe.cfg"
	ViceLooks.open("user://test_looks.cfg")
	_clean()
	ViceLooks.reset()
	Obsession.save_path = "user://test_looks_obsession.cfg"
	Obsession.reset()
	Vices.hold = 0.0
	Glass.glass = 0
	Hymn.level = 0.0

	# Every look's textures are baked, and every look and path is whole.
	for key: String in ViceLooks.LOOKS:
		var look: Dictionary = ViceLooks.LOOKS[key]
		_check("%s starts from one of her outfits" % key, look["base"] in ["suit", "suit_shade", "suit_ophelia", "date"], look["base"])
		var baked := ["body", "hair", "eyeline", "face"].filter(func(part): return ResourceLoader.exists(ViceLooks.TEX % [key, part]))
		_check("%s has its textures baked" % key, not baked.is_empty())
	for path: String in ViceLooks.PATHS:
		for key: String in ViceLooks.PATHS[path]["looks"]:
			_check("%s's look %s exists" % [path, key], ViceLooks.LOOKS.has(key))
		_check("%s is in the order" % path, path in ViceLooks.ORDER)

	# Nothing has her at first.
	_check("nothing has her at first", ViceLooks.forced() == "")
	_check("the wardrobe isn't locked", not Wardrobe.locked())

	# Stages by meter.
	Vices.hold = 30.0
	_check("Hold 30 is His stage 1", ViceLooks.forced() == "vl_marrow_1", ViceLooks.forced())
	Vices.hold = 100.0
	ViceLooks.note_reached()
	_check("full Hold is His stage 4", ViceLooks.forced() == "vl_marrow_4", ViceLooks.forced())
	_check("its name reads as the stage", ViceLooks.look_name("vl_marrow_4") == "Marrow's: His (Marrow's Own)", ViceLooks.look_name("vl_marrow_4"))
	_check("the wardrobe locks", Wardrobe.locked())
	Glass.glass = Glass.MAX_GLASS
	_check("a tie goes by ORDER (Marrow before Glass)", ViceLooks.forced() == "vl_marrow_4", ViceLooks.forced())
	Hymn.level = 100.0
	ViceLooks.note_reached()
	_check("Hymn comes first of all", ViceLooks.forced() == "vl_hymn_4", ViceLooks.forced())
	Hymn.level = 0.0
	Vices.hold = 50.0
	_check("the deepest path wins", ViceLooks.forced() == "vl_glass_4", ViceLooks.forced())
	_check("changed() sees it", ViceLooks.changed())
	_check("and only once", not ViceLooks.changed())

	# Keepsake: one look per stage, three stages.
	Vices.hold = 0.0
	Glass.glass = 0
	ViceLooks.add("obsession", 100.0)
	_check("it's Ophelia's own obsession meter", Obsession.meter == 100.0, Obsession.meter)
	_check("full obsession is Homebound", ViceLooks.forced() == "vl_keepsake_3", ViceLooks.forced())
	_check("Homebound wears keepsake_c whole", ViceLooks.resolve("vl_keepsake_3") == ["keepsake_c", 4], ViceLooks.resolve("vl_keepsake_3"))
	_check("Keepsake starts from Ophelia's suit", ViceLooks.base("vl_keepsake_1") == "suit_ophelia")
	ViceLooks.changed()

	# Faith's glass is gold.
	ViceLooks.add("obsession", -100.0)
	ViceLooks.add("devotion", 100.0)
	ViceLooks.note_reached()
	_check("the Idol's glass covers her", ViceLooks.glass_level() > 0.8, ViceLooks.glass_level())
	_check("and it's gold", ViceLooks.glass_tint() == ViceLooks.GOLD, ViceLooks.glass_tint())
	ViceLooks.add("devotion", -100.0)
	_check("Marrow's glass is violet", ViceLooks.glass_tint() == ViceLooks.VIOLET)

	# Freed: everything she reached stays in the wardrobe.
	ViceLooks.changed()
	_check("free again", ViceLooks.forced() == "" and not Wardrobe.locked())
	var eco_list := Wardrobe.outfits("eco")
	for id in ["vl_marrow_1", "vl_marrow_4", "vl_glass_4", "vl_hymn_4", "vl_keepsake_3", "vl_faith_4"]:
		_check("she kept %s" % id, id in eco_list, eco_list)
	_check("not what she never reached", not "vl_colony_1" in eco_list)
	Wardrobe.choose("eco", "vl_glass_2")
	_check("she can pick a kept look", Wardrobe.choice("eco") == "vl_glass_2", Wardrobe.choice("eco"))
	Vices.hold = 80.0
	Wardrobe.choose("eco", "suit")
	_check("but not change while under", Wardrobe.choice("eco") == "vl_glass_2", Wardrobe.choice("eco"))
	Vices.hold = 0.0

	# Free endings.
	_check("Warden isn't hers yet", not "vl_warden" in Wardrobe.outfits("eco"))
	_check("Warden unlocks", ViceLooks.unlock("warden"))
	_check("and it's in her wardrobe", "vl_warden" in Wardrobe.outfits("eco"))
	_check("by name", Wardrobe.outfit_name("vl_warden") == "Warden", Wardrobe.outfit_name("vl_warden"))

	_check("Her Own waits until she's helped Ophelia", not "vl_her_own" in Wardrobe.outfits("eco"))
	Obsession.resolved = "helped"
	ViceLooks.note_reached()
	_check("helping her through it unlocks Her Own", "vl_her_own" in Wardrobe.outfits("eco"))
	Obsession.reset()

	# Saved.
	ViceLooks.open(ViceLooks.save_path)
	_check("what she reached is saved", int(ViceLooks.reached.get("glass", 0)) == 4, ViceLooks.reached)
	_check("her unlocks are saved", "warden" in ViceLooks.unlocked, ViceLooks.unlocked)

	# Teen: none of it.
	ContentRating.set_rating("T", false)
	Vices.hold = 100.0
	_check("Teen: nothing has her", ViceLooks.forced() == "")
	_check("Teen: no looks in the wardrobe", ViceLooks.wardrobe_looks().is_empty())
	ContentRating.set_rating("M", false)
	Vices.hold = 0.0

	# On her model.
	var eco: Node3D = ECO.instantiate()
	root.add_child(eco)
	await _ticks(3)
	_check("she wears a look by name", eco.wear("vl_glass_4"))
	_check("over the outfit it starts from", eco.outfit == "suit_shade" and eco.vice_look == "vl_glass_4", [eco.outfit, eco.vice_look])
	var skeleton := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	var salon := skeleton.get_node_or_null(Hair.SALON_HAIR)
	_check("Kintsugi braids her hair", salon != null and salon.get_meta("style", "") == "braids", salon)
	var clusters := ViceLooks.crystal_clusters(eco)
	_check("crystal grows on her", clusters.size() == 12, clusters.size())
	_check("riding her bones", clusters.all(func(c): return c is BoneAttachment3D and c.get_parent() == skeleton and c.bone_idx >= 0))
	var iris := _surface(eco, "eco_v_iris")
	_check("her eyes go pale", iris != null and (iris.get_shader_parameter("albedo") as Color).is_equal_approx(ViceLooks.LOOKS["kintsugi"]["iris"]), iris)
	var body := _surface(eco, "eco_v_body")
	_check("her suit opens on her skin", body != null and body.get_shader_parameter("mask_tex") == load(ViceLooks.TEX % ["kintsugi", "mask"]), body)
	eco.wear("vl_glass_1")
	await _ticks(1)
	_check("stage 1: a little crystal", ViceLooks.crystal_clusters(eco).size() == 3, ViceLooks.crystal_clusters(eco).size())
	_check("stage 1: her eyes are still hers", _surface(eco, "eco_v_iris") == null)
	_check("stage 1: her hair is dyed already", _surface(eco, "eco_v_hair") != null)
	eco.wear("suit")
	await _ticks(1)
	_check("out of it: no crystal", ViceLooks.crystal_clusters(eco).is_empty())
	_check("out of it: her own hair colour", _surface(eco, "eco_v_hair") == null)
	_check("out of it: no look", eco.vice_look == "")
	_check("a look she doesn't have isn't worn", not eco.wear("vl_nothing_9"))
	eco.queue_free()

	_clean()
	ContentRating.set_rating(rating, false)
	await _ticks(2)
	print("RESULT ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)


## The override on the first surface using the glb material `name`, if any.
func _surface(eco: Node, name: String) -> ShaderMaterial:
	for mi: MeshInstance3D in eco.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == name:
				return mi.get_surface_override_material(i) as ShaderMaterial
	return null
