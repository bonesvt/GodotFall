extends RefCounted
## Scrapjack: blackjack at the Rusted Halo's back table (vices.gd, bar_screen.gd).
## Eco bets scrap against Dutch, the dealer. Closest to 21 without going over
## wins; aces count 1 or 11, faces 10. Dealer hits to 17 and stands on any 17.
## A natural (two cards making 21) pays 3:2, a win pays 1:1, a push gives the
## bet back. Double down: double the bet, take exactly one more card.
## The scrap itself moves in the bar screen; this only says what the hand pays.

enum State { BETTING, PLAYING, DONE }

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["♠", "♥", "♦", "♣"]
const DEALER_STANDS := 17
## A fresh shoe once fewer than this many cards are left.
const RESHUFFLE_AT := 15

var rng := RandomNumberGenerator.new()
var deck: Array = []
var player: Array = []
var dealer: Array = []
var bet := 0
var state := State.BETTING
## "natural", "win", "push", "lose", "bust", "dealer_bust" once DONE.
var outcome := ""
var doubled := false


func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	shuffle()


func shuffle() -> void:
	deck = []
	for s in SUITS:
		for r in RANKS:
			deck.append({"rank": r, "suit": s})
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var c = deck[i]
		deck[i] = deck[j]
		deck[j] = c


func draw() -> Dictionary:
	if deck.is_empty():
		shuffle()
	return deck.pop_back()


static func card_value(card: Dictionary) -> int:
	var r: String = card["rank"]
	if r == "A":
		return 1
	if r in ["J", "Q", "K"]:
		return 10
	return int(r)


## Best total for a hand: aces count 11 where that doesn't bust it.
static func total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c in hand:
		t += card_value(c)
		if c["rank"] == "A":
			aces += 1
	if aces > 0 and t + 10 <= 21:
		t += 10
	return t


static func is_natural(hand: Array) -> bool:
	return hand.size() == 2 and total(hand) == 21


static func card_text(card: Dictionary) -> String:
	return "%s%s" % [card["rank"], card["suit"]]


## Deals a hand on `amount` scrap. Settles at once on a natural either side.
func deal(amount: int) -> void:
	if deck.size() < RESHUFFLE_AT:
		shuffle()
	bet = amount
	doubled = false
	outcome = ""
	player = [draw(), draw()]
	dealer = [draw(), draw()]
	state = State.PLAYING
	if is_natural(player) or is_natural(dealer):
		_settle()


func hit() -> void:
	if state != State.PLAYING:
		return
	player.append(draw())
	if total(player) > 21:
		_settle()
	elif total(player) == 21:
		stand()


func stand() -> void:
	if state != State.PLAYING:
		return
	while total(dealer) < DEALER_STANDS:
		dealer.append(draw())
	_settle()


## Only on her first two cards.
func can_double() -> bool:
	return state == State.PLAYING and player.size() == 2


func double_down() -> void:
	if not can_double():
		return
	bet *= 2
	doubled = true
	player.append(draw())
	if total(player) > 21:
		_settle()
	else:
		stand()


func _settle() -> void:
	state = State.DONE
	var p := total(player)
	var d := total(dealer)
	if is_natural(player) and not is_natural(dealer):
		outcome = "natural"
	elif is_natural(dealer) and not is_natural(player):
		outcome = "lose"
	elif p > 21:
		outcome = "bust"
	elif d > 21:
		outcome = "dealer_bust"
	elif p > d:
		outcome = "win"
	elif p == d:
		outcome = "push"
	else:
		outcome = "lose"


## Scrap back to Eco once the hand is DONE, bet included (0 when she lost).
func payout() -> int:
	match outcome:
		"natural":
			return bet + bet * 3 / 2
		"win", "dealer_bust":
			return bet * 2
		"push":
			return bet
	return 0


## The dealer's hole card stays face down while she's still playing.
func dealer_shown() -> Array:
	if state == State.PLAYING:
		return [dealer[0]]
	return dealer
