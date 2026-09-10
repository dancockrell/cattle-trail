extends RefCounted

const State = preload("res://scripts/companion_state.gd")
const Storage = preload("res://scripts/save_storage.gd")
const Snapshot = preload("res://scripts/room_snapshot.gd")
const Clock = preload("res://scripts/trail_clock.gd")
const LanternAdventure = preload("res://scripts/lantern_adventure.gd")
const LanternRoom = preload("res://scripts/lantern_room.gd")
const LanternEquipment = preload("res://scripts/lantern_equipment.gd")
const AdaState = preload("res://scripts/ada_companion.gd")
const InesState = preload("res://scripts/ines_companion.gd")
const InesRoom = preload("res://scripts/ines_room.gd")
const BirdieState = preload("res://scripts/birdie_companion.gd")
const BirdieRoom = preload("res://scripts/birdie_room.gd")
const SimpleState = preload("res://scripts/simple_companion_state.gd")
const SimpleRoom = preload("res://scripts/simple_companion_room.gd")
const SimpleCatalog = preload("res://scripts/simple_companion_catalog.gd")
const CompanionActors = preload("res://scripts/companion_actors.gd")
const MechanicRoom = preload("res://scripts/mechanic_room.gd")
const GeneratedRoster = preload("res://scripts/generated_companion_roster.gd")
const Perks = preload("res://scripts/companion_perks.gd")
const CartAdventure = preload("res://scripts/ada_cart_adventure.gd")
const CartRoom = preload("res://scripts/ada_cart_room.gd")
const CampCare = preload("res://scripts/camp_care_room.gd")
const Recovery = preload("res://scripts/camp_recovery.gd")
const Dialogue = preload("res://scripts/dialogue_scene.gd")
const SAVE_PATH := "user://clear-fork-save.json"
const BANTER_PATH := "res://data/eleanor_banter.json"
const WAGON_SCENE_PATH := "res://data/eleanor_wagon_scene.json"
const ADA_BANTER_PATH := "res://data/ada_banter.json"
var room: Control
var state = State.new()
var lantern_adventure = LanternAdventure.new()
var ada_state = AdaState.new()
var ines_state = InesState.new()
var birdie_state = BirdieState.new()
var generated_roster = GeneratedRoster.new()
var cart_adventure = CartAdventure.new()
var cart
var camp_recovery = Recovery.new()
var camp_care
var lantern
var mechanic
var ines
var birdie
var simple_companions: Array = [] # Array of {"id":String,"state":SimpleState,"room":SimpleRoom}
var companion_actors
var lantern_equipment: Sprite2D

func sync_lantern_equipment() -> void:
	if lantern_equipment != null: lantern_equipment.sync_state(lantern_adventure)
var minutes := 720.0
var banter: Dictionary = {}
var ada_banter: Dictionary = {}
## The wagon conversation. Every other verb in this room is "ride somewhere
## and press a button"; this is the one place a person wants something and
## the player answers. The scene itself is data, so the next one is a JSON
## file and nothing here changes.
var wagon_talk = Dialogue.new()
var wagon_scene_open := false
var wagon_record: Dictionary = blank_wagon_record()

## Shared by every per-character banter file: reject anything not matching
## this speaker so one character's file can never voice another's line.
static func _load_banter(path: String, speaker: String) -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(path): return result
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not content is Dictionary or not content.get("events") is Array: return result
	for event in content.events:
		if not event is Dictionary: continue
		if not event.get("id") is String or not event.get("text") is String: continue
		if event.id.is_empty() or event.text.is_empty() or event.get("speaker") != speaker: continue
		var priority: Variant = event.get("priority")
		if not (priority is int or priority is float) or priority not in [0,1,2]: continue
		result[event.id] = event
	return result

func field_perk(stat: String, baseline := 0.0) -> float:
	var records: Array = generated_roster.perk_state_records()
	records.append(ines_state.perk_record())
	return Perks.value(records, "field", stat, baseline)

func advance_time(delta: float) -> void:
	minutes = Clock.advance(minutes,delta)

