extends SceneTree
## Eco's wardrobe (scripts/hub/wardrobe.gd, wardrobe_screen.gd): everyone's
## outfits are listed, a pick is saved and worn by the NPCs instead of their
## per-run rotation, the screen switches people and saves picks, and the
## wardrobe stands in the hub with its screen.
## Run: godot --headless --path . -s tests/wardrobe_test.gd

const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const WardrobeScreen := preload("res://scripts/hub/wardrobe_screen.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const HubBuilder := preload("res://scripts/hub/hub_builder.gd")

var failures := 0


func _check(label: String, ok: bool, detail = null) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label, "  ", detail)


func _initialize() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Wardrobe.save_path = "user://test_wardrobe.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Wardrobe.save_path))

	var list := Wardrobe.outfits("ophelia")
	_check("Ophelia's outfits are her model's", list == HubNpc.OUTFITS["ophelia"], list)
	_check("Ophelia starts on changes every run", Wardrobe.choice("ophelia") == Wardrobe.ROTATE)
	_check("her options lead with changes every run", Wardrobe.options("ophelia") == [Wardrobe.ROTATE] + list)
	_check("Eco wears her suit", Wardrobe.outfits("eco").has("suit") and Wardrobe.choice("eco") == "suit")
	_check("only people with outfits to pick get a tab", Wardrobe.people().all(func(p): return Wardrobe.outfits(p[0]).size() > 1) and Wardrobe.people().any(func(p): return p[0] == "ophelia"), Wardrobe.people())
	for outfit in list:
		_check("ophelia: %s has a name" % outfit, Wardrobe.outfit_name(outfit) != "")

	# A pick sticks across runs; no pick rotates.
	var stage := Node3D.new()
	root.add_child(stage)
	var oph := HubNpc.create("ophelia", Vector3.ZERO, 0.0)
	stage.add_child(oph)
	await _ticks(2)
	oph.wear_for_run(1)
	_check("no pick: run 1's outfit", oph.outfit == HubNpc.OUTFITS["ophelia"][1], oph.outfit)
	Wardrobe.choose("ophelia", "night")
	_check("the pick is saved", Wardrobe.choice("ophelia") == "night")
	for r in [0, 1, 4]:
		oph.wear_for_run(r)
		_check("picked outfit worn after run %d" % r, oph.outfit == "night", oph.outfit)
	Wardrobe.choose("ophelia", "not_an_outfit")
	_check("an unknown outfit isn't saved", Wardrobe.choice("ophelia") == "night")
	Wardrobe.choose("ophelia", Wardrobe.ROTATE)
	oph.wear_for_run(2)
	_check("back to changes every run", oph.outfit == HubNpc.OUTFITS["ophelia"][2], oph.outfit)
	stage.queue_free()

	# The screen.
	var screen := WardrobeScreen.new(4)
	root.add_child(screen)
	await _ticks(3)
	var tabs: Array = Wardrobe.people().map(func(p): return p[0])
	screen.person = tabs.find("ophelia")
	screen.switch_person(0)
	_check("screen shows Ophelia", screen.who() == "ophelia" and screen.kind == "wardrobe")
	screen.select(Wardrobe.options("ophelia").find("hoodie"))
	_check("picking an outfit saves it", screen.confirm() and Wardrobe.choice("ophelia") == "hoodie")
	_check("picking it again changes nothing", not screen.confirm())
	_check("the change is listed for the run manager", screen.changed == [["ophelia", "hoodie"]], screen.changed)
	var preview: Node = screen._model
	_check("Ophelia on the turntable in her hoodie", preview != null and preview.outfit == "hoodie", preview.outfit if preview != null else null)
	screen.select(0)
	_check("changes every run previews this run's outfit", preview.outfit == list[4 % list.size()], preview.outfit)
	screen.queue_free()

	# In the hub.
	var hub := Node3D.new()
	root.add_child(hub)
	var info: Dictionary = HubBuilder.build(hub)
	var found: Array = info["interactables"].filter(func(i): return i["id"] == "wardrobe")
	_check("the wardrobe is in the hub and opens its screen", found.size() == 1 and found[0].get("screen") == "wardrobe", found)
	hub.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Wardrobe.save_path))
	await _ticks(2)
	print("RESULT ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
