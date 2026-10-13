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
  trees.append({"position": item.position, "kind": item.kind, "hp": Defs.KINDS[item.kind].hp, "regrow": 0.0, "fall": 0.0, "cycle": 0})

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
   events.append({"type": "pickup", "from": log.position, "kind": log.kind})

func unload(delta: float, destination: String) -> void:
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
   events.append({"type": "sell", "kind": log.kind, "amount": amount, "to": end})
   notice = "売上！ リュックや斧を強化してみよう"
  else:
   projects[destination] += 1
   spent[log.kind] += 1
   for project in Defs.PROJECTS:
    if project.id == destination: end = project.position
   events.append({"type": "deposit", "kind": log.kind, "to": end})
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