func clock_label() -> String:
	return Clock.label(minutes)

func _init(owner_room: Control) -> void:
	room = owner_room
	banter = _load_banter(BANTER_PATH,"ELEANOR")
	ada_banter = _load_banter(ADA_BANTER_PATH,"ADA")
	lantern = LanternRoom.new(self)
	mechanic = MechanicRoom.new(self)
	cart = CartRoom.new(self)
	camp_care = CampCare.new(self)
	ines = InesRoom.new(self)
	birdie = BirdieRoom.new(self)
	for row in SimpleCatalog.ROWS:
		var s_state = SimpleState.new()
		s_state.configure(row.id, row.age, row.perk_id)
		var runtime_config: Dictionary = row.duplicate()
		runtime_config["position"] = SimpleCatalog.position_for(row)
		var s_room = SimpleRoom.new(self, runtime_config, s_state)
		simple_companions.append({"id": row.id, "state": s_state, "room": s_room})
	# Draw the simple companions. Without this they are coordinates the player
	# walks to and nothing is on screen where they stand.
	companion_actors = CompanionActors.new()
	companion_actors.populate(room, SimpleCatalog.ROWS)
	lantern_equipment = LanternEquipment.new()
	lantern_equipment.configure(room.eleanor,load("res://assets/lantern/carried_lantern.png"),Vector2(16,8))
	room.eleanor.add_child(lantern_equipment)

func say_event(event_id: String, saved_beat_id: String) -> void:
	# Existing beat IDs stay authoritative across old saves and content rewrites.
	if not banter.has(event_id): return
	var event: Dictionary = banter[event_id]
	room.say_once(saved_beat_id,room.eleanor,event.speaker,event.text,int(event.priority))

func say_ada_event(event_id: String, saved_beat_id: String, actor: Node2D) -> void:
	if not ada_banter.has(event_id) or not is_instance_valid(actor): return
	var event: Dictionary = ada_banter[event_id]
	room.say_once(saved_beat_id,actor,event.speaker,event.text,int(event.priority))

## Resolves simple_companion_catalog.gd's "unlock_key" strings. Add a case
## here when a future data row needs a new gate; this is the one place that
## has to change, not every controller that shares the gate.
func check_unlock(key: String) -> bool:
	match key:
		"birdie_recruited": return birdie_state.recruitment == "recruited"
		_: return false

func is_eleanor() -> bool:
	return state.controlled_actor == "eleanor" or lantern_adventure.controlled_actor == "eleanor"

func active_actor() -> Node2D:
	if cart != null and cart.is_active() and is_instance_valid(cart.vehicle): return cart.vehicle
	return room.eleanor if is_eleanor() else room.player

func tell(line: String) -> void:
	room.message = line
	room.refresh()

func switch_character() -> void:
	if wagon_scene_open:
		choose_wagon_option(2)
		return
	if cart != null and cart.pause_or_resume(): return
	if state.adventure_status=="completed" and lantern.switch_character(): return
	if state.recruitment != "recruited":
		tell("After gathering the herd, return to Eleanor and invite her along.")
		return
	if room.player.action_time > 0 or room.rope_time > 0:
		tell("Finish the cast or lead before changing characters.")
		return
	if is_eleanor():
		state.cancel_adventure()
	else:
		if state.adventure_status == "completed":
			tell("Eleanor's adventure is complete. Meet her at the wagon for shared rest.")
			return
		var resuming: bool = state.adventure_status == "paused"
		var result: Dictionary = state.begin_adventure(false)
		if result.get("ok",false) and resuming:
			say_event("return_from_pause","eleanor_resume")
	room.target = Vector2.INF
	room.player.pose(false)
	room.eleanor.pose(false)
	tell("Playing Eleanor, 24 / Walk to a restless steer and Talk to steady it." if is_eleanor() else "Playing the trail boss / Eleanor's progress is kept.")

