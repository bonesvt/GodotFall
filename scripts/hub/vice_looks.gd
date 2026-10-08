extends RefCounted
## Eco's hypno looks (Mature only, like the rest of vices.gd): what each path
## that gets its hooks in her dresses her in, and the looks she picks for
## herself once she's out. The plan is /vices/marrow-outfits.md; Bones picked
## one look per path from the concept sheets.
##
## The paths (PATHS) each have a meter, and their look comes on in stages as
## it climbs (STAGE_AT): her hair and makeup first, then her suit, then the
## pieces and the haircut, then her eyes. While any path has her (forced()),
## that look is what she wears, runs included, and the wardrobe won't change
## it ("Not yours to change right now"). The deepest path wins; ties go by
## ORDER. Every stage she's reached stays in the wardrobe once she's free of
## it (reached), and the free endings' looks (FREE) once she's earned them.
##
##   hymn      Sleepwalker         Hymn.level (hymn.gd)
##   marrow    His                 Marrow's Hold (vices.gd hold)
##   glass     Kintsugi            Glass level (glass.gd), with crystal growths
##   faith     Idol                devotion (here, until the faith route lands)
##   colony    Parade              Town's Grip (here, until Colony City lands)
##   keepsake  Keepsake, Matching, Homebound   Ophelia's obsession (here)
##
## Every look is a recolour of pieces she already has: the textures are baked
## by tools/eco/bake_vice_looks.py (from tools/eco/vice_looks.json) into
## assets/textures/eco/looks/, and LOOKS says which outfit it starts from and
## what it shows, hides and re-dyes. eco_model.gd apply_suit() calls apply().
## The meters kept here, what she's reached and what she's unlocked are saved
## next to her vices (path_for()).

