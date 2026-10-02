extends RefCounted
## Eco's whispers, by situation. She can't key the militia net without giving
## herself away, so everything she'd say back to them she says under her
## breath, to herself, to her dead father, to the old god in her temple.
##
## Radio categories (rumor_eco, alerted, man_down, ...) are her reactions to
## the exchange that just went off the air (see radio_lines.gd). The rest are
## her own moments: kills, takedowns, getting hurt, quiet stretches, and the
## run's beats (new zone, a part fitted, titanfall, the boss down, home).
##
## A line can start with "keyword|keyword>": it is only said when the radio
## exchange she is answering mentions one of those words, and is preferred
## over the plain lines when it does. Plain lines fit any exchange.
##
## Tone: rated M. Eco is young, angry, grieving and very good at this. She
## swears, she's cold to the men who laughed at her, and the quiet lines are
## where the grief leaks out. She never gloats about suffering; she finishes
## things. Nothing sexual, no slurs.

const LINES := {
	# --- Reactions to the militia net ---------------------------------------
	"rumor_eco": [
		"Keep talking. I know your voice now.",
		"...Breathe, Eco. They want you angry. Angry gets sloppy.",
		"Fuck you too.",
		"Can't answer. God, I wish I could. I'd love to hear him choke on it.",
		"That's the one who laughed loudest. I remember.",
		"Write that down. I'll read it at your funeral.",
		"goggles>Want my goggles? Come and take them.",
		"daddy|old man|father|atlas>Say his name again. Go on. Say it.",
		"burned>He didn't burn running. He burned holding the line you ran from.",
		" tent|recruit>Laughed me out of the tent. Let's see who's laughing at the end.",
		"poster>Poster girl. Sure. Wanted posters count.",
		"bitch|slut|skank>Bitch, huh? This bitch is on your channel, genius.",
		"motor pool>Motor pool. Right. Who do you think fixes your trucks?",
		"bounty>Bounty, huh. Hope it's enough to bury the lot of you.",
		"ear to ear>Ear to ear. Big talk from a guy who can't find me.",
		"cage>A cage for the parade. You'll need a bigger cage.",
		"hanging>Public hanging. Bring a lot of rope, boys. Bring one each.",
		"scope|staring| view>Look all you want. Last thing you'll see.",
		"pistol|lock>The lock's dead. I'm not. Ask your patrols.",
		"cried|funeral>I cried once. Then I picked up his gun.",
		"note|thanks for the parts>You're welcome, boys.",
		"patrols>That's what the patrols said. Before.",
		"titan>Out of your bones, if I have to.",
		"be won|stupid enough>Stupid enough to win it. Watch.",
	],
	"rumor_salvage": [
		"Thanks for the tip, boys.",
		"Broadcasting where the parts are. On an open net. Idiots.",
		"Mm. That's mine now.",
		"Keep talking about it. Tell me exactly where.",
		"Dad would've had that running in an hour. Give me two.",
	],
	"idle": [
		"Listen to them. Same as the recruiters. Just dirtier.",
		"mouth|deserter>One less mouth. Christ.",
		"You lot are scared too. You just hide it in each other.",
		"...Same war. Different side of the scope.",
	],
	"suspicious": [
		"Don't. Don't look over here.",
		"Stay low. Stay small.",
		"It's the wind, idiot. Just the wind.",
		"Easy... easy...",
		"Shit. Don't move. Don't breathe.",
	],
	"stand_down": [
		"That's right. Nothing here.",
		"Back to your rations.",
		"Good boy.",
		"...Okay. Okay. Still a ghost.",
	],
	"alerted": [
		"Shit. Made me.",
		"Okay. Plan B. There's always a plan B.",
		"Fine. We do it loud.",
		"Fuck. Move, Eco, move.",
		"Here they come.",
	],
	"lost": [
		"Lost me. Good. Breathe.",
		"Keep looking. I'm right here.",
		"Slow your heart. Slow.",
		"Ghost again.",
	],
	"man_down": [
		"That one was mine.",
		"One.",
		"He won't be answering.",
		"Count them, HQ. I am.",
	],
	"last_man": [
		"Just you now.",
		"Your friends left you. Mine did too. Funny how that goes.",
		"Run. Please run. ...No? Okay.",
	],
	"no_answer": [
		"Nobody's answering, HQ.",
		"Your squad's busy. For good.",
		"Quiet net. I like it quiet.",
	],

	# --- Her own moments -----------------------------------------------------
	"kill": [
		"Stay down.",
		"That's for the tent.",
		"Shouldn't have laughed.",
		"Lock's dead. Doesn't matter.",
		"Who needs auto-lock.",
		"Dad would've hated this. ...Dad would've done it anyway.",
		"Sorry. No. I'm not.",
		"Next.",
	],
	"headshot": [
		"Steady hands. Mechanic's hands.",
		"Square in the visor.",
		"Lock's fried. My aim isn't.",
		"Right between the eyes, Dad. Like you showed me.",
	],
	"takedown": [
		"Shh.",
		"Quiet now.",
		"Sleep.",
		"Don't tell your friends.",
		"Shh, shh. It's over.",
		"Never heard me. None of you ever did.",
	],
	"hurt": [
		"Not here. Not like this.",
		"Get up. Get up, Eco.",
		"Fuck, that hurts. Keep moving.",
		"Bleeding. Fine. Walk it off.",
		"Not yet, Dad. Not yet.",
	],
	"dry": [
		"Count your shots, idiot.",
		"Empty. Shit.",
		"Click. Great.",
	],
	"downed": [
		"Again.",
		"Okay. Okay. Again.",
		"...Still breathing. Still breathing.",
		"That one almost had me.",
	],
	"quiet": [
		"Miss you, Dad.",
		"Your titan's in pieces, Dad. I'll put it back together. Promise.",
		"Old god, if you're listening... no. Didn't think so.",
		"Cold out here.",
		"Hands are shaking. Mechanics' hands don't shake.",
		"Torque spec on an Atlas hip joint... four-forty. Still remember.",
		"Nobody's coming. That's fine. Nobody ever was.",
		"He used to hum while he welded. Can't remember the song anymore.",
		"Eat something later. Later. Sure.",
		"They're right about one thing. I'm not a Pilot. Not yet.",
		"Keep moving. Stop and you start thinking.",
		"Dad's gun. Dad's war. My problem now.",
	],
	"zone_start": [
		"New ground. Same assholes.",
		"Parts first. Revenge second. Okay. Mostly parts.",
		"Okay. Quiet feet.",
		"Smells like burn pits. They're close.",
		"Let's go shopping.",
	],
	"part_installed": [
		"That'll fit.",
		"Come on, baby. One more piece.",
		"Ugly weld. It'll hold. Probably.",
		"Dad would've yelled at that wiring.",
		"Getting there. Getting there.",
	],
	"titanfall": [
		"Here we go, Dad.",
		"Standby for titanfall. ...Always wanted to say that.",
		"Hold together. Please hold together.",
		"Okay. Okay. Breathe. You built this.",
	],
	"boss_down": [
		"Down. It's down.",
		"...Did you see that, Dad?",
		"Not a Pilot, huh.",
		"Tell the recruiters. Tell all of them.",
	],
	"home": [
		"Home. Such as it is.",
		"Evening, old god. Still here.",
		"Back in one piece. Most of the pieces.",
		"Strip the parts, wash the blood off, go again.",
	],
}


