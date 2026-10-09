extends RefCounted
## The shops of Solace that sell Eco something (town.gd puts them in the
## street; their screens are town_shop_screen.gd), what they sell, and what
## she has bought:
##   Seven Suns Noodles   a hot meal before a run: a boost for that one run
##   Mercy Clinic         implants: small boosts for good
##   Sal's Salvage        swaps one material for another
##   Ink & Iron           piercings and tattoos (eco_extras.gd puts them on her)
##   Stitch & Steel       accessories (eco_extras.gd), and a fitting room for her outfits
## Prices are in her materials (armory.gd). Everything is saved to save_path.
## The boosts ride on her suit's profile (armory.gd suit_profile, which
## player.gd apply_suit reads): boost() adds the meal waiting for the next run
## and every implant. The run manager eats the meal when a run ends.

const Armory := preload("res://scripts/hub/armory.gd")
const Extras := preload("res://scripts/hub/eco_extras.gd")

## Where purchases are saved.
static var save_path := "user://town.cfg"

## Meals: one at a time, for the next run only. `boost` keys are suit profile
## keys (multiplied in, or added for max_health_bonus and max_armor).
const MEALS := {
	"seven_suns": {"name": "Seven Suns bowl", "cost": {"scrap": 12},
		"blurb": "Hiro's house noodles, seven kinds of chilli. +25 max health for the next run.",
		"boost": {"max_health_bonus": 25.0}},
	"burnt_edges": {"name": "Burnt edges", "cost": {"scrap": 15},
		"blurb": "The crispy bits off the bottom of the pan, saved for her. Wallruns 25% longer, grapple back 20% sooner, next run.",
		"boost": {"wallrun_time_mult": 1.25, "grapple_cooldown_mult": 0.8}},
	"firecracker": {"name": "Firecracker skewers", "cost": {"scrap": 15},
		"blurb": "Glazed, blistered, eaten walking. 8% faster on foot for the next run.",
		"boost": {"speed_mult": 1.08}},
	"midnight_congee": {"name": "Midnight congee", "cost": {"scrap": 10, "alloy": 2},
		"blurb": "Slow rice and ginger. Calm stomach, calm hands. Grunts notice you 20% slower next run.",
		"boost": {"notice_mult": 0.8}},
	"sticky_parcels": {"name": "Sticky rice parcels", "cost": {"scrap": 14},
		"blurb": "Wrapped in leaves, three to a string. Health starts coming back 1 s sooner next run.",
		"boost": {"regen_delay_add": -1.0}},
	"firewater": {"name": "Hiro's firewater", "cost": {"scrap": 18},
		"blurb": "A shot of something Hiro brews behind the stall, and a bowl to soak it up. Guns hit 10% harder next run, but she's louder: grunts notice her 15% sooner.",
		"boost": {"damage_mult": 1.1, "notice_mult": 1.15}},
}

const IMPLANTS := {
	"dermal_mesh": {"name": "Dermal mesh", "cost": {"scrap": 90, "alloy": 25, "circuits": 2},
		"blurb": "A weave under the skin over her ribs. +15 max health, for good.", "boost": {"max_health_bonus": 15.0}},
	"reflex_lace": {"name": "Reflex lace", "cost": {"scrap": 110, "alloy": 30, "circuits": 3},
		"blurb": "Threads along the nerves in her legs. 5% faster on the ground, for good.", "boost": {"speed_mult": 1.05}},
	"quiet_heart": {"name": "Quiet heart", "cost": {"scrap": 100, "alloy": 25, "circuits": 3},
		"blurb": "A pacer that keeps her pulse low when it matters. Grunts notice you 10% slower, for good.", "boost": {"notice_mult": 0.9}},
	"lung_booster": {"name": "Lung booster", "cost": {"scrap": 120, "alloy": 35, "circuits": 4},
		"blurb": "More air, longer runs along the walls. Wallruns 15% longer, for good.", "boost": {"wallrun_time_mult": 1.15}},
	"med_pump": {"name": "Med pump", "cost": {"scrap": 140, "alloy": 40, "circuits": 5},
		"blurb": "A drip of sealant on a timer. Health starts coming back 0.5 s sooner, for good.", "boost": {"regen_delay_add": -0.5}},
}

