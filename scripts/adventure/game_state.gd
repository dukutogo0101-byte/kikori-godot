extends RefCounted
const Defs = preload("res://scripts/adventure/definitions.gd")
var position = Defs.SPAWN
var facing = Vector2(0, -1)
var velocity = Vector2.ZERO
var trees: Array = []
var ground: Array = []
var bag: Array = []
var money = 0
var sold = [0, 0, 0]
var spent = [0, 0, 0]
var created = [0, 0, 0]
var next_id = 1
var levels = {"axe": 0, "pack": 0, "boots": 0}
var projects = {"bridge": 0, "workshop": 0, "high_bridge": 0}
var events: Array = []
var target = -1
var chop_clock = 0.0
var transfer_clock = 0.0
var elapsed = 0.0
var first_cut = -1.0
var first_sale = -1.0
var first_upgrade = -1.0
var bridge_time = -1.0
var notice = "森へドラッグして移動。木のそばで止まろう"

func _init() -> void:
 for item in Defs.tree_layout():
  trees.append({"position": item.position, "kind": item.kind, "hp": Defs.KINDS[item.kind].hp, "regrow": 0.0, "fall": 0.0, "cycle": 0, "harvested": false})

func capacity() -> int:
 return 6 + int(levels.pack) * 4

func speed() -> float:
 return 3.2 + int(levels.boots) * 0.55

func damage() -> int:
 return 1 + int(levels.axe)

func cut_interval() -> float:
 return maxf(0.23, 0.42 - int(levels.axe) * 0.022)

func complete(id: String) -> bool:
 for project in Defs.PROJECTS:
  if project.id == id:
   return projects[id] >= project.need
 return false

func area_open(area: int) -> bool:
 return area == 0 or (area == 1 and complete("bridge")) or (area == 2 and complete("high_bridge"))

func value(kind: int) -> int:
 return int(Defs.KINDS[kind].value * (1.5 if complete("workshop") else 1.0))

func price(key: String) -> int:
 return int(round(Defs.BASE_PRICES[key] * pow(1.65, levels[key])))

func walkable(p: Vector2) -> bool:
 var inside = false
 for i in Defs.AREAS.size():
  if area_open(i) and Defs.AREAS[i].grow(-Defs.PLAYER_RADIUS).has_point(p):
   inside = true
 for i in Defs.BRIDGES.size():
  if complete("bridge" if i == 0 else "high_bridge"):
   # Extend the corridor over both banks so the radius doesn't leave a seam.
   var corridor = Defs.BRIDGES[i].grow_individual(-Defs.PLAYER_RADIUS, 0.7, -Defs.PLAYER_RADIUS, 0.7)
   if corridor.has_point(p): inside = true
 if not inside: return false
 for rect in Defs.BUILDINGS:
  if rect.grow(Defs.PLAYER_RADIUS).has_point(p): return false
 for tree in trees:
  if tree.hp > 0 and tree.position.distance_to(p) < 0.42 + Defs.PLAYER_RADIUS:
   return false
 return true

func move(direction: Vector2, delta: float) -> void:
 var input = direction.limit_length(1.0)
 velocity = input * speed()
 if input.length() > 0.05:
  facing = input.normalized()
  target = -1
  chop_clock = 0
  transfer_clock = 0
 var destination = position + velocity * delta
 if walkable(destination):
  position = destination
 else:
  # Slide on obstacles, rather than snagging on corners.
  var x = Vector2(destination.x, position.y)
  if walkable(x): position = x
  var z = Vector2(position.x, destination.y)
  if walkable(z): position = z

