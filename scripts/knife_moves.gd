extends RefCounted
## Each knife's own moves for scripts/knife.gd: how she holds it, how she
## draws it, her two alternating attacks, the takedown thrust and the inspect.
##
##   needle     elegant and precise: held like a foil; a finger-roll draw off
##              the ring pommel, fast straight thrusts, and an inspect that
##              spins it round her finger through the ring.
##   kunai      guerrilla: held in reverse grip, point down along her forearm;
##              it flips from forward to reverse on the draw, rips in hooking
##              and hammer slashes, and twirls round her finger in its ring.
##   butterfly  flashy: comes out closed and flips open (the bite handle
##              rolls out, then the safe handle), quick snappy wrist flicks,
##              and an inspect of rollovers and an aerial (tossed closed,
##              caught and flipped open again).
##
## An animation is {length, hand, blade, pivot, handles, trail, events}:
##   hand     [time, position, rotation] keys for her hand, relative to the
##            camera; "base" in a key is the pose she's holding (ready, or
##            tucked away for a quick strike from the hip).
##   blade    [time, offset, rotation] keys for the knife in her fingers,
##            turning about `pivot` (in hand space: the ring she spins it on,
##            the Butterfly's pivot pins).
##   handles  Butterfly only: [time, Vector3(safe, bite, 0), _] keys, how far
##            each handle has swung away from the tang (0 shut as the grip,
##            PI folded over the blade: a closed balisong).
##   trail    [from, to]: seconds the tip leaves a light trail.
##   events   [time, kind, arg]: "sound" (an SFX name), "glint" (a glint
##            running up the edge), "star" (a sparkle at the tip).
## Attacks all land at knife.gd hit_time (0.09 s) and last stab_time (0.42 s),
## so every knife fights the same; only the moves differ.

## Tucked out of sight at her hip.
const REST := Vector3(-0.34, -0.46, -0.12)
const REST_ROT := Vector3(0.9, 0.5, 0.6)
const HIT := 0.09
const END := 0.42

const STYLES := ["needle", "kunai", "butterfly"]


static func moves(style: String) -> Dictionary:
	match style:
		"kunai":
			return _kunai()
		"butterfly":
			return _butterfly()
	return _needle()


# --- Needle ----------------------------------------------------------------------

