extends SceneTree
## Brushing past people (hub_npc.gd soft body, npc_springs.gd): everyone in
## the hub and town has a slim soft capsule Eco presses into like a padded
## wall instead of walking through; bumping into them makes them look
## surprised and rocks them back a little, and their soft parts and hers push
## each other aside. Townsfolk with the bones get springs too.
## Run: godot --headless --path . -s res://tests/crowd_test.gd

const PLAYER := preload("res://scenes/player.tscn")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcSprings := preload("res://scripts/hub/npc_springs.gd")

var failures := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	# Mom, facing Eco, a metre ahead of her
	var mom: Node3D = HubNpc.create("mom", Vector3(0, 0, -1.0), 180.0)
	root.add_child(mom)
	var player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.strolling = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for f in 30:
		await physics_frame
	_check("she has a soft body", mom.soft_body != null and mom.soft_body.is_in_group("npc_body") and float(mom.soft_body.get_meta("softness")) > 0.0, mom.soft_body)
	var springs = mom.get_node("Springs")
	var calm_swing: float = springs.swing_deg()

	# walk Eco into her
	player.wish_dir = Vector3(0, 0, -1)
	var touched_at := 0.0
	var most := 0.0
	var surprised := false
	var rocked := 0.0
	for f in 120:
		var v: Vector3 = player.soft_press(Vector3(0, 0, -1.3))
		player.global_position += Vector3(v.x, 0, v.z) / 60.0
		if touched_at == 0.0 and player.press > 0.0:
			touched_at = -player.global_position.z
		most = maxf(most, springs.swing_deg())
		surprised = surprised or mom.face == "surprised"
		rocked = maxf(rocked, -(mom.get_node("Model") as Node3D).global_position.z - 1.0)
		await process_frame
	var gap: float = mom.global_position.z - player.global_position.z
	print("Eco stops %.3f m from Mom's middle (her capsule 0.2); Mom's springs swing %.1f deg (calm %.1f)" % [-gap, most, calm_swing])
	_check("Eco presses into her, not through her", -gap > 0.2 + 0.07 and -gap < 0.2 + 0.16, -gap)
	_check("Mom notices the bump", surprised, mom.face)
	_check("and is rocked back a little", rocked > 0.02 and rocked < 0.08, rocked)
	_check("then settles back on her spot", (mom.get_node("Model") as Node3D).position.length() < 0.01, (mom.get_node("Model") as Node3D).position)
	_check("her soft parts are pushed aside by Eco", most > calm_swing + 3.0, [calm_swing, most])
	var eco = player.get_node("EcoBody").shadow
	var bust: int = eco.skeleton.find_bone("J_Sec_L_Bust1")
	var q: Quaternion = eco.skeleton.get_bone_pose_rotation(bust)
	var turned := rad_to_deg(q.angle_to(eco.skeleton.get_bone_rest(bust).basis.get_rotation_quaternion()))
	_check("and Eco's are pushed by her", turned > 4.0, turned)

	# a townsperson with the bones gets springs; one without doesn't
	var sk_with := (load("res://assets/models/npc/town_mira.glb") as PackedScene).instantiate()
	var sk_without := (load("res://assets/models/npc/town_bram.glb") as PackedScene).instantiate()
	root.add_child(sk_with)
	root.add_child(sk_without)
	var a = NpcSprings.make("town_mira", sk_with.find_child("Skeleton3D", true, false))
	var b = NpcSprings.make("town_bram", sk_without.find_child("Skeleton3D", true, false))
	_check("townsfolk with the bones get springs", a != null and b == null, [a, b])
	if a != null:
		a.free()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