func interact() -> bool:
	if wagon_scene_open: return choose_wagon_option(0)
	if ines != null and ines.interact(): return true
	if birdie != null and birdie.interact(): return true
	for entry in simple_companions:
		if entry.room.interact(): return true
	if cart != null and cart.interact(): return true
	if mechanic.interact(): return true
	if lantern.interact(): return true
	if is_eleanor():
		if state.adventure_status == "active":
			var nearest: Node2D
			var distance := 40.0
			for index in range(room.cows.size()):
				if state.steadied_cattle.size() >= State.REQUIRED_CATTLE: break
				if str(index) in state.steadied_cattle: continue
				var cow: Node2D = room.cows[index]
				if room.eleanor.position.distance_to(cow.position) < distance:
					nearest = cow
					distance = room.eleanor.position.distance_to(cow.position)
			if nearest != null:
				var index: int = room.cows.find(nearest)
				state.steady_cattle(str(index))
				room.eleanor.action("talk", nearest.position-room.eleanor.position)
				var count: int = state.steadied_cattle.size()
				say_event("calm_"+str(count),"steady_"+str(index))
				tell("Eleanor steadied %d of 3 cattle. %s" % [count,"Return to the wagon and Talk." if count>=3 else "Find another restless steer."])
				save_game()
			elif state.steadied_cattle.size() >= 3 and room.eleanor.position.distance_to(Vector2(148,127))<55:
				state.finish_adventure()
				say_event("adventure_complete","eleanor_adventure")
				tell("Shared adventure complete. Eleanor trusts you. Rest together at the wagon; her Steady Company perk adds 3 recovery.")
				save_game()
			else:
				tell("Walk within a few steps of a restless steer and Talk." if state.steadied_cattle.size()<3 else "Return to the wagon and Talk to finish Eleanor's adventure.")
		else:
			tell("Eleanor's adventure is complete. Rest by the wagon, or switch back to the trail boss.")
		return true
	if room.won and room.player.position.distance_to(room.eleanor.position)<65:
		if state.recruitment != "recruited":
			state.recruit(true,true)
			say_event("recruited","eleanor_recruited")
			tell("Eleanor, 24, joins the outfit. Talk again at the wagon; she has been trying to say something. Companion [Tab] plays her short cattle-calming adventure.")
			save_game()
			return true
	# Talk at the tailgate used to repeat her introduction forever. It opens
	# the conversation instead, and once that conversation has happened it
	# reports which camp the player left himself in.
	if wagon_scene_available():
		open_wagon_scene()
		return true
	if room.won and not is_eleanor() and state.recruitment == "recruited" and room.player.position.distance_to(room.eleanor.position) <= FLIRT_RANGE:
		var standing: String = wagon_standing_line()
		if not standing.is_empty():
			tell(standing)
			return true
	return false

func rest_together() -> void:
	if wagon_scene_open:
		choose_wagon_option(3)
		return
	if cart != null and cart.toggle_valve(2): return
	camp_care.rest()

## Pressing Flirt from across camp used to refuse and tell the player where to
## stand. The game knows where the quiet moment is, so it walks him there
## instead, and a repeated refusal for the same reason escalates rather than
## repeating one string. The counter is runtime only: a reload starts the
## escalation over, which is the right behaviour and needs no save field.
var flirt_refusal_reason := ""
var flirt_refusal_count := 0

const FLIRT_RANGE := 55.0
const FLIRT_APPROACH := 24.0