## Sal's trades: what she gives, what she gets. As often as she likes.
const TRADES := {
	"scrap_alloy": {"name": "Scrap for alloy", "give": {"scrap": 40}, "get": {"alloy": 6},
		"blurb": "Sal melts it down himself. Don't ask what else goes in the pot."},
	"alloy_scrap": {"name": "Alloy for scrap", "give": {"alloy": 5}, "get": {"scrap": 25},
		"blurb": "He'll take good plate and give you a sack of bolts. Everybody wins but you."},
	"alloy_circuits": {"name": "Alloy for a circuit", "give": {"alloy": 15}, "get": {"circuits": 1},
		"blurb": "Colony boards, pulled from wrecks. Serial numbers sanded off."},
	"circuits_alloy": {"name": "A circuit for alloy", "give": {"circuits": 1}, "get": {"alloy": 10},
		"blurb": "He always needs boards. He never says what for."},
	"core_haul": {"name": "Lock core for a haul", "give": {"lock_cores": 1}, "get": {"scrap": 120, "alloy": 40, "circuits": 4},
		"blurb": "A titan lock core. Sal goes very quiet, then very generous."},
}

## Date spots (town.gd "date" spots, run_manager.gd date_at): where Eco can
## take whoever she's romancing once they're ready (romance.gd can_date), what
## she pays, and what the spot is called.
const DATES := {
	"cafe": {"name": "the Greenhouse Cafe", "cost": {"scrap": 10}},
	"arcade": {"name": "the Glowbox Arcade", "cost": {"scrap": 8}},
	"cinema": {"name": "the Holo-Cinema", "cost": {"scrap": 12}},
	"ice_cream": {"name": "Scoops", "cost": {"scrap": 5}},
	"garden": {"name": "the rooftop garden", "cost": {}},
	"noodles": {"name": "Seven Suns", "cost": {"scrap": 8}},
	"bar": {"name": "the Rusted Halo", "cost": {"scrap": 15}},
	"smoke": {"name": "the Halo's back step", "cost": {}},
}

## Ink & Iron's prices (what each looks like: eco_extras.gd).
const PIERCING_COST := {
	"lobes": {"scrap": 10}, "lobe_hoops": {"scrap": 15}, "helix": {"scrap": 20}, "nose_stud": {"scrap": 15},
	"septum": {"scrap": 20}, "brow": {"scrap": 20},
	"snakebites": {"scrap": 25}, "bridge": {"scrap": 25}, "navel": {"scrap": 20, "alloy": 2},
}
const TATTOO_COST := {
	"precursor": {"scrap": 45, "alloy": 8}, "cry_anyway": {"scrap": 40, "alloy": 5}, "fern_band": {"scrap": 60, "alloy": 12},
	"swallows": {"scrap": 45, "alloy": 6}, "sun_tree": {"scrap": 55, "alloy": 10}, "stars": {"scrap": 30, "alloy": 4},
	"heart_bolt": {"scrap": 40, "alloy": 6}, "wrench": {"scrap": 40, "alloy": 6},
	"tally": {"scrap": 35, "alloy": 4}, "lower_back": {"scrap": 65, "alloy": 12}, "hip_moth": {"scrap": 50, "alloy": 8},
	"thigh_snake": {"scrap": 60, "alloy": 10},
}
const ACCESSORY_COST := {
	"shades": {"scrap": 25}, "visor": {"scrap": 35, "alloy": 6}, "beanie": {"scrap": 20}, "bandana": {"scrap": 15},
	"choker": {"scrap": 20, "alloy": 3},
}

## What each kind of thing is called in the save file, and its catalogue.
const KINDS := ["piercings", "tattoos", "accessories", "implants"]


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	return cfg


static func _list(key: String) -> Array:
	return (_cfg().get_value("town", key, []) as Array).duplicate()


static func _set_list(key: String, list: Array) -> void:
	var cfg := _cfg()
	cfg.set_value("town", key, list)
	cfg.save(save_path)


## Ids she owns of a kind ("piercings", "tattoos", "accessories", "implants").
static func owned(kind: String) -> Array:
	return _list(kind)


static func owns(kind: String, id: String) -> bool:
	return owned(kind).has(id)


## The ones she has on (bought and not taken off).
static func worn_of(kind: String) -> Array:
	var off := _list(kind + "_off")
	return owned(kind).filter(func(id): return not off.has(id))


## Everything she has on, for eco_extras.gd.
static func worn() -> Dictionary:
	return {"piercings": worn_of("piercings"), "tattoos": worn_of("tattoos"), "accessories": worn_of("accessories")}


static func price(kind: String, id: String) -> Dictionary:
	match kind:
		"piercings":
			return PIERCING_COST.get(id, {})
		"tattoos":
			return TATTOO_COST.get(id, {})
		"accessories":
			return ACCESSORY_COST.get(id, {})
		"implants":
			return IMPLANTS.get(id, {}).get("cost", {})
		"meals":
			return MEALS.get(id, {}).get("cost", {})
	return {}


