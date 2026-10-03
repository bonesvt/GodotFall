extends SkeletonModifier3D
## Runs eco_model.gd's `posing` inside the skeleton's own update, after her
## animation and before the mesh is skinned. Posing from _process instead
## only shows in Godot 4.7 if nothing re-poses her first, and her
## AnimationPlayer does every frame.

var model: Node


func _process_modification() -> void:
	if model != null and model.posing.is_valid():
		model.posing.call(model)
