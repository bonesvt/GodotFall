extends RefCounted
## Eco's whispers, by situation. She can't key the militia net without giving
## herself away, so everything she'd love to say back to them she says under
## her breath, to herself, to her dead father, to the old god in her temple.
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
## Voice (Bones, 2026-10-02): Eco is bratty and sassy. She mocks, teases,
## rolls her eyes, gets the last word even when nobody can hear it, and is
## far too pleased with herself when she's good, which is often. Underneath
## it is grief for her father; it only slips out in the quiet lines, and she
## covers it fast. Rated M: she swears. Nothing sexual, no slurs.

const LINES := {
	# --- Reactions to the militia net ---------------------------------------
	"rumor_eco": [
		"Aww. Talk about me some more, boys. I'm blushing.",
		"Wow. Riveting. Tell me more.",
		"Fuck you too, sweetie.",
		"So brave. Saying that on a radio. Miles away. Wow.",
		"You know I can hear you, right? ...No? Cute.",
		"Mm-hm. And yet I'm the one with your frequency.",
		"Big words for a guy who can't find me.",
		"Write that down. I'll read it at your funeral. With feeling.",
		"goggles>My goggles? Ew. Get your own.",
		"daddy|old man|father|atlas>Say his name again. I dare you. Go on.",
		"burned>Keep my dad's name out of your mouth, you smelly little man.",
		" tent|recruit>Laughed me out of the tent. Cute. Who's laughing now?",
		"poster>Poster girl? Wanted poster, babe. Get it right.",
		"bitch|slut|skank>Bitch? Bitch is on your channel, genius.",
		"motor pool>Motor pool. Who do you think fixes your crappy trucks?",
		"bounty>Only that much? Rude. I'm worth way more.",
		"ear to ear>Ear to ear. Big talk. Tiny aim.",
		"cage>A cage? For me? You shouldn't have. Seriously, don't.",
		"hanging>Public hanging. You'd need to catch me first, slowpoke.",
		"scope|staring| view>Enjoying the view? It's the last one you get.",
		"pistol|lock>Broken pistol, broken patrols. Funny how that works.",
		"cried|funeral>I'll cry at yours too. Laughing, but still.",
		"note|thanks for the parts>You're welcome. Leave more next time.",
		"patrols>Yep. That was me. You're welcome.",
		"titan>Out of your scrap, dummy. Thanks for donating.",
		"be won|stupid enough>Stupid enough to win it. Watch me.",
	],
	"rumor_salvage": [
		"Ooh. Thanks for the tip, boys.",
		"Broadcasting where the parts are. On an open net. Adorable.",
		"Mine now. Finders keepers.",
		"Keep talking. Tell me exactly where. Good boys.",
		"Dad would've had that running in an hour. I'll do it in forty minutes.",
	],
	"idle": [
		"Wow. Riveting stuff, boys.",
		"mouth|deserter>One less mouth. Christ, you people.",
		"And they said I wasn't militia material. Thank god.",
		"Do you ever talk about anything else? Besides me. Obviously.",
	],
	"suspicious": [
		"Nope. Nothing here. Keep walking.",
		"Don't you dare look over here.",
		"It's the wind, genius. Just the wind.",
		"Shh. Shh shh shh.",
		"Ugh. Of course he heard that.",
	],
	"stand_down": [
		"Good boy. Back to your rations.",
		"Wow. Elite soldiers, every one of you.",
		"Told you. Nothing here.",
		"Still a ghost. Obviously.",
	],
	"alerted": [
		"Oh, NOW you see me.",
		"Ugh. Fine. We do it loud.",
		"Shit. Okay. Hi, boys.",
		"Took you long enough.",
		"Rude. I was being sneaky.",
	],
	"lost": [
		"Lost me? Aww. Poor baby.",
		"Marco... Polo. Ha.",
		"Keep looking. I'm right here, dummy.",
		"And she's gone. Again. Wow.",
	],
	"man_down": [
		"Oops.",
		"One down. Who's next? Don't all volunteer at once.",
		"He's not answering. Rude, right?",
		"Count them, HQ. I'm winning.",
	],
	"last_man": [
		"Just you and me now. Cozy.",
		"Your friends ditched you. Mine did too. We should hang out. Briefly.",
		"Run. Please run. It's funnier.",
	],
	"no_answer": [
		"Nobody's answering, HQ. Weird, huh?",
		"Your squad's busy. Forever.",
		"Quiet net. Finally. My ears thank me.",
	],

	# --- Her own moments -----------------------------------------------------
	"kill": [
		"Stay down, sweetie.",
		"That's for the tent.",
		"Shouldn't have laughed.",
		"Auto-lock? Who needs it.",
		"Too easy. Seriously. Try harder.",
		"Bye-bye.",
		"Oops. Was that your friend?",
		"Next!",
	],
	"headshot": [
		"Headshot. With a broken gun. Yeah, I'm that good.",
		"Square in the visor. Did you see that? Nobody saw that. Ugh.",
		"Lock's fried. My aim isn't.",
		"Like you showed me, Dad. Only better.",
	],
	"takedown": [
		"Shh. Nap time.",
		"Night night.",
		"Boo.",
		"Don't tell your friends.",
		"Shh. Grown-ups are working.",
		"Never heard me. Never do.",
	],
	"hurt": [
		"Ow! Okay. Rude.",
		"Not like this. Not in this outfit.",
		"Fuck, that stings. I'm fine. I'm fine!",
		"Bleeding. Great. Love that for me.",
		"Get up, Eco. You're too pretty to die here.",
	],
	"dry": [
		"Click? Oh, come on.",
		"Empty. Shit. Who's counting? Not me, apparently.",
		"Count your shots, Eco. Ugh.",
	],
	"downed": [
		"Ow. Okay. That didn't count.",
		"Again. And this time, no peeking.",
		"Still breathing. Suck it.",
		"That one almost had me. Almost.",
	],
	"quiet": [
		"Miss you, Dad. Don't make it weird.",
		"Your titan's in pieces, Dad. I'll put it back together. Prettier, too.",
		"Old god, if you're listening... a little help? No? Typical man.",
		"Cold out here. Should've packed a jacket. Too late, looking this good.",
		"Hands are shaking. Mechanics' hands don't shake. Stop it, hands.",
		"Torque spec on an Atlas hip joint... four-forty. Still remember. Nerd.",
		"Nobody's coming. Fine. Didn't want company anyway.",
		"He used to hum while he welded. Terribly. ...I'd give anything to hear it.",
		"Eat something later. Later. Sure.",
		"Not a Pilot, they said. Okay. Watch me.",
		"Keep moving. Stop and you start thinking. Gross.",
		"Dad's gun. Dad's war. My problem now. Lucky me.",
	],
	"zone_start": [
		"New ground. Same idiots.",
		"Parts first. Revenge second. Okay, maybe tied.",
		"Okay. Quiet feet. Cute and quiet.",
		"Smells like burn pits and bad decisions. They're close.",
		"Let's go shopping.",
	],
	"part_installed": [
		"Ooh. That'll fit.",
		"Come on, baby. One more piece.",
		"Ugly weld. Gorgeous mechanic. Evens out.",
		"Dad would've yelled at that wiring. Love you too, Dad.",
		"Getting there. She's gonna be so pretty.",
	],
	"titanfall": [
		"Here we go, Dad. Watch this.",
		"Standby for titanfall. ...God, I've always wanted to say that.",
		"Hold together, baby. Please hold together.",
		"Okay. Breathe. You built this. You're amazing.",
	],
	"boss_down": [
		"Down. It's DOWN. Ha!",
		"...Did you see that, Dad? Tell me you saw that.",
		"Not a Pilot, huh? Say it again. I'll wait.",
		"Somebody tell the recruiters. Actually, I'll tell them.",
	],
	"home": [
		"Home sweet temple.",
		"Evening, old god. Miss me?",
		"Back in one piece. Mostly. Okay, a lot of pieces.",
		"Strip the parts, wash the blood off, go again. Glamorous.",
	],
}