## Whether `id` of `kind` is on sale under the current content rating
## (Mature-only entries need Mature). Kinds as price(), plus "dates".
static func available(kind: String, id: String) -> bool:
	var entry: Dictionary = {}
	match kind:
		"piercings":
			entry = Extras.PIERCINGS.get(id, {})
		"tattoos":
			entry = Extras.TATTOOS.get(id, {})
		"accessories":
			entry = Extras.ACCESSORIES.get(id, {})
		"implants":
			entry = IMPLANTS.get(id, {})
		"meals":
			entry = MEALS.get(id, {})
		"dates":
			entry = DATES.get(id, {})
	return not entry.is_empty()


## Pays for something and keeps it (and puts it on). False if she owns it
## already or can't pay.
static func buy(armory: Armory, kind: String, id: String) -> bool:
	if owns(kind, id) or price(kind, id).is_empty() or not available(kind, id) or not armory._spend(price(kind, id)):
		return false
	armory.save()
	var list := owned(kind)
	list.append(id)
	_set_list(kind, list)
	if kind == "accessories":
		# one per slot: take off anything else in the same one
		var slot: String = Extras.ACCESSORIES[id]["slot"]
		for other in worn_of(kind):
			if other != id and Extras.ACCESSORIES[other]["slot"] == slot:
				set_worn(kind, other, false)
	return true


## The cheat box (cheat_screen.gd): she owns every piercing, tattoo and
## accessory, Mature ones included (they still only show under Mature). New
## ones go in the wardrobe taken off, so she isn't wearing everything at once.
## Returns how many were new.
static func unlock_all() -> int:
	var catalogs := {"piercings": Extras.PIERCINGS, "tattoos": Extras.TATTOOS, "accessories": Extras.ACCESSORIES}
	var added := 0
	for kind: String in catalogs:
		var list := owned(kind)
		var off := _list(kind + "_off")
		for id: String in catalogs[kind]:
			if not list.has(id):
				list.append(id)
				off.append(id)
				added += 1
		_set_list(kind, list)
		_set_list(kind + "_off", off)
	return added


## Puts something she owns on or takes it off (free).
static func set_worn(kind: String, id: String, on: bool) -> void:
	var off := _list(kind + "_off")
	off.erase(id)
	if not on:
		off.append(id)
	_set_list(kind + "_off", off)
	if on and kind == "accessories":
		var slot: String = Extras.ACCESSORIES[id]["slot"]
		for other in worn_of(kind):
			if other != id and Extras.ACCESSORIES[other]["slot"] == slot:
				set_worn(kind, other, false)


static func wearing(kind: String, id: String) -> bool:
	return worn_of(kind).has(id)


# --- meals ------------------------------------------------------------------------

## The meal she's eaten for the next run ("" for none).
static func meal() -> String:
	return String(_cfg().get_value("town", "meal", ""))


## Buys a meal for the next run (replacing one already eaten, which is wasted).
static func buy_meal(armory: Armory, id: String) -> bool:
	if not available("meals", id) or not armory._spend(MEALS[id]["cost"]):
		return false
	armory.save()
	var cfg := _cfg()
	cfg.set_value("town", "meal", id)
	cfg.save(save_path)
	return true


## The run that the meal was for is over.
static func finish_meal() -> void:
	var cfg := _cfg()
	if cfg.has_section_key("town", "meal"):
		cfg.erase_section_key("town", "meal")
		cfg.save(save_path)


# --- trades -----------------------------------------------------------------------

static func trade(armory: Armory, id: String) -> bool:
	if not TRADES.has(id) or not armory._spend(TRADES[id]["give"]):
		return false
	var got: Dictionary = TRADES[id]["get"]
	for m in got:
		armory.stash[m] = armory.amount(m) + int(got[m])   # not armory.bank(): a trade isn't salvage (lifetime totals)
	armory.save()
	return true


# --- boosts -----------------------------------------------------------------------

## Every boost she has now: the meal for the next run and her implants.
static func boosts() -> Array:
	var out := []
	var m := meal()
	if available("meals", m):
		out.append(MEALS[m]["boost"])
	for id in owned("implants"):
		if IMPLANTS.has(id):
			out.append(IMPLANTS[id]["boost"])
	return out


## Her suit's profile (armory.gd suit_profile) with the meal and implants on top.
static func boost(profile: Dictionary) -> Dictionary:
	var p := profile.duplicate()
	for b: Dictionary in boosts():
		for key in b:
			match key:
				"max_health_bonus":
					p[key] = float(p.get(key, 0.0)) + float(b[key])
				"regen_delay_add":
					p["regen_delay"] = maxf(float(p.get("regen_delay", 3.0)) + float(b[key]), 0.5)
				_:
					p[key] = float(p.get(key, 1.0)) * float(b[key])
	return p