func tick(delta: float, direction: Vector2) -> void:
 var dt = clampf(delta, 0, 0.1)
 elapsed += dt
 events.clear()
 move(direction, dt)
 for tree in trees:
  tree.fall = maxf(0, tree.fall - dt)
  if tree.hp <= 0:
   tree.regrow = maxf(0, tree.regrow - dt)
   if tree.regrow <= 0 and tree.position.distance_to(position) > 1.1:
    tree.hp = Defs.KINDS[tree.kind].hp
    tree.harvested = false
    events.append({"type": "regrow", "position": tree.position})
 pickup()
 if direction.length() > 0.05:
  return
 if position.distance_to(Defs.SALE) < 1.2:
  target = -1
  unload(dt, "sale")
  return
 for project in Defs.PROJECTS:
  if area_open(project.area) and not complete(project.id) and position.distance_to(project.position) < 1.1:
   target = -1
   unload(dt, project.id)
   return
 transfer_clock = 0
 if bag.size() >= capacity():
  target = -1
  notice = "満載！ 金色の売り場か、橋へ運ぼう"
  return
 var chosen = -1
 var distance = 1.62
 for i in trees.size():
  var tree = trees[i]
  var d = tree.position.distance_to(position)
  if tree.hp > 0 and area_open(tree.kind) and d < distance:
   chosen = i
   distance = d
 if chosen != target:
  chop_clock = 0
  target = chosen
 if target < 0: return
 facing = (trees[target].position - position).normalized()
 chop_clock += dt
 if chop_clock >= cut_interval():
  chop_clock -= cut_interval()
  var tree = trees[target]
  # Refuse to spawn beyond the ground cap; never discard an existing resource.
  if ground.size() + Defs.KINDS[tree.kind]["yield"] > Defs.MAX_GROUND:
   notice = "落ちている丸太を先に運ぼう"
   return
  tree.hp = maxi(0, tree.hp - damage())
  events.append({"type": "hit", "position": tree.position, "tree": target})
  if tree.hp == 0:
   fell(target)

func fell(index: int) -> void:
 var tree = trees[index]
 if tree.hp > 0 or tree.harvested: return
 tree.harvested = true
 tree.regrow = Defs.KINDS[tree.kind].regrow
 tree.fall = 0.72
 tree.cycle += 1
 if first_cut < 0: first_cut = elapsed
 for i in Defs.KINDS[tree.kind]["yield"]:
  var offset = Vector2(cos(i * 2.4), sin(i * 2.4)) * (0.32 + i * 0.16)
  ground.append({"id": next_id, "kind": tree.kind, "position": tree.position + offset})
  next_id += 1
  created[tree.kind] += 1
 events.append({"type": "fell", "position": tree.position, "tree": index})
 notice = "丸太に近づくと自動で背負える"

func pickup() -> void:
 for i in range(ground.size() - 1, -1, -1):
  if bag.size() >= capacity(): break
  if ground[i].position.distance_to(position) < 1.65:
   var log = ground[i]
   bag.append({"id": log.id, "kind": log.kind})
   ground.remove_at(i)
   events.append({"type": "pickup", "from": log.position, "kind": log.kind, "id": log.id})

func unload(delta: float, destination: String) -> void:
 if destination != "sale" and (not projects.has(destination) or complete(destination)): return
 if bag.is_empty():
  transfer_clock = 0
  return
 transfer_clock += delta
 var interval = 0.105
 while transfer_clock >= interval and not bag.is_empty():
  transfer_clock -= interval
  var log = bag.pop_back()
  var end = Defs.SALE
  if destination == "sale":
   var amount = value(log.kind)
   money += amount
   sold[log.kind] += 1
   if first_sale < 0: first_sale = elapsed
   events.append({"type": "sell", "id": log.id, "kind": log.kind, "amount": amount, "to": end})
   notice = "売上！ リュックや斧を強化してみよう"
  else:
   projects[destination] += 1
   spent[log.kind] += 1
   for project in Defs.PROJECTS:
    if project.id == destination: end = project.position
   events.append({"type": "deposit", "id": log.id, "kind": log.kind, "to": end})
   if complete(destination):
    if destination == "bridge": bridge_time = elapsed
    events.append({"type": "complete", "id": destination, "position": end})
    notice = "橋が完成！ 新しい森へ" if destination != "workshop" else "工房が完成！ 木材の売値が1.5倍"
    transfer_clock = 0
    break

