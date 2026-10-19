extends RefCounted
const Defs = preload("res://scripts/adventure/definitions.gd")
const Legacy = preload("res://scripts/adventure/legacy_state.gd")
const Logistics = preload("res://scripts/adventure/logistics.gd")
var logistics = Logistics.new()
var wide_view = false
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
var levels = {"axe": 0, "cut_range": 0, "collect_range": 0}
var projects = {"bridge": 0, "workshop": 0, "high_bridge": 0}
var events: Array = []
var target = -1
var targets: Array = []
var migrated_refund = 0
var migration_credit = 0
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
  trees.append({"position": item.position, "kind": item.kind, "hp": Defs.KINDS[item.kind].hp, "regrow": 0.0, "fall": 0.0, "cycle": 0, "harvested": false, "quality": Defs.quality(item.position)})

func capacity() -> int:
 return Defs.CARRY_CAPACITY

func speed() -> float:
 return Defs.WALK_SPEED

func cut_radius() -> float:
 return Defs.CUT_RADII[levels.cut_range]

func collect_radius() -> float:
 return Defs.COLLECT_RADII[levels.collect_range]

func tool_name() -> String:
 return Defs.TOOL_NAMES[levels.cut_range]

func tool_tier() -> int:
 return 0 if levels.cut_range==0 else (1 if levels.cut_range<3 else (2 if levels.cut_range<5 else 3))

func resource_reachable(at: Vector2) -> bool:
 # Expanded tools reach whole groves, but never through buildings or water.
 var steps=maxi(1,int(ceil(position.distance_to(at)/0.45)))
 for step in range(1,steps+1):
  var p=position.lerp(at,float(step)/steps)
  for rect in building_rects():
   if rect.has_point(p): return false
  var land=false
  for area in 3:
   if area_open(area) and Defs.in_area(p,area): land=true;break
  if not land:
   for i in Defs.BRIDGES.size():
    if complete("bridge" if i==0 else "high_bridge") and Defs.BRIDGES[i].grow(0.05).has_point(p): land=true;break
  if not land: return false
 return true

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

func value(kind: int, quality: int = 0, stage: int = 0) -> int:
 return Defs.KINDS[kind].value * (1+quality) * [1,2,4][clampi(stage,0,2)]

func building_rects() -> Array:
 var result=[Defs.BUILDINGS[0]]
 for site in logistics.sites: result.append(logistics.footprint(site))
 return result

func active_projects() -> Array:
 return [Defs.PROJECTS[0],Defs.PROJECTS[2]]

func price(key: String) -> int:
 if not levels.has(key): return 0
 return int(round(Defs.BASE_PRICES[key] * pow(1.65, levels[key])))

func walkable(p: Vector2) -> bool:
 var inside = false
 for i in Defs.AREAS.size():
  if area_open(i) and Defs.in_area(p,i,Defs.PLAYER_RADIUS): inside=true
 for i in Defs.BRIDGES.size():
  if complete("bridge" if i == 0 else "high_bridge"):
   # Extend the corridor over both banks so the radius doesn't leave a seam.
   var corridor = Defs.BRIDGES[i].grow_individual(-Defs.PLAYER_RADIUS, 0.7, -Defs.PLAYER_RADIUS, 0.7)
   if corridor.has_point(p): inside = true
 if not inside: return false
 for rect in building_rects():
  if rect.grow(Defs.PLAYER_RADIUS).has_point(p): return false
 for tree in trees:
  if tree.hp > 0 and tree.position.distance_to(p) < 0.42 + Defs.PLAYER_RADIUS:
   return false
 return true

