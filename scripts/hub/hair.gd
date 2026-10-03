extends RefCounted
## Haircuts from the salon in Solace (salon_screen.gd): Eco's and her romance
## options' (Ophelia for now). Each haircut that isn't someone's own hair is
## its own mesh, assets/models/hair/<who>_<style>.glb (built by
## tools/salon/build_hair.py from the same VRoid preset as their model and
## skinned to the same bones), swapped onto their skeleton in place of the
## model's "Hair" mesh. The choice is saved, and every model of that person
## (Eco's first-person body and her full model, the salon's preview) wears it.
##
## To give someone else haircuts: add them to STYLES, build their glbs with
## build_hair.py, and call apply() on their model (hub_npc.gd does for anyone
## in STYLES).

## Who can get a haircut, and their haircuts: [id, name, the stylist's pitch].
## The first is the hair their model was built with.
const STYLES := {
	"eco": [
		["bob", "The Bob", "Chin-length, swept fringe. The classic. Says 'I fix titans and I'll fix you.'"],
		["pixie", "Pixie Crop", "Short all round, nothing to grab in a fight. Very fast, very rude."],
		["shoulder", "Shoulder Layers", "Grown out to the shoulders and let loose. Softer, if you can believe it."],
		["braids", "Long Braids", "Two braids down to your waist. Extensions, babe. Nobody needs to know."],
		["ponytail", "Braided Ponytail", "Pulled tight to a high braided tail. Out of your goggles, still swings when you run."],
		["undercut", "Undercut", "Left side buzzed, right side a bob. The militia will hate it. That's the point."],
	],
	"ophelia": [
		["choppy", "Choppy Fringe", "Her own: ragged at the jaw, fringe over one eye, violet streak."],
		["pixie", "Messy Pixie", "Cropped short, the fringe still hiding that one eye. She'll pretend not to like it."],
		["shoulder", "Long and Ragged", "Grown out past her shoulders, ends cut uneven. Very sad-song album cover."],
		["braids", "Twin Braids", "Two long braids, extensions. Goth schoolgirl, if the school was on fire."],
		["ponytail", "High Ponytail", "Pulled back into a braided tail. She'll let you see both her eyes. Maybe."],
		["undercut", "Undercut", "One side buzzed, the fringe swept over the other. Loud, for her."],
	],
}

const HairSprings := preload("res://scripts/hub/hair_springs.gd")
const GLB := "res://assets/models/hair/%s_%s.glb"
const SALON_HAIR := "SalonHair"

## Where the choices are saved ([hair] <who> = <style>).
static var save_path := "user://salon.cfg"


static func has_styles(who: String) -> bool:
	return STYLES.has(who)


static func style_ids(who: String) -> Array:
	return STYLES.get(who, []).map(func(s): return s[0])


static func default_style(who: String) -> String:
	var list: Array = STYLES.get(who, [])
	return list[0][0] if not list.is_empty() else ""


static func style_name(who: String, style: String) -> String:
	for s in STYLES.get(who, []):
		if s[0] == style:
			return s[1]
	return style


static func pitch(who: String, style: String) -> String:
	for s in STYLES.get(who, []):
		if s[0] == style:
			return s[2]
	return ""


## The haircut someone has now (their own hair until they've been to the salon).
static func current(who: String) -> String:
	var cfg := ConfigFile.new()
	var style := default_style(who)
	if cfg.load(save_path) == OK:
		style = String(cfg.get_value("hair", who, style))
	return style if style_ids(who).has(style) else default_style(who)


## Saves someone's new haircut and puts it on every model of them in the tree.
static func choose(tree: SceneTree, who: String, style: String) -> void:
	if not style_ids(who).has(style):
		return
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("hair", who, style)
	cfg.save(save_path)
	if tree != null:
		for model in tree.get_nodes_in_group("haircut_" + who):
			apply(model, who, style)


## Puts a haircut on someone's model ("" = the one they have now): their own
## hair shows for their default style, otherwise it hides under the haircut's
## mesh, skinned to the same skeleton. Remembers the model, so choose() can
## re-cut it later. Anyone but Eco also gets hair physics (hair_springs.gd).
static func apply(model: Node, who: String, style := "") -> void:
	if model == null or not has_styles(who):
		return
	if style == "":
		style = current(who)
	if not model.is_in_group("haircut_" + who):
		model.add_to_group("haircut_" + who)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	# hair physics (Eco's model runs her own springs)
	if who != "eco" and model.get_node_or_null("HairSprings") == null:
		var springs := HairSprings.make(skeleton)
		if springs != null:
			model.add_child(springs)
	var own := skeleton.get_node_or_null("Hair") as MeshInstance3D
	var old := skeleton.get_node_or_null(SALON_HAIR) as MeshInstance3D
	if old != null:
		if old.get_meta("style", "") == style:
			return
		skeleton.remove_child(old)
		old.queue_free()
	if style == default_style(who) or not ResourceLoader.exists(GLB % [who, style]):
		if own != null:
			own.visible = true
		return
	var cut := _mesh_of(load(GLB % [who, style]).instantiate())
	if cut == null:
		return
	cut.name = SALON_HAIR
	cut.set_meta("style", style)
	skeleton.add_child(cut)
	cut.transform = Transform3D.IDENTITY
	cut.skeleton = NodePath("..")
	if own != null:
		own.visible = false
		cut.cast_shadow = own.cast_shadow
		cut.layers = own.layers
		_dress(cut, own)


## Takes the haircut's mesh out of its glb (the rest of the glb is thrown away).
static func _mesh_of(scene: Node) -> MeshInstance3D:
	var mi := scene.find_child("Hair", true, false) as MeshInstance3D
	if mi == null:
		var all := scene.find_children("*", "MeshInstance3D", true, false)
		mi = all[0] if not all.is_empty() else null
	if mi != null:
		mi.get_parent().remove_child(mi)
		mi.owner = null
	scene.free()
	return mi


## Gives each of the haircut's surfaces the material of the model's own hair
## with the same name (eco_v_hair, npc_ophelia_hair_fringe, ...), so it gets
## their toon shading, colour and outline.
static func _dress(cut: MeshInstance3D, own: MeshInstance3D) -> void:
	var by_name := {}
	for i in own.mesh.get_surface_count():
		var m := own.get_active_material(i)
		if m != null:
			by_name[material_key(m)] = m
	for i in cut.mesh.get_surface_count():
		var src := cut.mesh.surface_get_material(i)
		var key := material_key(src) if src != null else ""
		var m: Material = by_name.get(key)
		if m == null and i < own.mesh.get_surface_count():
			m = own.get_active_material(i)
		cut.set_surface_override_material(i, m)


## A material's name: its resource name, or its file's name (eco_v_hair.tres).
static func material_key(m: Material) -> String:
	if m.resource_name != "":
		return m.resource_name
	return m.resource_path.get_file().get_basename()
