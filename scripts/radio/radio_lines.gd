extends RefCounted
## Militia radio chatter, by situation. Eco listens; she never talks back.
## The lines themselves live in dialogue/radio/<rating>.txt (see
## dialogue_bank.gd and dialogue/README.md) so they can be edited as text.
##
## Each entry is one exchange: lines split by " | ", each "role: text".
## Roles: a = the grunt the event is about (or any nearby grunt), b and c =
## other nearby grunts, hq = militia command (always reachable).
## Placeholders: {a} {b} {c} callsigns, {dead} the grunt who just died,
## {part} a random titan part name.
##
## Tone: rated M. The militia are cruel, contemptuous bullies in a war that
## made them worse. They laughed Eco out of the recruiting tent for being a
## woman, mock her dead father, and want her dead. Profanity and violent
## threats are fine, and so is crude leering and gendered insults (bitch,
## skank, slut, sparingly). Never sexual violence or assault threats, nothing
## explicit, no c-word, no real-world hate slurs.

const DialogueBank := preload("res://scripts/radio/dialogue_bank.gd")

const CALLSIGNS := [
	"BRASS", "HOUND", "MOOSE", "TANK", "DUKE", "BUTCH", "ROCCO", "SPUD",
	"BULLDOG", "CHUCK", "MAC", "KNUCKLES", "BIG RED", "SLAB", "GRIZZ", "TOAD",
]
const HQ_CALLSIGN := "MILITIA HQ"


## Parses one entry into [[role, text], ...].
static func parse(entry: String) -> Array:
	var out := []
	for part in entry.split(" | "):
		var colon := part.find(": ")
		out.append([part.substr(0, colon), part.substr(colon + 2)])
	return out


## The grunt roles an entry needs (a, b, c), not counting hq.
static func roles(entry: String) -> Array:
	var out := []
	for line in parse(entry):
		if line[0] != "hq" and not out.has(line[0]):
			out.append(line[0])
	for tag in ["{b}", "{c}"]:
		var role: String = tag.substr(1, 1)
		if entry.contains(tag) and not out.has(role):
			out.append(role)
	return out


# --- Rating banks --------------------------------------------------------
# Teen and Mature each get their own file rather than a censored M bank, so
# every category still has full exchanges.

const RATINGS := ["T", "M"]
const RATING_NAMES := {"T": "T (Teen)", "M": "M (Mature 17+)"}


## The line bank for a content rating: {category: [entries]}, read from
## dialogue/radio/<rating>.txt.
static func bank(rating: String) -> Dictionary:
	return DialogueBank.bank("radio", rating)
