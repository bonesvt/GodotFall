extends SceneTree
## Headless test for Eco's clothes off duty (eco_model.gd outfit "skater",
## "y2k" and "date"): each has a Teen and a Mature version picked by the content rating
## (scripts/radio/content_rating.gd), with its own body texture and loose parts
## and every suit piece hidden; she leaves her goggles off in all of them,
## swaps her boots for sneakers in the casual ones, keeps them on a date (in
## her date-night makeup), the other version goes on when the rating changes,
## and back in a suit her armour comes back. The wardrobe keeps clothes for home.
## Run: godot --headless --path . -s res://tests/outfit_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")

const PATH := "user://test_outfit_wardrobe.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rating_before := ContentRating.current()
	var eco = ECO.instantiate()
	root.add_child(eco)
	await process_frame
	eco.suit_tier = 3
	eco.suit_weight = "heavy"
	var pieces: Array = eco.find_children("suit_t*", "MeshInstance3D", true, false)
	var goggles: Node3D = eco.find_child("Goggles*", true, false)
	var boots: Node3D = eco.find_child("Boots*", true, false)
	var face: MeshInstance3D = eco.find_child("Face", true, false)
	_check("model has goggles, boots and a face", goggles != null and boots != null and face != null, "")
	for part in ["outfit_skater_t_hoodie", "outfit_skater_m_hoodie", "outfit_skater_any_hood", "outfit_skater_any_shoes",
			"outfit_skater_any_buns", "outfit_y2k_t_skirt", "outfit_y2k_m_skirt", "outfit_y2k_t_warmers", "outfit_y2k_m_warmers",
			"outfit_y2k_any_shoes", "outfit_y2k_any_clips", "outfit_date_t_jacket", "outfit_date_m_jacket",
			"outfit_date_m_skirt", "outfit_date_any_hoops"]:
		_check("%s is in the model" % part, eco.find_child(part, true, false) != null, "")
	_check("starts in her suit", eco.outfit == "suit" and pieces.any(func(p): return p.visible), "")
	for rating in ["T", "M"]:
		ContentRating.set_rating(rating, false)
		for outfit in ["skater", "y2k", "date"]:
			var look := "%s_%s" % [outfit, rating.to_lower()]
			_check("wears %s" % outfit, eco.wear(outfit) and eco.look() == look, eco.look())
			var tex: Texture2D = eco.body_material().get_shader_parameter("albedo_tex")
			_check("%s has its own texture" % look, _body(eco) == eco.OUTFIT_BODY[look] and tex != null \
					and tex.resource_path.ends_with("v_body_%s.png" % look), tex.resource_path if tex else "")
			_check("%s hides every suit piece and jacket" % look, pieces.all(func(p): return not p.visible) \
					and eco.find_children("base_*", "MeshInstance3D", true, false).all(func(p): return not p.visible), "")
			var loose: Array = eco.find_children("outfit_*", "MeshInstance3D", true, false)
			var wrong: Array = loose.filter(func(m): return m.visible != (String(m.name).begins_with("outfit_%s_" % outfit) \
					and String(m.name).get_slice("_", 2) in [rating.to_lower(), "any"]))
			_check("%s shows only its own loose parts" % look, wrong.is_empty(), wrong.map(func(m): return m.name))
			var dated: bool = outfit == "date"
			_check("%s goggles off, boots %s" % [look, "on" if dated else "off"], not goggles.visible and boots.visible == dated, "")
			_check("%s makeup" % look, _face(face) == (eco.DATE_FACE if dated else null), _face(face))
	eco.wear("date")
	ContentRating.set_rating("T", false)
	await process_frame
	_check("a rating change puts the other version on", eco.look() == "date_t" and _body(eco) == eco.OUTFIT_BODY["date_t"] \
			and eco.find_child("outfit_date_t_jacket", true, false).visible and not eco.find_child("outfit_date_m_skirt", true, false).visible, eco.look())
	eco.wear("suit")
	_check("back in her suit her armour comes back", pieces.any(func(p): return p.visible) and goggles.visible and boots.visible \
			and _body(eco) == eco.body_material() and _body(eco).get_shader_parameter("use_kit") \
			and _face(face) == eco.KIT_FACE["heavy"] and eco.look() == "", "")
	Wardrobe.save_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_check("the wardrobe has her clothes", Wardrobe.options("eco").has("skater") and Wardrobe.options("eco").has("y2k") and Wardrobe.options("eco").has("date"), "")
	Wardrobe.choose("eco", "date")
	Wardrobe.dress_eco(null, true)
	_check("she wears them at home", Wardrobe.eco_now == "date", Wardrobe.eco_now)
	Wardrobe.dress_eco(null, false)
	_check("and her suit on a run", Wardrobe.eco_now == "suit", Wardrobe.eco_now)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	ContentRating.set_rating(rating_before, false)
	eco.queue_free()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _body(eco) -> Material:
	for node in eco.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "eco_v_body":
				return mi.get_surface_override_material(i)
	return null


func _face(face: MeshInstance3D) -> Material:
	for i in face.mesh.get_surface_count():
		var m := face.mesh.surface_get_material(i)
		if m != null and m.resource_name == "eco_v_face":
			return face.get_surface_override_material(i)
	return null


func _check(what: String, ok: bool, got) -> void:
	if ok:
		print("ok    ", what)
	else:
		failures += 1
		print("FAIL  ", what, "  (", got, ")")
