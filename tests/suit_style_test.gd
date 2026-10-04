extends SceneTree
## Headless test for Eco's pilot suits in her wardrobe: each one (eco_model.gd
## OUTFITS suit*) swaps her bodysuit and shows only its own pieces while she has no
## suit upgrade, the upgrades' cuts go over any of them, the wardrobe lists
## them all by name, and she keeps her pick on a run.
## Run: godot --headless --path . -s res://tests/suit_style_test.gd

const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const ECO := preload("res://assets/models/eco.tscn")

const PATH := "user://test_suit_style.cfg"

var failures := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Wardrobe.save_path = PATH
	_run.call_deferred()


func _run() -> void:
	var eco = ECO.instantiate()
	root.add_child(eco)
	await process_frame   # in the tree and ready, so wear() dresses her
	_model(eco)
	_wardrobe(eco)
	eco.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _jackets(eco) -> Array:
	var shown := []
	for node in eco.find_children("base_*", "MeshInstance3D", true, false):
		if node.visible:
			shown.append(String(node.name))
	return shown


func _body(eco) -> Material:
	for node in eco.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "eco_v_body":
				return mi.get_surface_override_material(i)
	return null


## Her own pieces: a jacket, cowl or vest (base_<style>_jacket), Ophelia's skirt, or none.
func _pieces(style: String) -> Array:
	match style:
		"harness":
			return []
		"ophelia":
			return ["base_ophelia_skirt"]
	return ["base_%s_jacket" % style]


func _model(eco) -> void:
	var suits: Array = eco.OUTFITS.filter(func(o): return o.begins_with("suit"))
	_check("eight pilot suits", suits.size() == 8 and eco.OUTFITS[0] == "suit", suits)
	_check("starts in her own suit", eco.outfit == "suit" and eco.style() == "gwen" and _body(eco) == null, eco.outfit)
	for outfit in suits:
		_check("wears " + outfit, eco.wear(outfit) and eco.outfit == outfit, eco.outfit)
		var style: String = eco.style()
		_check(outfit + " has its own bodysuit", _body(eco) == eco.STYLE_BODY.get(outfit), _body(eco))
		var shown := _jackets(eco)
		var want := _pieces(style)
		_check(outfit + " shows only its own jacket", shown == want, shown)
		if style != "gwen":
			var tex: Texture2D = eco.STYLE_BODY[outfit].get_shader_parameter("albedo_tex")
			_check(outfit + " has its own texture", tex != null and tex.resource_path.ends_with("v_body_%s.png" % style), tex)
	eco.wear("suit_racer")
	eco.suit_tier = 2
	_check("an upgrade's cut goes over any suit", _body(eco) == eco.MEDIUM_BODY and _jackets(eco).is_empty(), _jackets(eco))
	eco.suit_tier = 0
	_check("and the suit comes back without it", _body(eco) == eco.STYLE_BODY["suit_racer"] and _jackets(eco) == ["base_racer_jacket"], _jackets(eco))
	_check("clothes she hasn't got change nothing", not eco.wear("lingerie") and eco.outfit == "suit_racer", eco.outfit)
	eco.wear("suit")


func _wardrobe(eco) -> void:
	var options := Wardrobe.options("eco")
	_check("the wardrobe has all her suits", options == eco.OUTFITS, options)
	for outfit in options:
		_check(outfit + " has a name", Wardrobe.NAMES.has(outfit), outfit)
	Wardrobe.choose("eco", "suit_techwear")
	_check("her pick saves", Wardrobe.choice("eco") == "suit_techwear", Wardrobe.choice("eco"))
	Wardrobe.dress_eco(null, false)
	_check("she keeps her pick on a run", Wardrobe.eco_now == "suit_techwear", Wardrobe.eco_now)
	Wardrobe.dress_eco(null, true)
	_check("and at home", Wardrobe.eco_now == "suit_techwear", Wardrobe.eco_now)


func _check(what: String, ok: bool, got) -> void:
	if ok:
		print("ok    ", what)
	else:
		failures += 1
		print("FAIL  ", what, "  (", got, ")")