const FLIRT_SELF_LINES = [
	"You are wearing Eleanor's boots at the moment. Switch back to the trail boss first.",
	"Eleanor catches her own reflection in the kettle and laughs. Companion [Tab] puts you back in your own saddle.",
	"Eleanor: I am flattered, but I already know what I am thinking. Switch back.",
	"Eleanor: Courting yourself is a long ride for a short answer. Companion [Tab]."
]
const FLIRT_WALK_LINES = [
	"You start for the wagon. Eleanor sees you coming and keeps her hands busy.",
	"Still walking. Eleanor: The coffee is not going anywhere either.",
	"Eleanor: Any slower and I will come and fetch you.",
	"Eleanor sets the kettle down and waits, openly amused."
]
const FLIRT_TOO_SOON_LINES = [
	"First share Eleanor's cattle-calming adventure. A little history makes a better invitation.",
	"Eleanor: Steady three head with me first. Then ask.",
	"Eleanor: You are courting a woman you have not worked beside. Three cattle. Then we talk.",
	"Eleanor: Still no. Still three cattle. I am nothing if not consistent."
]
const FLIRT_SETTLED_LINES = [
	"Eleanor smiles: We already have a sunset to look forward to.",
	"Eleanor: You asked, I said yes, and it has not worn off since.",
	"Eleanor: Ask a third time and I will start to think you forget things.",
	"Eleanor hands you the kettle. Some answers keep better than others."
]

func _flirt_refused(reason: String, lines: Array) -> void:
	if reason == flirt_refusal_reason:
		flirt_refusal_count = mini(flirt_refusal_count+1,lines.size()-1)
	else:
		flirt_refusal_reason = reason
		flirt_refusal_count = 0
	tell(lines[flirt_refusal_count])

func flirt() -> void:
	if wagon_scene_open:
		choose_wagon_option(1)
		return
	if ines != null and ines.flirt(): return
	if birdie != null and birdie.flirt(): return
	for entry in simple_companions:
		if entry.room.flirt(): return
	if cart != null and cart.flirt(): return
	if is_eleanor():
		_flirt_refused("self",FLIRT_SELF_LINES)
		return
	if room.player.position.distance_to(room.eleanor.position)>FLIRT_RANGE:
		var toward: Vector2 = (room.player.position-room.eleanor.position).normalized()
		if toward == Vector2.ZERO: toward = Vector2.RIGHT
		room.target = room.limit_position(room.eleanor.position+toward*FLIRT_APPROACH)
		_flirt_refused("walk",FLIRT_WALK_LINES)
		return
	var result: Dictionary = state.choose_romance(true)
	if result.get("ok",false):
		flirt_refusal_reason = ""
		flirt_refusal_count = 0
		room.eleanor.action("talk",room.player.position-room.eleanor.position)
		say_event("mutual_flirt","mutual_flirt")
		tell("You choose to stay beside her. Eleanor's answering smile says enough. Relationship: courting. Shared rest remains available either way.")
		save_game()
	elif state.events.romance_chosen:
		_flirt_refused("settled",FLIRT_SETTLED_LINES)
	else:
		_flirt_refused("too_soon",FLIRT_TOO_SOON_LINES)

## --- The wagon conversation -------------------------------------------
## Entry is Talk at the wagon once she is in the outfit, which is the press
## that used to repeat her introduction. The scene borrows the four camp
## controls that already exist, in the order they sit on the row, so no new
## UI appears: Talk [E] is answer 1, Flirt [H] is 2, Companion [Tab] is 3,
## Rest [G] is 4. Shoot has no answer behind it and is switched off rather
## than left looking live.
const WAGON_OPTION_SLOTS := [0, 1, 3, 4]
## The key each answer slot actually answers on. These are NOT numbered,
## deliberately: keys 1-3 belong to the rustler's fate, so a numbered answer
## row here would put two numbered menus on screen claiming the same keys.
const WAGON_OPTION_KEYS := ["[E]", "[H]", "[Tab]", "[G]"]

## The record adds one field to the dialogue system's own: which endings
## have already been paid for, so replaying cannot hand out trust twice.
static func blank_wagon_record() -> Dictionary:
	var record: Dictionary = Dialogue.blank_record()
	record["paid"] = []
	return record

static func valid_wagon_record(value) -> bool:
	if not value is Dictionary: return false
	var data: Dictionary = (value as Dictionary).duplicate(true)
	var paid: Variant = data.get("paid")
	if not paid is Array: return false
	for entry in paid:
		if not entry is String or entry.is_empty() or entry.length() > 128: return false
	data.erase("paid")
	return Dialogue.valid_record(data)