# --- Rating banks --------------------------------------------------------
# Same idea as radio_lines.gd: lower ratings get their own clean lines, not a
# censored M bank, and any category a bank leaves out stays quiet.

## T: mild swearing (damn, hell), sass and grief, no f-words.
const LINES_T := {
	"rumor_eco": [
		"Aww. Talk about me some more, boys. I'm blushing.",
		"Wow. Riveting. Tell me more.",
		"You know I can hear you, right? ...No? Cute.",
		"Big words for a guy who can't find me.",
		"goggles>My goggles? Ew. Get your own.",
		"old man|father|daddy|atlas>Say his name again. I dare you.",
		" tent|recruit>Laughed me out of the tent. Cute. Who's laughing now?",
		"poster>Poster girl? Wanted poster, babe. Get it right.",
		"bounty>Only that much? Rude. I'm worth way more.",
		"pistol|lock>Broken pistol, broken patrols. Funny how that works.",
		"note|thanks for the parts>You're welcome. Leave more next time.",
		"patrols>Yep. That was me.",
		"titan>Out of your scrap, dummy. Thanks for donating.",
	],
	"rumor_salvage": [
		"Ooh. Thanks for the tip, boys.",
		"Broadcasting where the parts are. On an open net. Adorable.",
		"Mine now. Finders keepers.",
	],
	"idle": [
		"Wow. Riveting stuff, boys.",
		"Do you ever talk about anything else? Besides me. Obviously.",
	],
	"suspicious": [
		"Nope. Nothing here. Keep walking.",
		"Don't you dare look over here.",
		"It's the wind, genius.",
		"Damn it. Of course he heard that.",
	],
	"stand_down": [
		"Good boy. Back to your rations.",
		"Told you. Nothing here.",
		"Still a ghost. Obviously.",
	],
	"alerted": [
		"Oh, NOW you see me.",
		"Ugh. Fine. We do it loud.",
		"Damn. Okay. Hi, boys.",
		"Rude. I was being sneaky.",
	],
	"lost": [
		"Lost me? Aww. Poor baby.",
		"Marco... Polo. Ha.",
		"Keep looking. I'm right here, dummy.",
	],
	"man_down": [
		"Oops.",
		"One down. Who's next?",
		"Count them, HQ. I'm winning.",
	],
	"last_man": [
		"Just you and me now. Cozy.",
		"Run. Please run. It's funnier.",
	],
	"no_answer": [
		"Nobody's answering, HQ. Weird, huh?",
		"Quiet net. Finally.",
	],
	"kill": [
		"Stay down, sweetie.",
		"That's for the tent.",
		"Auto-lock? Who needs it.",
		"Too easy.",
		"Next!",
	],
	"headshot": [
		"Headshot. With a broken gun. Yeah, I'm that good.",
		"Lock's fried. My aim isn't.",
	],
	"takedown": [
		"Shh. Nap time.",
		"Night night.",
		"Boo.",
	],
	"hurt": [
		"Ow! Okay. Rude.",
		"Hell, that stings. I'm fine. I'm fine!",
		"Get up, Eco. You're too pretty to die here.",
		"Bleeding. Great. Love that for me.",
	],
	"dry": [
		"Click? Oh, come on.",
		"Empty. Damn.",
	],
	"downed": [
		"Ow. Okay. That didn't count.",
		"Again. And this time, no peeking.",
		"Still breathing. Ha.",
	],
	"quiet": [
		"Miss you, Dad. Don't make it weird.",
		"Your titan's in pieces, Dad. I'll put it back together. Prettier, too.",
		"Old god, if you're listening... a little help? No? Typical.",
		"Hands are shaking. Stop it, hands.",
		"He used to hum while he welded. Terribly. ...I'd give anything to hear it.",
		"Nobody's coming. Fine. Didn't want company anyway.",
	],
	"zone_start": [
		"New ground. Same idiots.",
		"Okay. Quiet feet. Cute and quiet.",
		"Let's go shopping.",
	],
	"part_installed": [
		"Ooh. That'll fit.",
		"Come on, baby. One more piece.",
		"Ugly weld. Gorgeous mechanic. Evens out.",
	],
	"titanfall": [
		"Here we go, Dad. Watch this.",
		"Standby for titanfall. ...I've always wanted to say that.",
		"Hold together, baby. Please hold together.",
	],
	"boss_down": [
		"Down. It's DOWN. Ha!",
		"...Did you see that, Dad? Tell me you saw that.",
		"Not a Pilot, huh? Say it again. I'll wait.",
	],
	"home": [
		"Home sweet temple.",
		"Evening, old god. Miss me?",
		"Back in one piece. Mostly.",
	],
}

