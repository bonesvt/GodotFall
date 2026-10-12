extends SceneTree
## Screenshots of the Rusted Halo (bar_screen.gd): the drinks menu, a
## Scrapjack hand, and the test level seen sober, buzzed and hammered
## (drunk_screen.gd). Sets the rating to Mature for the run, not saved.
##   xvfb-run -a godot --path . --audio-driver Dummy -s res://tools/hub/bar_shots.gd -- [out_dir] [--bar]
## --bar skips the drunk views (they're slow on the cloud's software renderer).
## Needs a renderer (not --headless).

const BarScreen := preload("res://scripts/hub/bar_screen.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const DrunkScreen := preload("res://scripts/ui/drunk_screen.gd")

var out := "user://bar_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	_go.call_deferred()


func _shot(name: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _go() -> void:
	var level: Node = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	var player := level.find_child("Player", true, false)
	if player != null:
		player.set_physics_process(false)
	root.add_child(DrunkScreen.new())
	for b in ([] if "--bar" in OS.get_cmdline_user_args() else [0.0, 2.0, 4.5]):
		Vices.buzz = b
		await _shot("drunk_view_%d" % int(b * 10), 40)

	var armory: Armory = Armory.open("user://bar_shots_armory.cfg")
	armory.stash = {"scrap": 140, "alloy": 22, "circuits": 1, "lock_cores": 0}
	Vices.buzz = 2.2
	var bar := BarScreen.new(armory, 5)
	root.add_child(bar)
	bar.select(1)
	if not "--bar" in OS.get_cmdline_user_args():
		await _shot("bar_drinks")
	bar.set_tab("cards")
	bar.set_bet(1)
	bar.deal()
	await _shot("bar_cards_hand")
	if bar.game.state == bar.game.State.PLAYING:
		bar.stand()
	await _shot("bar_cards_settled")
	quit()