## Resolves the scene's "requires" keys. Whether her cattle-calming
## adventure is finished is this room's business, not the dialogue file's.
func wagon_scene_facts() -> Dictionary:
	return {
		"steadied_three": state.adventure_status == "completed",
		"crossing_settled": lantern_adventure.status == "completed",
		"courting": bool(state.events.get("romance_chosen", false)),
	}

## Deferring is the only ending that leaves her ask open, so it is the only
## one that lets the player come back to it. Everything else is said once.
func wagon_scene_available() -> bool:
	if wagon_scene_open or is_eleanor(): return false
	if not room.won or state.recruitment != "recruited": return false
	if lantern_adventure.status == "active": return false
	if room.player.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0: return false
	if room.player.position.distance_to(room.eleanor.position) > FLIRT_RANGE: return false
	if bool(wagon_record.visited) and String(wagon_record.terminal) != "deferred": return false
	return true

func open_wagon_scene() -> bool:
	var data: Dictionary = Dialogue.load_file(WAGON_SCENE_PATH)
	if data.is_empty() or not wagon_talk.configure(data, wagon_scene_facts()):
		# Loud. A missing scene file must not fall quietly back to the two
		# sentences Eleanor used to have.
		push_error("Eleanor's wagon scene did not load: " + str(Dialogue.validate(data)))
		tell("Eleanor's wagon scene did not load. " + WAGON_SCENE_PATH + " is missing or malformed.")
		return false
	wagon_scene_open = true
	_speak_wagon_node()
	return true

func _speak_wagon_node(said := "") -> void:
	var node: Dictionary = wagon_talk.current()
	if node.is_empty(): return
	if room.eleanor.action_time <= 0:
		room.eleanor.action("talk", room.player.position - room.eleanor.position)
	var prefix := ""
	if not said.is_empty(): prefix = "You: %s  " % said
	tell("%s%s: %s" % [prefix, node.speaker, node.line])

## The one place an answer is applied. Returns true whenever the scene ate
## the press, an unavailable option included: pressing a shut door tells the
## player why instead of letting the button do its ordinary camp job.
func choose_wagon_option(slot: int) -> bool:
	if not wagon_scene_open: return false
	var listed: Array = wagon_talk.options()
	var said := ""
	if slot >= 0 and slot < listed.size(): said = String(listed[slot].text)
	var result: Dictionary = wagon_talk.choose(slot)
	if not result.ok:
		if result.reason == "unavailable": tell(String(result.note))
		else: tell("There is no answer in that seat. Pick one of the numbered replies.")
		return true
	if wagon_talk.finished: _finish_wagon_scene(said)
	else: _speak_wagon_node(said)
	return true

func _finish_wagon_scene(said: String) -> void:
	var outcome: Dictionary = wagon_talk.outcome()
	var written: Dictionary = wagon_talk.record()
	wagon_scene_open = false
	var ending := String(outcome.id)
	var gained := 0
	if not (wagon_record.paid as Array).has(ending):
		(wagon_record.paid as Array).append(ending)
		gained = int(outcome.trust)
		state.trust = clampi(state.trust + gained, 0, 100)
	var flags: Array = (wagon_record.flags as Array).duplicate()
	for flag in written.flags:
		if not flags.has(flag): flags.append(flag)
	wagon_record.visited = true
	wagon_record.terminal = written.terminal
	wagon_record.flags = flags
	wagon_record.taken = written.taken
	if room.eleanor.action_time <= 0:
		room.eleanor.action("talk", room.player.position - room.eleanor.position)
	var trust_note := ""
	if gained > 0: trust_note = " Eleanor's trust +%d." % gained
	var prefix := ""
	if not said.is_empty(): prefix = "You: %s  " % said
	tell("%sELEANOR: %s / %s%s" % [prefix, outcome.line, outcome.summary, trust_note])
	save_game()

func wagon_flag(flag: String) -> bool:
	return (wagon_record.flags as Array).has(flag)