func buy(key: String) -> bool:
 if not levels.has(key) or levels[key] >= Defs.MAX_LEVEL or money < price(key): return false
 money -= price(key)
 levels[key] += 1
 if first_upgrade < 0: first_upgrade = elapsed
 events.append({"type": "upgrade", "id": key})
 notice = "強化！ %sが快適になった" % Defs.UPGRADE_NAMES[key]
 return true

func conserved() -> bool:
 for kind in 3:
  var held = 0
  for log in bag: held += 1 if log.kind == kind else 0
  for log in ground: held += 1 if log.kind == kind else 0
  if created[kind] != held + sold[kind] + spent[kind]: return false
 return true

func snapshot() -> Dictionary:
 var state = {"version": 2, "position": [position.x, position.y], "facing": [facing.x, facing.y], "money": money, "levels": levels.duplicate(), "projects": projects.duplicate(), "created": created.duplicate(), "sold": sold.duplicate(), "spent": spent.duplicate(), "next_id": next_id, "elapsed": elapsed, "timings": [first_cut,first_sale,first_upgrade,bridge_time], "trees": [], "ground": [], "bag": bag.duplicate(true)}
 for tree in trees:
  state.trees.append({"hp": tree.hp, "regrow": tree.regrow, "fall": tree.fall, "cycle": tree.cycle})
 for log in ground:
  state.ground.append({"id": log.id, "kind": log.kind, "position": [log.position.x, log.position.y]})
 return state

static func number(v, low: float, high: float, integer: bool = false) -> bool:
 return (v is float or v is int) and is_finite(float(v)) and float(v) >= low and float(v) <= high and (not integer or float(v) == floor(float(v)))

static func pair(v) -> bool:
 return v is Array and v.size() == 2 and number(v[0],-1000,1000) and number(v[1],-1000,1000)

