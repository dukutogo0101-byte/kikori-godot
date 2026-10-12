class_name KikoriSimulation
extends RefCounted
## Deterministic economy. No nodes, browser APIs, rendering, or wall-clock dependencies.
const VERSION = 1
const MAX_LEVEL = 20
const MAX_STOCK = 240
const LOG_VALUE = 12
const TREE_COUNT = 18
const REGROW_SECONDS = 24.0
const TREE_SPOTS = [
	Vector3(-6, 0, -4), Vector3(-4, 0, -4.5), Vector3(-2, 0, -4),
	Vector3(-7, 0, -2), Vector3(-5, 0, -2.3), Vector3(-3, 0, -2),
	Vector3(-6.5, 0, 0), Vector3(-4.5, 0, -0.2), Vector3(-2.5, 0, 0),
	Vector3(-7.7, 0, -5), Vector3(-5.5, 0, -6), Vector3(-3.2, 0, -6),
	Vector3(-1, 0, -5.8), Vector3(-8, 0, 0), Vector3(-8, 0, -3.4),
	Vector3(-1, 0, -2.3), Vector3(-6.3, 0, 1.7), Vector3(-4.5, 0, 1.7)]
var money = 30.0
var earned = 0.0
var levels = {"wood": 0, "truck": 0, "mill": 0}
var trees: Array = []
var workers: Array = []
var ground_logs: Array = []
var cargo: Array = []
var mill_stock = 0
var processed = 0
var felled = 0
var truck_phase = "loading"
var truck_clock = 0.0
var mill_clock = 0.0
var elapsed = 0.0
var boost_left = 0.0
var boost_cooldown = 0.0
var events: Array = []

func _init() -> void:
	for i in TREE_COUNT:
		trees.append({"hp": 4, "regrow": 0.0})
	_sync_workers()

func _sync_workers() -> void:
	while workers.size() < mini(5, int(levels.wood) + 1):
		workers.append({"target": -1, "phase": "idle", "clock": 0.0,
			"from": -1, "travel": 1.0})

func cost(kind: String) -> int:
	if not levels.has(kind) or levels[kind] >= MAX_LEVEL:
		return 0
	var base = {"wood": 50, "truck": 70, "mill": 60}
	return int(round(base[kind] * pow(1.65, levels[kind])))

func buy(kind: String) -> bool:
	var price = cost(kind)
	if price <= 0 or money < price:
		return false
	money -= price
	levels[kind] += 1
	_sync_workers()
	return true

func capacity() -> int:
	return 3 + int(levels.truck) * 2

func trip_seconds() -> float:
	return maxf(1.8, 5.0 / (1.0 + float(levels.truck) * 0.12))

func process_seconds() -> float:
	return maxf(0.22, 2.4 / (1.0 + float(levels.mill) * 0.3))

func chop_seconds() -> float:
	return 0.9 / (1.0 + float(levels.wood) * 0.08)

func activate_boost() -> bool:
	if boost_cooldown > 0.0:
		return false
	boost_left = 15.0
	boost_cooldown = 45.0
	return true

func step(dt: float) -> Array:
	events = []
	if not is_finite(dt) or dt <= 0.0:
		return events
	dt = minf(dt, 0.1)
	elapsed += dt
	boost_left = maxf(0.0, boost_left - dt)
	boost_cooldown = maxf(0.0, boost_cooldown - dt)
	var work_dt = dt * (2.0 if boost_left > 0.0 else 1.0)
	for i in TREE_COUNT:
		if trees[i].regrow > 0.0:
			trees[i].regrow = maxf(0.0, trees[i].regrow - dt)
			if trees[i].regrow <= 0.0:
				trees[i].hp = 4
	for w in workers:
		if w.phase == "idle":
			var target = _pick_tree(int(w.from))
			if target >= 0 and ground_logs.size() <= MAX_STOCK - 3:
				w.target = target
				w.phase = "travel"
				w.clock = 0.0
				var start = TREE_SPOTS[w.from] if w.from >= 0 else Vector3(-3, 0, 2)
				w.travel = maxf(0.7, start.distance_to(TREE_SPOTS[target]) / 2.4)
		elif w.phase == "travel":
			w.clock += work_dt
			if w.clock >= w.travel:
				w.phase = "chop"
				w.clock = 0.0
		elif w.phase == "chop":
			# Back pressure pauses axes before producing stock above the cap.
			if ground_logs.size() > MAX_STOCK - 3:
				continue
			w.clock += work_dt
			if w.clock >= chop_seconds():
				w.clock -= chop_seconds()
				var t = int(w.target)
				trees[t].hp -= 1
				events.append({"type": "chop", "tree": t})
				if trees[t].hp <= 0:
					trees[t].regrow = REGROW_SECONDS
					felled += 1
					for n in 3:
						ground_logs.append(t)
					events.append({"type": "fell", "tree": t})
					w.from = t
					w.target = -1
					w.phase = "idle"
					w.clock = 0.0
	truck_clock += work_dt
	match truck_phase:
		"loading":
			if truck_clock >= 0.3 and not ground_logs.is_empty() and cargo.size() < capacity():
				cargo.append(ground_logs.pop_front())
				truck_clock = 0.0
			if not cargo.is_empty() and (cargo.size() >= capacity() or truck_clock > 1.0):
				truck_phase = "outbound"
				truck_clock = 0.0
		"outbound":
			if truck_clock >= trip_seconds():
				truck_phase = "unloading"
				truck_clock = 0.0
		"unloading":
			if truck_clock >= 0.25 and not cargo.is_empty() and mill_stock < MAX_STOCK:
				cargo.pop_front()
				mill_stock += 1
				truck_clock = 0.0
			if cargo.is_empty():
				truck_phase = "returning"
				truck_clock = 0.0
		"returning":
			if truck_clock >= trip_seconds():
				truck_phase = "loading"
				truck_clock = 0.0
	if mill_stock > 0:
		mill_clock += work_dt
		if mill_clock >= process_seconds():
			mill_clock -= process_seconds()
			mill_stock -= 1
			processed += 1
			money += LOG_VALUE
			earned += LOG_VALUE
			events.append({"type": "sale", "value": LOG_VALUE})
	else:
		mill_clock = 0.0
	return events