func move(direction: Vector2, delta: float) -> void:
 var input = direction.limit_length(1.0)
 velocity = input * speed() * (1.15 if logistics.has_road(self,Logistics.cell(position)) else 1.0)
 if input.length() > 0.05:
  facing = input.normalized()
  target = -1
  targets.clear()
  chop_clock = 0
  transfer_clock = 0
 # High default speed still cannot skip a trunk or a river bank.
 var steps = maxi(1,int(ceil(velocity.length()*delta/(Defs.PLAYER_RADIUS*0.5))))
 for step in steps:
  var destination = position + velocity * delta / steps
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
 targets.clear()
 for tree in trees:
  tree.fall = maxf(0, tree.fall - dt)
  if tree.hp <= 0:
   tree.regrow = maxf(0, tree.regrow - dt)
   if tree.regrow <= 0 and tree.position.distance_to(position) > 1.1 and not logistics.blocks_regrowth(tree.position):
    tree.hp = Defs.KINDS[tree.kind].hp
    tree.harvested = false
    logistics.invalidate_navigation()
    events.append({"type": "regrow", "position": tree.position})
 logistics.tick(self,dt)
 pickup()
 if direction.length() > 0.05:
  return
 for sale in Defs.MARKETS:
  if area_open(sale.area) and position.distance_to(sale.position)<1.2:
   target=-1
   unload(dt,"sale",sale.position)
   return
 for site in logistics.sites:
  if position.distance_to(site.position)<1.05:
   target=-1
   logistics.player_transfer(self,site.id,dt)
   return
 for project in active_projects():
  if area_open(project.area) and not complete(project.id) and position.distance_to(project.position) < 1.1:
   target = -1
   unload(dt, project.id)
   return
 transfer_clock = 0
 if bag.size() >= capacity():
  target = -1
  notice = "満載！ 中央基地へ出荷するか、橋へ運ぼう"
  return
 var chosen = -1
 var distance = cut_radius()
 for i in trees.size():
  var tree = trees[i]
  var d = tree.position.distance_to(position)
  if tree.hp > 0 and area_open(tree.kind) and d < cut_radius() and resource_reachable(tree.position):
   targets.append(i)
   if d < distance:
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
  for index in targets:
   var tree = trees[index]
   # Reserve each complete yield before committing damage, including multi-cut.
   if ground.size() + Defs.KINDS[tree.kind]["yield"] > Defs.MAX_GROUND:
    notice = "落ちている丸太を先に運ぼう"
    continue
   tree.hp = maxi(0, tree.hp - damage())
   events.append({"type": "hit", "position": tree.position, "tree": index})
   if tree.hp == 0: fell(index)

func fell(index: int) -> void:
 var tree = trees[index]
 if tree.hp > 0 or tree.harvested or ground.size()+Defs.KINDS[tree.kind]["yield"]>Defs.MAX_GROUND: return
 logistics.invalidate_navigation()
 tree.harvested = true
 tree.regrow = Defs.KINDS[tree.kind].regrow
 tree.fall = 0.72
 tree.cycle += 1
 if first_cut < 0: first_cut = elapsed
 for i in Defs.KINDS[tree.kind]["yield"]:
  var offset = Vector2(cos(i * 2.4), sin(i * 2.4)) * (0.32 + i * 0.16)
  ground.append({"id": next_id, "kind": tree.kind, "position": tree.position + offset, "quality": tree.quality, "stage":0})
  next_id += 1
  created[tree.kind] += 1
 events.append({"type": "fell", "position": tree.position, "tree": index})
 notice = "丸太に近づくと自動で背負える"

func pickup() -> void:
 for i in range(ground.size() - 1, -1, -1):
  if bag.size() >= capacity(): break
  if ground[i].position.distance_to(position) < collect_radius() and area_open(ground[i].kind) and resource_reachable(ground[i].position):
   var log = ground[i]
   bag.append({"id": log.id, "kind": log.kind, "quality": log.get("quality",0), "stage":log.get("stage",0)})
   ground.remove_at(i)
   events.append({"type": "pickup", "from": log.position, "kind": log.kind, "id": log.id})

func unload(delta: float, destination: String, sale_at: Vector2 = Defs.SALE) -> void:
 if destination == "sale" and (sale_at.distance_to(Defs.SALE)>0.01 or position.distance_to(Defs.SALE)>=1.2): return
 if destination != "sale" and (not projects.has(destination) or complete(destination)): return
 if bag.is_empty():
  transfer_clock = 0
  return
 transfer_clock += delta
 var interval = 0.04
 while transfer_clock >= interval and not bag.is_empty():
  transfer_clock -= interval
  var log = bag.pop_back()
  var end = sale_at
  if destination == "sale":
   sell_log(log,end)
   notice = "売上！ 伐採道具や収集範囲を強化してみよう"
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