static func _needle() -> Dictionary:
	var ready := Vector3(-0.2, -0.24, -0.34)
	var ready_rot := Vector3(0.3, -0.75, -0.7)
	var ring := Vector3(0, 0, 0.09)  # the ring pommel, in her hand
	var show := Vector3(-0.08, -0.12, -0.32)
	var show_rot := Vector3(0.1, -0.2, -1.45)  # blade across the view, edge up
	var spin := Vector3(-0.1, -0.15, -0.36)
	var spin_rot := Vector3(1.2, -0.35, -0.2)  # palm up, the ring on her finger
	return {
		"ready": [ready, ready_rot],
		"grip": Vector3.ZERO,
		"lines": [
			"Balanced it twelve times. Thirteen's the charm.",
			"Needle-thin. It goes where the armour isn't.",
			"Dad said never bring a knife to a gunfight. I bring both.",
			"The ring's for spinning. And for looking cool. Mostly spinning.",
		],
		"anims": {
			# Up from the hip on her finger through the ring: it rolls once
			# round the finger and drops into her fist.
			"draw": {"length": 0.55, "pivot": ring,
				"hand": [
					[0.0, REST, REST_ROT],
					[0.18, ready + Vector3(0.02, 0.07, 0.02), ready_rot + Vector3(-0.3, 0.15, 0.25)],
					[0.42, ready + Vector3(0.0, -0.01, 0.0), ready_rot + Vector3(0.06, 0.0, -0.04)],
					[0.55, "base", "base"],
				],
				"blade": [
					[0.0, Vector3.ZERO, Vector3(-TAU * 1.25, 0, 0)],
					[0.38, Vector3.ZERO, Vector3(0.1, 0, 0)],
					[0.55, Vector3.ZERO, Vector3.ZERO],
				],
				"events": [[0.0, "sound", "knife_draw"], [0.12, "sound", "knife_spin"], [0.38, "star", null]],
			},
			# A fencer's lunge: straight down the crosshair, a twist on the way in.
			"attack_a": {"length": END, "trail": [0.02, HIT + 0.08],
				"hand": [
					[0.0, ready + Vector3(0.02, -0.02, 0.08), ready_rot + Vector3(0.1, 0.1, 0.0)],
					[HIT, Vector3(-0.12, -0.16, -0.46), Vector3(0.1, -0.5, -0.3)],
					[HIT + 0.07, Vector3(-0.11, -0.16, -0.49), Vector3(0.1, -0.5, -0.3)],
					[END, "base", "base"],
				],
				"blade": [[0.0, Vector3.ZERO, Vector3.ZERO], [HIT, Vector3.ZERO, Vector3(0, 0, 0.9)], [END, Vector3.ZERO, Vector3.ZERO]],
			},
			# A rising thrust from low, under the ribs.
			"attack_b": {"length": END, "trail": [0.02, HIT + 0.08],
				"hand": [
					[0.0, ready + Vector3(0.03, -0.1, 0.05), ready_rot + Vector3(-0.3, 0.0, 0.1)],
					[HIT, Vector3(-0.09, -0.12, -0.44), Vector3(0.32, -0.45, -0.55)],
					[HIT + 0.07, Vector3(-0.08, -0.1, -0.47), Vector3(0.34, -0.45, -0.55)],
					[END, "base", "base"],
				],
				"blade": [[0.0, Vector3.ZERO, Vector3.ZERO], [HIT, Vector3.ZERO, Vector3(0, 0, -0.9)], [END, Vector3.ZERO, Vector3.ZERO]],
			},
			"thrust": {"length": END, "trail": [0.02, HIT + 0.1],
				"hand": [
					[0.0, "base", "base"],
					[HIT, Vector3(-0.14, -0.17, -0.4), Vector3(0.12, -0.55, -0.35)],
					[HIT + 0.08, Vector3(-0.14, -0.17, -0.42), Vector3(0.12, -0.55, -0.35)],
					[END, "base", "base"],
				],
			},
			# Edge to the light, then round and round her finger by the ring.
			"inspect": {"length": 2.8, "pivot": ring,
				"hand": [
					[0.0, "base", "base"],
					[0.35, show, show_rot],
					[0.75, show + Vector3(0.01, 0.005, 0.0), show_rot + Vector3(0.0, 0.08, 0.0)],
					[0.95, spin, spin_rot],
					[1.95, spin + Vector3(0.0, 0.01, 0.0), spin_rot],
					[2.25, ready + Vector3(0.02, 0.02, 0.0), ready_rot],
					[2.8, "base", "base"],
				],
				"blade": [
					[0.0, Vector3.ZERO, Vector3.ZERO],
					[0.95, Vector3.ZERO, Vector3.ZERO],
					[1.9, Vector3.ZERO, Vector3(0, -TAU * 3.0, 0)],
					[2.8, Vector3.ZERO, Vector3(0, -TAU * 3.0, 0)],
				],
				"events": [[0.4, "glint", null], [0.95, "sound", "knife_spin"], [1.35, "sound", "knife_spin"],
						[1.9, "sound", "knife_catch"], [1.9, "star", null]],
			},
		},
	}


# --- Plate Kunai -------------------------------------------------------------------