const Vices := preload("res://scripts/hub/vices.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Hair := preload("res://scripts/hub/hair.gd")

const TEX := "res://assets/textures/eco/looks/%s_%s.png"
## Each look's id in the wardrobe and on her model starts with this.
const PREFIX := "vl_"
const VIOLET := Color(0.72, 0.32, 1.0)
const GOLD := Color(1.0, 0.72, 0.25)
const EMBER := Color(1.0, 0.6, 0.15)
const SUIT_ARMOR := ["suit_t1h_breastplate", "suit_t1h_bracer_l", "suit_t1h_bracer_r", "suit_t1h_elbow_l", "suit_t1h_elbow_r", "suit_t1h_belt",
		"suit_t2h_pauldron_l", "suit_t2h_pauldron_r", "suit_t2h_pauldron_lame_l", "suit_t2h_pauldron_lame_r",
		"suit_t2h_rerebrace_l", "suit_t2h_rerebrace_r", "suit_t3h_hip_l", "suit_t3h_hip_r", "suit_t3h_hip_lame_l",
		"suit_t3h_hip_lame_r", "suit_t3h_knee_l", "suit_t3h_knee_r", "suit_t3h_shin_l", "suit_t3h_shin_r",
		"suit_t4h_collar", "suit_t4h_backplate", "suit_t5h_core", "suit_t5h_crest_l", "suit_t5h_crest_r"]
const CRESTS := ["suit_t4h_collar", "suit_t5h_core", "suit_t5h_crest_l", "suit_t5h_crest_r", "suit_t4h_backplate", "suit_t1h_bracer_l", "suit_t1h_bracer_r"]

## The looks: "base" the outfit it starts from (eco_model.gd OUTFITS), "show"
## meshes to put on, "hide" mesh name prefixes to take off, "mats" glb
## material -> {albedo, emit, emit_col, sheen} re-dyes for what's shown,
## "hair_style" a salon cut (hair.gd), "iris" her eye colour, "glass" how far
## the glass covers her at full strength and "glass_tint" its colour,
## "crystals" crystal growths on her body. The baked textures (body, glow,
## hair, fringe, eyeline, face) are used where they exist.
const LOOKS := {
	"his": {"base": "suit_shade", "hair_style": "pixie", "show": ["outfit_skater_any_shoes"], "hide": ["base_", "Boots", "Goggles"],
		"mats": {"eco_v_sneaker_skater": {"albedo": Color(0.08, 0.06, 0.1)}, "eco_v_sneaker_skater_sole": {"albedo": VIOLET, "emit": 0.6}}},
	# Kintsugi with Frost's icy braids and pale eyes, and crystal growing out of her
	"kintsugi": {"base": "suit_shade", "hair_style": "braids", "iris": Color(0.7, 0.9, 1.0), "crystals": true,
		"show": [], "hide": ["base_", "Goggles"], "mats": {}},
	"sleepwalker": {"base": "suit_shade", "hair_style": "shoulder", "iris": Color(0.85, 0.9, 1.0),
		"show": ["outfit_skater_t_hoodie", "outfit_skater_any_hood", "outfit_skater_any_shoes"], "hide": ["base_", "Boots", "Goggles"],
		"mats": {"eco_v_hoodie_skater": {"albedo": Color(0.9, 1.05, 0.88)}, "eco_v_hoodie_skater_edge": {"albedo": Color(0.92, 0.94, 1.0), "emit": 0.4},
			"eco_v_hoodie_skater_hood": {"albedo": Color(0.85, 1.0, 0.82)}, "eco_v_sneaker_skater": {"albedo": Color(0.9, 0.9, 0.88)},
			"eco_v_sneaker_skater_sole": {"albedo": Color(0.95, 0.95, 0.95)}}},
	"idol": {"base": "suit_shade", "hair_style": "braids", "iris": GOLD, "glass": 0.9, "glass_tint": GOLD,
		"show": CRESTS, "hide": ["base_", "Goggles"],
		"mats": {"eco_v_armor": {"albedo": Color(0.9, 0.85, 0.72), "sheen": 0.6}, "eco_v_armor_edge": {"albedo": GOLD, "emit": 1.0},
			"eco_v_armor_glow": {"albedo": GOLD, "emit": 2.4}}},
	"parade": {"base": "suit_shade", "hair_style": "ponytail",
		"show": ["outfit_date_t_jacket", "outfit_date_any_hoops", "suit_t1h_belt"], "hide": ["base_shade", "Goggles"],
		"mats": {"eco_v_jacket_date": {"albedo": Color(0.97, 0.97, 0.98), "sheen": 0.4}, "eco_v_jacket_date_edge": {"albedo": Color(1.0, 0.8, 0.4), "emit": 0.6},
			"eco_v_steel": {"albedo": Color(1.0, 0.8, 0.35), "sheen": 1.0}, "eco_v_armor": {"albedo": Color(0.97, 0.97, 0.98), "sheen": 0.6},
			"eco_v_armor_edge": {"albedo": Color(1.0, 0.8, 0.4), "emit": 0.6}}},
	# Ophelia dresses her: her own suit, then matching her, then never leaving
	"keepsake_a": {"base": "suit_ophelia", "iris": EMBER, "show": [], "hide": ["Goggles"], "mats": {}},
	"keepsake_b": {"base": "suit_shade", "iris": EMBER, "show": ["base_ophelia_skirt", "outfit_skater_t_hoodie"], "hide": ["base_shade", "Goggles"],
		"mats": {"eco_v_hoodie_skater": {"albedo": Color(0.3, 0.26, 0.34)}, "eco_v_hoodie_skater_edge": {"albedo": VIOLET, "emit": 0.7}}},
	"keepsake_c": {"base": "suit_shade", "hair_style": "shoulder", "iris": EMBER,
		"show": ["outfit_skater_t_hoodie", "outfit_skater_any_hood", "outfit_skater_any_shoes"], "hide": ["base_", "Boots", "Goggles"],
		"mats": {"eco_v_hoodie_skater": {"albedo": Color(1.15, 0.8, 0.8)}, "eco_v_hoodie_skater_hood": {"albedo": Color(1.1, 0.75, 0.75)},
			"eco_v_hoodie_skater_edge": {"albedo": Color(1.0, 0.75, 0.7), "emit": 0.4}, "eco_v_sneaker_skater": {"albedo": Color(0.95, 0.95, 0.95)}}},
	# her own picks, once she's out
	"her_own": {"base": "date", "show": ["outfit_date_any_hoops"], "hide": [], "mats": {}},
	"warden": {"base": "suit_shade", "hair_style": "ponytail",
		"show": ["suit_t4l_choker", "outfit_date_any_hoops", "suit_t2h_pauldron_l", "suit_t2h_pauldron_r", "suit_t1h_bracer_l", "suit_t1h_bracer_r", "suit_t1h_belt"],
		"hide": ["base_", "Goggles"],
		"mats": {"eco_v_armor": {"albedo": Color(0.6, 0.62, 0.66), "sheen": 0.9}, "eco_v_armor_edge": {"albedo": Color(0.85, 0.85, 0.9)},
			"eco_v_kit_leather": {"albedo": Color(0.04, 0.04, 0.05)}, "eco_v_leather_red": {"albedo": Color(0.8, 0.8, 0.85), "sheen": 1.0},
			"eco_v_steel": {"albedo": Color(0.85, 0.85, 0.9), "sheen": 1.0}}},
	"survivor": {"base": "suit_shade", "hair_style": "shoulder", "show": ["suit_t1m_toolpouch", "suit_t2m_scarf", "suit_t2m_scarf_knot", "outfit_skater_any_shoes"],
		"hide": ["base_", "Boots", "Goggles"], "mats": {"eco_v_kit_scarf": {"albedo": Color(0.9, 0.7, 0.3)}}},
	"unbound": {"base": "suit_shade", "hair_style": "braids", "show": ["outfit_skater_t_hoodie"], "hide": ["base_", "Goggles"],
		"mats": {"eco_v_hoodie_skater": {"albedo": Color(0.25, 0.22, 0.3)}}},
}

## The paths that take her over: their name, meter, look (one look in stages,
## or one look per stage) and stage names.
const PATHS := {
	"hymn": {"name": "Hymn: Sleepwalker", "meter": "hymn", "looks": ["sleepwalker"], "stages": ["Compliant", "Resident", "Dispenser", "Choir"]},
	"marrow": {"name": "Marrow's: His", "meter": "hold", "looks": ["his"], "stages": ["A Taste", "Hooked", "His", "Marrow's Own"]},
	"glass": {"name": "Glass: Kintsugi", "meter": "glass", "looks": ["kintsugi"], "stages": ["First Vial", "Facets", "Prism", "Crystalline"]},
	"faith": {"name": "Faith: Idol", "meter": "devotion", "looks": ["idol"], "stages": ["Acolyte", "Votary", "Ascendant", "Idol"]},
	"colony": {"name": "Colony City: Parade", "meter": "town_grip", "looks": ["parade"], "stages": ["Transferee", "Conscript", "Rising", "Colony Ace"]},
	"keepsake": {"name": "Ophelia's", "meter": "obsession", "looks": ["keepsake_a", "keepsake_b", "keepsake_c"], "stages": ["Keepsake", "Matching", "Homebound"]},
}
## Which path wins when two have her equally deep.
const ORDER := ["hymn", "marrow", "glass", "faith", "colony", "keepsake"]
## The meter level each stage comes on at (out of 100).
const STAGE_AT := [25.0, 50.0, 75.0, 100.0]
## What each part of a staged look waits for (the stage it comes on at).
const GATE := {"hair": 1, "makeup": 1, "body": 2, "pieces": 3, "hair_style": 3, "iris": 4}
## The free endings' looks, unlocked by their endings (unlock()).
const FREE := {
	"warden": {"name": "Warden", "look": "warden"},
	"survivor": {"name": "Survivor", "look": "survivor"},
	"unbound": {"name": "Unbound", "look": "unbound"},
	"her_own": {"name": "Her Own (after Ophelia)", "look": "her_own"},
}
const MAX := 100.0
## Where crystal grows on her as the Glass look deepens (bone, how far out
## from it in metres): three more sites per stage.
const CRYSTAL_SITES := [
	["J_Bip_L_LowerArm", 0.04], ["J_Bip_R_LowerArm", 0.04], ["J_Bip_C_UpperChest", 0.1],
	["J_Bip_L_UpperArm", 0.045], ["J_Bip_R_UpperArm", 0.045], ["J_Bip_C_Spine", 0.1],
	["J_Bip_L_UpperLeg", 0.07], ["J_Bip_R_UpperLeg", 0.07], ["J_Bip_L_Shoulder", 0.06],
	["J_Bip_R_Shoulder", 0.06], ["J_Bip_L_LowerLeg", 0.05], ["J_Bip_R_LowerLeg", 0.05],
]
const CRYSTALS := "ViceCrystals"

## The meters with no home of their own yet, 0..MAX.
static var devotion := 0.0
static var town_grip := 0.0
static var obsession := 0.0
## path -> the deepest stage she's been at (what the wardrobe keeps for her).
static var reached := {}
## FREE ids she's earned.
static var unlocked: Array = []
static var save_path := "user://vice_looks.cfg"
## The last forced() seen by changed().
static var _last_forced := ""


static func allowed() -> bool:
	return ContentRating.current() == "M"


static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_looks.cfg"


## A path's meter, 0..MAX.
static func meter(path: String) -> float:
	match PATHS[path]["meter"]:
		"hymn":
			return Hymn.level
		"hold":
			return Vices.hold
		"glass":
			return float(Glass.glass) * MAX / float(Glass.MAX_GLASS)
		"devotion":
			return devotion
		"town_grip":
			return town_grip
		"obsession":
			return obsession
	return 0.0


## How deep a path has her: 0 (not at all) up to its number of stages.
static func stage(path: String) -> int:
	if not allowed():
		return 0
	var m := meter(path)
	var s := 0
	for at: float in STAGE_AT:
		if m >= at:
			s += 1
	return mini(s, PATHS[path]["stages"].size())


## The look a path has her in at a stage, "vl_<path>_<stage>", or a free
## ending's look, "vl_<id>".
static func look_id(path: String, at_stage: int) -> String:
	return "%s%s_%d" % [PREFIX, path, at_stage]


static func is_look(id: String) -> bool:
	return id.begins_with(PREFIX)


## {"path", "stage"} or {"free"} for a look id, {} if it isn't one.
static func parse(id: String) -> Dictionary:
	if not is_look(id):
		return {}
	var rest := id.trim_prefix(PREFIX)
	if FREE.has(rest):
		return {"free": rest}
	var cut := rest.rfind("_")
	if cut < 0:
		return {}
	var path := rest.left(cut)
	var s := rest.substr(cut + 1).to_int()
	if not PATHS.has(path) or s < 1 or s > PATHS[path]["stages"].size():
		return {}
	return {"path": path, "stage": s}


## The look she's made to wear now, or "" if nothing has her.
static func forced() -> String:
	var best := ""
	var deepest := 0
	for path: String in ORDER:
		var s := stage(path)
		if s > deepest:
			deepest = s
			best = path
	return look_id(best, deepest) if best != "" else ""


## Whether forced() changed since the last call (run_manager.gd redresses
## her then), noting every stage she reaches.
static func changed() -> bool:
	note_reached()
	var now := forced()
	if now == _last_forced:
		return false
	_last_forced = now
	return true


static func note_reached() -> void:
	var grew := false
	for path: String in PATHS:
		var s := stage(path)
		if s > int(reached.get(path, 0)):
			reached[path] = s
			grew = true
	if grew:
		save()


static func unlock(id: String) -> bool:
	if not FREE.has(id) or id in unlocked:
		return false
	unlocked.append(id)
	save()
	return true


## The looks in her wardrobe: every stage she's reached and every free look
## she's earned (none under Teen).
static func wardrobe_looks() -> Array:
	if not allowed():
		return []
	var list := []
	for path: String in ORDER:
		for s in range(1, int(reached.get(path, 0)) + 1):
			list.append(look_id(path, s))
	for id: String in FREE:
		if id in unlocked:
			list.append(PREFIX + id)
	return list


## Whether a look id names a look (whatever she's reached).
static func valid(id: String) -> bool:
	return not parse(id).is_empty()


static func look_name(id: String) -> String:
	var p := parse(id)
	if p.has("free"):
		return FREE[p["free"]]["name"]
	if p.is_empty():
		return id
	var info: Dictionary = PATHS[p["path"]]
	return "%s (%s)" % [info["name"], info["stages"][p["stage"] - 1]]


## The LOOKS key a look id wears, and the stage gate its parts open at (a
## look with one look per stage, or a free one, is all there at once).
static func resolve(id: String) -> Array:
	var p := parse(id)
	if p.has("free"):
		return [FREE[p["free"]]["look"], 4]
	if p.is_empty():
		return ["", 0]
	var looks: Array = PATHS[p["path"]]["looks"]
	if looks.size() > 1:
		return [looks[p["stage"] - 1], 4]
	return [looks[0], int(p["stage"])]


## The outfit a look starts from ("suit" for anything else).
static func base(id: String) -> String:
	var key: String = resolve(id)[0]
	return LOOKS[key]["base"] if LOOKS.has(key) else "suit"


## How far the glass covers her (the eco_glass global): Marrow's Glass, or
## the Idol's gold glass as Faith deepens.
static func glass_level() -> float:
	var level := Glass.look()
	var r := resolve(forced())
	if LOOKS.has(r[0]):
		level = maxf(level, float(LOOKS[r[0]].get("glass", 0.0)) * r[1] / 4.0)
	return level


## The glass's colour (the eco_glass_tint global).
static func glass_tint() -> Color:
	var r := resolve(forced())
	if LOOKS.has(r[0]) and LOOKS[r[0]].has("glass_tint") and float(LOOKS[r[0]].get("glass", 0.0)) * r[1] / 4.0 >= Glass.look():
		return LOOKS[r[0]]["glass_tint"]
	return VIOLET


static func _tex(key: String, part: String) -> Texture2D:
	var path := TEX % [key, part]
	return load(path) if ResourceLoader.exists(path) else null


## Dresses her model in its vice_look over the outfit it starts from (after
## eco_model.gd apply_suit has put that on), or takes the last look's hair,
## eyes and crystals back off.
static func apply(eco: Node3D) -> void:
	var id := String(eco.get("vice_look")) if eco.get("vice_look") != null else ""
	var r := resolve(id) if id != "" else ["", 0]
	var key: String = r[0]
	_undo(eco)
	if key == "" or not LOOKS.has(key):
		if eco.has_meta("vice_look_on"):
			eco.remove_meta("vice_look_on")
			_reset_hair(eco)
			_crystals(eco, 0)
		return
	var gate: int = r[1]
	var look: Dictionary = LOOKS[key]
	var style: String = look.get("hair_style", "")
	if eco.get_meta("vice_look_on", "") != id:
		_reset_hair(eco)
	eco.set_meta("vice_look_on", id)
	if style != "" and gate >= GATE["hair_style"]:
		Hair.apply(eco, "eco", style)
	var show: Array = look["show"] if gate >= GATE["pieces"] else []
	var mats: Dictionary = look["mats"]
	var textures := {}
	for part in ["body", "glow", "hair", "fringe", "eyeline", "face"]:
		textures[part] = _tex(key, part)
	var done := []
	for node in eco.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or String(mi.get_parent().name).begins_with(CRYSTALS):
			continue
		var mesh_name := String(mi.name)
		for prefix: String in look["hide"]:
			if mesh_name.begins_with(prefix):
				mi.visible = false
		if mesh_name in show:
			mi.visible = true
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			var now := mi.get_surface_override_material(i)
			var from: Material = now if now != null else m
			var rn := m.resource_name
			var spec := {}
			if rn == "eco_v_body" and gate >= GATE["body"] and textures["body"] != null:
				spec = {"tex": textures["body"], "glow_tex": textures["glow"]}
			elif rn == "eco_v_hair" and gate >= GATE["hair"] and textures["hair"] != null:
				spec = {"tex": textures["hair"]}
			elif rn == "eco_v_hair_fringe" and gate >= GATE["hair"] and textures["fringe"] != null:
				spec = {"tex": textures["fringe"]}
			elif rn == "eco_v_face" and gate >= GATE["makeup"] and textures["face"] != null:
				spec = {"tex": textures["face"]}
			elif rn == "eco_v_eyeline" and gate >= GATE["makeup"] and textures["eyeline"] != null:
				spec = {"tex": textures["eyeline"]}
			elif rn == "eco_v_iris" and gate >= GATE["iris"] and look.has("iris"):
				spec = {"albedo": look["iris"], "emit": 0.8}
			elif mats.has(rn) and gate >= GATE["pieces"] and mi.visible:
				spec = mats[rn]
			if not spec.is_empty() and from is ShaderMaterial:
				var ours := _recolour(from, spec)
				mi.set_surface_override_material(i, ours)
				done.append([mi, i, now, ours])
	eco.set_meta("vice_look_overrides", done)
	_crystals(eco, gate * 3 if look.get("crystals", false) else 0)


## Takes back the re-dyes the last apply() made, where they're still on (a
## surface eco_model.gd has re-dressed since keeps what it put there).
static func _undo(eco: Node3D) -> void:
	for each: Array in eco.get_meta("vice_look_overrides", []):
		var mi: MeshInstance3D = each[0]
		if is_instance_valid(mi) and mi.get_surface_override_material(each[1]) == each[3]:
			mi.set_surface_override_material(each[1], each[2])
	eco.set_meta("vice_look_overrides", [])


static func _recolour(m: ShaderMaterial, spec: Dictionary) -> ShaderMaterial:
	var d: ShaderMaterial = m.duplicate()
	if spec.has("tex"):
		d.set_shader_parameter("albedo_tex", spec["tex"])
	if spec.has("glow_tex") and spec["glow_tex"] != null:
		d.set_shader_parameter("glow_tex", spec["glow_tex"])
	if spec.has("albedo"):
		d.set_shader_parameter("albedo", spec["albedo"])
	if spec.has("emit"):
		d.set_shader_parameter("emission", spec.get("emit_col", spec.get("albedo", Color.WHITE)))
		d.set_shader_parameter("emission_energy", spec["emit"])
	if spec.has("sheen"):
		d.set_shader_parameter("sheen", spec["sheen"])
	return d


## The crystal clusters on her model (_crystals()).
static func crystal_clusters(eco: Node3D) -> Array:
	var skeleton := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return []
	return skeleton.get_children().filter(func(c): return String(c.name).begins_with(CRYSTALS + "_"))


## Her own hair back: its colour, and her salon cut.
static func _reset_hair(eco: Node3D) -> void:
	var skeleton := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var salon := skeleton.get_node_or_null(Hair.SALON_HAIR)
	if salon != null:
		skeleton.remove_child(salon)
		salon.queue_free()
	Hair.apply(eco, "eco")


## Crystal growths on her: clusters of glass prisms at the first `sites` of
## CRYSTAL_SITES, pale ice with violet light in them, each cluster riding its
## bone (a BoneAttachment3D straight under her skeleton, "ViceCrystals_<n>").
static func _crystals(eco: Node3D, sites: int) -> void:
	var skeleton := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	sites = mini(sites, CRYSTAL_SITES.size())
	if int(skeleton.get_meta("vice_crystal_sites", 0)) == sites:
		return
	for old in crystal_clusters(eco):
		skeleton.remove_child(old)
		old.queue_free()
	skeleton.set_meta("vice_crystal_sites", sites)
	if sites <= 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.2
	mat.roughness = 0.08
	mat.emission_enabled = true
	mat.emission = VIOLET
	mat.emission_energy_multiplier = 0.9
	mat.rim_enabled = true
	mat.rim = 0.6
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in sites:
		var bone_name: String = CRYSTAL_SITES[n][0]
		var reach: float = CRYSTAL_SITES[n][1]
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var attach := BoneAttachment3D.new()
		attach.name = "%s_%d" % [CRYSTALS, n]
		skeleton.add_child(attach)
		attach.bone_name = bone_name
		var rest := skeleton.get_bone_global_rest(bone)
		# where the bone runs in her rest pose (to its first child), in her skeleton's space
		var from := rest.origin
		var to := from + rest.basis.y * 0.12
		var child := skeleton.get_bone_children(bone)
		if not child.is_empty():
			to = skeleton.get_bone_global_rest(child[0]).origin
		var along := (to - from).normalized()
		# out from the middle of her, turned to her front or back by turns (she faces -Z), square to the bone
		var out := Vector3(signf(from.x) if absf(from.x) > 0.03 else 0.0, 0.0, 0.6 if n % 2 == 0 else -0.5)
		out = (out - along * out.dot(along)).normalized()
		var to_bone := rest.affine_inverse()
		for k in 3 + rng.randi_range(0, 2):
			var prism := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			var size := rng.randf_range(0.04, 0.09)
			mesh.top_radius = 0.0
			mesh.bottom_radius = size * 0.32
			mesh.height = size
			mesh.radial_segments = 6
			mesh.rings = 1
			mesh.material = mat
			prism.mesh = mesh
			prism.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# rooted at her surface part way along the bone, tipped outwards
			var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.45
			var sideways := (spread - out * spread.dot(out)).normalized() * reach * 0.5
			var at := from.lerp(to, rng.randf_range(0.2, 0.75)) + out * reach + sideways
			var dir := to_bone.basis * (out + spread).normalized()
			prism.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())), to_bone * at + dir.normalized() * size * 0.35)
			attach.add_child(prism)


