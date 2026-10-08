extends SceneTree
## Concept mock-ups of Act 3's look packages: Eco's real model, one sheet per
## path, four stages left to right. Each stage puts her in an outfit with its
## suit and trims re-dyed, a haircut and hair dye, makeup painted onto her face
## texture (lipstick, liner, shadow, blush, face markings), piercings, a collar
## and tattoos from Solace's shops (eco_extras.gd), her skin tone, the glass on
## her skin and the spirals in her eyes, with a caption. Plus a sheet for
## Ophelia's obsession (her model, hub_npc.gd) ending on Eco under Keepsake.
## Gun finishes and titan paint aren't drawn: the captions say what they'd be.
##   godot --path . -s res://tools/eco/look_concepts.gd -- <out_dir> [--paths=marrow,ophelia]
## Needs a renderer (not --headless). Writes <out_dir>/look_<path>.png.

const ECO := preload("res://assets/models/eco.tscn")
const Vices := preload("res://scripts/hub/vices.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const EcoExtras := preload("res://scripts/hub/eco_extras.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const PANEL := Vector2i(420, 760)
## The close-up of her face under each panel (makeup, piercings, collar, eyes).
const FACE := Vector2i(420, 320)

const VIOLET := Color(0.55, 0.2, 0.85)
const GOLD := Color(1.0, 0.78, 0.32)
const ROSE := Color(1.0, 0.42, 0.62)

## path: {title, bg, light, stages: [stage]}. A stage: name, notes, and any of
## outfit, hair, tint (hair dye), suit/suit_amt (suit re-dye), trim (glow trims),
## skin, glow/energy, glass, hold, trance, eye (iris tint), makeup {lips, lips_amt,
## liner, shadow, shadow_amt, blush, blush_amt, marks}, extras {piercings,
## accessories, tattoos}, npc/npc_outfit/mood (someone else instead of Eco).
const PATHS := {
	"marrow": {"title": "MARROW'S - \"HIS\"", "bg": Color(0.13, 0.07, 0.18), "light": Color(0.95, 0.85, 1.0), "stages": [
		{"name": "1  A taste", "outfit": "suit", "hair": "bob", "hold": 20.0,
			"makeup": {"shadow": Color(0.62, 0.42, 0.78), "shadow_amt": 0.45},
			"notes": "Her own gear. Violet smudged under the eyes,\nlike she slept in it. Gun: stock."},
		{"name": "2  Hooked", "outfit": "suit_hush", "hair": "bob", "tint": Color(0.9, 0.78, 1.0), "hold": 60.0,
			"makeup": {"liner": Color(0.35, 0.1, 0.5), "lips": Color(0.5, 0.2, 0.42), "lips_amt": 0.6, "shadow": VIOLET, "shadow_amt": 0.4},
			"extras": {"piercings": ["lobe_hoops"]},
			"notes": "His courier suit. Plum lips, violet liner.\nHoops he left on her table. Gun: Hush finish."},
		{"name": "3  His", "outfit": "suit_hush", "hair": "bob", "tint": Color(0.62, 0.45, 0.9), "skin": Color(0.9, 0.84, 0.92), "hold": 100.0,
			"suit": Color(0.32, 0.1, 0.5), "suit_amt": 0.55, "trim": Color(0.85, 0.35, 1.0),
			"makeup": {"liner": Color(0.2, 0.02, 0.3), "lips": Color(0.32, 0.05, 0.32), "lips_amt": 0.85, "shadow": VIOLET, "shadow_amt": 0.7},
			"extras": {"piercings": ["lobe_hoops", "helix", "nose_stud"]},
			"notes": "Suit dyed his violet. Dark lips, heavy shadow,\npale skin. Titan: violet-black, spiral decals."},
		{"name": "4  Marrow's Own", "outfit": "suit_hush", "hair": "pixie", "tint": Color(0.5, 0.3, 0.95), "skin": Color(0.88, 0.8, 0.92),
			"suit": Color(0.16, 0.03, 0.24), "suit_amt": 0.8, "trim": Color(1.0, 0.3, 0.85), "hold": 100.0, "trance": true,
			"makeup": {"liner": Color(0.08, 0.0, 0.1), "lips": Color(0.36, 0.0, 0.38), "lips_amt": 1.0, "shadow": Color(0.45, 0.08, 0.6), "shadow_amt": 0.9},
			"extras": {"piercings": ["lobe_hoops", "helix", "septum"], "accessories": ["choker"], "tattoos": ["stars"]},
			"notes": "The cut he picked, his collar on her neck.\nGun: Marrow's Mark. Titan: his cinema's logo."},
	]},
	"glass": {"title": "GLASS", "bg": Color(0.08, 0.08, 0.16), "light": Color(0.85, 0.85, 1.0), "stages": [
		{"name": "1  First vial", "outfit": "suit_shade", "hair": "bob", "glass": 0.0, "hold": 60.0,
			"notes": "Her shade suit. A glint at the corner\nof the eye. Gun: stock."},
		{"name": "2  Facets", "outfit": "suit_shade", "hair": "bob", "glass": 0.35, "hold": 70.0, "tint": Color(0.92, 0.88, 1.0),
			"suit": Color(0.22, 0.24, 0.45), "suit_amt": 0.45, "trim": Color(0.6, 0.75, 1.0),
			"makeup": {"shadow": Color(0.72, 0.78, 1.0), "shadow_amt": 0.45, "lips": Color(0.72, 0.62, 0.9), "lips_amt": 0.5},
			"extras": {"piercings": ["brow"]},
			"notes": "Crystal at the jaw. The suit's trims go\nice-blue. Frost on her lids and lips."},
		{"name": "3  Prism", "outfit": "suit_shade", "hair": "bob", "glass": 0.7, "hold": 85.0, "tint": Color(0.85, 0.82, 1.0),
			"suit": Color(0.42, 0.46, 0.78), "suit_amt": 0.65, "trim": Color(0.75, 0.95, 1.0),
			"makeup": {"liner": Color(0.85, 0.9, 1.0), "shadow": Color(0.8, 0.85, 1.0), "shadow_amt": 0.6, "lips": Color(0.62, 0.62, 0.98), "lips_amt": 0.75},
			"extras": {"piercings": ["brow", "bridge"]},
			"notes": "Silver liner, glass-blue lips. Cracks run\nthrough her tattoos. Gun: Prism."},
		{"name": "4  Crystalline", "outfit": "suit_shade", "hair": "bob", "glass": 1.0, "hold": 100.0, "tint": Color(1.2, 1.2, 1.45),
			"suit": Color(0.78, 0.82, 1.0), "suit_amt": 0.85, "trim": Color(0.85, 0.95, 1.0), "glow": Color(0.55, 0.45, 1.0), "energy": 0.06,
			"makeup": {"liner": Color(1.0, 1.0, 1.0), "shadow": Color(0.95, 0.95, 1.0), "shadow_amt": 0.75, "lips": Color(0.85, 0.88, 1.0), "lips_amt": 1.0},
			"extras": {"piercings": ["brow", "bridge"]},
			"notes": "The suit itself glassing over. Frosted hair.\nTitan: crystal clusters on the plates."},
	]},
	"hymn": {"title": "HYMN - THE COLONY'S DOSE", "bg": Color(0.78, 0.8, 0.84), "light": Color(1.0, 1.0, 1.0), "stages": [
		{"name": "1  Compliant", "outfit": "suit", "hair": "bob", "hold": 0.0, "extras": {"piercings": ["lobes"]},
			"notes": "Her own clothes, her own studs, a colony\narmband and a dose tag on a lanyard."},
		{"name": "2  Resident", "outfit": "suit_ghost", "hair": "ponytail", "hold": 0.0,
			"suit": Color(0.6, 0.62, 0.66), "suit_amt": 0.6, "trim": Color(0.9, 0.95, 1.0),
			"makeup": {"lips": Color(0.85, 0.72, 0.7), "lips_amt": 0.6},
			"notes": "Grey colony issue, hair tied back to regs.\nLips gone nude. The studs came out."},
		{"name": "3  Dispenser", "outfit": "suit_ghost", "hair": "pixie", "tint": Color(1.25, 1.25, 1.3),
			"suit": Color(0.74, 0.8, 0.92), "suit_amt": 0.85, "trim": Color(0.6, 0.85, 1.0),
			"makeup": {"lips": Color(0.9, 0.82, 0.82), "lips_amt": 0.8, "marks": "rank"},
			"extras": {"accessories": ["visor"]},
			"notes": "Cut short, dyed silver, colony visor.\nA white rank line under each eye."},
		{"name": "4  Choir", "outfit": "suit_ghost", "hair": "pixie", "tint": Color(1.6, 1.6, 1.65),
			"suit": Color(0.86, 0.9, 1.0), "suit_amt": 0.95, "trim": Color(0.85, 0.95, 1.0),
			"makeup": {"lips": Color(0.96, 0.9, 0.9), "lips_amt": 1.0, "marks": "rank", "shadow": Color(1.0, 1.0, 1.0), "shadow_amt": 0.5},
			"notes": "All white, glowing at the seams, no colour\nleft on her. Titan: grey over Dad's markings."},
	]},
	"faith": {"title": "FAITH - THE PRECURSOR'S", "bg": Color(0.22, 0.16, 0.08), "light": Color(1.0, 0.92, 0.75), "stages": [
		{"name": "1  Acolyte", "outfit": "suit", "hair": "shoulder",
			"suit": Color(0.62, 0.55, 0.45), "suit_amt": 0.5, "trim": GOLD,
			"makeup": {"shadow": GOLD, "shadow_amt": 0.5},
			"extras": {"tattoos": ["precursor"]},
			"notes": "Suit faded to temple stone, gold trims.\nGold dust on her lids. The glyph on her wrist."},
		{"name": "2  Votary", "outfit": "suit", "hair": "braids", "tint": Color(1.15, 0.95, 0.6),
			"suit": Color(0.78, 0.7, 0.52), "suit_amt": 0.7, "trim": GOLD,
			"makeup": {"liner": Color(0.75, 0.5, 0.12), "shadow": GOLD, "shadow_amt": 0.7, "lips": Color(0.72, 0.45, 0.28), "lips_amt": 0.65, "marks": "glyphs"},
			"extras": {"tattoos": ["precursor", "fern_band"], "piercings": ["lobe_hoops"]},
			"notes": "Braids, bronze lips, glyph lines painted\ndown her cheeks. Gun: Relic."},
		{"name": "3  Ascendant", "outfit": "suit", "hair": "braids", "tint": Color(1.3, 1.05, 0.55), "glass": 0.5,
			"suit": Color(0.92, 0.85, 0.66), "suit_amt": 0.8, "trim": Color(1.0, 0.88, 0.5), "glow": GOLD, "energy": 0.04,
			"makeup": {"liner": Color(0.85, 0.6, 0.15), "shadow": GOLD, "shadow_amt": 0.85, "lips": Color(0.9, 0.68, 0.3), "lips_amt": 0.85, "marks": "glyphs"},
			"extras": {"tattoos": ["precursor", "fern_band", "sun_tree"], "piercings": ["lobe_hoops", "bridge"]},
			"notes": "Gold lips, gold veins of light, glass at her\nhands and face. Glyph sleeves glowing."},
		{"name": "4  Idol", "outfit": "suit", "hair": "braids", "tint": Color(1.5, 1.2, 0.6), "glass": 1.0,
			"suit": Color(1.0, 0.94, 0.78), "suit_amt": 0.9, "trim": Color(1.0, 0.95, 0.7), "glow": GOLD, "energy": 0.07,
			"makeup": {"liner": GOLD, "shadow": GOLD, "shadow_amt": 1.0, "lips": GOLD, "lips_amt": 1.0, "marks": "glyphs"},
			"extras": {"tattoos": ["precursor", "fern_band", "sun_tree"], "piercings": ["lobe_hoops", "bridge"]},
			"notes": "Statue-still, glassed over. (Glass is violet\nin-game today; it would be clear gold.)"},
	]},
	"colony": {"title": "COLONY CITY - TOWN'S GRIP MAXED", "bg": Color(0.6, 0.68, 0.82), "light": Color(1.0, 0.98, 0.95), "stages": [
		{"name": "1  Transferee", "outfit": "suit", "hair": "bob",
			"notes": "Travel coat, colony ID badge,\nher things in a bag."},
		{"name": "2  Conscript", "outfit": "suit_techwear", "hair": "ponytail",
			"suit": Color(0.82, 0.86, 0.94), "suit_amt": 0.55, "trim": Color(0.3, 0.6, 1.0),
			"makeup": {"lips": Color(0.82, 0.42, 0.48), "lips_amt": 0.5},
			"notes": "Pilot gear re-dyed colony white and blue.\nDad's patch hidden in the collar."},
		{"name": "3  Rising", "outfit": "suit_techwear", "hair": "shoulder", "tint": Color(1.1, 1.0, 1.05),
			"suit": Color(0.78, 0.84, 1.0), "suit_amt": 0.8, "trim": Color(0.35, 0.6, 1.0),
			"makeup": {"lips": Color(0.85, 0.12, 0.2), "lips_amt": 0.85, "liner": Color(0.05, 0.03, 0.05), "blush": Color(1.0, 0.55, 0.6), "blush_amt": 0.35},
			"extras": {"piercings": ["lobes"], "accessories": ["shades"]},
			"notes": "Red lips, a black wing, glossy hair.\nTattoos lasered off, one by one."},
		{"name": "4  Colony Ace", "outfit": "suit_techwear", "hair": "shoulder", "tint": Color(1.2, 1.05, 1.1),
			"suit": Color(0.86, 0.88, 1.0), "suit_amt": 0.9, "trim": Color(0.65, 0.35, 1.0),
			"makeup": {"lips": Color(0.75, 0.02, 0.12), "lips_amt": 1.0, "liner": Color(0.02, 0.0, 0.02), "shadow": Color(0.55, 0.45, 0.65), "shadow_amt": 0.5,
				"blush": Color(1.0, 0.5, 0.58), "blush_amt": 0.45},
			"extras": {"piercings": ["lobe_hoops"]},
			"notes": "Poster glam in white and violet.\nGun: Ace. Titan: her face as nose art."},
	]},
	"ophelia": {"title": "OPHELIA'S OBSESSION - KEEPSAKE", "bg": Color(0.16, 0.08, 0.12), "light": Color(1.0, 0.88, 0.92), "stages": [
		{"name": "1  Upset", "npc": "ophelia", "npc_outfit": "tee", "mood": ["angry"],
			"notes": "Eco went out without seeing her. Again.\nShe doesn't come to the door."},
		{"name": "2  Clingy", "npc": "ophelia", "npc_outfit": "hoodie", "mood": ["sad", "lookaway"],
			"notes": "Waiting at the gate when runs end.\nWearing Eco's hoodie. Asks where she was."},
		{"name": "3  Obsessed", "npc": "ophelia", "npc_outfit": "tee", "mood": ["smile"], "tint": Color(1.35, 0.7, 0.9),
			"glow": ROSE, "energy": 0.05,
			"notes": "The violet streak gone rose. Rose-papered\ncigarettes, rolled just for Eco."},
		{"name": "4  Eco on Keepsake", "outfit": "suit", "hair": "bob", "hold": 60.0, "eye": ROSE, "glow": ROSE, "energy": 0.04, "trim": ROSE,
			"tint": Color(1.1, 0.85, 0.95),
			"makeup": {"lips": Color(0.9, 0.35, 0.5), "lips_amt": 0.8, "blush": ROSE, "blush_amt": 0.55, "shadow": ROSE, "shadow_amt": 0.5},
			"extras": {"accessories": ["choker"], "piercings": ["lobe_hoops"]},
			"notes": "Rose in her eyes, rose on her lips, Ophelia's\nneck ring glowing rose. Runs cut short for her."},
	]},
	"keepsake": {"title": "KEEPSAKE - DRESSED BY OPHELIA", "bg": Color(0.18, 0.08, 0.13), "light": Color(1.0, 0.88, 0.93), "stages": [
		{"name": "1  Matching", "outfit": "suit_ophelia", "hair": "bob", "tint": Color(1.1, 0.82, 0.95), "hold": 40.0, "eye": ROSE,
			"makeup": {"liner": Color(0.05, 0.02, 0.05), "lips": Color(0.88, 0.4, 0.55), "lips_amt": 0.7, "blush": ROSE, "blush_amt": 0.35},
			"extras": {"piercings": ["lobe_hoops"]},
			"notes": "Ophelia's colours, Ophelia's liner. 'We match!'\nShe picked it all out while Eco was on a run."},
		{"name": "2  Her Doll", "outfit": "suit_homemade", "hair": "shoulder", "tint": Color(1.25, 0.75, 0.95), "hold": 70.0, "eye": ROSE,
			"suit": Color(0.92, 0.18, 0.5), "suit_amt": 0.85, "trim": ROSE,
			"makeup": {"lips": Color(0.95, 0.38, 0.6), "lips_amt": 0.95, "blush": ROSE, "blush_amt": 0.65, "shadow": ROSE, "shadow_amt": 0.6},
			"extras": {"piercings": ["lobe_hoops", "nose_stud"]},
			"notes": "Dressed up for nobody but Ophelia. Rose dye,\nrosy cheeks, a smile that doesn't reach her eyes."},
		{"name": "3  Hers", "outfit": "suit_shade", "hair": "undercut", "tint": Color(0.75, 0.42, 0.7), "hold": 100.0, "eye": ROSE, "trance": true,
			"suit": Color(0.24, 0.05, 0.15), "suit_amt": 0.7, "trim": ROSE,
			"makeup": {"liner": Color(0.02, 0.0, 0.02), "lips": Color(0.45, 0.04, 0.2), "lips_amt": 1.0, "shadow": Color(0.5, 0.1, 0.32), "shadow_amt": 0.85},
			"extras": {"piercings": ["snakebites", "lobe_hoops", "helix"], "tattoos": ["heart_bolt"]},
			"notes": "Black and rose like her. Ophelia's snakebites,\na heart she drew on the flash sheet herself."},
		{"name": "4  Her Own (Mature)", "outfit": "suit_vesper_open", "hair": "bob",
			"makeup": {"liner": Color(0.03, 0.02, 0.03), "lips": Color(0.8, 0.06, 0.12), "lips_amt": 0.9},
			"extras": {"piercings": ["lobe_hoops", "nose_stud"], "tattoos": ["cry_anyway", "heart_bolt", "swallows", "hip_moth"]},
			"notes": "Broke Ophelia's obsession: her pick, her ink,\nher red lips. Mature only, never forced."},
	]},
	"capture": {"title": "HYMN - CAUGHT SKIPPING THE DOSE", "bg": Color(0.78, 0.8, 0.84), "light": Color(1.0, 1.0, 1.0), "stages": [
		{"name": "1  Headphones", "outfit": "suit_ghost", "hair": "pixie", "tint": Color(1.25, 1.25, 1.3),
			"suit": Color(0.6, 0.64, 0.72), "suit_amt": 0.7, "props": ["headphones"],
			"notes": "Locked on. Trigger words and colony radio\non loop; the game's music fades under it."},
		{"name": "2  Cuff", "outfit": "suit_ghost", "hair": "pixie", "tint": Color(1.25, 1.25, 1.3),
			"suit": Color(0.7, 0.75, 0.85), "suit_amt": 0.8, "props": ["headphones", "cuff"],
			"makeup": {"lips": Color(0.88, 0.8, 0.8), "lips_amt": 0.7, "marks": "rank"},
			"notes": "A dose cuff on her wrist: miss the line\nand it doses her where she stands."},
		{"name": "3  Headset", "outfit": "suit_ghost", "hair": "pixie", "tint": Color(1.4, 1.4, 1.45),
			"suit": Color(0.8, 0.85, 0.98), "suit_amt": 0.9, "props": ["headphones", "cuff", "vr"],
			"makeup": {"lips": Color(0.92, 0.85, 0.86), "lips_amt": 0.9, "marks": "rank"},
			"notes": "The headset goes on. She sees what the\ncolony wants her to see."},
		{"name": "4  Through it", "npc": "ophelia", "npc_outfit": "hoodie", "mood": ["smile"],
			"pov": {"tag": "FRIEND", "words": [["OBEY", Vector2(-170, -150), 54], ["YOU ARE SAFE", Vector2(-20, 40), 24],
				["TAKE YOUR DOSE", Vector2(-175, 120), 24], ["LOWER YOUR WEAPON", Vector2(-150, 200), 22]]},
			"notes": "The grunt in front of her wears Ophelia's\nface. Tag: FRIEND. Lower your weapon."},
	]},
}

## Where her makeup goes on the face texture (eco v_face.png, 1024 square).
const LIPS := [Vector2(512, 766), Vector2(72, 18)]
const EYES := [[Vector2(330, 498), Vector2(165, 78)], [Vector2(700, 498), Vector2(165, 78)]]
const EYE_BAND := Rect2i(110, 470, 800, 90)
const CHEEKS := [[Vector2(330, 628), Vector2(95, 42)], [Vector2(702, 628), Vector2(95, 42)]]

var out := "user://look_concepts"
var only: Array = []
var _dyed := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--paths="):
			only = Array(a.get_slice("=", 1).split(","))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	ContentRating.set_rating("M", false)
	Hair.save_path = "user://look_concepts_salon.cfg"
	Vices.save_path = "user://look_concepts_vices.cfg"
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	for id in PATHS:
		if not only.is_empty() and not id in only:
			continue
		var path: Dictionary = PATHS[id]
		var stages: Array = path["stages"]
		var sheet := Image.create(PANEL.x * stages.size(), PANEL.y + FACE.y, false, Image.FORMAT_RGBA8)
		for i in stages.size():
			var shots: Array = await _stage(path, stages[i])
			sheet.blit_rect(shots[0], Rect2i(Vector2i.ZERO, PANEL), Vector2i(PANEL.x * i, 0))
			sheet.blit_rect(shots[1], Rect2i(Vector2i.ZERO, FACE), Vector2i(PANEL.x * i, PANEL.y))
		sheet.save_png(out.path_join("look_%s.png" % id))
		print("wrote look_%s.png" % id)
	quit()


func _stage(path: Dictionary, s: Dictionary) -> Array:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = path["bg"]
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = path["light"]
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_color = path["light"]
	stage.add_child(sun)

	Vices.hold = float(s.get("hold", 0.0))
	Vices.entranced = bool(s.get("trance", false))
	RenderingServer.global_shader_parameter_set("eco_glass", float(s.get("glass", 0.0)))
	var model: Node3D
	if s.has("npc"):
		model = HubNpc.create(s["npc"], Vector3.ZERO, 25.0)
		stage.add_child(model)
		await _frames(2)
		model.wear(String(s.get("npc_outfit", "")))
		model.mood(s.get("mood", []))
	else:
		model = ECO.instantiate()
		model.rotation_degrees.y = 25.0
		stage.add_child(model)
		model.wear(String(s.get("outfit", "suit")))
		Hair.apply(model, "eco", String(s.get("hair", "bob")))
		EcoExtras.apply(model, s.get("extras", {"piercings": [], "accessories": [], "tattoos": []}))
	await _frames(3)
	_paint(model, s)
	if s.has("props"):
		_props(model, s["props"])

	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.95, -3.9), Vector3(0, 0.82, 0))
	cam.fov = 40
	if s.has("pov"):
		# through her eyes: someone a few steps off, the way the headset shows them
		cam.look_at_from_position(Vector3(0.25, 1.52, -2.2), Vector3(0, 1.25, 0))
		cam.fov = 55
	cam.make_current()

	# the PS2 screen (autoload) draws at the window's size: frame the panel in its middle
	var win := Vector2(root.get_texture().get_size())
	var o := ((win - Vector2(PANEL)) * 0.5).floor()
	var layer := CanvasLayer.new()
	layer.layer = 100
	stage.add_child(layer)
	var dark: Color = path["bg"]
	var ink := Color.WHITE if dark.get_luminance() < 0.5 else Color(0.08, 0.08, 0.12)
	_label(layer, path["title"], 15, o + Vector2(16, 12), ink.lerp(Color(0.5, 0.5, 0.5), 0.35))
	_label(layer, s["name"], 26, o + Vector2(16, 34), ink)
	_label(layer, s.get("notes", ""), 14, o + Vector2(16, PANEL.y - 60), ink)
	if s.has("pov"):
		_headset_view(stage, win, s["pov"])
	await _frames(25)
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img = img.get_region(Rect2i(Vector2i(o), PANEL))
	# her face, close, from the same side
	layer.visible = false
	cam.fov = 22
	cam.look_at_from_position(Vector3(0.0, 1.5, -1.35), Vector3(0, 1.44, 0))
	await _frames(12)
	var face := root.get_texture().get_image()
	face.convert(Image.FORMAT_RGBA8)
	var fw := int(win.x * 0.42)
	var fh := int(fw * float(FACE.y) / FACE.x)
	face = face.get_region(Rect2i(int((win.x - fw) * 0.5), int((win.y - fh) * 0.5), fw, fh))
	face.resize(FACE.x, FACE.y)
	stage.queue_free()
	Vices.entranced = false
	await _frames(2)
	return [img, face]