func nearest_sale() -> Vector2:
 return Defs.SALE

func log_value(log: Dictionary) -> int:
 return value(log.kind,int(log.get("quality",0)),int(log.get("stage",0)))

func sell_log(log: Dictionary, at: Vector2, automatic: bool = false) -> bool:
 # The terminal is the sole income boundary. Regional warehouses never pay.
 if at.distance_to(Defs.SALE)>0.01: return false
 var amount=log_value(log)
 money+=amount
 sold[log.kind]+=1
 if not automatic and first_sale<0: first_sale=elapsed
 events.append({"type":"auto_sell" if automatic else "sell","id":log.id,"kind":log.kind,"amount":amount,"to":Defs.SALE})
 return true

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
  var held = logistics.held(kind)
  for log in bag: held += 1 if log.kind == kind else 0
  for log in ground: held += 1 if log.kind == kind else 0
  if created[kind] != held + sold[kind] + spent[kind]: return false
 return true

func snapshot() -> Dictionary:
 var state = {"version": 9, "migration_credit":migration_credit, "logistics": logistics.snapshot(), "wide_view": wide_view, "position": [position.x, position.y], "facing": [facing.x, facing.y], "money": money, "levels": levels.duplicate(), "projects": projects.duplicate(), "created": created.duplicate(), "sold": sold.duplicate(), "spent": spent.duplicate(), "next_id": next_id, "elapsed": elapsed, "timings": [first_cut,first_sale,first_upgrade,bridge_time], "trees": [], "ground": [], "bag": bag.duplicate(true)}
 for tree in trees:
  state.trees.append({"hp": tree.hp, "regrow": tree.regrow, "fall": tree.fall, "cycle": tree.cycle})
 for log in ground:
  state.ground.append({"id": log.id, "kind": log.kind, "position": [log.position.x, log.position.y], "quality": log.get("quality",0), "stage":log.get("stage",0)})
 return state

static func number(v, low: float, high: float, integer: bool = false) -> bool:
 return (v is float or v is int) and is_finite(float(v)) and float(v) >= low and float(v) <= high and (not integer or float(v) == floor(float(v)))

static func pair(v) -> bool:
 return v is Array and v.size() == 2 and number(v[0],-1000,1000) and number(v[1],-1000,1000)

