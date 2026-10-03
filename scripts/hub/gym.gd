extends RefCounted
## Biggie's gym, the room behind his den (hub_rooms.gd _gym): each piece of
## equipment is a workout that plays as a short scene (gym_workout.gd) and
## trains parts of Eco's body. What she has trained is saved with her armory
## (armory.gd fitness) and shapes her model (eco_model.gd set_fitness): the
## Fit_* blend shapes built by tools/eco/build_eco_vroid.py and the muscle tone
## painted into v_body_tone.png.
##
## Muscles grow while you rest: each workout can be done once per visit to
## the temple, and comes back after the next run.

## What can be trained, and the most points each can hold (a fully trained body).
const PARTS := ["stomach", "abs", "arms", "legs", "glutes"]
const MAX_POINTS := 100
const NAMES := {"stomach": "STOMACH", "abs": "ABS", "arms": "ARMS", "legs": "LEGS", "glutes": "GLUTES"}

## The equipment: what it's called, the prompt, and the points one session
## gives each part it trains.
const WORKOUTS := {
	"squat": {"name": "Barbell squats", "gains": {"glutes": 8, "legs": 8}},
	"bridge": {"name": "Hip thrusts", "gains": {"glutes": 10, "stomach": 3}},
	"pullup": {"name": "Pull-ups", "gains": {"arms": 9, "abs": 4}},
	"crunch": {"name": "Crunches", "gains": {"abs": 9, "stomach": 6}},
	"bag": {"name": "Heavy bag", "gains": {"stomach": 6, "arms": 5, "legs": 4}},
}

## Biggie, coaching from the doorway while she works. One line per shot.
const COACHING := {
	"squat": ["Sit back like there's a chair. Chest up.", "Drive through the heels, kid.", "That's depth. Your dad never went that low."],
	"bridge": ["Feet flat. Squeeze at the top.", "Hold it. Hold it. Good.", "Hips like you're lifting a titan off you."],
	"pullup": ["Dead hang first. No kicking.", "Chin over the bar or it doesn't count.", "Slow on the way down. That's where it grows."],
	"crunch": ["Hands light. Don't yank your neck.", "Breathe out on the way up.", "Tight. Like a grunt's about to step on your belly."],
	"bag": ["Jab, jab, cross. Keep your guard up.", "Turn the hip into it.", "That bag owes you money. Collect."],
}
## What Eco says as she finishes, per workout.
const DONE_LINES := {
	"squat": "Legs are jelly. Worth it.",
	"bridge": "Okay. That burns in places I didn't know I had.",
	"pullup": "Dad could do thirty. I'll get there.",
	"crunch": "Abs of a scavenger. Earned, not issued.",
	"bag": "Pretend it's the recruiting officer. Every time.",
}
## Biggie, when she tries a workout she's already done this visit.
const RESTED_LINE := "You've done that one today. Muscle grows when you rest. Go break something out there and come back."


## A fresh body: nothing trained yet.
static func fresh() -> Dictionary:
	var f := {}
	for part in PARTS:
		f[part] = 0
	return f


## Adds one session of `workout` to `fitness` (capped at MAX_POINTS) and
## returns what it actually gave each part.
static func train(fitness: Dictionary, workout: String) -> Dictionary:
	var got := {}
	var gains: Dictionary = WORKOUTS.get(workout, {}).get("gains", {})
	for part: String in gains:
		var before: int = int(fitness.get(part, 0))
		var after := mini(before + int(gains[part]), MAX_POINTS)
		fitness[part] = after
		if after > before:
			got[part] = after - before
	return got


## How trained each part is, 0..1 (what eco_model.gd set_fitness takes).
static func amounts(fitness: Dictionary) -> Dictionary:
	var a := {}
	for part in PARTS:
		a[part] = clampf(float(fitness.get(part, 0)) / MAX_POINTS, 0.0, 1.0)
	return a


## "+8 GLUTES  +8 LEGS", for the toast after a workout.
static func gains_text(got: Dictionary) -> String:
	if got.is_empty():
		return "Already in peak shape."
	var bits := []
	for part in PARTS:
		if got.has(part):
			bits.append("+%d %s" % [got[part], NAMES[part]])
	return "  ".join(bits)


## The chalkboard on the gym wall: one row per part, a tally out of ten.
static func board_text(fitness: Dictionary) -> String:
	var rows := ["BIGGIE'S BOARD"]
	for part in PARTS:
		var p: int = int(fitness.get(part, 0))
		var marks := int(round(float(p) / MAX_POINTS * 10.0))
		rows.append("%-8s %s%s" % [NAMES[part], "#".repeat(marks), ".".repeat(10 - marks)])
	return "\n".join(rows)
