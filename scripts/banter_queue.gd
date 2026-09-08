extends RefCounted
## Pending speech only. The caller marks a beat spoken after actual rendering.
const CAPACITY := 2
const DEFAULT_TTL := 6.0
const MAX_TTL := 10.0
var _pending: Array[Dictionary] = []

func offer(beat: String, payload: Dictionary, priority: int, ttl: float = DEFAULT_TTL) -> bool:
	if beat.is_empty() or not is_finite(ttl) or ttl <= 0: return false
	# Serializable payloads must not retain Nodes or other live object references.
	if not _value_safe(payload): return false
	for entry in _pending:
		if entry.beat == beat: return false
	if _pending.size() >= CAPACITY:
		var replace := -1
		for index in range(_pending.size()):
			if int(_pending[index].priority) < priority:
				replace = index
				break
		if replace < 0: return false
		_pending.remove_at(replace)
	_pending.append({"beat":beat,"payload":payload.duplicate(true),"priority":priority,"remaining":minf(ttl,MAX_TTL)})
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	for index in range(_pending.size()-1,-1,-1):
		_pending[index].remaining = maxf(0,float(_pending[index].remaining)-delta)
		if _pending[index].remaining <= 0: _pending.remove_at(index)

func take() -> Dictionary:
	if _pending.is_empty(): return {}
	var selected := 0
	for index in range(1,_pending.size()):
		if int(_pending[index].priority) > int(_pending[selected].priority): selected = index
	var entry: Dictionary = _pending[selected]
	_pending.remove_at(selected)
	return entry.duplicate(true)

func clear() -> void:
	_pending.clear()

func _value_safe(value: Variant, depth: int = 0) -> bool:
	# Bounded traversal also rejects cyclic containers without recursion overflow.
	if depth > 32: return false
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]: return false
	if value is Dictionary:
		for key in value:
			if not _value_safe(key,depth+1) or not _value_safe(value[key],depth+1): return false
	elif value is Array:
		for item in value:
			if not _value_safe(item,depth+1): return false
	return true
