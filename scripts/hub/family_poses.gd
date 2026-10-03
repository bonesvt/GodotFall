extends RefCounted
## Held poses for the Motherly Love scenes (family_scene.gd), for both Mom's
## model and Eco's: they share the VRoid rig (J_Bip_* bones, T-pose rest,
## facing -Z, her right +X). Mom's own model and animations belong to the hub
## NPC work; these poses ride on top as a SkeletonModifier3D, so nothing in
## her glb changes.
##
## A pose is a list of turns [bone, axis, degrees], applied in order from the
## rest pose, each about a skeleton-space axis through the bone's joint (like
## eco_model.gd _turn): RIGHT (+X) swings a hanging limb forward and leans the
## torso back, BACK (+Z) tips toward her left (+) or right (-), UP (+Y) turns
## her to her left (+). Bones not listed keep the rest pose; J_Sec_* (hair,
## jiggle) are left to their springs.

const R := Vector3.RIGHT
const B := Vector3.BACK
const U := Vector3.UP

## Sitting up in bed against the headboard, legs out under the quilt, her
## right arm around whoever sits on her right, left hand in her lap.
const MOM_CUDDLE := [
	["J_Bip_C_Hips", R, 14.0],
	["J_Bip_R_UpperLeg", R, 80.0], ["J_Bip_L_UpperLeg", R, 80.0],
	["J_Bip_R_LowerLeg", R, -8.0], ["J_Bip_L_LowerLeg", R, -8.0],
	["J_Bip_C_Spine", R, -6.0],
	["J_Bip_C_Neck", B, -6.0], ["J_Bip_C_Head", B, -12.0], ["J_Bip_C_Head", R, 6.0],
	["J_Bip_R_UpperArm", U, -30.0], ["J_Bip_R_UpperArm", B, -22.0],
	["J_Bip_R_LowerArm", U, 75.0],
	["J_Bip_L_UpperArm", B, 72.0], ["J_Bip_L_UpperArm", U, -18.0],
	["J_Bip_L_LowerArm", R, 60.0], ["J_Bip_L_LowerArm", U, -20.0],
]

## Curled into Mom on her left: leaning over, head on her shoulder, knees
## drawn up a little, hands together in her lap.
const ECO_CUDDLE := [
	["J_Bip_C_Hips", R, 14.0],
	["J_Bip_R_UpperLeg", R, 92.0], ["J_Bip_L_UpperLeg", R, 92.0],
	["J_Bip_R_LowerLeg", R, -30.0], ["J_Bip_L_LowerLeg", R, -30.0],
	["J_Bip_C_Spine", B, 14.0], ["J_Bip_C_Chest", B, 12.0],
	["J_Bip_C_Neck", B, 10.0], ["J_Bip_C_Head", B, 12.0], ["J_Bip_C_Head", R, 8.0],
	["J_Bip_R_UpperArm", B, -68.0], ["J_Bip_R_UpperArm", U, 22.0],
	["J_Bip_R_LowerArm", R, 65.0], ["J_Bip_R_LowerArm", U, 25.0],
	["J_Bip_L_UpperArm", B, 66.0], ["J_Bip_L_UpperArm", U, -25.0],
	["J_Bip_L_LowerArm", R, 65.0], ["J_Bip_L_LowerArm", U, -25.0],
]

## Lying on her back (the scene lays the whole model down), propped up on the
## pillows from the waist, arms at her sides, head turned a little to her
## right, toward Mom.
const ECO_SICK := [
	["J_Bip_C_Spine", R, -10.0], ["J_Bip_C_Chest", R, -9.0],
	["J_Bip_R_UpperArm", B, -78.0], ["J_Bip_L_UpperArm", B, 78.0],
	["J_Bip_R_LowerArm", R, 12.0], ["J_Bip_L_LowerArm", R, 12.0],
	["J_Bip_C_Head", U, -22.0], ["J_Bip_C_Head", R, -6.0],
]

## On a stool by the bed, leaning in, holding a bowl of soup in both hands.
const MOM_SICK := [
	["J_Bip_R_UpperLeg", R, 88.0], ["J_Bip_L_UpperLeg", R, 88.0],
	["J_Bip_R_LowerLeg", R, -88.0], ["J_Bip_L_LowerLeg", R, -88.0],
	["J_Bip_C_Spine", R, -12.0], ["J_Bip_C_Chest", R, -8.0],
	["J_Bip_C_Head", R, -10.0], ["J_Bip_C_Head", B, 6.0],
	["J_Bip_R_UpperArm", B, -72.0], ["J_Bip_R_UpperArm", R, 30.0],
	["J_Bip_R_LowerArm", R, 62.0], ["J_Bip_R_LowerArm", U, 30.0],
	["J_Bip_L_UpperArm", B, 72.0], ["J_Bip_L_UpperArm", R, 30.0],
	["J_Bip_L_LowerArm", R, 62.0], ["J_Bip_L_LowerArm", U, -30.0],
]

const POSES := {"mom_cuddle": MOM_CUDDLE, "eco_cuddle": ECO_CUDDLE, "eco_sick": ECO_SICK, "mom_sick": MOM_SICK}


## Puts `pose` on the skeleton under `model` and returns the modifier (free it
## to let go). It goes before any other modifier, so Mom's head gestures
## (hub_npc.gd HeadPose) still play over it.
static func hold(model: Node, pose: String) -> SkeletonModifier3D:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or not POSES.has(pose):
		return null
	var m := Hold.new()
	m.name = "FamilyPose"
	m.turns = POSES[pose]
	skel.add_child(m)
	skel.move_child(m, 0)
	return m


class Hold extends SkeletonModifier3D:
	var turns: Array = []
	## Called with the skeleton once the pose is on: the posed bones only read
	## back right then (the skeleton puts its pose back after each update), so
	## props that ride on the body place themselves here.
	var after: Callable

	func _process_modification() -> void:
		var skel := get_skeleton()
		if skel == null:
			return
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with("J_Bip_"):
				skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion())
				skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin)
		for t in turns:
			var i := skel.find_bone(t[0])
			if i < 0:
				continue
			var parent := skel.get_bone_parent(i)
			var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
			var before := skel.get_bone_pose_rotation(i)
			var turned := parent_basis.inverse() * Basis(t[1], deg_to_rad(t[2])) * parent_basis * Basis(before)
			skel.set_bone_pose_rotation(i, turned.get_rotation_quaternion())
		if after.is_valid():
			after.call(skel)
