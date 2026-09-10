extends RefCounted
## Design-only proposal made real: design/ECONOMY.md "Shrewd dealing, as a
## mechanic (PROPOSAL — not accepted design)". A single counter-offer beat
## (accept / counter-once / walk), per-buyer reputation 0-5 starting at 2,
## and a reputation-to-price nudge. All numeric constants below are the
## doc's own first-pass numbers, explicitly not accepted balance.
## Pure logic only: no scene tree, no autoload, nothing but Dictionaries
## and numbers in and out, same shape as scripts/companion_perks.gd.

const REPUTATION_MIN := 0
const REPUTATION_MAX := 5
const REPUTATION_NEUTRAL := 2

## ECONOMY.md: "A fair sale ... is +1, capped at 5."
const FAIR_SALE_DELTA := 1
## ECONOMY.md: "A walked-away sale is neutral — no gain, no loss."
const WALK_AWAY_DELTA := 0
## ECONOMY.md: "a sale where the player's counter is caught as a bluff costs −2."
const RIGGED_OR_BLUFF_DELTA := -2

## ECONOMY.md: "a counter ... either lands (small gain...)". First-pass
## tuning value only, per the doc's own "not specified here" framing.
const COUNTER_GAIN_FRACTION := 0.10

## ECONOMY.md: "Each point of reputation nudges the buyer's opening price
## in the player's favor by some small, tunable percentage (not specified
## here)". First-pass guess: 2% per reputation point above the neutral
## baseline of 2. Not balanced, just wired up so the number exists and is
## testable.
const REPUTATION_PRICE_PERCENT_PER_POINT := 0.02


static func record_fair_sale(reputation: int) -> int:
	return clampi(reputation + FAIR_SALE_DELTA, REPUTATION_MIN, REPUTATION_MAX)


static func record_walked_away(reputation: int) -> int:
	return clampi(reputation + WALK_AWAY_DELTA, REPUTATION_MIN, REPUTATION_MAX)


static func record_rigged_or_bluff_caught(reputation: int) -> int:
	return clampi(reputation + RIGGED_OR_BLUFF_DELTA, REPUTATION_MIN, REPUTATION_MAX)


## ECONOMY.md market factor: reputation nudges the buyer's opening price.
## Returns opening_price adjusted by (reputation - neutral) * percent-per-point.
static func adjusted_opening_price(base_price: float, reputation: int) -> float:
	var points := float(reputation - REPUTATION_NEUTRAL)
	return base_price * (1.0 + points * REPUTATION_PRICE_PERCENT_PER_POINT)


## Resolves the single negotiation beat from ECONOMY.md section 1.
## opening_price: already the output of the cattle-market factors, not this
##   class's job to compute.
## action: "accept", "counter", or "walk".
## rigged: true for a buyer like Chester Vane whose auctions aren't honest,
##   per conflicts-and-rivalries.md — a "counter" against one is the bluff
##   moment itself.
## Returns {outcome: String, final_price: float, reputation_delta: int}
## so a caller applies the sale and the reputation change in one step.
static func resolve(opening_price: float, action: String, rigged: bool) -> Dictionary:
	match action:
		"accept":
			return {"outcome": "accepted", "final_price": opening_price, "reputation_delta": FAIR_SALE_DELTA}
		"walk":
			return {"outcome": "walked_away", "final_price": 0.0, "reputation_delta": WALK_AWAY_DELTA}
		"counter":
			if rigged:
				# The doc's own framing: for a rigged actor, the counter IS
				# the bluff moment. It never lands, and it costs reputation.
				return {"outcome": "bluff_caught", "final_price": 0.0, "reputation_delta": RIGGED_OR_BLUFF_DELTA}
			var raised := opening_price * (1.0 + COUNTER_GAIN_FRACTION)
			return {"outcome": "countered", "final_price": raised, "reputation_delta": FAIR_SALE_DELTA}
		_:
			return {"outcome": "invalid", "final_price": 0.0, "reputation_delta": 0}
