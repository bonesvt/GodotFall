extends RefCounted
## The air where Eco is: `wind` (world m/s) streams her hair and ripples her
## soft parts (eco_model.gd _weather). Each place sets its own when it's built
## (run_manager.gd): still indoors and in the hub, a breeze in the Deepwood,
## gusts over the Boneyard. Gusts come and go on top of it.

static var wind := Vector3.ZERO

## The wind for each zone kind (run_manager.gd: zone_info "wind" overrides).
const ZONES := {
	"forest": Vector3(1.5, 0, 0.8),
	"marsh": Vector3(-2.0, 0, 1.0),
	"boneyard": Vector3(5.0, 0, -2.5),
	"city": Vector3(2.5, 0, 2.0),
	"military": Vector3(3.5, 0, 0.0),
}
## A light breeze anywhere else outdoors.
const BREEZE := Vector3(1.2, 0, 0.6)


## The wind for a zone of `biome` (a ZONES key in its name, else a breeze).
static func for_biome(biome: String) -> Vector3:
	for key: String in ZONES:
		if key in biome:
			return ZONES[key]
	return BREEZE
