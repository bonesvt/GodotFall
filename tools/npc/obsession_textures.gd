extends SceneTree
## Bakes Ophelia's lacing-stage textures (obsession_look.gd) from her own:
##   body_hoodie_lacing.png  gold-stained fingertips from rolling the papers,
##                           and ECO in pen with a heart on the back of her
##                           left hand
##   face_lacing.png         dark circles under her eyes
## It finds the spots on her mesh (fingertip bones, the back of the hand, just
## under each eye) and paints their triangles in UV space, so it follows the
## model whatever its UV layout.
##   godot --headless --path . -s res://tools/npc/obsession_textures.gd

const DIR := "res://assets/textures/npc/ophelia/"
const GOLD := Color(0.86, 0.62, 0.2)
const SHADOW := Color(0.36, 0.2, 0.3)
const INK := Color(0.12, 0.1, 0.22)

## A 3x5 font for her doodle.
const GLYPHS := {
	"E": ["###", "#..", "##.", "#..", "###"],
	"C": [".##", "#..", "#..", "#..", ".##"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."],
}

var skel: Skeleton3D


func _initialize() -> void:
	var model: Node3D = load("res://assets/models/npc/ophelia.glb").instantiate()
	root.add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	var body := _surface(model, "npc_ophelia_body")
	var face := _surface(model, "npc_ophelia_face")
	if body.is_empty() or face.is_empty():
		push_error("ophelia's body or face surface not found")
		quit(1)
		return
	var body_img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "body_hoodie.png"))
	body_img.convert(Image.FORMAT_RGBA8)
	_fingertips(body, body_img)
	_doodle(body, body_img)
	body_img.save_png(ProjectSettings.globalize_path(DIR + "body_hoodie_lacing.png"))
	var face_img := Image.load_from_file(ProjectSettings.globalize_path(DIR + "face.png"))
	face_img.convert(Image.FORMAT_RGBA8)
	_circles(face, face_img)
	face_img.save_png(ProjectSettings.globalize_path(DIR + "face_lacing.png"))
	print("baked body_hoodie_lacing.png and face_lacing.png")
	quit()


## {verts, uvs, normals, index, weight(bone_name) -> PackedFloat32Array}
func _surface(model: Node, mat_name: String) -> Dictionary:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var mat := m3.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != mat_name:
				continue
			var a := m3.mesh.surface_get_arrays(s)
			var names := {}
			for b in m3.skin.get_bind_count():
				var n := String(m3.skin.get_bind_name(b))
				if n == "":
					n = skel.get_bone_name(m3.skin.get_bind_bone(b))
				names[b] = n
			return {"verts": a[Mesh.ARRAY_VERTEX], "uvs": a[Mesh.ARRAY_TEX_UV], "normals": a[Mesh.ARRAY_NORMAL],
				"index": a[Mesh.ARRAY_INDEX], "bones": a[Mesh.ARRAY_BONES], "weights": a[Mesh.ARRAY_WEIGHTS], "names": names}
	return {}


## How much of vertex v is skinned to bones whose names pass `test`.
func _weight(s: Dictionary, v: int, test: Callable) -> float:
	var per: int = s["bones"].size() / s["verts"].size()
	var w := 0.0
	for k in per:
		if test.call(String(s["names"].get(s["bones"][v * per + k], ""))):
			w += s["weights"][v * per + k]
	return w