func _pick_tree(previous: int) -> int:
	var best = -1
	var distance = INF
	var start = TREE_SPOTS[previous] if previous >= 0 else Vector3(-3, 0, 2)
	for i in TREE_COUNT:
		if trees[i].hp <= 0 or trees[i].regrow > 0.0:
			continue
		var reserved = false
		for w in workers:
			if w.target == i:
				reserved = true
		if not reserved:
			var d = start.distance_squared_to(TREE_SPOTS[i])
			if d < distance:
				best = i
				distance = d
	return best

func advance(seconds: float) -> void:
	var ticks = int(clampf(seconds, 0.0, 600.0) * 10.0)
	for i in ticks:
		step(0.1)

func snapshot() -> Dictionary:
	return {"version": VERSION, "money": money, "earned": earned,
		"levels": levels.duplicate(), "trees": trees.duplicate(true),
		"workers": workers.duplicate(true), "ground_logs": ground_logs.duplicate(),
		"cargo": cargo.duplicate(), "mill_stock": mill_stock, "processed": processed,
		"felled": felled, "truck_phase": truck_phase, "truck_clock": truck_clock,
		"mill_clock": mill_clock, "elapsed": elapsed, "boost_left": boost_left,
		"boost_cooldown": boost_cooldown}

static func valid_number(v: Variant, lo: float, hi: float) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and v >= lo and v <= hi

static func valid_int(v: Variant, lo: int, hi: int) -> bool:
	return valid_number(v, lo, hi) and float(v) == floor(float(v))

func restore(data: Variant) -> bool:
	# Validate the complete state before replacing any live values.
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	for key in ["money", "earned", "elapsed"]:
		if not valid_number(data.get(key), 0, 1e12):
			return false
	if not data.get("levels") is Dictionary:
		return false
	for key in ["wood", "truck", "mill"]:
		if not valid_int(data.levels.get(key), 0, MAX_LEVEL):
			return false
	for key in ["mill_stock", "processed", "felled"]:
		if not valid_int(data.get(key), 0, MAX_STOCK if key == "mill_stock" else 1000000000):
			return false
	for key in ["truck_clock", "mill_clock", "boost_left", "boost_cooldown"]:
		if not valid_number(data.get(key), 0, 1e9):
			return false
	if not data.get("truck_phase") in ["loading", "outbound", "unloading", "returning"]:
		return false
	if not data.get("trees") is Array or data.trees.size() != TREE_COUNT:
		return false
	for t in data.trees:
		if not t is Dictionary or not valid_int(t.get("hp"), 0, 4) or not valid_number(t.get("regrow"), 0, REGROW_SECONDS):
			return false
		if (t.hp == 0) != (t.regrow > 0):
			return false
	for key in ["ground_logs", "cargo"]:
		if not data.get(key) is Array or data[key].size() > (MAX_STOCK if key == "ground_logs" else 3 + int(data.levels.truck) * 2):
			return false
		for t in data[key]:
			if not valid_int(t, 0, TREE_COUNT - 1):
				return false
	if data.felled * 3 != data.ground_logs.size() + data.cargo.size() + data.mill_stock + data.processed:
		return false
	if not data.get("workers") is Array or data.workers.size() != mini(5, int(data.levels.wood) + 1):
		return false
	var reserved: Array = []
	for w in data.workers:
		if not w is Dictionary or not w.get("phase") in ["idle", "travel", "chop"]:
			return false
		if not valid_int(w.get("target"), -1, TREE_COUNT - 1) or not valid_int(w.get("from"), -1, TREE_COUNT - 1):
			return false
		if not valid_number(w.get("clock"), 0, 1e9) or not valid_number(w.get("travel"), 0.01, 100):
			return false
		if w.phase != "idle":
			if w.target < 0 or data.trees[int(w.target)].hp <= 0 or reserved.has(int(w.target)):
				return false
			reserved.append(int(w.target))
		elif w.target != -1:
			return false
	money = float(data.money)
	earned = float(data.earned)
	levels = {"wood": int(data.levels.wood), "truck": int(data.levels.truck), "mill": int(data.levels.mill)}
	trees = data.trees.duplicate(true)
	for t in trees:
		t.hp = int(t.hp)
		t.regrow = float(t.regrow)
	workers = data.workers.duplicate(true)
	# JSON numbers are floats: normalize fields that become Array indices.
	for w in workers:
		w.target = int(w.target)
		w.from = int(w.from)
		w.clock = float(w.clock)
		w.travel = float(w.travel)
	ground_logs = data.ground_logs.map(func(t): return int(t))
	cargo = data.cargo.map(func(t): return int(t))
	mill_stock = int(data.mill_stock)
	processed = int(data.processed)
	felled = int(data.felled)
	truck_phase = data.truck_phase
	truck_clock = float(data.truck_clock)
	mill_clock = float(data.mill_clock)
	elapsed = float(data.elapsed)
	boost_left = float(data.boost_left)
	boost_cooldown = float(data.boost_cooldown)
	return true