func restore(data: Dictionary) -> bool:
 # Build a candidate: failures leave this game completely unchanged.
 if data.get("version")==5 or data.get("version")==6: return migrate(data)
 if data.get("version")!=7 and data.get("version")!=8 and data.get("version")!=9: return false
 var candidate = get_script().new()
 for key in ["position","facing"]:
  if not pair(data.get(key)): return false
 if not number(data.get("money"),0,1e10,true) or not number(data.get("next_id"),1,1e8,true) or not number(data.get("elapsed"),0,1e9): return false
 for group in ["levels","projects"]:
  if not data.get(group) is Dictionary: return false
 var purchase_prices=Defs.BASE_PRICES
 if data.levels.size()!=3: return false
 for key in purchase_prices:
  if not number(data.levels.get(key),0,Defs.MAX_LEVEL,true): return false
  if candidate.levels.has(key): candidate.levels[key] = int(data.levels[key])
 for project in Defs.PROJECTS:
  if not number(data.projects.get(project.id),0,project.need,true): return false
  candidate.projects[project.id] = int(data.projects[project.id])
 if not candidate.complete("bridge") and (candidate.projects.workshop > 0 or candidate.projects.high_bridge > 0): return false
 for group in ["created","sold","spent"]:
  if not data.get(group) is Array or data[group].size() != 3: return false
  for i in 3:
   if not number(data[group][i],0,1e8,true): return false
  candidate.set(group, [int(data[group][0]),int(data[group][1]),int(data[group][2])])
 for kind in 3:
  if candidate.created[kind]>0 and not candidate.area_open(kind): return false
 var total = candidate.created[0]+candidate.created[1]+candidate.created[2]
 if data.next_id != total + 1: return false
 if candidate.spent[0]+candidate.spent[1]+candidate.spent[2] != candidate.projects.bridge + candidate.projects.workshop + candidate.projects.high_bridge: return false
 if not data.get("trees") is Array or data.trees.size() != trees.size(): return false
 var produced = [0,0,0]
 for i in data.trees.size():
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
 var saved_capacity=candidate.capacity()
 if not data.get("bag") is Array or data.bag.size() > saved_capacity: return false
 if not data.get("ground") is Array or data.ground.size() > Defs.MAX_GROUND: return false
 for group in ["bag","ground"]:
  for log in data[group]:
   if not log is Dictionary or not number(log.get("id"),1,total,true) or not number(log.get("kind"),0,2,true): return false
   var id = int(log.id)
   var kind = int(log.kind)
   if ids.has(id) or not candidate.area_open(kind): return false
   ids[id] = true
   var restored = {"id": id,"kind": kind}
   if not number(log.get("quality",0),0,2,true): return false
   restored.quality=int(log.get("quality",0))
   if not number(log.get("stage",0),0,2,true) or (group=="ground" and log.get("stage",0)!=0): return false
   restored.stage=int(log.get("stage",0))
   if group == "ground":
    if not pair(log.get("position")): return false
    var at = Vector2(log.position[0],log.position[1])
    var on_land=false
    for area in 3:
     if candidate.area_open(area) and Defs.AREAS[area].grow(1).has_point(at): on_land=true
    if not on_land: return false
    restored.position = at
   candidate.get(group).append(restored)
 if not data.get("wide_view") is bool: return false
 candidate.wide_view=data.wide_view
 if not candidate.logistics.restore(candidate,data.get("logistics"),ids,total,data.get("version")==7,data.get("version")!=9): return false
 if not candidate.conserved(): return false
 if not data.get("timings") is Array or data.timings.size() != 4: return false
 for v in data.timings:
  if not number(v,-1,data.elapsed): return false
 candidate.first_cut = float(data.timings[0])
 candidate.first_sale = float(data.timings[1])
 candidate.first_upgrade = float(data.timings[2])
 candidate.bridge_time = float(data.timings[3])
 # Money can only come from sold logs. Validate it against recorded purchases.
 var costs = candidate.logistics.costs()
 for key in purchase_prices:
  for level in int(data.levels[key]): costs += int(round(purchase_prices[key] * pow(1.65,level)))
 var base_income = 0
 for kind in 3: base_income += candidate.sold[kind] * Defs.KINDS[kind].value
 if not number(data.get("migration_credit",0),0,1e8,true): return false
 candidate.migration_credit=int(data.get("migration_credit",0))
 var income = int(data.money) + costs - candidate.migration_credit
 var maximum_income=0
 for kind in 3: maximum_income+=candidate.sold[kind]*candidate.value(kind,2,2)
 if income < base_income or income > maximum_income: return false
 candidate.money = int(data.money)+candidate.migrated_refund
 candidate.next_id = int(data.next_id)
 candidate.elapsed = float(data.elapsed)
 candidate.position = Vector2(data.position[0],data.position[1])
 if not candidate.walkable(candidate.position): candidate.position = Defs.SPAWN
 candidate.facing = Vector2(data.facing[0],data.facing[1]).normalized()
 if candidate.facing == Vector2.ZERO: candidate.facing = Vector2(0,-1)
 for key in ["logistics","migration_credit","wide_view","position","facing","money","levels","projects","created","sold","spent","next_id","elapsed","first_cut","first_sale","first_upgrade","bridge_time","trees","ground","bag","migrated_refund"]:
  set(key,candidate.get(key))
 velocity = Vector2.ZERO
 target = -1
 targets.clear()
 chop_clock = 0
 transfer_clock = 0
 events.clear()
 return true

func nearest_tree_position() -> Vector2:
 var nearest = position
 var distance = 1e9
 for tree in trees:
  if tree.hp > 0 and area_open(tree.kind) and tree.position.distance_to(position)<distance:
   nearest = tree.position
   distance = tree.position.distance_to(position)
 return nearest