static func _kunai() -> Dictionary:
	var ready := Vector3(-0.19, -0.11, -0.38)
	var ready_rot := Vector3(0.95, -0.4, 0.3)
	# Reverse grip: the blade out of the bottom of her fist, the ring over her thumb.
	var grip := Vector3(-PI / 2.0, 0, 0)
	var ring := Vector3(0, 0.087, 0)
	var show := Vector3(-0.06, -0.12, -0.33)
	var show_rot := Vector3(0.15, -0.25, 1.45)
	var twirl := Vector3(-0.12, -0.12, -0.38)
	var twirl_rot := Vector3(0.1, -0.35, 0.0)
	return {
		"ready": [ready, ready_rot],
		"grip": grip,
		"lines": [
			"Colony armour plate. They should've made it thicker.",
			"The trace still lights up. I like to think it's angry.",
			"Ground the edge on Dad's old wheel. Took a week.",
			"Paracord. Holds a grip, a splint, a snare. Whatever I need.",
		],
		"anims": {
			# Out point-first, flipped over her knuckles into reverse grip.
			"draw": {"length": 0.5, "pivot": Vector3.ZERO,
				"hand": [
					[0.0, REST, REST_ROT],
					[0.2, ready + Vector3(0.06, 0.1, 0.04), ready_rot + Vector3(-0.5, 0.3, 0.3)],
					[0.38, ready + Vector3(0.0, -0.02, 0.0), ready_rot + Vector3(0.1, 0.0, -0.05)],
					[0.5, "base", "base"],
				],
				"blade": [
					[0.0, Vector3.ZERO, Vector3(PI, 0, 0)],
					[0.16, Vector3(0, 0.03, 0), Vector3(PI * 0.6, 0, 0)],
					[0.3, Vector3.ZERO, Vector3(-0.15, 0, 0)],
					[0.5, Vector3.ZERO, Vector3.ZERO],
				],
				"events": [[0.0, "sound", "knife_draw"], [0.3, "sound", "knife_catch"], [0.32, "star", null]],
			},
			# A backhand hook: across from her left, the edge dragging through.
			"attack_a": {"length": END, "trail": [0.02, HIT + 0.1],
				"hand": [
					[0.0, Vector3(-0.36, -0.1, -0.26), Vector3(0.7, 0.9, 0.5)],
					[HIT, Vector3(-0.06, -0.14, -0.45), Vector3(0.75, -0.05, 0.35)],
					[HIT + 0.09, Vector3(0.18, -0.2, -0.32), Vector3(0.7, -1.0, 0.2)],
					[END, "base", "base"],
				],
			},
			# A hammer strike: from up by her ear, point driving down and in.
			"attack_b": {"length": END, "trail": [0.02, HIT + 0.1],
				"hand": [
					[0.0, Vector3(-0.14, 0.04, -0.28), Vector3(-0.2, -0.35, 0.3)],
					[HIT, Vector3(-0.07, -0.16, -0.45), Vector3(1.0, -0.3, 0.25)],
					[HIT + 0.09, Vector3(-0.12, -0.3, -0.34), Vector3(1.45, -0.3, 0.2)],
					[END, "base", "base"],
				],
			},
			# The takedown: down hard behind the collar.
			"thrust": {"length": END, "trail": [0.02, HIT + 0.1],
				"hand": [
					[0.0, Vector3(-0.12, 0.06, -0.3), Vector3(-0.3, -0.3, 0.3)],
					[HIT, Vector3(-0.08, -0.15, -0.44), Vector3(1.1, -0.3, 0.25)],
					[HIT + 0.08, Vector3(-0.08, -0.19, -0.44), Vector3(1.2, -0.3, 0.25)],
					[END, "base", "base"],
				],
			},
			# Shows the trace, then twirls it round her finger in its ring and
			# snaps it back into reverse grip.
			"inspect": {"length": 2.7, "pivot": ring,
				"hand": [
					[0.0, "base", "base"],
					[0.35, show, show_rot],
					[0.8, show + Vector3(0.01, 0.0, 0.0), show_rot + Vector3(0.0, 0.1, 0.0)],
					[1.0, twirl, twirl_rot],
					[2.0, twirl + Vector3(0.0, 0.01, 0.0), twirl_rot],
					[2.25, ready + Vector3(0.02, 0.02, 0.0), ready_rot],
					[2.7, "base", "base"],
				],
				"blade": [
					[0.0, Vector3.ZERO, Vector3.ZERO],
					[1.0, Vector3.ZERO, Vector3.ZERO],
					[1.95, Vector3.ZERO, Vector3(0, 0, TAU * 3.0)],
					[2.7, Vector3.ZERO, Vector3(0, 0, TAU * 3.0)],
				],
				"events": [[0.4, "glint", null], [1.0, "sound", "knife_spin"], [1.4, "sound", "knife_spin"],
						[1.95, "sound", "knife_catch"], [1.95, "star", null]],
			},
		},
	}


