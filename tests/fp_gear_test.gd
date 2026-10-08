extends SceneTree
## The Shepherd's gear (colony_gear.gd) in first person: her arm on the gun
## (eco_fp_arms.gd) is her whole model cut down to the right arm, so gear on
## any other bone (headphones, visor, spine, the cuff, the left glove) must be
## hidden there or it floats in front of the camera. Her right glove stays.
##   godot --headless --path . --audio-driver Dummy -s res://tests/fp_gear_test.gd

const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const EcoArms := preload("res://scripts/eco_fp_arms.gd")
const EcoBody := preload("res://scripts/eco_fp_body.gd")

var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	Hymn.gear = ["headphones", "cuff", "visor", "bridge", "gloves", "spine"]
	_run.call_deferred()


func _run() -> void:
	var arms := EcoArms.new()
	root.add_child(arms)
	for i in 3:
		await process_frame
	var sk: Skeleton3D = arms.skeleton
	var shown := []
	var glove := false
	for child in sk.get_children():
		var att := child as BoneAttachment3D
		if att == null or not String(att.name).begins_with("ColonyGear"):
			continue
		if att.is_visible_in_tree():
			shown.append(String(att.name))
			if String(att.name).begins_with("ColonyGear_Glove") and String(att.name).ends_with("R"):
				glove = true
	_check("no gear off her right arm shows", shown.all(func(n): return n.begins_with("ColonyGear_Glove") and n.ends_with("R")), shown)
	_check("her right glove does", glove, shown)
	# the suit changing rebuilds the gear; it stays hidden
	arms.model.apply_suit()
	await process_frame
	var again := sk.get_children().filter(func(c): return c is BoneAttachment3D and String(c.name) == "ColonyGear" and c.is_visible_in_tree())
	_check("still hidden after a rebuild", again.is_empty(), again)

	# her full model in first person ("Shadow", eco_fp_body.gd) is drawn only
	# into shadows: its gear must be too, or it hangs round the camera
	var holder := Node3D.new()
	root.add_child(holder)
	var fp: Node3D = EcoBody.new()
	holder.add_child(fp)
	for i in 3:
		await process_frame
	fp.shadow.apply_suit()
	var drawn := _gear_meshes(fp.shadow).filter(func(m): return m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_check("first person: her shadow copy's gear only casts a shadow", not _gear_meshes(fp.shadow).is_empty() and drawn.is_empty(), drawn.size())
	fp.set_third_person(true)
	drawn = _gear_meshes(fp.shadow).filter(func(m): return m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_check("third person: it's drawn for real", drawn.is_empty(), drawn.size())
	Hymn.gear = []
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _gear_meshes(model: Node) -> Array:
	var out := []
	for att in model.find_children("ColonyGear*", "BoneAttachment3D", true, false):
		out.append_array(att.find_children("*", "MeshInstance3D", true, false))
	return out


func _check(what: String, ok: bool, detail = null) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + what + ("" if ok else "  (%s)" % str(detail)))
