extends RefCounted
## Cutter's body (cutter.gd), in the Choir's toon look like the Shepherd's
## (shepherd_model.gd, whose builders it borrows), cut into the parts
## threat_model.gd's biped walk moves: Hips, LegL/R with KneeL/R, Torso, Head.
## Ophelia's old dealer: ~1.9 m, lanky and a little hunched, a charcoal hoodie
## with red stripes down the sleeves and the hood up, round red goggles glowing
## in the shadow of it, a bandolier of Redline vials across his chest, ripped
## dark jeans, red sneakers, and a long syringe of Redline in his right hand.
## Faces -Z; his right is +X.

const SM := preload("res://scripts/hub/shepherd_model.gd")


## A Node3D holding all of Cutter, pivots and all.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CutterModel"
	var hoodie := SM._mat("cutter_hoodie", Color(0.4, 0.38, 0.42), 0.0, 0.1)
	var jeans := SM._mat("cutter_jeans", Color(0.26, 0.32, 0.48), 0.0, 0.05)
	var red := SM._mat("cutter_red", Color(0.9, 0.14, 0.14), 0.0, 0.3)
	var lining := SM._mat("cutter_lining", Color(0.6, 0.08, 0.1), 0.0, 0.1)
	var white := SM._mat("cutter_white", Color(0.88, 0.86, 0.84), 0.0, 0.2)
	var skin := SM._mat("cutter_skin", Color(0.72, 0.58, 0.5), 0.0, 0.1)
	var dark := SM._mat("cutter_dark", Color(0.05, 0.05, 0.06), 0.0, 0.2)
	var glow := SM._mat("cutter_glow", Color(1.0, 0.15, 0.12), 2.2, 0.0)
	var steel := SM._mat("cutter_steel", Color(0.7, 0.72, 0.75), 0.0, 0.6)

	var hips := SM._pivot(root, "Hips", Vector3(0, 0.95, 0))
	var torso := SM._pivot(root, "Torso", Vector3(0, 1.02, 0))
	var head := SM._pivot(torso, "Head", Vector3(0, 1.66, -0.06))
	# legs: long and thin in ripped dark jeans, red sneakers
	for side in ["L", "R"]:
		var s := 1.0 if side == "R" else -1.0
		var leg := SM._pivot(root, "Leg" + side, Vector3(0.1 * s, 0.95, 0))
		var knee := SM._pivot(leg, "Knee" + side, Vector3(0.105 * s, 0.52, 0.0))
		var hip_at := Vector3(0.1 * s, 0.95, 0)
		var knee_at := Vector3(0.105 * s, 0.52, 0.0)
		var ankle_at := Vector3(0.105 * s, 0.09, 0.0)
		SM._limb(leg, hip_at, knee_at, 0.065, 0.05, jeans)
		SM._ell(knee, knee_at + Vector3(0, 0.02, -0.04), Vector3(0.035, 0.03, 0.01), skin)  # the rip at the knee
		SM._limb(knee, knee_at, ankle_at, 0.05, 0.04, jeans)
		SM._box(knee, Vector3(0.105 * s, 0.045, -0.04), Vector3(0.1, 0.09, 0.27), red)
		SM._box(knee, Vector3(0.105 * s, 0.012, -0.04), Vector3(0.105, 0.025, 0.28), white)  # the sole
	# hips: the hoodie's hem
	SM._ell(hips, Vector3(0, 1.0, 0), Vector3(0.15, 0.08, 0.11), hoodie)
	SM._ell(hips, Vector3(0, 0.93, 0), Vector3(0.13, 0.06, 0.1), jeans)
	# torso: the hoodie, hunched forward; red stripes; the bandolier
	SM._limb(torso, Vector3(0, 1.0, 0), Vector3(0, 1.32, -0.03), 0.13, 0.15, hoodie)
	SM._ell(torso, Vector3(0, 1.42, -0.04), Vector3(0.2, 0.17, 0.13), hoodie)
	SM._ell(torso, Vector3(0, 1.12, -0.11), Vector3(0.11, 0.06, 0.03), hoodie)  # the front pocket
	var strap_a := Vector3(-0.17, 1.52, -0.08)
	var strap_b := Vector3(0.14, 1.05, -0.12)
	SM._limb(torso, strap_a, strap_b, 0.018, 0.018, dark)
	for i in 5:
		var at := strap_a.lerp(strap_b, 0.18 + i * 0.16) + Vector3(0, 0, -0.03)
		SM._limb(torso, at + Vector3(0, -0.035, 0), at + Vector3(0, 0.035, 0), 0.01, 0.01, glow)
	# the hood up and pushed back, red inside its rim; his face out of it: a thin
	# face, round red goggles over his eyes, a wide grin
	SM._ell(head, Vector3(0, 1.71, 0.03), Vector3(0.13, 0.15, 0.135), hoodie)
	SM._torus(head, Vector3(0, 1.68, -0.06), 0.085, 0.11, lining, Vector3(90, 0, 0))
	SM._ell(head, Vector3(0, 1.66, -0.06), Vector3(0.078, 0.1, 0.08), skin)
	SM._limb(head, Vector3(-0.07, 1.69, -0.12), Vector3(0.07, 1.69, -0.12), 0.006, 0.006, dark)  # the goggles' strap
	for s in [-1.0, 1.0]:
		SM._torus(head, Vector3(0.033 * s, 1.69, -0.132), 0.015, 0.023, steel, Vector3(90, 0, 0))
		SM._ell(head, Vector3(0.033 * s, 1.69, -0.134), Vector3(0.016, 0.016, 0.006), glow)
	SM._ell(head, Vector3(0, 1.615, -0.128), Vector3(0.04, 0.009, 0.008), white)  # the grin
	SM._ell(head, Vector3(0, 1.6, -0.115), Vector3(0.045, 0.028, 0.03), skin)  # a stubbled chin
	SM._limb(torso, Vector3(0, 1.55, -0.04), Vector3(0, 1.64, -0.06), 0.05, 0.05, skin)  # his neck
	# arms: long, in the hoodie's sleeves with red stripes; hands bare
	var rh := Vector3(0.24, 1.08, -0.3)   # right hand, up and forward with the syringe
	var lh := Vector3(-0.28, 0.85, -0.06)  # left hand, low and twitchy
	for arm in [[1.0, Vector3(0.22, 1.5, -0.04), Vector3(0.3, 1.22, -0.1), rh], [-1.0, Vector3(-0.22, 1.5, -0.04), Vector3(-0.3, 1.18, 0.0), lh]]:
		var s: float = arm[0]
		var sh: Vector3 = arm[1]
		var el: Vector3 = arm[2]
		var wr: Vector3 = arm[3]
		SM._limb(torso, sh, el, 0.055, 0.048, hoodie)
		SM._limb(torso, el, wr, 0.048, 0.04, hoodie)
		SM._limb(torso, sh + Vector3(0.045 * s, 0, 0), el + Vector3(0.042 * s, 0, 0), 0.012, 0.012, red)
		SM._limb(torso, el + Vector3(0.038 * s, 0, 0), wr + Vector3(0.032 * s, 0, 0), 0.011, 0.011, red)
		SM._ell(torso, wr + (wr - el).normalized() * 0.05, Vector3(0.035, 0.045, 0.03), skin)
	# the syringe: a long glass barrel of Redline, a steel needle, the plunger under his thumb
	var d := Vector3(-0.15, 0.2, -1).normalized()
	var grip := rh + (rh - Vector3(0.3, 1.22, -0.1)).normalized() * 0.05
	SM._limb(torso, grip - d * 0.06, grip + d * 0.12, 0.016, 0.016, white)
	SM._limb(torso, grip - d * 0.04, grip + d * 0.11, 0.012, 0.012, glow)
	SM._limb(torso, grip + d * 0.12, grip + d * 0.2, 0.0025, 0.001, steel)
	SM._limb(torso, grip - d * 0.06, grip - d * 0.1, 0.006, 0.006, white)
	SM._box(torso, grip - d * 0.105, Vector3(0.04, 0.008, 0.04), white)
	return root
