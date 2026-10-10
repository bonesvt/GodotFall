extends RefCounted
## What going back to whoever had them does to Mom and Ophelia (rescue.gd):
## once one of them has walked to the same captor VISITS times
## (Rescue.visits), she dresses and talks like theirs until that captor's
## hold on her fades to nothing. Not Eco's hypno looks (vice_looks.gd): these
## are clothes on them, built round their own bodies.
##   marrow  a long dark coat lined violet, its sleeves down over her hands;
##           quiet, distant, defends him
##   colony  a white colony jumpsuit, hair pinned back; calm, polite, the
##           colony's phrases
##   cutter  an oversized grey hoodie with his red stripes, ripped jeans;
##           twitchy, fast, after Eco's scrap
## The clothes are real meshes in their glbs (tools/npc/npc_outfits.py):
## Outfit_captor_<captor>_*, cut from her own body and let out, skinned to her
## rig, hidden unless she's in that look. Whatever she had on goes while she
## wears them.

const Hair := preload("res://scripts/hub/hair.gd")

## The look's meshes in their glb.
const PREFIX := "Outfit_captor_%s_"
## Their lines, while it lasts (Mom's and Ophelia's: %s is Eco's name for
## nobody; the lines are theirs as they are).
const LINES := {
	"marrow": {
		"mom": ["Mom, very quietly: \"He listens. You never sit still long enough.\"",
			"Mom: \"Don't look at me like that, sweetheart. I'm calmer than I've been since your father.\"",
			"Mom looks past Eco, at nothing. \"He said you could come and sit with us. Just sit.\"",
			"Mom: \"I'm fine. I'm finally fine. Why does that make you so angry?\""],
		"ophelia": ["Ophelia, quiet, not looking at her: \"He listens. You never sit still long enough.\"",
			"Ophelia: \"He's not what you think. He's the only one who doesn't want anything from me.\"",
			"Ophelia pulls the coat round herself. \"It's warm down there. It's quiet. You'd hate it.\"",
			"Ophelia: \"Stop. I know what you're going to say. Don't.\""],
	},
	"colony": {
		"mom": ["Mom, smiling, hands folded: \"Calm is a kindness, Eco.\"",
			"Mom: \"Have you taken your film today, sweetheart? It's for your own good. It's for everyone's.\"",
			"Mom: \"The line moves faster when everyone's polite. Remember that.\"",
			"Mom: \"Good morning, citizen. Oh. I mean, good morning, baby.\""],
		"ophelia": ["Ophelia, hair pinned back, smiling: \"Calm is a kindness, Eco.\"",
			"Ophelia: \"Compliance isn't the same as giving up. It's resting. You should rest.\"",
			"Ophelia: \"Good morning, citizen.\" A beat. \"Sorry. Habit. Good morning.\"",
			"Ophelia: \"Everyone's nicer in the white. Even me. Especially me.\""],
	},
	"cutter": {
		"mom": ["Mom, talking too fast: \"Eco! Eco, hi, have you got any scrap? Ten? Twenty? I'll pay you back, I swear.\"",
			"Mom, hands going: \"I'm good, I'm good, I'm so good, why are you looking at me like that?\"",
			"Mom: \"Cutter's not so bad, okay? He gets it. He gets me. You don't.\"",
			"Mom: \"Just spot me a little scrap, just till tomorrow, please, baby, please.\""],
		"ophelia": ["Ophelia, bouncing on her heels: \"Eco, Eco, you got scrap? Like ten? I'll pay you back, for real this time.\"",
			"Ophelia: \"I'm fine, I'm fine, I'm buzzing, it's good, it's so good, don't do the face.\"",
			"Ophelia: \"He was here first, you know? Before Marrow, before any of it. He gets me.\"",
			"Ophelia, picking at her sleeve: \"Twenty scrap. Fifteen. Ten. Come on. Come on.\""],
	},
}


## Dresses `npc` (a hub_npc.gd) in what `captor` has her in, or takes it off ("").
static func apply(npc: Node3D, who: String, captor: String) -> void:
	remove(npc)
	if captor == "":
		return
	var look := npc.find_children((PREFIX % captor) + "*", "MeshInstance3D", true, false)
	if look.is_empty():
		return
	npc.set_meta("rescue_look", captor)
	var under := npc.find_children("Outfit_*", "MeshInstance3D", true, false) + npc.find_children("Piercings*", "MeshInstance3D", true, false)
	for mi in under:  # theirs under it would poke through
		if mi in look:
			mi.visible = true
		elif mi.visible:
			mi.visible = false
			mi.set_meta("rescue_hidden", true)
	if captor == "colony" and who == "ophelia":
		Hair.apply(npc.get_node_or_null("Model") if npc.get_node_or_null("Model") != null else npc, who, "ponytail")


static func remove(npc: Node3D) -> void:
	var captor: String = npc.get_meta("rescue_look", "")
	if captor != "":
		for mi in npc.find_children((PREFIX % captor) + "*", "MeshInstance3D", true, false):
			mi.visible = false
	for mi in npc.find_children("Outfit_*", "MeshInstance3D", true, false) + npc.find_children("Piercings*", "MeshInstance3D", true, false):
		if mi.has_meta("rescue_hidden"):
			mi.visible = true
			mi.remove_meta("rescue_hidden")
	if captor == "colony":
		Hair.apply(npc.get_node_or_null("Model") if npc.get_node_or_null("Model") != null else npc, String(npc.get("who")))
	if npc.has_meta("rescue_look"):
		npc.remove_meta("rescue_look")


static func line(who: String, captor: String, n: int) -> String:
	var pool: Array = LINES.get(captor, {}).get(who, [])
	return pool[n % pool.size()] if not pool.is_empty() else ""


## A plain material (rescue_event.gd builds its props from it).
static func _mat(c: Color, rough := 0.85, sheen := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = sheen
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
