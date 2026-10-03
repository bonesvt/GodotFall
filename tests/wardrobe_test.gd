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

	for who in ["mom", "ophelia"]:
		var list := Wardrobe.outfits(who)
		_check("%s's outfits are her model's" % who, list == HubNpc.OUTFITS[who], list)
		_check("%s starts on changes every run" % who, Wardrobe.choice(who) == Wardrobe.ROTATE)
		_check("%s's options lead with changes every run" % who, Wardrobe.options(who) == [Wardrobe.ROTATE] + list)
	var eco := Wardrobe.outfits("eco")
	_check("Eco has her suit at least, and wears it", eco.has("suit") and Wardrobe.choice("eco") == "suit", eco)
	for who in ["eco", "mom", "ophelia"]:
		for outfit in Wardrobe.outfits(who):
			_check("%s: %s has a name" % [who, outfit], Wardrobe.outfit_name(outfit) != "")

	# A pick sticks across runs; no pick rotates.
	var stage := Node3D.new()
	root.add_child(stage)
	var oph := HubNpc.create("ophelia", Vector3.ZERO, 0.0)
	stage.add_child(oph)
	await _ticks(2)
	oph.wear_for_run(1)
	_check("no pick: run 1's outfit", oph.outfit == HubNpc.OUTFITS["ophelia"][1], oph.outfit)
	Wardrobe.choose("ophelia", "lingerie")
	_check("the pick is saved", Wardrobe.choice("ophelia") == "lingerie")
	for r in [0, 1, 4]:
		oph.wear_for_run(r)
		_check("picked outfit worn after run %d" % r, oph.outfit == "lingerie", oph.outfit)
	Wardrobe.choose("ophelia", "not_an_outfit")
	_check("an unknown outfit isn't saved", Wardrobe.choice("ophelia") == "lingerie")
	Wardrobe.choose("ophelia", Wardrobe.ROTATE)
	oph.wear_for_run(2)
	_check("back to changes every run", oph.outfit == HubNpc.OUTFITS["ophelia"][2], oph.outfit)
	stage.queue_free()

	# The screen.
	var screen := WardrobeScreen.new(3)
	root.add_child(screen)
	await _ticks(3)
	_check("screen opens on Eco", screen.who() == "eco" and screen.kind == "wardrobe")
	screen.switch_person(1)
	_check("next is Mom", screen.who() == "mom")
	screen.select(Wardrobe.options("mom").find("bikini"))
	_check("picking an outfit saves it", screen.confirm() and Wardrobe.choice("mom") == "bikini")
	_check("picking it again changes nothing", not screen.confirm())
	_check("the change is listed for the run manager", screen.changed == [["mom", "bikini"]], screen.changed)
	var preview: Node = screen._model
	_check("Mom on the turntable in her bikini", preview != null and preview.outfit == "bikini", preview.outfit if preview != null else null)
	screen.select(0)
	_check("changes every run previews this run's outfit", preview.outfit == HubNpc.OUTFITS["mom"][3 % HubNpc.OUTFITS["mom"].size()], preview.outfit)
	screen.switch_person(1)
	await _ticks(1)
	_check("then Ophelia, on her own model", screen.who() == "ophelia" and screen._model.who == "ophelia")
	screen.switch_person(1)
	_check("and round to Eco", screen.who() == "eco")
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
