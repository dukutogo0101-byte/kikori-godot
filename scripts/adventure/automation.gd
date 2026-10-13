extends RefCounted
# Active-play automation uses the same trees and resource IDs as the player.
# Every log is in ground, bag, storage, worker cargo, sold or construction.
const Defs = preload("res://scripts/adventure/definitions.gd")
var levels: Array = []
var stocks: Array = [[],[],[]]
var cutters: Array = []
var porters: Array = []

func _init() -> void:
 for area in 3:
  levels.append({"camp":0,"porter":0,"mill":0})
  cutters.append({"position":Defs.CAMPS[area],"target":-1,"clock":0.0,"cargo":[]})
  porters.append({"position":Defs.CAMPS[area],"clock":0.0,"cargo":[]})

func price(area: int, key: String, level: int = -1) -> int:
 var current = int(levels[area][key]) if level < 0 else level
 return int(round(Defs.AUTOMATION[key].price * pow(1.45,area) * pow(2.1,current)))

func capacity(area: int) -> int:
 return 12 + int(levels[area].camp)*8

func can_buy(game, area: int, key: String) -> bool:
 return area>=0 and area<3 and Defs.AUTOMATION.has(key) and game.area_open(area) and levels[area][key]<Defs.AUTO_MAX_LEVEL and (key=="camp" or levels[area].camp>0) and game.money>=price(area,key)

func buy(game, area: int, key: String) -> bool:
 if not can_buy(game,area,key): return false
 game.money-=price(area,key)
 levels[area][key]+=1
 game.notice="%sの%s Lv.%d！" % [Defs.AREA_NAMES[area],Defs.AUTOMATION[key].name,levels[area][key]]
 game.events.append({"type":"upgrade","id":key,"position":Defs.CAMPS[area]})
 return true

func market(area: int) -> Vector2:
 return Defs.MARKETS[0 if area==0 else area+1].position

func travel(game, worker: Dictionary, to: Vector2, dt: float, speed: float) -> bool:
 if worker.position.distance_to(to)<0.04:
  worker.position=to
  return true
 # Outer grove lane, then a clear horizontal aisle. No crossing live trunks.
 var waypoint = to
 if absf(worker.position.y-to.y)>0.04:
  waypoint=Vector2(-8.3,worker.position.y) if absf(worker.position.x+8.3)>0.04 else Vector2(-8.3,to.y)
 var offset = waypoint-worker.position
 var step=offset.normalized()*minf(offset.length(),speed*dt)
 var next=worker.position+step
 if game.walkable(next): worker.position=next
 return false

func tick(game, dt: float) -> void:
 for area in 3:
  if not game.area_open(area) or levels[area].camp==0: continue
  var worker=cutters[area]
  if not worker.cargo.is_empty():
   if travel(game,worker,Defs.CAMPS[area],dt,2.6+levels[area].camp*0.3):
    stocks[area].append_array(worker.cargo)
    worker.cargo.clear()
    worker.target=-1
   continue
  if stocks[area].size()+Defs.KINDS[area]["yield"]>capacity(area):
   worker.target=-1
   continue
  if worker.target<0 or game.trees[worker.target].hp<=0:
   worker.target=-1
   var closest=1e9
   for i in game.trees.size():
    var t=game.trees[i]
    if t.kind==area and is_equal_approx(t.position.x,-10.0) and t.hp>0 and t.position.distance_to(worker.position)<closest:
     worker.target=i
     closest=t.position.distance_to(worker.position)
   worker.clock=0.0
  if worker.target<0: continue
  var tree=game.trees[worker.target]
  if not travel(game,worker,tree.position+Vector2(1.05,0),dt,2.6+levels[area].camp*0.3): continue
  worker.clock+=dt
  if worker.clock<0.65: continue
  worker.clock-=0.65
  if game.ground.size()+Defs.KINDS[area]["yield"]>Defs.MAX_GROUND: continue
  tree.hp=maxi(0,tree.hp-int(levels[area].camp))
  game.events.append({"type":"auto_hit","position":tree.position,"tree":worker.target})
  if tree.hp==0:
   game.fell(worker.target)
   # Collect only this drop; if the player already picked it up, it stays theirs.
   for i in range(game.ground.size()-1,-1,-1):
    var log=game.ground[i]
    if log.kind==area and log.position.distance_to(tree.position)<1.2 and worker.cargo.size()<Defs.KINDS[area]["yield"]:
     worker.cargo.append({"id":log.id,"kind":log.kind})
     game.ground.remove_at(i)
   worker.target=-1
 for area in 3:
  if levels[area].porter==0: continue
  var carrier=porters[area]
  var destination=Defs.CAMPS[area] if carrier.cargo.is_empty() else market(area)
  if not travel(game,carrier,destination,dt,3.0+levels[area].porter*0.6): continue
  if carrier.cargo.is_empty():
   for i in mini(stocks[area].size(),4+levels[area].porter*4): carrier.cargo.append(stocks[area].pop_back())
   carrier.clock=0.0
  else:
   carrier.clock+=dt
   while carrier.clock>=0.105 and not carrier.cargo.is_empty():
    carrier.clock-=0.105
    game.sell_log(carrier.cargo.pop_back(),destination,true)

