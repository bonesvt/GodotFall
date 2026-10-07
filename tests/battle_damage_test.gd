extends SceneTree
## Battle damage (scripts/ps2/battle_damage.gd): hits, slides and time out on a
## run make Eco dirtier, more scuffed, torn and cut, and sliding wears her suit
## through at the outer thighs, glutes and hips; Teen shows only the dirt and
## scuffs; the setting turns it off; the baked maps never let a tear or cut
## near the always-covered zones; her materials read the map; and it all
## washes off at the temple.
## Run: godot --headless --path . -s res://tests/battle_damage_test.gd

const ECO := preload("res://assets/models/eco.tscn")
const BattleDamage := preload("res://scripts/ps2/battle_damage.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const TEST_SETTINGS := "user://test_battle_damage_settings.cfg"
const MAP := "res://assets/textures/eco/v_damage.png"
const SLIDE_MAP := "res://assets/textures/eco/v_damage_slide.png"
## glb metres per rest metre (tools/eco/bake_damage.py K)
const K := 1.1817

var failures := 0


func _initialize() -> void:
	Prefs.path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	var rating := ContentRating.current()
	_levels()
	_rating_and_setting()
	_map_keeps_clear()
	_materials()
	await _in_a_run()
	ContentRating.set_rating(rating, false)
	print("battle damage test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _levels() -> void:
	BattleDamage.reset()
	_check("starts clean", BattleDamage.shown() == Vector4.ZERO, BattleDamage.shown())
	BattleDamage.on_hit(45.0)
	_check("a hit tears and cuts a little", BattleDamage.tears > 0.05 and BattleDamage.scars > 0.03 and BattleDamage.tears < 0.3,
			[BattleDamage.tears, BattleDamage.scars])
	var g := BattleDamage.grime
	for i in 60:
		BattleDamage.tick(1.0, null)
	_check("a minute out there dirties her", BattleDamage.grime > g + 0.1, BattleDamage.grime)
	for i in 20:
		BattleDamage.on_hit(100.0)
	_check("levels top out at 1", BattleDamage.tears == 1.0 and BattleDamage.scars == 1.0 and BattleDamage.scuffs == 1.0,
			[BattleDamage.tears, BattleDamage.scars, BattleDamage.scuffs])
	_check("hits don't wear through like slides", BattleDamage.slide == 0.0, BattleDamage.slide)
	var player := SlidingPilot.new()
	for i in 30:
		BattleDamage.tick(1.0, player)
	_check("half a minute of sliding wears her suit through", BattleDamage.slide > 0.3, BattleDamage.slide)
	player.free()
	BattleDamage.reset()
	_check("reset washes it all off", BattleDamage.grime == 0.0 and BattleDamage.tears == 0.0, BattleDamage.grime)


func _rating_and_setting() -> void:
	BattleDamage.set_all(0.8)
	ContentRating.set_rating("T", false)
	var v := BattleDamage.shown()
	_check("Teen: dirt and scuffs only", v.x > 0.7 and v.y > 0.7 and v.z == 0.0 and v.w == 0.0, v)
	BattleDamage.apply()
	_check("Teen: no tears reach the shader", BattleDamage._pushed.z == 0.0 and BattleDamage._pushed_slide == 0.0,
			[BattleDamage._pushed, BattleDamage._pushed_slide])
	ContentRating.set_rating("M", false)
	v = BattleDamage.shown()
	_check("Mature: torn and cut too", v.z > 0.7 and v.w > 0.7, v)
	BattleDamage.apply()
	_check("Mature: tears reach the shader", BattleDamage._pushed.z > 0.7 and BattleDamage._pushed_slide > 0.7,
			[BattleDamage._pushed, BattleDamage._pushed_slide])
	_check("on by default", Prefs.battle_damage(), Prefs.battle_damage())
	Prefs.set_battle_damage(false)
	_check("setting off: nothing shows", BattleDamage.shown() == Vector4.ZERO, BattleDamage.shown())
	Prefs.set_battle_damage(true)
	BattleDamage.reset()


## Every vertex of her body within 6 cm of the always-covered zones (memory
## vesper-limits) reads "never" for tears and cuts; the chest tears and sliding
## wear (both checked by eye at full size in poses) stay 3.5 cm clear.
func _map_keeps_clear() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MAP))
	var slide := Image.load_from_file(ProjectSettings.globalize_path(SLIDE_MAP))
	_check("damage maps load", img != null and img.get_width() == 1024 and slide != null and slide.get_width() == 1024, [img, slide])
	if img == null or slide == null:
		return
	var eco = ECO.instantiate()
	var body := eco.find_child("Body", true, false) as MeshInstance3D
	var arrays := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var near := 0
	var bad := []
	var torn_somewhere := 0
	var slid_thigh := 0
	var slid_glute := 0
	var torn_chest := 0
	for i in verts.size():
		var v := verts[i]
		var p := Vector3(-v.x, v.z, v.y) / K   # rest space: z up, she faces -y
		var at := Vector2i(clampi(int(uvs[i].x * 1024), 0, 1023), clampi(int(uvs[i].y * 1024), 0, 1023))
		var px := img.get_pixelv(at)
		var worn := slide.get_pixelv(at).r < 0.99
		if px.g < 0.99:
			torn_somewhere += 1
			if p.z > 0.95 and p.z < 1.17 and p.y < 0.0 and absf(p.x) < 0.15:
				torn_chest += 1
		if worn and p.z > 0.6 and p.z < 0.8 and absf(p.x) > 0.11:
			slid_thigh += 1
		if worn and p.z > 0.72 and p.z < 0.88 and p.y > 0.02:
			slid_glute += 1
		if worn and _locked(p, 0.035):
			bad.append(p)
		if not _locked(p, 0.06, 0.035):
			continue
		near += 1
		if px.g < 0.99 or px.a < 0.99:
			bad.append(p)
	_check("map: tears exist", torn_somewhere > 30, torn_somewhere)
	_check("map: hits tear her chest too, clear of her bust", torn_chest > 10, torn_chest)
	_check("slide map: wears through her outer upper thighs", slid_thigh > 10, slid_thigh)
	_check("slide map: and the outer parts of her glutes", slid_glute > 5, slid_glute)
	_check("map: nothing near the covered zones can tear or scar (%d vertices checked)" % near, near > 200 and bad.is_empty(),
			bad.slice(0, 5))
	eco.free()


