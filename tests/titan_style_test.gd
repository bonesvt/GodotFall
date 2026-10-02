extends SceneTree
## Titan paint jobs and tweaks (titan_style.gd): styles save per chassis, a
## paint job recolours the livery, tweaks scale or remove the right parts, and
## the titan you drop wears the saved style.
## Run: godot --headless --path . -s res://tests/titan_style_test.gd

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const TitanStyle := preload("res://scripts/run/titan_style.gd")
const Titan := preload("res://scripts/run/titan.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TitanStyle.path = "user://titan_style_test.cfg"
	DirAccess.remove_absolute(TitanStyle.path)

	# Every player chassis has the parts the tweaks act on.
	for chassis in TitanStyle.CHASSIS:
		var model := Art.titan(chassis, "xo16")
		for part in ["ArmRFender", "Antenna", "LegRPouch", "CockpitCharms", "Decals", "Core"]:
			_check("%s has %s" % [chassis, part], model.find_child(part, true, false) != null, part)
		_check("%s default style changes nothing" % chassis, _overrides(_styled(chassis, TitanStyle.DEFAULT)) == 0, _overrides(_styled(chassis, TitanStyle.DEFAULT)))
		model.free()

	# Saving is per chassis and survives a reload.
	var style := TitanStyle.load_style("ogre")
	_check("unsaved style is the default", style == TitanStyle.DEFAULT, style)
	style["livery"] = "bubblegum"
	style["fenders"] = "big"
	TitanStyle.save_style("ogre", style)
	_check("saved style loads back", TitanStyle.load_style("ogre") == style, TitanStyle.load_style("ogre"))
	_check("other chassis keep theirs", TitanStyle.load_style("atlas") == TitanStyle.DEFAULT, TitanStyle.load_style("atlas"))

	# Picking a paint job clears hand-picked colours; stepping wraps around.
	style = TitanStyle.DEFAULT.duplicate()
	style["body"] = "lime"
	TitanStyle.step(style, "livery", 1)
	_check("paint job clears picked colours", style["livery"] != "factory" and style["body"] == "", style)
	TitanStyle.step(style, "fenders", -1)
	TitanStyle.step(style, "fenders", -1)
	_check("steps wrap around", style["fenders"] == "big", style["fenders"])

	# A paint job recolours body, stripes and trim.
	style = TitanStyle.DEFAULT.duplicate()
	style["livery"] = "midnight"
	var painted := _styled("atlas", style)
	var body := _albedo(painted, "paint_atlas")
	_check("paint job paints the body", body.is_equal_approx(TitanStyle.PALETTE["licorice"]), body)
	_check("paint job paints stripes", _albedo(painted, "stripe_atlas").is_equal_approx(TitanStyle.PALETTE["hot pink"]), _albedo(painted, "stripe_atlas"))
	style["stripe"] = "none"
	_check("no stripes means body colour", _albedo(_styled("atlas", style), "stripe_atlas").is_equal_approx(body), _albedo(_styled("atlas", style), "stripe_atlas"))
	style = TitanStyle.DEFAULT.duplicate()
	style["core"] = "pink"
	var core := _styled("stryder", style).find_child("Core", true, false) as MeshInstance3D
	_check("core glow recolours the core", core.get_surface_override_material(0) != null, core)

	# Tweaks: fenders scale, parts switched off are gone, the antenna grows from its base.
	style = TitanStyle.DEFAULT.duplicate()
	style.merge({"fenders": "big", "stickers": "off", "pouch": "off", "charms": "off", "antenna": "tall"}, true)
	var tweaked := _styled("atlas", style)
	await process_frame
	_check("big fenders", (tweaked.find_child("ArmLFender", true, false) as Node3D).scale.is_equal_approx(Vector3.ONE * 1.18), "")
	_check("stickers off", tweaked.find_children("*Decals", "", true, false).is_empty(), tweaked.find_children("*Decals", "", true, false))
	_check("pouch off", tweaked.find_child("LegRPouch", true, false) == null, "")
	_check("charms off", tweaked.find_child("CockpitCharms", true, false) == null, "")
	var stock_antenna := Art.titan("atlas", "xo16").find_child("Antenna", true, false) as MeshInstance3D
	var tall := tweaked.find_child("Antenna", true, false) as MeshInstance3D
	var stock_box := stock_antenna.transform * stock_antenna.get_aabb()
	var tall_box := tall.transform * tall.get_aabb()
	_check("tall antenna grows up from its base", absf(tall_box.position.y - stock_box.position.y) < 0.01 and tall_box.size.y > stock_box.size.y * 1.3, [stock_box, tall_box])
	style["antenna"] = "off"
	_check("antenna off", _styled("atlas", style).find_child("Antenna", true, false) == null, "")

	# A dropped titan wears the saved style.
	style = TitanStyle.DEFAULT.duplicate()
	style["livery"] = "grape soda"
	TitanStyle.save_style("atlas", style)
	var titan := Titan.new()
	titan.setup(TitanParts.assemble({}))
	titan.parts = {"chassis": {"id": "atlas"}, "weapon": {"id": "xo16"}}
	root.add_child(titan)
	_check("dropped titan wears the paint job", _albedo(titan.model, "paint_atlas").is_equal_approx(TitanStyle.PALETTE["grape"]), _albedo(titan.model, "paint_atlas"))
	titan.free()

	DirAccess.remove_absolute(TitanStyle.path)
	print("titan style: %s" % ("all ok" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _styled(chassis: String, style: Dictionary) -> Node3D:
	var model := Art.titan(chassis, "xo16")
	TitanStyle.apply(model, chassis, style)
	return model


## Albedo of the first surface using `material`, counting overrides.
func _albedo(model: Node3D, material: String) -> Color:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(s).resource_name == material:
				var mat: ShaderMaterial = mi.get_active_material(s)
				return mat.get_shader_parameter("albedo")
	return Color.BLACK


func _overrides(model: Node3D) -> int:
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(s) != null:
				n += 1
	return n


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