func held(kind: int) -> int:
 var count=0
 for area in 3:
  for source in [stocks[area],cutters[area].cargo,porters[area].cargo]:
   for log in source: count+=1 if log.kind==kind else 0
 return count

func blocks_regrowth(at: Vector2) -> bool:
 for worker in cutters+porters:
  if worker.position.distance_to(at)<1.1: return true
 return false

func costs() -> int:
 var total=0
 for area in 3:
  for key in Defs.AUTOMATION:
   for level in levels[area][key]: total+=price(area,key,level)
 return total

func snapshot() -> Dictionary:
 var data={"levels":levels.duplicate(true),"stocks":stocks.duplicate(true),"cutters":[],"porters":[]}
 for name in ["cutters","porters"]:
  for worker in get(name):
   var copy=worker.duplicate(true)
   copy.position=[worker.position.x,worker.position.y]
   data[name].append(copy)
 return data

func restore(data, game, ids: Dictionary, total: int) -> bool:
 if not data is Dictionary: return false
 for name in ["levels","stocks","cutters","porters"]:
  if not data.get(name) is Array or data[name].size()!=3: return false
 for area in 3:
  if not data.levels[area] is Dictionary: return false
  for key in Defs.AUTOMATION:
   if not game.number(data.levels[area].get(key),0,Defs.AUTO_MAX_LEVEL,true): return false
   levels[area][key]=int(data.levels[area][key])
  if not game.area_open(area) and levels[area]!={"camp":0,"porter":0,"mill":0}: return false
  if levels[area].camp==0 and (levels[area].porter>0 or levels[area].mill>0): return false
  if not restore_logs(data.stocks[area],stocks[area],area,capacity(area),game,ids,total): return false
  if levels[area].camp==0 and not stocks[area].is_empty(): return false
  for name in ["cutters","porters"]:
   var source=data[name][area]
   var worker=get(name)[area]
   if not source is Dictionary or not game.pair(source.get("position")) or not game.number(source.get("clock"),0,0.65): return false
   var at=Vector2(source.position[0],source.position[1])
   if not Defs.AREAS[area].grow(-Defs.PLAYER_RADIUS).has_point(at): return false
   worker.position=at if game.walkable(at) else Defs.CAMPS[area]
   worker.clock=float(source.clock)
   var limit=Defs.KINDS[area]["yield"] if name=="cutters" else 4+levels[area].porter*4
   if not restore_logs(source.get("cargo"),worker.cargo,area,limit,game,ids,total): return false
   if levels[area]["camp" if name=="cutters" else "porter"]==0 and not worker.cargo.is_empty(): return false
   if name=="cutters":
    if not game.number(source.get("target"),-1,game.trees.size()-1,true): return false
    worker.target=int(source.target)
    if worker.target>=0 and (game.trees[worker.target].kind!=area or game.trees[worker.target].position.x>-10): return false
  if stocks[area].size()+cutters[area].cargo.size()>capacity(area): return false
 return true

func restore_logs(source, destination: Array, area: int, limit: int, game, ids: Dictionary, total: int) -> bool:
 if not source is Array or source.size()>limit: return false
 for log in source:
  if not log is Dictionary or not game.number(log.get("id"),1,total,true) or not game.number(log.get("kind"),area,area,true): return false
  var id=int(log.id)
  if ids.has(id): return false
  ids[id]=true
  destination.append({"id":id,"kind":area})
 return true
