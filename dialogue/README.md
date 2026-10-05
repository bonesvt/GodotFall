# Dialogue

Every line the colony grunts say on the radio and every line Eco whispers lives in these text files.
Change them, add to them or delete from them without touching any code.

| File | What it is |
| --- | --- |
| `radio/T.txt`, `radio/M.txt` | enemy radio chatter, Teen and Mature |
| `eco/T.txt`, `eco/M.txt` | Eco's whispers, Teen and Mature |
| `town/T.txt`, `town/M.txt` | the people of Solace, Teen and Mature |

In game, **Settings > Game > Dialogue rating** switches between Teen and Mature and re-reads these files, so you can
edit a file while the game is running and pick the rating again to hear the new lines.

## How a file is laid out

```
# Lines starting with # are notes. The game ignores them.

[kill]
Stay down, sweetie.
Next!

[rumor_eco]
Wow. Riveting. Tell me more.
goggles > My goggles? Ew. Get your own.
```

- `[kill]` starts a situation. Every line under it can play in that situation, picked at random,
  and every line plays once before any repeats.
- Blank lines don't matter. A situation with no lines left stays silent at that rating.
- The situation names are fixed (the game looks them up by name); the lists below have them all.
  A misspelled name never plays, and `tests/whisper_test.gd` catches that for T.

### Radio lines

One exchange per line. Speakers are split by ` | `, each written `role: text`:

```
a: Caught another deserter by the river. | b: And? | a: And now he's digging latrines.
```

- `a` is the grunt the event is about (or any grunt nearby), `b` and `c` are other grunts nearby,
  `hq` is colony command. An exchange with `b` or `c` only plays when that many grunts are in earshot.
- `{a}` `{b}` `{c}` become those grunts' callsigns, `{dead}` the grunt who just died, `{part}` a
  random titan part name.

Radio situations: `idle`, `rumor_eco`, `rumor_salvage`, `suspicious`, `stand_down`, `alerted`,
`combat`, `pilot_moving`, `hurt`, `man_down`, `last_man`, `lost`, `no_answer`, and `prisoner`
(calm chatter about the girl in the holding block, only in Level 2 until she's out).

### Eco's lines

One whisper per line. A line can answer something specific the radio said:

```
goggles > My goggles? Ew. Get your own.
old man|father|atlas > Say his name again. I dare you.
```

Words before `>` (split by `|`) are whole words or phrases. When the exchange she's answering
mentions one, that line is picked over the plain ones; otherwise it never plays there.

Eco situations:
- answering the radio: `rumor_eco`, `rumor_salvage`, `prisoner`, `idle`, `suspicious`, `stand_down`, `alerted`,
  `lost`, `man_down`, `last_man`, `no_answer`
- her own moments: `kill`, `headshot`, `takedown`, `hurt`, `dry` (mag empty), `downed`, `quiet`
- the run: `zone_start`, `part_installed`, `titanfall`, `boss_down`, `home`

Recorded voice lines go in `assets/audio/voice/eco/<situation>_<n>.ogg`, where `n` counts the
situation's lines in `eco/M.txt` from 0, so re-record if you reorder them.

### Town lines

The people of Solace (scripts/hub/townsfolk.gd) talk among themselves and to Eco as she walks
through town. Lines are written like radio lines (`a: ... | b: ...`), and the number on each
situation is how suspicious the town has got:

- `1`: her first two runs. They believe her mom's excuses (mostly).
- `2`: runs three to five. They've noticed the grease, the rivets, the lights at the temple.
- `3`: after that. They're sure, and they're covering for her.

Situations: `chat_1` `chat_2` `chat_3` (two people, `a` and `b`, where Eco can overhear),
`mutter_1` `mutter_2` `mutter_3` (someone passing, `a` only), `greet_1` `greet_2` `greet_3`
(a word for Eco as she walks by, `a` only). A stage with no lines falls back to the one before.
`tests/townsfolk_test.gd` checks every situation has lines at both ratings.

## Exporting the game

Godot only packs `.txt` files into an export if you ask: in the export preset, under
**Resources > Filters to export non-resource files/folders**, add `dialogue/*`.
