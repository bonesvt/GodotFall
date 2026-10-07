extends SceneTree
## Her clothes cling to her soft parts (eco_cling.gd): skirts that were
## weighted to her hips and thighs only now carry the glute weights of the
## skin under them, so a bouncing or squashed glute takes the skirt with it
## instead of poking through; jackets keep their own bust weights; things
## far from her chest and glutes (shoes, clips) are left alone. With
## cloth_cling off nothing changes. It's built once and shared, so a second
## Eco costs nothing.
## Run: godot --headless --path . -s res://tests/cling_test.gd

const ECO := preload("res://assets/models/eco.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var off = ECO.instantiate()
	off.cloth_cling = false
	root.add_child(off)
	var started := Time.get_ticks_msec()
	var eco = ECO.instantiate()
	root.add_child(eco)
	var first := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var again = ECO.instantiate()
	root.add_child(again)
	var second := Time.get_ticks_msec() - started
	print("clung %d clothing meshes; first Eco %d ms, second %d ms" % [eco.clung, first, second])
	_check("her clothes are put on the soft weights", eco.clung >= 4, eco.clung)
	_check("not with cloth_cling off", off.clung == 0, off.clung)

	for skirt in ["base_ophelia_skirt", "outfit_y2k_t_skirt", "outfit_date_m_skirt"]:
		var before := _soft_share(off, skirt, "Glute")
		var after := _soft_share(eco, skirt, "Glute")
		print("%s: glute weight on %d%% of its vertices (was %d%%), up to %.2f" % [skirt, roundi(after[0] * 100), roundi(before[0] * 100), after[1]])
		_check("%s rides her glutes" % skirt, before[0] == 0.0 and after[0] > 0.05 and after[1] > 0.3, after)
	var shoes := _soft_share(eco, "outfit_y2k_any_shoes", "")
	_check("her shoes are left alone", shoes[0] == 0.0, shoes)
	var jacket_before := _soft_share(off, "base_gwen_jacket", "Bust")
	var jacket_after := _soft_share(eco, "base_gwen_jacket", "Bust")
	_check("her jacket keeps its own bust weights", absf(jacket_before[0] - jacket_after[0]) < 0.001, [jacket_before, jacket_after])
	_check("a second Eco reuses the work", second < maxi(first / 3, 400), [first, second])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


## [share of the mesh's vertices weighted to a J_Sec bone containing `part`
## ("" any), the most such weight on one vertex].
func _soft_share(eco, mesh_name: String, part: String) -> Array:
	var mi := eco.skeleton.find_child(mesh_name, false, false) as MeshInstance3D
	if mi == null:
		return [-1.0, 0.0]
	var sk: Skeleton3D = eco.skeleton
	var count := 0
	var total := 0
	var most := 0.0
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		for v in verts.size():
			total += 1
			var w := 0.0
			for k in per:
				var b := bones[v * per + k]
				var n := String(mi.skin.get_bind_name(b))
				if n == "":
					n = sk.get_bone_name(mi.skin.get_bind_bone(b))
				if n.begins_with("J_Sec_") and not "Hair" in n and (part == "" or part in n):
					w += weights[v * per + k]
			if w > 0.01:
				count += 1
				most = maxf(most, w)
	return [float(count) / maxi(total, 1), most]


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
