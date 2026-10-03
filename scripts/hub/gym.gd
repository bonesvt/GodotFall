extends RefCounted
## Biggie's gym, the room behind his den (hub_rooms.gd _gym): each piece of
## equipment is a workout that plays as a short scene (gym_workout.gd) and
## trains parts of Eco's body. What she has trained is saved with her armory
## (armory.gd fitness) and shapes her model (eco_model.gd set_fitness): the
## Fit_* blend shapes built by tools/eco/build_eco_vroid.py and the muscle tone
## painted into v_body_tone.png.
##
## Muscles grow while you rest: each workout can be done once per visit to
## the temple, and comes back after the next run. Mom or Ophelia can come and
## train beside her instead of Biggie (PARTNERS).

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
## Who Eco can invite to train with her ([T] by them in the hub; run_manager.gd
## invite_to_gym). Biggie leaves the gym to them. Their bodies train the same
## parts as hers (saved in armory.gd partner_fitness, shaped like hers by
## hub_npc.gd set_fitness). With Ophelia it's a date once she'll go on one.
const PARTNERS := ["mom", "ophelia"]
## What each says when Eco asks (Ophelia's date answer is her [date gym] in
## dialogue/npc/ophelia.txt).
const INVITE_LINES := {
	"mom": [["eco", "Want to work out with me, Mom?"], ["mom", "Oh! Let me find my good sneakers. Meet you in Biggie's gym, sweetheart."]],
	"ophelia": [["eco", "Work out with me? Biggie's gym. No Biggie."], ["ophelia", "...Fine. If anyone sees me sweat, I'll deny it."]],
}
## What they say together through each workout, one line per shot (in place
## of Biggie's coaching and Eco's last word): [speaker, text, moods].
## "ophelia_date" is Ophelia when the workout is a date.
const PARTNER_LINES := {
	"mom": {
		"squat": [["mom", "Knees out, sweetheart. Your father always forgot that."], ["eco", "Mom, you're out-squatting me."], ["mom", "Who do you think carried you up those stairs for six years?"]],
		"bridge": [["mom", "Squeeze, hold, breathe. Just like I taught you to stay calm."], ["eco", "You never taught me this."], ["mom", "I'm teaching you now. Hold it, Eco."]],
		"pullup": [["mom", "Slow down, you'll pull something. I'll get one... eventually."], ["eco", "Come on, Mom. One more."], ["mom", "There! Did you see that? Don't tell Biggie you helped."]],
		"crunch": [["mom", "Hands light behind your head. Don't strain your neck, baby."], ["eco", "Mom. Count, don't coach."], ["mom", "Twelve. Thirteen. You used to do these to get out of chores."]],
		"bag": [["mom", "I've got the bag. Elbows in. If anyone hurts you out there, you hit like that."], ["eco", "That's the plan."], ["mom", "Good. Now hug me before you go break something."]],
	},
	"ophelia": {
		"squat": [["ophelia", "I don't do mornings, or legs. This is both."], ["eco", "You're doing great."], ["ophelia", "I'm doing something. Don't make it weird."]],
		"bridge": [["ophelia", "Lying on a mat in the dark. Finally, a workout for me."], ["eco", "Hips up, Ophelia."], ["ophelia", "They're up. Spiritually."]],
		"pullup": [["ophelia", "Hanging from a bar like a bat. Respect."], ["eco", "Pull, don't dangle."], ["ophelia", "One. That's a personal record and a personal limit."]],
		"crunch": [["ophelia", "Every crunch is one less thing to feel."], ["eco", "That's... not how they work."], ["ophelia", "Twenty. Feeling nothing. It's working."]],
		"bag": [["ophelia", "Can I write a name on it first?"], ["eco", "Whose?"], ["ophelia", "Everyone's. Hit it. I've got it."]],
	},
	"ophelia_date": {
		"squat": [["ophelia", "I'm not looking at you. I'm looking at my form.", ["blush", "lookaway"]], ["eco", "Your form looks good too."], ["ophelia", "...Shut up. Again.", ["smile", "blush"]]],
		"bridge": [["ophelia", "Side by side on the mats. Very romantic. Very sweaty."], ["eco", "You came, though."], ["ophelia", "I came for you. The sandbag's a bonus.", ["blush", "smile"]]],
		"pullup": [["ophelia", "You make that look easy. It's annoying. It's also... a lot.", ["blush"]], ["eco", "Want a boost?"], ["ophelia", "Touch my waist and I'll fall off this bar.", ["fluster", "lookaway"]]],
		"crunch": [["ophelia", "Nobody's ever counted my reps before."], ["eco", "Eighteen. Nineteen. Twenty."], ["ophelia", "Twenty-one is for you. Don't tell anyone.", ["smile", "blush"]]],
		"bag": [["ophelia", "Remind me never to make you angry.", ["surprised"]], ["eco", "Hold it steady. Here comes the cross."], ["ophelia", "...I felt that in my teeth. This is a date. I'm on a gym date.", ["joy", "blush"]]],
	},
}

## Biggie, when she tries a workout she's already done this visit.
const RESTED_LINE := "You've done that one today. Muscle grows when you rest. Go break something out there and come back."
## What Eco says instead when she brought someone (Biggie isn't there).
const RESTED_PARTNER_LINE := "We've done that one today. Biggie says muscle grows when you rest."


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