## E: no swearing, no gore, no taunting the dead; cheek and determination.
const LINES_E := {
	"rumor_eco": [
		"Aww. Talk about me some more. I'm blushing.",
		"You know I can hear you, right? Cute.",
		" tent|recruit>Sent me home? Cute. Watch me now.",
		"goggles>My goggles? Ew. Get your own.",
		"note|thanks for the parts>You're welcome. Leave more next time.",
		"titan>Watch me.",
		"junk>Junk to you. Titan parts to me.",
	],
	"rumor_salvage": [
		"Ooh. Thanks for the tip.",
		"Finders keepers.",
	],
	"suspicious": [
		"Nope. Nothing here.",
		"Don't you dare look over here.",
		"It's the wind, genius.",
	],
	"stand_down": [
		"Told you. Nothing here.",
		"Still sneaky. Obviously.",
	],
	"alerted": [
		"Oh, NOW you see me.",
		"Rude. I was being sneaky.",
		"Okay. Plan B.",
	],
	"lost": [
		"Lost me? Aww.",
		"Marco... Polo.",
	],
	"man_down": [
		"Oops.",
	],
	"last_man": [
		"Just you and me now.",
	],
	"no_answer": [
		"Quiet net. Finally.",
	],
	"kill": [
		"Stay down.",
		"Auto-lock? Who needs it.",
		"Next!",
	],
	"headshot": [
		"With a broken gun, too.",
		"Lock's fried. My aim isn't.",
	],
	"takedown": [
		"Shh. Nap time.",
		"Boo.",
	],
	"hurt": [
		"Ow! Rude.",
		"Get up, Eco.",
		"I'm fine. I'm fine!",
	],
	"dry": [
		"Click? Oh, come on.",
		"Empty. Ugh.",
	],
	"downed": [
		"That didn't count.",
		"Again. No peeking.",
	],
	"quiet": [
		"Miss you, Dad. Don't make it weird.",
		"Your titan's in pieces, Dad. I'll put it back together. Prettier, too.",
		"He used to hum while he welded. Terribly. ...I miss it.",
		"Nobody's coming. Fine. Didn't want company anyway.",
	],
	"zone_start": [
		"New ground. Quiet feet.",
		"Let's go shopping.",
	],
	"part_installed": [
		"Ooh. That'll fit.",
		"One more piece.",
	],
	"titanfall": [
		"Here we go, Dad. Watch this.",
		"Standby for titanfall. ...I've always wanted to say that.",
	],
	"boss_down": [
		"Down. It's DOWN. Ha!",
		"...Did you see that, Dad?",
	],
	"home": [
		"Home sweet temple.",
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