## What the colony's headset lays over her view: a white wash, its words
## floating in the middle of everything, and a tag on whoever's in front of her.
func _headset_view(stage: Node, win: Vector2, pov: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	stage.add_child(layer)
	var wash := ColorRect.new()
	wash.color = Color(0.92, 0.95, 1.0, 0.22)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wash)
	var c := win * 0.5
	for w in pov.get("words", []):
		_label(layer, w[0], int(w[2]), c + Vector2(w[1]), Color(1, 1, 1, 0.85))
	if pov.has("tag"):
		_label(layer, pov["tag"], 22, c + Vector2(-48, -235), Color(0.55, 1.0, 0.65))
	# the headset's frame: rounded corners closing in
	var frame := ColorRect.new()
	frame.color = Color(0.05, 0.06, 0.08, 1.0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec2 size;\nvoid fragment(){ vec2 p = (UV - 0.5) * size; vec2 h = vec2(190.0, 330.0); vec2 q = abs(p) - h + 60.0; float d = length(max(q, 0.0)) - 60.0; COLOR.a = smoothstep(0.0, 6.0, d); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("size", win)
	frame.material = mat
	layer.add_child(frame)


## Colony gear on her, built from primitives on her head and wrist (model
## space at rest: she faces -Z, her left is -X), the way eco_extras.gd builds
## piercings: "headphones", "vr", "cuff".
func _props(model: Node3D, props: Array) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.93, 0.94, 0.97)
	shell.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.16)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.85, 0.95, 1.0)
	lit.emission_enabled = true
	lit.emission = Color(0.7, 0.9, 1.0)
	lit.emission_energy_multiplier = 2.0
	var head := _attach(skel, "J_Bip_C_Head")
	var to_head := _rest_inverse(skel, "J_Bip_C_Head")
	if "headphones" in props:
		for side in [-1.0, 1.0]:
			var cup := _part(CylinderMesh.new(), shell, to_head, Vector3(0.088 * side, 1.505, 0.012), Vector3(0, 0, 90))
			(cup.mesh as CylinderMesh).top_radius = 0.048
			(cup.mesh as CylinderMesh).bottom_radius = 0.048
			(cup.mesh as CylinderMesh).height = 0.035
			head.add_child(cup)
			var ring := _part(TorusMesh.new(), lit, to_head, Vector3(0.107 * side, 1.505, 0.012), Vector3(0, 0, 90))
			(ring.mesh as TorusMesh).inner_radius = 0.026
			(ring.mesh as TorusMesh).outer_radius = 0.034
			head.add_child(ring)
		# the band over the top of her head
		for i in 9:
			var a := PI * (i + 0.5) / 9.0
			var p := Vector3(cos(a) * 0.098, 1.515 + sin(a) * 0.125, 0.012)
			var seg := _part(BoxMesh.new(), dark, to_head, p, Vector3(0, 0, rad_to_deg(a) + 90.0))
			(seg.mesh as BoxMesh).size = Vector3(0.05, 0.016, 0.03)
			head.add_child(seg)
	if "vr" in props:
		var box := _part(BoxMesh.new(), shell, to_head, Vector3(0, 1.535, -0.085), Vector3.ZERO)
		(box.mesh as BoxMesh).size = Vector3(0.175, 0.075, 0.075)
		head.add_child(box)
		var face := _part(BoxMesh.new(), lit, to_head, Vector3(0, 1.535, -0.124), Vector3.ZERO)
		(face.mesh as BoxMesh).size = Vector3(0.15, 0.022, 0.004)
		head.add_child(face)
		for side in [-1.0, 1.0]:
			var strap := _part(BoxMesh.new(), dark, to_head, Vector3(0.088 * side, 1.54, -0.01), Vector3.ZERO)
			(strap.mesh as BoxMesh).size = Vector3(0.012, 0.03, 0.15)
			head.add_child(strap)
	if "cuff" in props:
		var wrist := _attach(skel, "J_Bip_L_Hand")
		var to_wrist := _rest_inverse(skel, "J_Bip_L_Hand")
		var at := skel.get_bone_global_rest(skel.find_bone("J_Bip_L_Hand")).origin
		var cuff := _part(CylinderMesh.new(), shell, to_wrist, at + Vector3(0.05, 0, 0), Vector3(0, 0, 90))
		(cuff.mesh as CylinderMesh).top_radius = 0.042
		(cuff.mesh as CylinderMesh).bottom_radius = 0.042
		(cuff.mesh as CylinderMesh).height = 0.05
		wrist.add_child(cuff)
		var light := _part(TorusMesh.new(), lit, to_wrist, at + Vector3(0.05, 0, 0), Vector3(0, 0, 90))
		(light.mesh as TorusMesh).inner_radius = 0.041
		(light.mesh as TorusMesh).outer_radius = 0.047
		wrist.add_child(light)


