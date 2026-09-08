extends SceneTree
const Perks = preload("res://scripts/companion_perks.gd")
const State = preload("res://scripts/companion_state.gd")
func _initialize():
	var team := []
	for i in 20:
		team.append({"id":"rancher_%d"%i,"perk_id":"steady_herd","recruitment":"recruited","party_assignment":"camp"})
	assert(Perks.value(team,"field","lasso_follow_seconds")==4)
	team = [{"id":"e","perk_id":"eleanor_perk","recruitment":"recruited","party_assignment":"camp"}]
	assert(Perks.value(team,"camp","rest_madness_recovery")==3)
	team.append(team[0].duplicate(true))
	assert(Perks.value(team,"camp","rest_madness_recovery")==3)
	assert(Perks.value(team,"field","rest_madness_recovery")==0)
	team[0].production_preview = true
	assert(Perks.value(team,"camp","rest_madness_recovery")==0)
	team = []
	for i in 4:
		team.append({"id":"m%d"%i,"perk_id":"field_repairs","recruitment":"recruited","party_assignment":"field","value":99999})
	assert(is_equal_approx(Perks.value(team,"field","machine_repair_efficiency",1),1.25))
	assert(Perks.value(team,"camp","machine_repair_efficiency",1)==1)
	team[0].recruitment="available"
	team[1].party_assignment="none"
	team[2].perk_id="unknown"
	assert(is_equal_approx(Perks.value(team,"field","machine_repair_efficiency",1),1.1))
	var state = State.new()
	state.recruit(true,true)
	state.begin_adventure()
	for id in ["a","b","c"]: state.steady_cattle(id)
	state.finish_adventure()
	state.madness.player = 50
	var rest = state.shared_rest(720,true)
	assert(rest.ok and rest.perk_bonus==3 and rest.player_recovered==13)
	print("COMPANION PERKS PASS: assignment, recruitment, unique owners, caps, authored values, preview exclusion, existing rest")
	quit()
