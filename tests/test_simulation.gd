extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Store = preload("res://scripts/save_store.gd")
var failures = 0
var assertions = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func conservation(s: RefCounted) -> bool:
	return s.felled * 3 == s.ground_logs.size() + s.cargo.size() + s.mill_stock + s.processed

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 1e-9
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i], b[i]): return false
		return true
	return a == b

func _initialize() -> void:
	var s = Sim.new()
	check(s.money == 30 and s.workers.size() == 1, "Fresh economy")
	var initial = s.snapshot()
	check(not s.buy("wood") and s.snapshot() == initial, "Insufficient funds cannot mutate state")
	check(not s.buy("unknown"), "Unknown upgrades are rejected")
	s.advance(120)
	check(s.felled > 0 and s.processed > 0 and s.money > 30, "Fell → transport → mill → income completes")
	check(conservation(s), "No logs created or lost in the production loop")
	check(s.earned == s.processed * Sim.LOG_VALUE, "Every processed log is paid once")
	var price = s.cost("wood")
	var before = s.money
	check(s.buy("wood") and s.money == before - price, "Purchase charges its displayed price")
	check(s.workers.size() == 2 and s.levels.wood == 1, "Wood upgrade hires a worker")
	var capacity = s.capacity()
	check(s.buy("truck") and s.capacity() > capacity, "Truck upgrade increases capacity")
	var processing = s.process_seconds()
	check(s.buy("mill") and s.process_seconds() < processing, "Mill upgrade increases processing speed")
	check(s.activate_boost() and not s.activate_boost(), "Boost respects cooldown")
	s.advance(46)
	check(s.boost_left == 0 and s.boost_cooldown == 0 and s.activate_boost(), "Boost expires and can be reused")
	var copy = Sim.new()
	var json_state = JSON.parse_string(JSON.stringify(s.snapshot(), "", true, true))
	check(copy.restore(json_state), "Full state survives JSON round-trip")
	for i in 100:
		s.step(0.1)
		copy.step(0.1)
	check(equivalent(s.snapshot(), copy.snapshot()), "Restored jobs produce the same state within 1ns of timer precision")
	var malformed = s.snapshot()
	malformed.money = -5
	var stable = copy.snapshot()
	check(not copy.restore(malformed) and copy.snapshot() == stable, "Invalid save is rejected atomically")
	for mutate in ["tree", "worker", "cargo", "level", "version", "balance", "fraction"]:
		var data = s.snapshot()
		match mutate:
			"tree": data.trees[0].hp = -1
			"worker": data.workers[0].target = 200
			"cargo": data.cargo.append(200)
			"level": data.levels.wood = 100
			"version": data.version = 999
			"balance": data.felled += 1
			"fraction": data.levels.mill = 0.5
		check(not copy.restore(data), "Reject corrupt field: " + mutate)
	check(not copy.restore(null) and not copy.restore([]) and not copy.restore({}), "Reject invalid document types")
	var bounded = Sim.new()
	bounded.advance(999999)
	check(absf(bounded.elapsed - 600) < 0.01, "Offline simulation is capped at ten minutes")
	var control = Sim.new()
	control.advance(600)
	check(bounded.snapshot() == control.snapshot(), "Offline progress uses the real production loop")
	var regenerating = Sim.new()
	while regenerating.felled == 0:
		regenerating.step(0.1)
	var tree_id = regenerating.ground_logs[0]
	# Freeze workers so we can inspect the tree's complete regrowth.
	regenerating.workers.clear()
	regenerating.advance(25)
	check(regenerating.trees[tree_id].hp == 4 and regenerating.trees[tree_id].regrow == 0, "Trees regenerate")
	var fast = Sim.new()
	fast.money = 1e11
	for kind in ["wood", "truck", "mill"]:
		for i in Sim.MAX_LEVEL:
			check(fast.buy(kind), "Can reach max upgrade " + kind)
		check(fast.cost(kind) == 0 and not fast.buy(kind), "Max upgrade is terminal " + kind)
	for i in 36000:
		fast.step(0.1)
		if i % 100 == 0:
			check(conservation(fast), "Stock conservation under stress")
			check(fast.ground_logs.size() <= Sim.MAX_STOCK and fast.mill_stock <= Sim.MAX_STOCK, "Stock limits under stress")
	check(fast.processed > 1000, "Upgraded factory keeps producing for an hour")
	var crowded = Sim.new()
	crowded.money = 1e8
	for i in 15:
		crowded.buy("wood")
	for i in 24000:
		crowded.step(0.1)
	check(crowded.ground_logs.size() <= Sim.MAX_STOCK and conservation(crowded), "Back pressure is bounded when transport is the bottleneck")
	check(crowded.processed > 100, "Congestion does not deadlock the factory")
	var store = Store.new("user://kikori_test_save.json")
	check(store.write_save(s.snapshot()), "Native atomic save write succeeds")
	var loaded = Sim.new()
	check(loaded.restore(store.read_save()), "Native save read succeeds")
	check(equivalent(s.snapshot(), loaded.snapshot()), "File save preserves the full state")
	DirAccess.remove_absolute("user://kikori_test_save.json")
	print("KIKORI_TESTS assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures else 0)