func restore(data: Dictionary) -> bool:
 # Build a candidate: failures leave this game completely unchanged.
 if data.get("version") != 2: return false
 var candidate = get_script().new()
 for key in ["position","facing"]:
  if not pair(data.get(key)): return false
 if not number(data.get("money"),0,1e10,true) or not number(data.get("next_id"),1,1e8,true) or not number(data.get("elapsed"),0,1e9): return false
 for group in ["levels","projects"]:
  if not data.get(group) is Dictionary: return false
 for key in levels:
  if not number(data.levels.get(key),0,Defs.MAX_LEVEL,true): return false
  candidate.levels[key] = int(data.levels[key])
 for project in Defs.PROJECTS:
  if not number(data.projects.get(project.id),0,project.need,true): return false
  candidate.projects[project.id] = int(data.projects[project.id])
 if not candidate.complete("bridge") and (candidate.projects.workshop > 0 or candidate.projects.high_bridge > 0): return false
 for group in ["created","sold","spent"]:
  if not data.get(group) is Array or data[group].size() != 3: return false
  for i in 3:
   if not number(data[group][i],0,1e8,true): return false
  candidate.set(group, [int(data[group][0]),int(data[group][1]),int(data[group][2])])
 var total = candidate.created[0]+candidate.created[1]+candidate.created[2]
 if data.next_id != total + 1: return false
 if candidate.spent[0]+candidate.spent[1]+candidate.spent[2] != candidate.projects.bridge + candidate.projects.workshop + candidate.projects.high_bridge: return false
 if not data.get("trees") is Array or data.trees.size() != trees.size(): return false
 var produced = [0,0,0]
 for i in trees.size():
  var t = data.trees[i]
  var kind = trees[i].kind
  if not t is Dictionary or not number(t.get("hp"),0,Defs.KINDS[kind].hp,true) or not number(t.get("regrow"),0,Defs.KINDS[kind].regrow) or not number(t.get("fall"),0,0.72) or not number(t.get("cycle"),0,1e7,true): return false
  if t.hp > 0 and (t.regrow != 0 or t.fall != 0): return false
  if t.hp == 0 and t.cycle == 0: return false
  candidate.trees[i].hp = int(t.hp)
  candidate.trees[i].harvested = int(t.hp) == 0
  candidate.trees[i].regrow = float(t.regrow)
  candidate.trees[i].fall = float(t.fall)
  candidate.trees[i].cycle = int(t.cycle)
  produced[kind] += int(t.cycle) * Defs.KINDS[kind]["yield"]
 if produced != candidate.created: return false
 var ids = {}
 if not data.get("bag") is Array or data.bag.size() > candidate.capacity(): return false
 if not data.get("ground") is Array or data.ground.size() > Defs.MAX_GROUND: return false
 for group in ["bag","ground"]:
  for log in data[group]:
   if not log is Dictionary or not number(log.get("id"),1,total,true) or not number(log.get("kind"),0,2,true): return false
   var id = int(log.id)
   var kind = int(log.kind)
   if ids.has(id) or not candidate.area_open(kind): return false
   ids[id] = true
   var restored = {"id": id,"kind": kind}
   if group == "ground":
    if not pair(log.get("position")): return false
    var at = Vector2(log.position[0],log.position[1])
    if not Defs.AREAS[kind].grow(1).has_point(at): return false
    restored.position = at
   candidate.get(group).append(restored)
 if not candidate.conserved(): return false
 if not data.get("timings") is Array or data.timings.size() != 4: return false
 for v in data.timings:
  if not number(v,-1,data.elapsed): return false
 candidate.first_cut = float(data.timings[0])
 candidate.first_sale = float(data.timings[1])
 candidate.first_upgrade = float(data.timings[2])
 candidate.bridge_time = float(data.timings[3])
 # Money can only come from sold logs. Validate it against recorded purchases.
 var costs = 0
 for key in candidate.levels:
  for level in candidate.levels[key]: costs += int(round(Defs.BASE_PRICES[key] * pow(1.65,level)))
 var base_income = 0
 for kind in 3: base_income += candidate.sold[kind] * Defs.KINDS[kind].value
 var income = int(data.money) + costs
 if income < base_income or income > int(base_income * (1.5 if candidate.complete("workshop") else 1)): return false
 candidate.money = int(data.money)
 candidate.next_id = int(data.next_id)
 candidate.elapsed = float(data.elapsed)
 candidate.position = Vector2(data.position[0],data.position[1])
 if not candidate.walkable(candidate.position): candidate.position = Defs.SPAWN
 candidate.facing = Vector2(data.facing[0],data.facing[1]).normalized()
 if candidate.facing == Vector2.ZERO: candidate.facing = Vector2(0,-1)
 for key in ["position","facing","money","levels","projects","created","sold","spent","next_id","elapsed","first_cut","first_sale","first_upgrade","bridge_time","trees","ground","bag"]:
  set(key,candidate.get(key))
 velocity = Vector2.ZERO
 target = -1
 chop_clock = 0
 transfer_clock = 0
 events.clear()
 return true

func goal() -> Dictionary:
 if sold[0] + sold[1] + sold[2] == 0:
  return {"text": "木を切って、金色の売り場へ", "position": Defs.SALE}
 if levels.pack == 0:
  return {"text": "強化でリュックを大きくしよう", "position": Defs.SALE}
 for project in Defs.PROJECTS:
  if not complete(project.id):
   return {"text": "%s  %d / %d 本" % [project.name,projects[project.id],project.need], "position": project.position}
 return {"text": "銀の森を開拓！ 斧や靴を磨こう", "position": Vector2(0,-36)}

func summary() -> Dictionary:
 var state = snapshot()
 state["bag_count"] = bag.size()
 state["capacity"] = capacity()
 state["speed"] = speed()
 state["damage"] = damage()
 state["target"] = target
 state["conserved"] = conserved()
 state["prices"] = {"axe": price("axe"), "pack": price("pack"), "boots": price("boots")}
 state["layout"] = []
 for tree in trees: state.layout.append({"position": [tree.position.x,tree.position.y],"kind":tree.kind})
 return state