func goal() -> Dictionary:
 var first_delivery = sold[0] + sold[1] + sold[2] == 0
 if first_delivery or (levels.cut_range == 0 and money<price("cut_range")):
  var cargo_value = 0
  for log in bag: cargo_value += log_value(log)
  if not bag.is_empty() and (first_delivery or bag.size()>=capacity() or money+cargo_value>=price("cut_range")):
   return {"text": "丸太を中央基地へ届けよう", "position": nearest_sale(), "label": "中央基地"}
  var text = "木のそばで止まって伐採" if first_delivery else "木材を売って強化  %d / %d" % [money,price("cut_range")]
  return {"text": text, "position": nearest_tree_position(), "label": "木"}
 if levels.cut_range == 0:
  return {"text": "道具で伐採範囲を広げよう", "position": position, "label": "道具"}
 for project in active_projects():
  if not complete(project.id):
   return {"text": "%s  %d / %d 本" % [project.name,projects[project.id],project.need], "position": project.position, "label": "工房" if project.id == "workshop" else "橋"}
 if logistics.sites.is_empty():
  return {"text":"建設・物流から中間集積所を配置しよう", "position":position, "label":"建設"}
 return {"text":"奥地の良質材は最大3倍。基地へ出荷しよう", "position":Vector2(-24,-193), "label":"良質な白樺"}

func summary() -> Dictionary:
 var state = snapshot()
 state["bag_count"] = bag.size()
 state["capacity"] = capacity()
 state["speed"] = speed()
 state["damage"] = damage()
 state["target"] = target
 state["targets"] = targets.duplicate()
 state["cut_radius"] = cut_radius()
 state["collect_radius"] = collect_radius()
 state["tool_name"] = tool_name()
 state["tool_tier"] = tool_tier()
 state["velocity"] = [velocity.x,velocity.y]
 state["conserved"] = conserved()
 state["prices"] = {}
 for key in levels: state.prices[key]=price(key)
 state["markets"] = []
 for sale in Defs.MARKETS: state.markets.append({"position":[sale.position.x,sale.position.y],"area":sale.area,"open":area_open(sale.area)})
 state["world_bounds"] = [Defs.WORLD_BOUNDS.position.x,Defs.WORLD_BOUNDS.position.y,Defs.WORLD_BOUNDS.size.x,Defs.WORLD_BOUNDS.size.y]
 state["base"] = [Defs.SALE.x,Defs.SALE.y]
 state["layout"] = []
 for tree in trees: state.layout.append({"position": [tree.position.x,tree.position.y],"kind":tree.kind,"quality":tree.quality,"value":value(tree.kind,tree.quality)})
 return state

func migrate(data: Dictionary) -> bool:
 # Validate the entire old simulation before any conversion or refund.
 var old=Legacy.new()
 if not old.restore(data): return false
 var converted=old.snapshot()
 converted.version=7
 converted.erase("automation")
 var network=Logistics.new()
 network.roads=old.logistics.roads.duplicate()
 network.road_paid=old.logistics.road_paid
 network.carts=old.logistics.carts.duplicate(true)
 for area in 3:
  if old.automation.levels[area].camp>0:
   var site=network.make_site("camp%d" % area,"storage",Defs.CAMPS[area],old.automation.levels[area].camp)
   site.output=old.automation.stocks[area].duplicate(true)
   site.output.append_array(old.automation.cutters[area].cargo.duplicate(true))
   site.output.append_array(old.automation.porters[area].cargo.duplicate(true))
   site.worker_enabled=true
   network.sites.append(site)
  if old.logistics.depot_levels[area]>0:
   var site=network.make_site("depot%d" % area,"storage",Logistics.LEGACY_DEPOTS[area],old.logistics.depot_levels[area])
   site.legacy_depot=true
   site.output=old.logistics.stocks[area].duplicate(true)
   network.sites.append(site)
 converted.logistics=network.snapshot()
 # Old structures and passive price bonuses retire. Their cash purchases and
 # fixed workshop construction are credited exactly once; all wood IDs remain.
 var refund=old.automation.costs()
 for area in 3:
  for level in old.logistics.depot_levels[area]: refund+=old.logistics.depot_price(area,level)
 refund+=old.projects.workshop*10+old.migrated_refund
 converted.migration_credit=old.projects.workshop*10
 converted.money=old.money+refund-old.migrated_refund
 if not restore(converted): return false
 migrated_refund=refund
 return true