func _attach(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	return att


## From the skeleton's space at rest into `bone`'s.
func _rest_inverse(skel: Skeleton3D, bone: String) -> Transform3D:
	return skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()


func _part(mesh: Mesh, mat: Material, to_bone: Transform3D, at: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = to_bone * Transform3D(Basis.from_euler(rot_deg * PI / 180.0), at)
	return mi


func _label(layer: CanvasLayer, text: String, size: int, pos: Vector2, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6) if col.get_luminance() > 0.5 else Color(1, 1, 1, 0.5))
	l.add_theme_constant_override("outline_size", 4)
	layer.add_child(l)


## Dye, makeup, skin, glow and iris tint, on this model's own copies of its materials.
func _paint(model: Node, s: Dictionary) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null:
			continue
		var is_hair := m3.name in ["Hair", Hair.SALON_HAIR] or String(m3.name).to_lower().contains("hair")
		for i in m3.mesh.get_surface_count():
			var src := m3.get_active_material(i)
			if not src is ShaderMaterial:
				continue
			var mat: ShaderMaterial = src.duplicate()
			var tex = mat.get_shader_parameter("albedo_tex")
			var tex_path: String = tex.resource_path if tex is Texture2D else ""
			if is_hair and s.has("tint"):
				var base = mat.get_shader_parameter("albedo")
				var c: Color = base if base is Color else Color.WHITE
				var t: Color = s["tint"]
				mat.set_shader_parameter("albedo", Color(c.r * t.r, c.g * t.g, c.b * t.b, c.a))
				# a dye, not just a shade: the new colour shows through the dark of her own
				mat.set_shader_parameter("emission", t * 0.5)
				mat.set_shader_parameter("emission_energy", 0.35)
			elif s.has("glow"):
				mat.set_shader_parameter("emission", s["glow"])
				mat.set_shader_parameter("emission_energy", float(s.get("energy", 0.05)))
			if s.has("skin"):
				mat.set_shader_parameter("skin_tone", s["skin"])
			# her liner and lashes are their own mesh (the VRoid eyeline)
			if src.resource_name.contains("eyeline") and s.has("makeup") and s["makeup"].has("liner"):
				mat.set_shader_parameter("albedo", (s["makeup"]["liner"] as Color) * 1.6)
			if s.has("eye") and mat.get_shader_parameter("iris_swirl") == true:
				mat.set_shader_parameter("albedo", s["eye"])
			if tex is Texture2D and tex_path.contains("v_face") and s.has("makeup"):
				mat.set_shader_parameter("albedo_tex", _makeup(tex, s["makeup"]))
			if tex is Texture2D and tex_path.contains("v_body") and s.has("suit"):
				var mask = mat.get_shader_parameter("mask_tex")
				if mask is Texture2D:
					mat.set_shader_parameter("albedo_tex", _dye_suit(tex, mask, s["suit"], float(s.get("suit_amt", 0.6))))
			var glow = mat.get_shader_parameter("glow_tex")
			if glow is Texture2D and s.has("trim"):
				mat.set_shader_parameter("glow_tex", _dye_glow(glow, s["trim"]))
			m3.set_surface_override_material(i, mat)


func _image(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The suit re-dyed: where the mask says fabric, her texture's light and dark
## kept and its colour swapped for `col`, by `amt`.
func _dye_suit(tex: Texture2D, mask_tex: Texture2D, col: Color, amt: float) -> Texture2D:
	var key := "%s|%s|%s" % [tex.resource_path, col.to_html(), amt]
	if _dyed.has(key):
		return _dyed[key]
	var img := _image(tex)
	var mask := _image(mask_tex)
	if mask.get_size() != img.get_size():
		mask.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_NEAREST)
	var d := img.get_data()
	var m := mask.get_data()
	for p in range(0, d.size(), 4):
		var g := m[p + 1] / 255.0
		if g < 0.5:
			continue
		var r := d[p] / 255.0
		var gg := d[p + 1] / 255.0
		var b := d[p + 2] / 255.0
		var lum := 0.3 * r + 0.59 * gg + 0.11 * b
		var k := 0.4 + 0.9 * lum
		d[p] = int(clampf(lerpf(r, col.r * k, amt), 0.0, 1.0) * 255.0)
		d[p + 1] = int(clampf(lerpf(gg, col.g * k, amt), 0.0, 1.0) * 255.0)
		d[p + 2] = int(clampf(lerpf(b, col.b * k, amt), 0.0, 1.0) * 255.0)
	var t := _texture(Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d))
	_dyed[key] = t
	return t


