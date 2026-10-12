extends RefCounted
## Eco's whispers, by situation. She can't key the colony net without giving
## herself away, so everything she'd love to say back to them she says under
## her breath, to herself, to her dead father, to the old god in her temple.
##
## Radio categories (rumor_eco, alerted, man_down, ...) are her reactions to
## the exchange that just went off the air (see radio_lines.gd). The rest are
## her own moments: kills, takedowns, getting hurt, quiet stretches, and the
## run's beats (new zone, a part fitted, titanfall, the boss down, home).
##
## The lines themselves live in dialogue/eco/M.txt (see
## dialogue_bank.gd and dialogue/README.md) so they can be edited as text.
##
## A line can start with "keyword|other words >": it is only said when the
## radio exchange she is answering mentions one of those words (whole words),
## and is preferred over the plain lines when it does. Plain lines fit any
## exchange.
##
## Voice (Bones, 2026-10-04): Eco is 21, bubbly and bratty, fierce when it
## counts, and grabs every moment of relief. She mocks, teases, gets the last
## word even when nobody can hear it, and is far too pleased with herself
## when she's good, which is often. Underneath it is grief for her father; it
## only slips out in the quiet lines, and she covers it fast. She swears.
## Nothing sexual, no slurs.

const DialogueBank := preload("res://scripts/radio/dialogue_bank.gd")


## The whisper bank: {category: [lines]}, read from dialogue/eco/M.txt.
static func bank() -> Dictionary:
	return DialogueBank.bank("eco")