## Paints every triangle with a per-vertex amount (0..1) blended toward
## `tint`. Amounts gather per pixel first (the most any triangle gives it), so
## shared edges aren't painted twice.
func _paint(s: Dictionary, img: Image, amount: PackedFloat32Array, tint: Color, mode := "mix") -> void:
	var size := Vector2(img.get_size())
	var w := img.get_width()
	var got := {}
	var idx: PackedInt32Array = s["index"]
	for t in range(0, idx.size(), 3):
		var a := [amount[idx[t]], amount[idx[t + 1]], amount[idx[t + 2]]]
		if a[0] <= 0.0 and a[1] <= 0.0 and a[2] <= 0.0:
			continue
		var p := [s["uvs"][idx[t]] * size, s["uvs"][idx[t + 1]] * size, s["uvs"][idx[t + 2]] * size]
		var lo: Vector2 = (p[0] as Vector2).min(p[1]).min(p[2]).floor()
		var hi: Vector2 = (p[0] as Vector2).max(p[1]).max(p[2]).ceil()
		for y in range(int(lo.y), int(hi.y) + 1):
			for x in range(int(lo.x), int(hi.x) + 1):
				var bc := _bary(Vector2(x + 0.5, y + 0.5), p[0], p[1], p[2])
				if bc.x < -0.02 or bc.y < -0.02 or bc.z < -0.02:
					continue
				var k: float = clampf(a[0] * bc.x + a[1] * bc.y + a[2] * bc.z, 0.0, 1.0)
				var key := clampi(y, 0, img.get_height() - 1) * w + posmod(x, w)
				got[key] = maxf(float(got.get(key, 0.0)), k)
	for key in got:
		var xi: int = key % w
		var yi: int = key / w
		var k: float = got[key]
		var c := img.get_pixel(xi, yi)
		var out := c.lerp(c * tint * 1.6, k) if mode == "multiply" else c.lerp(Color(tint, c.a), k)
		out.a = c.a
		img.set_pixel(xi, yi, out)


func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d := v0.x * v1.y - v1.x * v0.y
	if absf(d) < 1e-9:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / d
	var w := (v0.x * v2.y - v2.x * v0.y) / d
	return Vector3(1.0 - v - w, v, w)


## Gold from rolling the papers: the last joint of every finger and thumb.
func _fingertips(s: Dictionary, img: Image) -> void:
	var amount := PackedFloat32Array()
	amount.resize(s["verts"].size())
	var tip := func(n: String) -> bool: return n.begins_with("J_Bip_") and n.ends_with("3") and (n.contains("_L_") or n.contains("_R_"))
	for v in amount.size():
		amount[v] = smoothstep(0.3, 0.8, _weight(s, v, tip)) * 0.55
	_paint(s, img, amount, GOLD, "multiply")


## ECO and a little heart in pen on the back of her left hand.
func _doodle(s: Dictionary, img: Image) -> void:
	var hand := skel.find_bone("J_Bip_L_Hand")
	var mid := skel.find_bone("J_Bip_L_Middle1")
	if hand < 0 or mid < 0:
		return
	var h := skel.get_bone_global_rest(hand).origin
	var along := (skel.get_bone_global_rest(mid).origin - h).normalized()
	var back := Vector3.UP  # the back of her hand faces up in the rest pose
	var idx: PackedInt32Array = s["index"]
	var verts: PackedVector3Array = s["verts"]
	var uvs: PackedVector2Array = s["uvs"]
	# the triangles on the back of the hand, and how UV space runs across them
	var tris := []
	var du := Vector2.ZERO
	var dv := Vector2.ZERO
	var centre := Vector2.ZERO
	for t in range(0, idx.size(), 3):
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		var n := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
		if n.length() < 1e-9:
			continue
		var cen := (verts[ia] + verts[ib] + verts[ic]) / 3.0
		var off := cen - h
		if absf(n.normalized().dot(back)) < 0.7 or off.dot(along) < 0.005 or off.dot(along) > 0.06 or off.y < 0.0:
			continue
		var hw := func(nm: String) -> bool: return nm == "J_Bip_L_Hand"
		if _weight(s, ia, hw) < 0.5:
			continue
		tris.append(t)
		# UV gradient of the world "along" and "across" directions on this triangle
		var e1 := verts[ib] - verts[ia]
		var e2 := verts[ic] - verts[ia]
		var f1 := uvs[ib] - uvs[ia]
		var f2 := uvs[ic] - uvs[ia]
		var across := along.cross(back)
		var m := Basis(e1, e2, n.normalized()).inverse()
		var ca := m * along
		var cb := m * across
		du += f1 * ca.x + f2 * ca.y
		dv += f1 * cb.x + f2 * cb.y
		centre += (uvs[ia] + uvs[ib] + uvs[ic]) / 3.0
	if tris.is_empty():
		push_warning("no back-of-hand triangles found")
		return
	centre /= tris.size()
	# metres -> pixels along each direction
	var size := Vector2(img.get_size())
	var px_along := du / tris.size() * size
	var px_across := dv / tris.size() * size
	var dot := 0.0035  # metres per font pixel
	var text := "ECO"
	var width := text.length() * 4 - 1
	for i in text.length():
		var g: Array = GLYPHS[text[i]]
		for row in 5:
			for col in 3:
				if g[row][col] != "#":
					continue
				# letters read across the hand, rows run toward her fingers
				var x := (i * 4 + col - width * 0.5) * dot
				var y := (2 - row) * dot
				_blot(img, centre * size + px_across * x + px_along * y, (px_along.length() + px_across.length()) * dot * 0.32)
	# a small heart above the name, toward her knuckles
	for p in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1.5, 0.8), Vector2(1.5, 0.8), Vector2(-0.5, 1.2), Vector2(0.5, 1.2), Vector2(0, -1.0), Vector2(-0.8, -0.3), Vector2(0.8, -0.3)]:
		_blot(img, centre * size + px_across * (p.x * dot * 0.8) + px_along * ((p.y + 6.0) * dot * 0.8), (px_along.length() + px_across.length()) * dot * 0.25)


