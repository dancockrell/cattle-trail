extends RefCounted
## Derives encounter presentation from authoritative saved progress.
## Rendering and dialogue never advance the encounter or grant rewards.
const OBJECTIVES := {
	"not_started":"Meet Eleanor at the wagon to tend the crossing spirit.",
	"carry_lantern":"Carry the lantern to the frightened crossing spirit.",
	"spirit_settled":"The spirit is listening. Lead the stranded cattle across.",
	"guide_cattle":"Guide the three stranded cattle through the crossing.",
	"return_to_wagon":"Everyone is across. Return to the wagon with Eleanor.",
	"completed":"Lanterns at the Ford complete. The crossing is quiet."
}

static func describe(adventure) -> Dictionary:
	var stage: String = adventure.stage
	var status: String = adventure.status
	var active := status=="active"
	var started := stage!="not_started"
	var spirit_clip := "wary"
	if stage=="carry_lantern": spirit_clip = "agitated"
	elif stage in ["spirit_settled","guide_cattle"]: spirit_clip = "listening"
	elif stage in ["return_to_wagon","completed"]: spirit_clip = "settled"
	var objective: String = OBJECTIVES.get(stage,OBJECTIVES.not_started)
	if status=="paused": objective = "Lantern adventure paused. Resume with Eleanor at the wagon."
	elif status=="failed": objective = "Take a breath at the wagon, then retry from your checkpoint."
	return {"objective":objective,"spirit_visible":started,"spirit_clip":spirit_clip,
		"carry_lantern":active,"controlled_actor":adventure.controlled_actor,
		"guided_count":adventure.guided_cattle.size(),"guided_total":adventure.REQUIRED_CATTLE,
		"can_resume":status=="paused","can_retry":status=="failed",
		"show_completion":status=="completed"}
