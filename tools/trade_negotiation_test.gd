extends SceneTree
const Trade = preload("res://scripts/trade_negotiation.gd")

func _initialize():
	# Reputation caps at 5 after repeated fair sales, doesn't overshoot.
	var reputation := 2
	for i in 10:
		reputation = Trade.record_fair_sale(reputation)
	assert(reputation == 5, "Reputation must cap at 5 no matter how many fair sales stack")

	# Reputation floors at 0 after repeated rigged/bluff losses, doesn't undershoot.
	reputation = 2
	for i in 10:
		reputation = Trade.record_rigged_or_bluff_caught(reputation)
	assert(reputation == 0, "Reputation must floor at 0 no matter how many rigged/bluff losses stack")

	# Walking away is neutral: no gain, no loss, from any starting value.
	assert(Trade.record_walked_away(2) == 2, "Walking away must not change reputation")
	assert(Trade.record_walked_away(0) == 0, "Walking away from the floor must not change reputation")
	assert(Trade.record_walked_away(5) == 5, "Walking away from the cap must not change reputation")

	# accept never changes the price, regardless of reputation.
	var accept_result := Trade.resolve(100.0, "accept", false)
	assert(accept_result.outcome == "accepted", "Accept must resolve to an accepted sale")
	assert(is_equal_approx(accept_result.final_price, 100.0), "Accept must sell at exactly the opening price, no adjustment")

	# walk produces no sale and no reputation change.
	var walk_result := Trade.resolve(100.0, "walk", false)
	assert(walk_result.outcome == "walked_away", "Walk must resolve to walked_away")
	assert(is_equal_approx(walk_result.final_price, 0.0), "Walking away must produce no sale price")
	assert(walk_result.reputation_delta == 0, "Walking away must produce no reputation change")

	# counter against a non-rigged buyer can land, and the price is genuinely higher.
	var counter_result := Trade.resolve(100.0, "counter", false)
	assert(counter_result.outcome == "countered", "A counter against an honest buyer must land as 'countered'")
	assert(counter_result.final_price > 100.0, "A landed counter must raise the price above the opening price")
	assert(counter_result.reputation_delta == 1, "A landed counter is a fair sale and must gain reputation")

	# counter against a rigged buyer is a different outcome, not the same behavior:
	# it never lands (no price above opening) and it costs reputation instead of gaining it.
	var rigged_counter := Trade.resolve(100.0, "counter", true)
	assert(rigged_counter.outcome == "bluff_caught", "A counter against a rigged buyer must be exposed as a bluff, not treated like an honest counter")
	assert(rigged_counter.outcome != counter_result.outcome, "Rigged and honest counters must not resolve to the same outcome")
	assert(not (rigged_counter.final_price > 100.0), "A rigged buyer's counter must never actually raise the price")
	assert(rigged_counter.reputation_delta < 0, "A bluff caught against a rigged buyer must cost reputation, not gain it")

	# Higher reputation produces a strictly better opening-price adjustment
	# than lower reputation, for the same nominal price.
	var low_rep_price := Trade.adjusted_opening_price(100.0, 0)
	var neutral_rep_price := Trade.adjusted_opening_price(100.0, 2)
	var high_rep_price := Trade.adjusted_opening_price(100.0, 5)
	assert(is_equal_approx(neutral_rep_price, 100.0), "Neutral reputation (2) must leave the nominal price unadjusted")
	assert(high_rep_price > neutral_rep_price, "Higher reputation must produce a better (higher) opening price than neutral")
	assert(neutral_rep_price > low_rep_price, "Neutral reputation must produce a better (higher) opening price than low reputation")
	assert(high_rep_price > low_rep_price, "Max reputation must produce a strictly better opening price than min reputation")

	print("TRADE NEGOTIATION PASS: reputation caps at 5, floors at 0, walking away is neutral, accept never moves price, walk produces no sale, honest counter lands above opening price, rigged counter is exposed as a distinct bluff outcome costing reputation, higher reputation yields a strictly better opening price")
	quit()