## The glowing trims in a new colour, as bright as they were.
func _dye_glow(tex: Texture2D, col: Color) -> Texture2D:
	var key := "%s|%s" % [tex.resource_path, col.to_html()]
	if _dyed.has(key):
		return _dyed[key]
	var img := _image(tex)
	var d := img.get_data()
	for p in range(0, d.size(), 4):
		var v := maxi(d[p], maxi(d[p + 1], d[p + 2])) / 255.0
		if v <= 0.0:
			continue
		d[p] = int(clampf(col.r * v, 0.0, 1.0) * 255.0)
		d[p + 1] = int(clampf(col.g * v, 0.0, 1.0) * 255.0)
		d[p + 2] = int(clampf(col.b * v, 0.0, 1.0) * 255.0)
	var t := _texture(Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d))
	_dyed[key] = t
	return t


## Her face texture with makeup painted on: lipstick over her lips, the liner
## and lashes recoloured, shadow round the eyes, blush, and markings.
func _makeup(tex: Texture2D, mk: Dictionary) -> Texture2D:
	var img := _image(tex)
	var sc := img.get_width() / 1024.0
	if mk.has("shadow"):
		for e in EYES:
			_wash(img, e[0] * sc, e[1] * sc, mk["shadow"], float(mk.get("shadow_amt", 0.6)), true)
	if mk.has("blush"):
		for c in CHEEKS:
			_wash(img, c[0] * sc, c[1] * sc, mk["blush"], float(mk.get("blush_amt", 0.4)), false)
	if mk.has("liner"):
		var band := Rect2i(Vector2i(Vector2(EYE_BAND.position) * sc), Vector2i(Vector2(EYE_BAND.size) * sc))
		var lc: Color = mk["liner"]
		for y in range(band.position.y, band.end.y):
			for x in range(band.position.x, band.end.x):
				var px := img.get_pixel(x, y)
				var lum := px.get_luminance()
				if lum < 0.4:
					img.set_pixel(x, y, px.lerp(lc * (0.35 + lum), 0.85))
	if mk.has("lips"):
		var lc: Color = mk["lips"]
		var amt := float(mk.get("lips_amt", 0.8))
		var c: Vector2 = LIPS[0] * sc
		var r: Vector2 = LIPS[1] * sc
		for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
			for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
				var q := Vector2((x - c.x) / r.x, (y - c.y) / r.y)
				if q.length() > 1.0:
					continue
				var px := img.get_pixel(x, y)
				# only where her lips are coloured, not the skin round them
				var w := clampf((px.s - 0.12) / 0.15, 0.0, 1.0) * smoothstep(1.0, 0.7, q.length())
				if w > 0.0:
					img.set_pixel(x, y, px.lerp(lc * (0.55 + 0.6 * px.v), w * amt))
	match String(mk.get("marks", "")):
		"rank":
			for cx in [330, 702]:
				_rect(img, Rect2i(Vector2i(Vector2(cx - 55, 566) * sc), Vector2i(Vector2(110, 6) * sc)), Color(1, 1, 1), 0.95)
		"glyphs":
			for cx in [300, 732]:
				_rect(img, Rect2i(Vector2i(Vector2(cx - 3, 562) * sc), Vector2i(Vector2(6, 120) * sc)), GOLD, 0.9)
				for dy in [585, 625, 665]:
					_rect(img, Rect2i(Vector2i(Vector2(cx - 12, dy) * sc), Vector2i(Vector2(24, 5) * sc)), GOLD, 0.9)
	if OS.get_environment("LOOK_DEBUG") != "":
		img.save_png(out.path_join("face_%d.png" % Time.get_ticks_usec()))
	return _texture(img)


## A soft wash of colour over an ellipse (multiplied in, so the shading stays),
## skipping the pale eye holes.
func _wash(img: Image, c: Vector2, r: Vector2, col: Color, amt: float, skip_pale: bool) -> void:
	for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
		for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var q := Vector2((x - c.x) / r.x, (y - c.y) / r.y).length()
			if q > 1.0:
				continue
			var px := img.get_pixel(x, y)
			if skip_pale and px.get_luminance() > 0.9 and px.s < 0.08:
				continue
			var w := smoothstep(1.0, 0.25, q) * amt
			img.set_pixel(x, y, px.lerp(Color(px.r * col.r, px.g * col.g, px.b * col.b).lerp(col * 0.85, 0.5), minf(w * 1.3, 1.0)))


func _rect(img: Image, r: Rect2i, col: Color, amt: float) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, amt))
