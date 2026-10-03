extends RefCounted
## Eco's gentler whispers, for when she's grown close to her mom (Motherly
## Love, scripts/hub/family.gd). eco_whispers.gd mixes them in with her usual
## lines: the softer she is (softness 0..1, her bond with Mom), the more often,
## up to MIX of the time, so she never stops being a brat entirely.
##
## Each line has the softness it needs: 1 from SOFTNESS[0] (warming up to
## Mom), 2 from SOFTNESS[1] (close), 3 from SOFTNESS[2] (mommy's girl). The
## gentleness goes outward too: she's kinder about the grunts she has to put
## down, and thinks of getting home to Mom. Clean language, so every rating
## can use them.

const MIX := 0.65
const SOFTNESS := [0.25, 0.5, 0.75]

const LINES := {
	"rumor_eco": [
		[1, "Say what you want. I've got somewhere warm to go home to."],
		[2, "You boys need a mom. Seriously. Somebody should feed you."],
		[3, "Mean little men. Mom would make you all sit down and eat soup."],
	],
	"stand_down": [
		[1, "Good. Go back to your fire. Stay warm."],
		[2, "That's it. Nobody else has to get hurt today."],
	],
	"man_down": [
		[2, "Somebody's waiting up for him too. ...Don't think about it."],
		[3, "Sorry. I didn't want that one."],
	],
	"kill": [
		[1, "Stay down. Please."],
		[1, "Shouldn't have come out here, sweetie."],
		[2, "Sorry. I mean it this time."],
		[2, "Quick. At least it was quick."],
		[3, "Go home, the rest of you. Please just go home."],
	],
	"headshot": [
		[1, "Clean. He didn't feel it."],
		[2, "Steady hands. Like Mom's when she sews."],
	],
	"takedown": [
		[1, "Shh. Sleep. You'll wake up with a headache, that's all."],
		[2, "Easy. Easy. Night night."],
		[3, "Sorry, buddy. Go home to your mom after this."],
	],
	"hurt": [
		[1, "Ow. Mom's gonna kill me."],
		[2, "Okay. Okay. Mom can stitch this. Keep going."],
		[3, "Mom. ...I'm okay. I'm okay. Coming home."],
	],
	"downed": [
		[1, "Up. Mom's waiting. Up."],
		[2, "Not today. I promised her. Not today."],
	],
	"quiet": [
		[1, "Mom packed me a sandwich. Cut in triangles. I'm twenty-something. ...It's good, though."],
		[1, "Is she awake right now? Probably. Listening to the band. Sorry, Mom."],
		[2, "Bring Mom a flower from out here. One that isn't trying to kill me."],
		[2, "Four notes. Hm-hm-hm-hmm. ...Okay. Okay, I can do this."],
		[2, "Ophelia should come to dinner. Mom would like that. I'd like that."],
		[3, "Love you, Mom. Don't make it a thing. ...Love you, Dad."],
		[3, "Soft hands, Dad. Mom says I got your hands. I'm being gentle with them."],
	],
	"zone_start": [
		[1, "In and out. Home for dinner."],
		[2, "Quiet feet. Nobody needs to get hurt who doesn't have to."],
		[3, "Promised Mom I'd come back. So I'm coming back."],
	],
	"part_installed": [
		[1, "There we go. Mom would call that tidy."],
		[2, "Gentle. Gentle. There. Good girl."],
	],
	"titanfall": [
		[2, "Watch over me, Dad. Mom's waiting up."],
	],
	"boss_down": [
		[2, "Down. Okay. Breathe. Going home."],
		[3, "Did it, Mom. I'm coming home."],
	],
	"home": [
		[1, "Home. Mom's light is on."],
		[2, "Hi, old god. Is Mom still up?"],
		[3, "Home. Quilt, soup, Mom. In that order. Okay, Mom first."],
	],
}


## The lines for `category` that fit `softness`, or [] below the first level.
static func fitting(category: String, softness: float) -> Array:
	var level := 0
	for i in SOFTNESS.size():
		if softness >= SOFTNESS[i]:
			level = i + 1
	var out := []
	for entry in LINES.get(category, []):
		if int(entry[0]) <= level:
			out.append(entry[1])
	return out