# --- Rating banks --------------------------------------------------------
# Same idea as radio_lines.gd: lower ratings get their own clean lines, not a
# censored M bank, and any category a bank leaves out stays quiet.

## T: mild swearing (damn, hell), grief and grit, no f-words.
const LINES_T := {
	"rumor_eco": [
		"Keep talking. I know your voice now.",
		"...Breathe, Eco. They want you angry. Angry gets sloppy.",
		"Write that down. I'll read it back to you.",
		"goggles>Want my goggles? Come and take them.",
		"old man|father|daddy|atlas>Say his name again. Go on.",
		" tent|recruit>Laughed me out of the tent. Let's see who's laughing at the end.",
		"poster>Poster girl. Sure. Wanted posters count.",
		"bounty>Bounty, huh. Come and collect.",
		"pistol|lock>The lock's dead. I'm not.",
		"note|thanks for the parts>You're welcome, boys.",
		"patrols>That's what the patrols said.",
		"titan>Watch me.",
	],
	"rumor_salvage": [
		"Thanks for the tip, boys.",
		"Broadcasting where the parts are. On an open net. Idiots.",
		"Mm. That's mine now.",
	],
	"idle": [
		"Listen to them. Same as the recruiters.",
		"You lot are scared too. You just hide it in each other.",
	],
	"suspicious": [
		"Don't. Don't look over here.",
		"Stay low. Stay small.",
		"It's the wind. Just the wind.",
		"Damn it. Don't move.",
	],
	"stand_down": [
		"That's right. Nothing here.",
		"Back to your rations.",
		"...Okay. Still a ghost.",
	],
	"alerted": [
		"Damn. Made me.",
		"Okay. Plan B. There's always a plan B.",
		"Fine. We do it loud.",
		"Move, Eco, move.",
	],
	"lost": [
		"Lost me. Good. Breathe.",
		"Keep looking. I'm right here.",
		"Ghost again.",
	],
	"man_down": [
		"That one was mine.",
		"One.",
		"Count them, HQ. I am.",
	],
	"last_man": [
		"Just you now.",
		"Your friends left you. Mine did too.",
	],
	"no_answer": [
		"Nobody's answering, HQ.",
		"Quiet net. I like it quiet.",
	],
	"kill": [
		"Stay down.",
		"That's for the tent.",
		"Shouldn't have laughed.",
		"Lock's dead. Doesn't matter.",
		"Next.",
	],
	"headshot": [
		"Steady hands. Mechanic's hands.",
		"Lock's fried. My aim isn't.",
	],
	"takedown": [
		"Shh.",
		"Quiet now.",
		"Never heard me.",
	],
	"hurt": [
		"Not here. Not like this.",
		"Get up. Get up, Eco.",
		"Hell, that hurts. Keep moving.",
		"Not yet, Dad. Not yet.",
	],
	"dry": [
		"Count your shots.",
		"Empty. Damn.",
	],
	"downed": [
		"Again.",
		"Okay. Okay. Again.",
		"...Still breathing.",
	],
	"quiet": [
		"Miss you, Dad.",
		"Your titan's in pieces, Dad. I'll put it back together. Promise.",
		"Old god, if you're listening... no. Didn't think so.",
		"Hands are shaking. Mechanics' hands don't shake.",
		"He used to hum while he welded. Can't remember the song anymore.",
		"Nobody's coming. That's fine.",
	],
	"zone_start": [
		"New ground. Same militia.",
		"Parts first. Okay. Quiet feet.",
		"Let's go shopping.",
	],
	"part_installed": [
		"That'll fit.",
		"Come on. One more piece.",
		"Ugly weld. It'll hold. Probably.",
	],
	"titanfall": [
		"Here we go, Dad.",
		"Standby for titanfall. ...Always wanted to say that.",
		"Hold together. Please hold together.",
	],
	"boss_down": [
		"Down. It's down.",
		"...Did you see that, Dad?",
		"Not a Pilot, huh.",
	],
	"home": [
		"Home. Such as it is.",
		"Evening, old god. Still here.",
		"Back in one piece. Most of the pieces.",
	],
}