## One of the meters kept here, 0..MAX.
static func level(meter_name: String) -> float:
	match meter_name:
		"devotion":
			return devotion
		"town_grip":
			return town_grip
		"obsession":
			return obsession
	return 0.0


## A cheat or the story moving one of the meters kept here.
static func add(meter_name: String, amount: float) -> void:
	match meter_name:
		"devotion":
			devotion = clampf(devotion + amount, 0.0, MAX)
		"town_grip":
			town_grip = clampf(town_grip + amount, 0.0, MAX)
		"obsession":
			obsession = clampf(obsession + amount, 0.0, MAX)
	save()


static func reset() -> void:
	devotion = 0.0
	town_grip = 0.0
	obsession = 0.0
	reached = {}
	unlocked = []
	_last_forced = ""


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	devotion = float(cfg.get_value("looks", "devotion", 0.0))
	town_grip = float(cfg.get_value("looks", "town_grip", 0.0))
	obsession = float(cfg.get_value("looks", "obsession", 0.0))
	reached = Dictionary(cfg.get_value("looks", "reached", {}))
	unlocked = Array(cfg.get_value("looks", "unlocked", [])).filter(func(id): return FREE.has(id))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("looks", "devotion", devotion)
	cfg.set_value("looks", "town_grip", town_grip)
	cfg.set_value("looks", "obsession", obsession)
	cfg.set_value("looks", "reached", reached)
	cfg.set_value("looks", "unlocked", unlocked)
	cfg.save(save_path)
