extends RefCounted
## The navmesh a generated zone bakes from its own colliders, so grunts (and
## anyone else walking the zone) can find their way round trees, cover,
## buildings and gullies: patrols walk their loops on it (grunt.gd `patrol`),
## and a patrol that loses sight of the pilot hunts toward where they were
## last seen along it. Baked on a thread once the zone is in the tree; until
## it's ready, walkers head straight for where they're going.

## Nodes in this group (and their children) are what the navmesh is baked from.
const GROUP := "nav_source"
## Recast's grid. The world's navigation map is set to match.
const CELL_SIZE := 0.3
const CELL_HEIGHT := 0.2


static func setup(root: Node3D, info: Dictionary) -> NavigationRegion3D:
	root.add_to_group(GROUP)
	var plan = info["plan"]
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = GROUP
	nm.cell_size = CELL_SIZE
	nm.cell_height = CELL_HEIGHT
	nm.agent_radius = 0.6
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 40.0
	# Only the valley floor, not the hills or the far trees.
	var w: float = plan.half_width(0.0) + 22.0
	nm.filter_baking_aabb = AABB(Vector3(-w, plan.floor_y - 2.0, plan.z_bottom), Vector3(w * 2.0, 60.0, plan.z_top - plan.z_bottom))
	var region := NavigationRegion3D.new()
	region.name = "Navmesh"
	region.navigation_mesh = nm
	root.add_child(region)
	info["nav_region"] = region
	if root.is_inside_tree():
		bake(region)
	else:
		root.tree_entered.connect(bake.bind(region), CONNECT_ONE_SHOT)
	return region


static func bake(region: NavigationRegion3D, threaded := true) -> void:
	var map := region.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
	# Roofs, decks and catwalks over the ground put edges close together; a
	# finer merge grid keeps them from being read as overlapping.
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, 0.25)
	region.bake_navigation_mesh(threaded)


## A path on the world's navmesh from `from` to `to`, or [] when there's no
## navmesh (yet) or no way there.
static func path(world: World3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := world.navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(map, from, to, true)
