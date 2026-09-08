extends SceneTree
const Factory = preload("res://scripts/character_factory.gd")
func _initialize():
	var factory = Factory.new()
	var entries := []
	for i in 12:
		entries.append({"id":"mechanic_%02d" % i,"family":"mechanic","age":22,"atlas":"res://candidate.png","rect":[i*64,0,64,64],"anchor":[32,61],"status":"candidate"})
	var catalog := {"variants":entries}
	assert(factory.create_roster(catalog,"clear-fork",10).is_empty())
	var first = factory.create_roster(catalog,"clear-fork",20,true)
	assert(first.size()==12)
	assert(first==factory.create_roster(JSON.parse_string(JSON.stringify(catalog)),"clear-fork",20,true))
	entries.reverse()
	assert(first==factory.create_roster(catalog,"clear-fork",20,true))
	assert(first!=factory.create_roster(catalog,"another-world",20,true))
	var ids := {}
	for actor in first:
		assert(actor.age>=18 and actor.relationship=="unmet" and actor.production_preview)
		assert(not ids.has(actor.art_id))
		ids[actor.art_id]=true
	first[0].sprite.rect[0] = -100
	assert(factory.create_roster(catalog,"clear-fork",20,true)[0].sprite.rect[0]>=0)
	entries[0].status="approved"
	assert(factory.create_roster(catalog,"clear-fork",20).size()==1)
	entries[0].age=17
	assert(factory.create_roster(catalog,"clear-fork",20).is_empty())
	entries.append(entries[1].duplicate(true))
	assert(factory.create_roster(catalog,"clear-fork",20,true).size()==11)
	entries[2].status="rejected"
	assert(factory.create_roster(catalog,"clear-fork",20,true).size()==10)
	print("CHARACTER FACTORY PASS: stable identities, unique art, adult ages, candidate gate, isolated data")
	quit()
