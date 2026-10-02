extends RefCounted
## Militia radio chatter, by situation. Eco listens; she never talks back.
##
## Each entry is one exchange: lines split by " | ", each "role: text".
## Roles: a = the grunt the event is about (or any nearby grunt), b and c =
## other nearby grunts, hq = militia command (always reachable).
## Placeholders: {a} {b} {c} callsigns, {dead} the grunt who just died,
## {part} a random titan part name.
##
## Tone: the militia are smug blowhards who laughed Eco out of the
## recruiting tent. Keep it PG-13 banter.

const LINES := {
	# Unaware, nothing going on.
	"idle": [
		"a: Who's got the deck of cards? | b: You lost the deck, {a}. In the river. | a: I lent it to the river.",
		"a: Anyone else's boots squeak? | b: Only yours, champ.",
		"a: Sarge says if we hold this ridge till Friday we get medals. | b: You already have four medals. | a: Five. One's a bottle cap, but nobody checks.",
		"a: Rate my mustache. | b: Two out of ten. | a: Out of ten?! | b: I rounded up.",
		"a: Ration bar today is 'beef flavour'. | b: Flavoured like what the beef thinks of us.",
		"a: I could've been a Pilot, you know. | b: You get winded on stairs. | a: Titans have elevators.",
		"hq: Militia net, radio check. | a: {a}, loud and handsome. | b: {b}, louder and handsomer.",
		"a: Bet you a week of latrine duty I hit that can from here. | b: You missed the last one by a whole hill.",
		"a: Saw a bird out there bigger than a Titan. | b: That was a Titan, {a}.",
		"a: Quiet out here. | b: Don't say that. That's how it starts in the movies. | a: Movies aren't real. | b: Neither is your rank.",
		"a: How's the arm, {b}? | b: Still sore from carrying this whole squad.",
		"hq: Inspection at oh-six-hundred. Polish something. | a: Copy, HQ. Polishing my attitude.",
		"a: Who keeps leaving cigar butts in the water can? | b: Not me. | a: You're smoking one right now.",
		"a: My helmet's too big. | b: Your head's too small. | a: Thanks, {b}.",
		"a: Talking to myself again. Great conversationalist. Great listener.",
		"hq: Patrol, sitrep. | a: Bored, HQ. Extremely bored. | hq: Bored is good. | a: Not for me it isn't.",
		"a: When I make sergeant, first thing I do is ban mornings. | b: When you make sergeant, I'm deserting.",
	],
	# Gossip about Eco, not knowing she's listening.
	"rumor_eco": [
		"a: You hear the scrapper girl's still out here? | b: The one they laughed out of the recruiting tent? | a: That's her. Says she's gonna build a Titan. | b: Out of what, kitchen spoons?",
		"a: Heard the Pilot reject's picking through our junk piles. | b: Good. Saves us hauling it.",
		"hq: All units, civilian scavenger reported in sector. Female, white hair. | a: The mechanic? She's harmless, HQ. | hq: Command doesn't care. Report sightings.",
		"a: Didn't her old man fly an Atlas? | b: Yeah, and look where that got him. | a: She thinks she's next in line. | b: Line for what, the scrapyard?",
		"a: Recruiter said she aced the sim. | b: Sim's for show. Cockpits are for real soldiers. | a: Real soldiers like you, who failed it twice? | b: The sim was rigged.",
		"a: If that little grease monkey shows up, I'm keeping her goggles as a souvenir. | b: You'd have to catch her first. | a: How hard can it be?",
		"a: Word is she's got her daddy's smart pistol. | b: A smart pistol with no smarts. Fitting. | a: Huh? | b: Keep up, {a}.",
		"a: Bet she cries if she breaks a nail. | b: Didn't she rebuild a Titan reactor by hand? | a: ...Bet she cries a little.",
		"a: Why'd they even let her apply? | b: Poster thing. Smile for the camera, go home. | a: Instead she went feral. | b: Sweetheart couldn't take a no.",
		"a: If she ever gets a Titan running, who's fighting it? | b: ... | a: {b}? | b: Bad connection. Can't hear you.",
		"a: Little Miss Pilot left a note on the supply crate. | b: What'd it say? | a: 'Thanks for the parts, boys.' With a smiley face. | b: Burn it.",
		"a: Recruiter asked if she could even lift a Titan battery. | b: And? | a: She lifted his desk. With him on it.",
	],
	# Salvage and titan part rumours.
	"rumor_salvage": [
		"hq: Be advised, salvage crate with a {part} in your sector. Guard it. | a: Guard a box. Living the dream.",
		"a: What's in the crates anyway? | b: Titan bits. Someone said a {part}. | a: We should sell it. | b: To who, the scavenger? Ha!",
		"a: Brass wants every Titan scrap locked down. | b: Afraid someone's gonna build one? | a: Afraid someone builds one better than ours.",
		"a: I sat in a Titan once. | b: The museum one doesn't count. | a: It had a {part}! | b: It had a gift shop.",
		"a: That wreck over the hill still has its core humming. | b: Leave it. Last guy who poked it lost his eyebrows.",
		"hq: Recovery team is delayed. Hold the salvage. | a: How delayed? | hq: Yes.",
		"a: Somebody left a {part} out in the open. | b: Not my problem. Not my paperwork.",
	],
	# Heard or glimpsed something.
	"suspicious": [
		"a: Hold up. Something moved. | b: It's the wind, {a}. | a: The wind doesn't wear boots.",
		"a: You hear that? | b: I hear you breathing through your mouth again.",
		"a: {b}, did you just throw a rock? | b: Why would I throw a rock? | a: ...Okay, now I'm nervous.",
		"a: Saw a flash on the ridge. | hq: Investigate and report. | a: Investigating. Slowly. Very professionally.",
		"a: Something's off. | b: Your aim. Always has been.",
		"a: Hello? ...I'm armed. Very armed.",
		"a: Eyes up. Could be the scavenger. | b: Here, kitty kitty.",
		"a: Movement, my sector. | b: Want backup? | a: I want you to go look, and I'll be the backup.",
	],
	# Suspicious grunt gives up.
	"stand_down": [
		"a: Nothing there. | b: Told you. Rats. | a: Big rats.",
		"a: False alarm. | hq: Noted. Again. | a: That's harsh, HQ.",
		"a: Must've been a bird. | b: That's six birds today, {a}.",
		"a: All clear. Probably. | b: Probably's my favourite kind of clear.",
		"a: Lost it. Going back to my post. | b: Your post missed you.",
		"a: Nothing. Probably that scavenger's pet rat. | hq: She doesn't have a pet rat. | a: Then whose rat is it?",
		"a: Clear. I'm not scared. I was never scared.",
	],
	# First contact.
	"alerted": [
		"a: Contact! It's the scavenger! | b: The reject? Here? | a: Shoot her!",
		"a: Eyes on her! White hair, bad attitude! | hq: Engage!",
		"a: It's the mechanic girl! | b: Let's show her why she didn't make the cut!",
		"a: Hostile! It's that Pilot wannabe! | b: Light her up, boys!",
		"a: There she is! Sweetheart, you lost? | b: Less talking, more shooting, {a}!",
		"hq: Hostile in your grid! | a: Copy! It's just the girl! | hq: Then this'll be quick.",
		"a: She's here! Wake up, {b}! | b: I was resting my eyes! | a: Rest them on her!",
	],
	# Mid fight.
	"combat": [
		"a: Hold still, sweetheart! | b: She's not gonna hold still, {a}.",
		"a: Go home and fix a toaster! | b: She can't hear you. | a: She can feel my disapproval.",
		"a: Flank her! | b: Which way's flank? | a: The other way!",
		"a: Somebody hit her already! | b: I'm trying! She keeps moving!",
		"a: Reloading! Cover me! | b: Cover yourself, I'm busy!",
		"a: You're no Pilot, kid! | b: Then why are we losing? | a: Shut up, {b}!",
		"hq: Status report! | a: Uh, winning? | b: Define winning.",
		"a: Push her back! | b: You push her back! | a: I outrank you! | b: You outrank nobody!",
		"a: She's just one girl! | b: Say it louder, maybe it'll help!",
	],
	# Eco is wallrunning, sliding or in the air while they're fighting her.
	"pilot_moving": [
		"a: She's on the walls! How is she on the walls?! | b: Shoot the walls!",
		"a: She's moving like a Pilot! | b: She's NOT a Pilot! | a: Tell her that!",
		"a: I can't hit her when she does that! | b: Lead your shots! | a: Lead them where?!",
		"a: Was that a double jump?! | b: Who gave her a jump kit?!",
		"a: Stop bouncing, it's not fair! | b: War's not fair, {a}!",
		"a: She's sliding under everything! | b: Aim low! | a: I'm aiming everywhere!",
	],
	# A grunt shot Eco.
	"hurt": [
		"a: Got a piece of her! | b: Nice! Do it again!",
		"a: Tagged her! | b: Don't get cocky.",
		"a: Ha! That's gotta sting!",
		"a: Hit her! She's slowing down! | b: She's really not.",
		"a: Hit confirmed! Who's laughing now?",
	],
	# One of them went down; spoken by survivors.
	"man_down": [
		"a: {dead}'s down! | b: Forget him, shoot her!",
		"a: She got {dead}! | b: Dang it, he owed me money!",
		"a: Man down! Man down! | hq: Hold your position! | a: Holding! Panicking a little, but holding!",
		"a: {dead}! Talk to me! | b: He's not talking, {a}. | a: This is bad.",
		"a: Okay, she's better than the recruiters said. | b: Don't you dare tell HQ that.",
		"a: We lost {dead}! | b: Lucky him. Now he doesn't have to listen to you.",
	],
	# Only one grunt left nearby.
	"last_man": [
		"a: HQ, it's just me left! Requesting backup! | hq: Negative. Hold the line. | a: Hold it with WHAT?!",
		"a: Guys? ...Guys? | hq: Report, {a}. | a: Squad's, uh, taking a nap.",
		"a: Okay lady, I take it back! The thing I said at recruitment! | a: All of it!",
		"a: HQ, I'd like to file a complaint. | hq: About what? | a: Everything!",
		"a: I'm not scared! I'm tactically sweating!",
		"a: This wasn't in the brochure! | hq: Stay calm, soldier. | a: You stay calm!",
	],
	# They lost track of her.
	"lost": [
		"a: Lost her! | b: How do you lose a whole person? | a: She's small!",
		"a: Where'd she go? | hq: Find her. | a: Working on it!",
		"a: No visual. She ran off. | b: Good riddance. | a: She'll be back. They always come back.",
		"a: She bugged out! Knew she didn't have it in her!",
		"a: She's gone. | b: Gone gone, or hiding gone? | a: ...Yes.",
	],
	# Everyone nearby is dead; command calls into silence.
	"no_answer": [
		"hq: Squad, report. | hq: Squad? ...Squad, respond.",
		"hq: Patrol, you've gone quiet. Check in. | hq: ...Somebody check in.",
		"hq: Militia net, any station on this channel. | hq: ...HQ out.",
	],
}

## Callsign stems handed out to grunts, plus a squad number.
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