func _blot(img: Image, at: Vector2, r: float) -> void:
	r = maxf(r, 1.2)
	for y in range(int(at.y - r - 1), int(at.y + r + 2)):
		for x in range(int(at.x - r - 1), int(at.x + r + 2)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(at)
			if d > r + 0.5 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var k := clampf(r + 0.5 - d, 0.0, 1.0) * 0.85
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.lerp(INK, k), c.a))


## Dark circles: a soft plum smudge painted straight into UV space just under
## each eye. Each eye is found from her eye-white mesh (its width and lowest
## point), and the face texture is read where the face mesh sits there.
func _circles(s: Dictionary, img: Image) -> void:
	var model := skel.get_parent()
	while model != null and not (model is Node3D and model.get_parent() == root):
		model = model.get_parent()
	var white := _surface(model, "npc_ophelia_eye_white")
	if white.is_empty():
		push_warning("no eye whites found")
		return
	var size := Vector2(img.get_size())
	for side in [-1.0, 1.0]:
		var lo := Vector3(0, INF, 0)
		var minx := INF
		var maxx := -INF
		var sum := Vector3.ZERO
		var n := 0
		for v in (white["verts"] as PackedVector3Array):
			if signf(v.x) != side:
				continue
			sum += v
			n += 1
			minx = minf(minx, v.x)
			maxx = maxf(maxx, v.x)
			if v.y < lo.y:
				lo = v
		if n == 0:
			continue
		var c := sum / n
		var under := Vector3(c.x, lo.y - 0.004, lo.z)
		var inner := Vector3(c.x - side * (maxx - minx) * 0.45, under.y, under.z)
		var outer := Vector3(c.x + side * (maxx - minx) * 0.45, under.y, under.z)
		var below := Vector3(c.x, under.y - 0.007, under.z)
		var uc := _uv_at(s, under) * size
		var ui := _uv_at(s, inner) * size
		var uo := _uv_at(s, outer) * size
		var ub := _uv_at(s, below) * size
		var ax := (uo - ui) * 0.5
		var ay := ub - uc
		_smudge(img, uc, ax, ay)


## The face texture's UV at the face mesh's nearest vertex to p.
func _uv_at(s: Dictionary, p: Vector3) -> Vector2:
	var best := INF
	var uv := Vector2.ZERO
	var verts: PackedVector3Array = s["verts"]
	for v in verts.size():
		var d := verts[v].distance_squared_to(p)
		if d < best:
			best = d
			uv = s["uvs"][v]
	return uv


## A soft elliptical smudge at c, with half-axes ax (along the eye) and ay (down).
func _smudge(img: Image, c: Vector2, ax: Vector2, ay: Vector2) -> void:
	var m := Transform2D(ax, ay, c).affine_inverse()
	var r := ax.length() + ay.length() + 2.0
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var q := m * Vector2(x + 0.5, y + 0.5)
			# heavier along the lash line, fading down the cheek
			var k := (1.0 - smoothstep(0.35, 1.0, q.length())) * 0.55
			if k <= 0.0:
				continue
			var col := img.get_pixel(x, y)
			var out := col.lerp(col * SHADOW * 1.6, k)
			out.a = col.a
			img.set_pixel(x, y, out)