## Where the scene's flags are actually read. A promise given, a promise
## refused and a boundary pushed leave three different camps behind them,
## and Talk at the tailgate is where the player hears which one he is in.
func wagon_standing_line() -> String:
	if wagon_flag("eleanor_sent_for"): return "Eleanor: First light, north line. Do not bring the bag."
	if wagon_flag("eleanor_spirit_boundary_pushed"): return "Eleanor: Kettle is hot. That is the whole of what I have for you tonight."
	if wagon_flag("eleanor_burial_promise"): return "Eleanor: Ordinary ground. You said it, I heard it, and that is the end of it."
	if wagon_flag("eleanor_refused_promise"): return "Eleanor: I wrote to Alvarez. Sit down anyway, the coffee is made."
	return ""

## Buttons carry the short label at every width: this row has to fit a
## 360-pixel window, and a Button grows its own minimum size to fit its
## text, so a long reply would push the row off the bottom of a phone. The
## reply the player actually chose is echoed back in full in the journal.
func decorate_wagon_scene_ui() -> void:
	if not wagon_scene_open: return
	var options: Array = wagon_talk.options()
	var locked_note := ""
	for slot in range(WAGON_OPTION_SLOTS.size()):
		var button = room.buttons.get_child(WAGON_OPTION_SLOTS[slot])
		if slot >= options.size():
			button.text = "-"
			button.disabled = true
			button.tooltip_text = ""
			continue
		var option: Dictionary = options[slot]
		button.text = "%s %s" % [WAGON_OPTION_KEYS[slot], option.short]
		button.disabled = not option.available
		button.tooltip_text = String(option.reason) if not option.available else String(option.text)
		if not option.available and locked_note.is_empty():
			locked_note = "%s is shut: %s" % [WAGON_OPTION_KEYS[slot], option.reason]
	room.buttons.get_child(2).disabled = true
	room.buttons.get_child(2).text = "-"
	room.objective.text = "ELEANOR AT THE WAGON / " + (locked_note if not locked_note.is_empty() else "Answer her: [E] [H] [Tab] [G]")

func decorate_ui() -> void:
	for index in [0,1,2,4]: room.buttons.get_child(index).disabled = false
	room.stats.tooltip_text = Clock.label(minutes)
	room.buttons.get_child(0).text = "Talk" if room.size.x<600 else "Talk [E]"
	room.buttons.get_child(2).text = "Shoot" if room.size.x<600 else "Shoot [F]"
	room.buttons.get_child(3).text = "Companion [Tab]"
	room.buttons.get_child(4).text = "Rest [G]"
	room.buttons.get_child(4).tooltip_text = ""
	if not room.won: return
	room.buttons.get_child(1).text = "Flirt" if room.size.x<600 else "Flirt [H]"
	if state.recruitment != "recruited":
		room.objective.text = "HERD SAFE / Return to Eleanor and invite her into the outfit"
	elif state.adventure_status != "completed":
		room.objective.text = "ELEANOR / %d of 3 steadied / %s" % [state.steadied_cattle.size(),"Playing Eleanor" if is_eleanor() else "Companion [Tab] to play"]
	else:
		var remaining := Clock.remaining_minutes(minutes,maxf(state.next_rest_minute,float(camp_recovery.next_available.get("player",0.0))))
		room.objective.text = "STEADY COMPANY / %s / %s" % [Clock.label(minutes),"Rest at wagon" if remaining==0 else "Rest in %dm" % remaining]
	room.stats.text = "$%d  HERD 6/6  MADNESS %d  ELEANOR %d" % [room.cash,int(state.madness.get("player",0)),int(state.madness.get("eleanor",0))]
	if lantern != null: lantern.decorate_ui()
	if mechanic != null: mechanic.decorate_ui()
	if cart != null: cart.decorate_ui()
	if camp_care != null: camp_care.decorate_ui()
	if ines != null: ines.decorate_ui()
	if birdie != null: birdie.decorate_ui()
	for entry in simple_companions: entry.room.decorate_ui()
	decorate_wagon_scene_ui()

