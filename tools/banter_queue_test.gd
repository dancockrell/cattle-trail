extends SceneTree
const Queue = preload("res://scripts/banter_queue.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var queue := Queue.new()
	check(queue.take().is_empty(),"Empty take")
	var payload := {"instance_id":123,"nested":{"text":"original"}}
	check(queue.offer("a",payload,1),"Offer accepted")
	payload.nested.text = "changed"
	check(not queue.offer("a",{},2),"Duplicate pending beat rejected without refresh")
	check(queue.offer("b",{},1) and not queue.offer("c",{},1),"Full equal priority does not replace")
	var first: Dictionary = queue.take()
	check(first.beat == "a" and first.payload.nested.text == "original","FIFO and deeply copied payload")
	check(first.remaining == 6.0 and queue.take().beat == "b","Default TTL and second FIFO")
	queue.offer("low",{},0)
	queue.offer("high",{},2)
	check(queue.take().beat == "high" and queue.take().beat == "low","Higher priority first")
	queue.offer("old",{},1)
	queue.offer("new",{},0)
	check(queue.offer("urgent",{},2),"Strictly higher insertion replaces oldest lower entry")
	check(queue.take().beat == "urgent" and queue.take().beat == "new","Oldest lower replacement, not lowest priority")
	queue.offer("protected",{},2)
	queue.offer("replaceable",{},0)
	check(queue.offer("medium",{},1),"Replacement skips protected oldest")
	check(queue.take().beat == "protected" and queue.take().beat == "medium","Higher pending survives replacement")
	for ttl in [0.0,-1.0,NAN,INF,-INF]:
		check(not queue.offer("invalid",{},0,ttl),"Invalid TTL rejected")
	check(not queue.offer("",{},0),"Empty beat rejected")
	queue.offer("expiry",{},0,2.0)
	for delta in [-1.0,NAN,INF]: queue.tick(delta)
	queue.tick(1.0)
	check(queue.take().remaining == 1.0,"Invalid ticks do not extend or corrupt TTL")
	queue.offer("expired",{},0,2.0)
	queue.tick(2.0)
	check(queue.take().is_empty() and queue.offer("expired",{},0),"Expiry releases pending dedupe")
	queue.clear()
	queue.offer("bounded",{},0,100.0)
	queue.tick(9.0)
	check(queue.take().remaining == 1.0,"Maximum TTL bounded to ten seconds")
	queue.offer("clear",{},0)
	queue.clear()
	check(queue.take().is_empty() and queue.offer("clear",{},0),"Clear removes entries and dedupe")
	queue.clear()
	var node := Node.new()
	check(not queue.offer("node",{"nested":[node]},0),"Live Node rejected even nested")
	node.free()
	var cyclic := {}
	cyclic["self"] = cyclic
	check(not queue.offer("cycle",cyclic,0),"Cyclic payload rejected safely")
	cyclic.clear()
	queue.offer("render",{},1)
	queue.take()
	check(queue.offer("render",{},1),"Taking does not permanently mark beat spoken")
	if failures == 0: print("BANTER QUEUE PASS: %d checks" % checks)
	else: print("BANTER QUEUE FAIL: %d of %d checks" % [failures,checks])
	quit(1 if failures > 0 else 0)