## E: no swearing, no gore, no taunting the dead; determination and grief.
const LINES_E := {
	"rumor_eco": [
		"Keep talking. I'm listening.",
		"...Breathe, Eco. They want you angry.",
		" tent|recruit>Sent me home. We'll see.",
		"goggles>Want my goggles? Come and get them.",
		"note|thanks for the parts>You're welcome.",
		"titan>Watch me.",
		"junk>Junk to you. Titan parts to me.",
	],
	"rumor_salvage": [
		"Thanks for the tip.",
		"Broadcasting where the parts are. On an open net.",
	],
	"suspicious": [
		"Don't look over here.",
		"Stay low. Stay small.",
		"Just the wind. Just the wind.",
	],
	"stand_down": [
		"Nothing here.",
		"...Okay. Still hidden.",
	],
	"alerted": [
		"They saw me.",
		"Okay. Plan B.",
		"Move, Eco, move.",
	],
	"lost": [
		"Lost me. Good.",
		"Breathe. Slow.",
	],
	"man_down": [
		"One down.",
	],
	"last_man": [
		"Just you now.",
	],
	"no_answer": [
		"Quiet net.",
	],
	"kill": [
		"Stay down.",
		"Lock's dead. Doesn't matter.",
		"Next.",
	],
	"headshot": [
		"Steady hands.",
		"Lock's fried. My aim isn't.",
	],
	"takedown": [
		"Shh.",
		"Quiet now.",
	],
	"hurt": [
		"Not here. Not like this.",
		"Get up, Eco.",
		"Keep moving.",
	],
	"dry": [
		"Count your shots.",
		"Empty.",
	],
	"downed": [
		"Again.",
		"Okay. Again.",
	],
	"quiet": [
		"Miss you, Dad.",
		"Your titan's in pieces, Dad. I'll put it back together. Promise.",
		"He used to hum while he welded. Can't remember the song anymore.",
		"Keep moving.",
	],
	"zone_start": [
		"New ground. Quiet feet.",
		"Parts first.",
	],
	"part_installed": [
		"That'll fit.",
		"One more piece.",
	],
	"titanfall": [
		"Here we go, Dad.",
		"Standby for titanfall. ...Always wanted to say that.",
	],
	"boss_down": [
		"Down. It's down.",
		"...Did you see that, Dad?",
	],
	"home": [
		"Home. Such as it is.",
		"Back in one piece.",
	],
}


## The whisper bank for a content rating. AO shares M, as on the radio.
static func bank(rating: String) -> Dictionary:
	match rating:
		"E":
			return LINES_E
		"T":
			return LINES_T
	return LINES