func save_game(test_path := "") -> bool:
	if room.qa_mode and test_path.is_empty(): return false
	if room.player.action_time>0 or room.rope_time>0 or room.rope_flight_time>0: return false
	var cattle := []
	for cow in room.cows: cattle.append({"position":[cow.position.x,cow.position.y],"secured":cow.secured})
	var data := {"version":1,"companion":state.to_dict(),"minutes":minutes,"player":[room.player.position.x,room.player.position.y],"eleanor":[room.eleanor.position.x,room.eleanor.position.y],"cattle":cattle,"cash":room.cash,"ammo":room.ammo,"won":room.won,"talked":room.talked,"rustler_active":room.rustler_active,"rustler_surrendered":room.rustler_surrendered,"rustler_fate":room.rustler_fate,"rustler_hired":room.rustler_hired,"rustler_present":room.rustler_present,"hits":room.hits,"spoken_beats":room.spoken_beats}
	data["lantern_adventure"] = lantern_adventure.to_dict()
	data["ada_companion"] = ada_state.to_dict()
	data["ines_companion"] = ines_state.to_dict()
	data["birdie_companion"] = birdie_state.to_dict()
	var simple_data := {}
	for entry in simple_companions: simple_data[entry.id] = entry.state.to_dict()
	data["simple_companions"] = simple_data
	data["camp_recovery"] = camp_recovery.to_dict()
	data["eleanor_wagon_scene"] = wagon_record.duplicate(true)
	data["generated_companions"] = generated_roster.to_dict()
	data["ada_cart_adventure"] = cart_adventure.to_dict()
	var cart_position: Vector2 = cart.position_for_save() if cart != null else CartRoom.PARK
	data["ada_cart_position"] = [cart_position.x,cart_position.y]
	var cart_heading: Vector2 = cart.motion.heading if cart != null else Vector2.RIGHT
	data["ada_cart_heading"] = [cart_heading.x,cart_heading.y]
	return Storage.write(SAVE_PATH if test_path.is_empty() else test_path,data)