# --- Butterfly ----------------------------------------------------------------------

static func _butterfly() -> Dictionary:
	var ready := Vector3(-0.2, -0.23, -0.34)
	var ready_rot := Vector3(0.25, -0.7, -0.9)
	var pins := Vector3(0, 0, -0.078)  # the pivot pins, in her hand
	var closed := Vector3(0, 0, 0.078)  # shifts a closed knife so the pins sit in her fingers
	var show := Vector3(-0.08, -0.12, -0.32)
	var show_rot := Vector3(0.1, -0.2, -1.45)
	var shut := Vector3(PI, PI, 0)
	var open := Vector3.ZERO
	return {
		"ready": [ready, ready_rot],
		"grip": Vector3.ZERO,
		"lines": [
			"Took me a month to stop cutting myself. Worth it.",
			"Click-clack. They never hear the second click.",
			"Flipping it helps me think. Thinking's overrated.",
			"Cyan inlays. Matches the pistol. Priorities.",
		],
		"anims": {
			# Comes out closed; the bite handle rolls out round her fingers,
			# the blade swings up, the safe handle slaps shut on it.
			"draw": {"length": 0.65, "pivot": pins,
				"hand": [
					[0.0, REST, REST_ROT],
					[0.16, ready + Vector3(0.03, 0.05, 0.03), ready_rot + Vector3(-0.3, 0.2, 0.4)],
					[0.34, ready + Vector3(0.0, 0.03, 0.0), ready_rot + Vector3(0.0, 0.0, -0.4)],
					[0.5, ready + Vector3(0.0, -0.01, 0.0), ready_rot + Vector3(0.05, 0.0, 0.05)],
					[0.65, "base", "base"],
				],
				"blade": [
					[0.0, closed, Vector3.ZERO],
					[0.14, closed, Vector3.ZERO],
					[0.42, Vector3.ZERO, Vector3(0, PI * 2.0, 0)],
					[0.65, Vector3.ZERO, Vector3(0, PI * 2.0, 0)],
				],
				"handles": [
					[0.0, shut, Vector3.ZERO],
					[0.14, shut, Vector3.ZERO],
					[0.28, Vector3(PI, 0, 0), Vector3.ZERO],
					[0.42, Vector3(0.5, 0, 0), Vector3.ZERO],
					[0.48, open, Vector3.ZERO],
					[0.65, open, Vector3.ZERO],
				],
				"events": [[0.0, "sound", "knife_draw"], [0.14, "sound", "knife_spin"], [0.3, "sound", "knife_catch"],
						[0.48, "sound", "knife_catch"], [0.5, "star", null]],
			},
			# Quick wrist flicks, forehand then backhand, the bite handle
			# kicking loose on the snap.
			"attack_a": {"length": END, "trail": [0.01, HIT + 0.06],
				"hand": [
					[0.0, Vector3(0.0, -0.17, -0.36), Vector3(0.2, -1.25, -1.1)],
					[HIT, Vector3(-0.12, -0.16, -0.43), Vector3(0.1, -0.2, -1.1)],
					[HIT + 0.06, Vector3(-0.24, -0.19, -0.37), Vector3(0.1, 0.6, -1.1)],
					[END, "base", "base"],
				],
				"handles": [[0.0, open, Vector3.ZERO], [HIT + 0.03, Vector3(0, 0.45, 0), Vector3.ZERO], [0.26, open, Vector3.ZERO]],
			},
			"attack_b": {"length": END, "trail": [0.01, HIT + 0.06],
				"hand": [
					[0.0, Vector3(-0.3, -0.18, -0.33), Vector3(0.15, 0.7, -0.75)],
					[HIT, Vector3(-0.1, -0.14, -0.43), Vector3(0.1, -0.25, -0.75)],
					[HIT + 0.06, Vector3(0.04, -0.17, -0.38), Vector3(0.15, -1.15, -0.75)],
					[END, "base", "base"],
				],
				"handles": [[0.0, open, Vector3.ZERO], [HIT + 0.03, Vector3(0.45, 0, 0), Vector3.ZERO], [0.26, open, Vector3.ZERO]],
			},
			"thrust": {"length": END, "trail": [0.02, HIT + 0.1],
				"hand": [
					[0.0, "base", "base"],
					[HIT, Vector3(-0.13, -0.16, -0.42), Vector3(0.1, -0.5, -0.6)],
					[HIT + 0.08, Vector3(-0.13, -0.16, -0.44), Vector3(0.1, -0.5, -0.6)],
					[END, "base", "base"],
				],
			},
			# Edge to the light, two rollovers (the bite handle swinging over
			# her knuckles), then an aerial: tossed, it folds shut spinning,
			# she catches it closed and flips it open again.
			"inspect": {"length": 3.0, "pivot": pins,
				"hand": [
					[0.0, "base", "base"],
					[0.35, show, show_rot],
					[0.5, show, show_rot + Vector3(0.0, 0.06, 0.0)],
					[0.7, show + Vector3(0.0, 0.01, 0.0), show_rot + Vector3(0.0, 0.0, 0.9)],
					[0.9, show, show_rot],
					[1.1, show + Vector3(0.0, 0.01, 0.0), show_rot + Vector3(0.0, 0.0, 0.9)],
					[1.3, ready + Vector3(0.02, 0.0, 0.0), ready_rot],
					[1.45, ready + Vector3(0.0, -0.05, 0.0), ready_rot + Vector3(0.25, 0.0, 0.0)],
					[2.1, ready + Vector3(0.0, 0.0, 0.0), ready_rot],
					[2.5, ready + Vector3(0.0, 0.01, 0.0), ready_rot + Vector3(0.0, 0.0, -0.3)],
					[3.0, "base", "base"],
				],
				"blade": [
					[0.0, Vector3.ZERO, Vector3.ZERO],
					[1.45, Vector3.ZERO, Vector3.ZERO],
					[1.8, Vector3(0, 0.2, -0.02), Vector3(-TAU * 1.5, 0, 0)],
					[2.1, closed, Vector3(-TAU * 2.0, 0, 0)],
					[2.2, closed, Vector3(-TAU * 2.0, 0, 0)],
					[2.45, Vector3.ZERO, Vector3(-TAU * 2.0, PI * 2.0, 0)],
					[3.0, Vector3.ZERO, Vector3(-TAU * 2.0, PI * 2.0, 0)],
				],
				"handles": [
					[0.0, open, Vector3.ZERO],
					[0.5, open, Vector3.ZERO],
					[0.7, Vector3(0, PI, 0), Vector3.ZERO],
					[0.9, open, Vector3.ZERO],
					[1.1, Vector3(0, PI, 0), Vector3.ZERO],
					[1.3, open, Vector3.ZERO],
					[1.6, Vector3(1.2, 1.2, 0), Vector3.ZERO],
					[1.9, shut, Vector3.ZERO],
					[2.2, shut, Vector3.ZERO],
					[2.32, Vector3(PI, 0, 0), Vector3.ZERO],
					[2.45, open, Vector3.ZERO],
					[3.0, open, Vector3.ZERO],
				],
				"events": [[0.4, "glint", null], [0.55, "sound", "knife_spin"], [0.95, "sound", "knife_spin"],
						[1.45, "sound", "knife_swish"], [2.1, "sound", "knife_catch"], [2.25, "sound", "knife_spin"],
						[2.45, "sound", "knife_catch"], [2.47, "star", null]],
			},
		},
	}