## Within `pad` of a covered zone (vesper-limits), or `bust_pad` of a bust disc.
func _locked(p: Vector3, pad: float, bust_pad := -1.0) -> bool:
	var ax := absf(p.x)
	for sx in [0.057, -0.057]:
		if p.y < 0.02 and Vector2(p.x - sx, p.z - 1.047).length() < 0.022 + (pad if bust_pad < 0.0 else bust_pad):
			return true
	if p.y < 0.0 and p.z > 0.712 - pad and p.z < 0.79 + pad and ax < 0.012 + 0.45 * (p.z - 0.70) + pad:
		return true   # groin
	if p.z > 0.712 - pad and p.z < 0.74 + pad and ax < 0.014 + pad:
		return true   # between the legs
	if p.y > 0.0 and p.z > 0.712 - pad and p.z < 0.81 + pad and ax < 0.012 + pad:
		return true   # back cleft
	return false


func _materials() -> void:
	var eco = ECO.instantiate()
	root.add_child(eco)
	var kinds := {}
	for node in eco.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as ShaderMaterial
			if m != null:
				kinds[m.resource_name] = [m.get_shader_parameter("damage_kind"), m.get_shader_parameter("damage_tex"),
						m.get_shader_parameter("damage_slide_tex")]
	_check("her body reads the map", kinds.get("eco_v_body", [0])[0] == 1 and kinds["eco_v_body"][1] != null, kinds.get("eco_v_body"))
	_check("her body reads the slide map", kinds["eco_v_body"][2] != null, kinds.get("eco_v_body"))
	_check("her face reads its map", kinds.get("eco_v_face", [0])[0] == 1 and kinds["eco_v_face"][1] != null, kinds.get("eco_v_face"))
	_check("her boots get dust", kinds.get("eco_v_boots", [0])[0] == 2, kinds.get("eco_v_boots"))
	_check("her hair stays clean", kinds.get("eco_v_hair", [null])[0] in [null, 0], kinds.get("eco_v_hair"))
	for outfit in ["suit_vesper", "suit_ghost"]:
		eco.wear(outfit)
		var m: ShaderMaterial = eco.body_material()
		_check("%s's bodysuit reads the map" % outfit, m.get_shader_parameter("damage_kind") == 1, m.get_shader_parameter("damage_kind"))
	eco.wear("suit")
	eco.suit_tier = 2
	var kit: ShaderMaterial = eco.body_material()
	_check("a suit kit's bodysuit reads the map", kit.get_shader_parameter("damage_kind") == 1, kit.get_shader_parameter("damage_kind"))
	eco.queue_free()


func _in_a_run() -> void:
	ContentRating.set_rating("M", false)
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_battle_damage_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	root.add_child(run_node)
	await _ticks(30)
	run_node.start_run(7)
	await _ticks(30)
	_check("a run starts clean", BattleDamage.tears == 0.0, BattleDamage.tears)
	run_node.player.take_damage(40.0)
	await _ticks(240)
	_check("hits on a run tear her suit", BattleDamage.tears > 0.05, BattleDamage.tears)
	_check("time on a run dirties her", BattleDamage.grime > 0.005, BattleDamage.grime)
	_check("the shader sees it", BattleDamage._pushed.z > 0.05, BattleDamage._pushed)
	run_node.enter_hub()
	await _ticks(5)
	_check("home at the temple she's clean", BattleDamage.shown() == Vector4.ZERO, BattleDamage.shown())
	run_node.queue_free()
	await _ticks(2)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, got) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what, "  got: ", got)


## A stand-in player sliding along.
class SlidingPilot extends CharacterBody3D:
	var state := 2   # eco_model.gd PlayerState.SLIDE