func load_game(test_path := "") -> bool:
	var path: String = SAVE_PATH if test_path.is_empty() else test_path
	if room.qa_mode and test_path.is_empty(): return false
	var data: Dictionary = Storage.read(path,Snapshot.validate)
	if data.is_empty(): return false
	var restored_care = CampCare.restored_recovery(data)
	if restored_care == null: return false
	var restored_cart = CartAdventure.new()
	if not restored_cart.load_dict(data.get("ada_cart_adventure",restored_cart.to_dict())): return false
	var restored_roster = GeneratedRoster.new()
	if not restored_roster.load_dict(data.get("generated_companions", restored_roster.to_dict())): return false
	var restored_ada = AdaState.new()
	if not restored_ada.load_dict(data.get("ada_companion",restored_ada.to_dict())): return false
	var restored_ines = InesState.new()
	if not restored_ines.load_dict(data.get("ines_companion",restored_ines.to_dict())): return false
	var restored_birdie = BirdieState.new()
	if not restored_birdie.load_dict(data.get("birdie_companion",restored_birdie.to_dict())): return false
	var simple_saved: Dictionary = data.get("simple_companions",{})
	if not simple_saved is Dictionary: return false
	var restored_simple := {}
	for row in SimpleCatalog.ROWS:
		var candidate = SimpleState.new()
		candidate.configure(row.id, row.age, row.perk_id)
		if not candidate.load_dict(simple_saved.get(row.id, candidate.to_dict())): return false
		restored_simple[row.id] = candidate
	var restored_wagon: Variant = data.get("eleanor_wagon_scene", blank_wagon_record())
	if not valid_wagon_record(restored_wagon): return false
	var restored_lantern = LanternAdventure.new()
	if not restored_lantern.load_dict(data.get("lantern_adventure",restored_lantern.to_dict())): return false
	if not state.load_dict(data.get("companion",{})): return false
	lantern_adventure = restored_lantern
	ada_state = restored_ada
	ines_state = restored_ines
	birdie_state = restored_birdie
	for entry in simple_companions:
		entry.state = restored_simple[entry.id]
		entry.room.state = entry.state
	generated_roster = restored_roster
	cart_adventure = restored_cart
	camp_recovery = restored_care
	wagon_record = (restored_wagon as Dictionary).duplicate(true)
	# A conversation in progress is not a saved thing; a reload puts the
	# player back outside it rather than mid-sentence with stale options.
	wagon_scene_open = false
	var cart_point: Array = data.get("ada_cart_position",[220,280])
	cart.saved_position = Vector2(cart_point[0],cart_point[1])
	var cart_heading: Array = data.get("ada_cart_heading",[1,0])
	cart.motion.heading = Vector2(cart_heading[0],cart_heading[1]).normalized()
	minutes = float(data.get("minutes",720))
	room.player.position = room.limit_position(Vector2(data.player[0],data.player[1]))
	room.eleanor.position = room.limit_position(Vector2(data.eleanor[0],data.eleanor[1]))
	for index in range(6):
		room.cows[index].position = room.limit_position(Vector2(data.cattle[index].position[0],data.cattle[index].position[1]))
		room.cows[index].secured = bool(data.cattle[index].secured)
	room.cash = int(data.get("cash",342))
	room.ammo = int(data.get("ammo",6))
	room.won = bool(data.get("won",false))
	room.talked = bool(data.get("talked",false))
	room.rustler_active = bool(data.get("rustler_active",true))
	# The decision the player made about him is part of the world, not a line of
	# dialogue. A save written before the decision existed carries none of these
	# fields, so each one falls back to what that older world meant: nobody had
	# surrendered, no fate was chosen, and he stood on the ground exactly while
	# he was still active.
	room.rustler_surrendered = bool(data.get("rustler_surrendered",false))
	room.rustler_fate = String(data.get("rustler_fate",""))
	room.rustler_hired = bool(data.get("rustler_hired",false))
	room.rustler_present = bool(data.get("rustler_present",room.rustler_active))
	# A man roped for the law or riding for wages is still on this ground. The
	# old line hid him whenever he was no longer a threat, which erased the
	# hired hand the player is paying.
	room.rustler.visible = room.rustler_active or room.rustler_present
	room.escaped = false
	room.rustler.position = Vector2(550,164)
	room.rustler.action_time = 0
	room.rustler.turn.cancel()
	room.rustler.pose(false)
	room.hits = int(data.get("hits",0))
	room.spoken_beats = data.get("spoken_beats",{})
	room.speech.remaining = 0
	room.speech.visible = false
	room.speech.speaker = null
	room.pending_banter.clear()
	room.target = Vector2.INF
	room.rope_time = 0
	room.rope_flight_time = 0
	room.rope_target = null
	room.pending_lasso = null
	room.pending_shot = false
	room.shot_time = 0
	room.shot_cooldown = 0
	room.shot.clear_points()
	room.rope.clear_points()
	room.rope_far_wrap.clear_points()
	room.player.action_time = 0
	room.eleanor.action_time = 0
	room.player.turn.cancel()
	room.eleanor.turn.cancel()
	room.player.pose(false)
	room.eleanor.pose(false)
	lantern.sync_after_load()
	mechanic.sync_after_load()
	cart.sync_after_load()
	ines.sync_after_load()
	birdie.sync_after_load()
	for entry in simple_companions: entry.room.sync_after_load()
	sync_lantern_equipment()
	# An unanswered question is restored as a question. build_choice_buttons()
	# only ever builds the row once, so a row hidden by a decision made earlier
	# in this session has to be put back on screen for a save where the choice
	# is still open, and taken back off for one where it is settled.
	if room.rustler_choice_pending():
		room.build_choice_buttons()
		for button in room.choice_buttons:
			if not is_instance_valid(button): continue
			button.visible = true
			button.disabled = room.qa_mode
		room.layout_ui()
	else:
		room.hide_choice_buttons()
	tell("Outfit restored. Your companions and completed actions are remembered.")
	return true



