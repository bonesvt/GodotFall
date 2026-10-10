extends SceneTree
## Ophelia's look through her obsession (obsession_look.gd): each stage's
## props, her watching Eco from across the hub once she's obsessed, and her
## hair going all Eco's red at keeper. Mature only.
##   godot --headless --path . --audio-driver Dummy -s res://tests/ophelia_look_test.gd

const Obsession := preload("res://scripts/hub/obsession.gd")
const ObsessionLook := preload("res://scripts/hub/obsession_look.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	_run.call_deferred()


func _run() -> void:
	var npc: Node3D = HubNpc.create("ophelia", Vector3.ZERO, 0.0)
	root.add_child(npc)
	await process_frame
	var want := {2: [], 3: ["Hips"], 4: ["Hips", "UpperChest", "Candle"], 5: ["Hips", "UpperChest", "Candle", "UpperArm", "Hand"]}
	for meter in [30.0, 60.0, 80.0, 95.0]:
		Obsession.reset()
		Obsession.meter = meter
		var s := ObsessionLook.stage()
		ObsessionLook.dress(npc, {})
		await process_frame
		var names := npc.find_children("ObsessionProp*", "Node3D", true, false).filter(func(n): return n.is_inside_tree() and not n.is_queued_for_deletion()).map(func(n): return String(n.name))
		var ok := true
		for w in want[s]:
			ok = ok and names.any(func(n): return n.contains(w))
		_check("stage %d at %d: its props" % [s, meter], ok, names)
		_check("stage %d: watching range" % s, npc.notice_range == (ObsessionLook.WATCH_RANGE if s >= 3 else HubNpc.NOTICE_RANGE), npc.notice_range)
	_check("keeper: her hair goes Eco's red", _dyed(npc), "")
	_check("lacing on: gold fingers and the pen on her hand", _tex(npc, "npc_ophelia_body") == ObsessionLook.LACING_BODY, _tex(npc, "npc_ophelia_body"))
	_check("lacing on: dark circles", _tex(npc, "npc_ophelia_face") == ObsessionLook.LACING_FACE, _tex(npc, "npc_ophelia_face"))
	Obsession.meter = 60.0
	ObsessionLook.dress(npc, {})
	_check("below keeper: her hair's her own", not _dyed(npc), "")
	_check("below lacing: her own skin", _tex(npc, "npc_ophelia_body") != ObsessionLook.LACING_BODY and _tex(npc, "npc_ophelia_face") != ObsessionLook.LACING_FACE, [_tex(npc, "npc_ophelia_body"), _tex(npc, "npc_ophelia_face")])
	Obsession.reset()
	ObsessionLook.dress(npc, {})
	await process_frame
	_check("over: no props, normal range", npc.find_children("ObsessionProp*", "Node3D", true, false).filter(func(n): return not n.is_queued_for_deletion()).is_empty() and npc.notice_range == HubNpc.NOTICE_RANGE, "")
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## The texture her material `part` shows now.
func _tex(npc: Node3D, part: String) -> String:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i)
			if base == null or base.resource_name != part:
				continue
			var o := m3.get_surface_override_material(i) as ShaderMaterial
			var t = (o if o != null else base as ShaderMaterial).get_shader_parameter("albedo_tex")
			return t.resource_path if t != null else ""
	return ""


func _dyed(npc: Node3D) -> bool:
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i)
			var o := m3.get_surface_override_material(i)
			if base != null and base.resource_name.ends_with("_hair") and o != null and o.has_meta("obsession"):
				return true
	return false


func _check(what: String, ok: bool, detail = null) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + what + ("" if ok else "  (%s)" % str(detail)))
