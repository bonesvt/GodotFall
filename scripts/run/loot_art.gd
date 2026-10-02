extends RefCounted
## The loot models (assets/models/loot, made by tools/run/build_loot.py) with
## game materials swapped in by mesh name suffix, like the hub's props.

const Props := preload("res://scripts/hub/hub_props.gd")

const SCENES := {
	"supply_crate": preload("res://assets/models/loot/supply_crate.glb"),
	"alloy_node": preload("res://assets/models/loot/alloy_node.glb"),
	"scrap": preload("res://assets/models/loot/scrap_bundle.glb"),
	"alloy": preload("res://assets/models/loot/alloy_chunk.glb"),
	"circuits": preload("res://assets/models/loot/circuit_chip.glb"),
}
## Glow colour per material (pickups, labels, the HUD).
const COLORS := {"scrap": Color(1.0, 0.75, 0.35), "alloy": Color(0.45, 0.85, 1.0), "circuits": Color(0.45, 1.0, 0.5), "lock_cores": Color(1.0, 0.45, 0.7)}


static func model(id: String) -> Node3D:
	var node: Node3D = SCENES[id].instantiate()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("__")
		var kind := parts[1] if parts.size() > 1 else "gunmetal"
		mi.material_override = Props.material(kind)
	return node


## Finds the ground under `pos`: a ray down from above, ignoring `exclude`.
## Returns null over a drop (nothing above kill_y).
static func ground_under(world: World3D, pos: Vector3, kill_y: float, exclude: Array) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 12, 0), Vector3(pos.x, kill_y, pos.z))
	query.exclude = exclude
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.position.y < kill_y + 3.0:
		return null
	return hit.position
