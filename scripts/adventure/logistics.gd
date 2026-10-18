extends RefCounted
# All inventory mutations are synchronous. Cargo reserves depot capacity at load.
const Defs = preload("res://scripts/adventure/definitions.gd")
const ROAD_PRICE = 2
const MAX_ROADS = 1200
const MAX_CARTS = 6
const LEGACY_DEPOTS = [Vector2(0,13),Vector2(0,-66),Vector2(6,-157)]
const DIRS = [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var roads = {}
var road_paid = 0
const MAX_SITES = 16
const FACILITIES = {
 "storage":{"name":"中間集積所","price":180,"color":"67a77c"},
 "processor":{"name":"加工所","price":320,"color":"609db7"},
 "factory":{"name":"製品工場","price":600,"color":"bd9362"}
}
const STAGES = ["丸太","加工材","製品"]
var sites: Array = []
var next_site = 1
var _walk_cache = {}
var carts: Array = []
var revision = 0
var message = "道をつなぎ、荷車の出発地と目的地を選ぼう"
var _paths = {}

static func cell(at: Vector2) -> Vector2i:
 return Vector2i(roundi(at.x),roundi(at.y))

static func line(a: Vector2i, b: Vector2i) -> Array:
 var result=[a]
 var p=a
 while p!=b and result.size()<161:
  if p.x!=b.x: p.x+=1 if b.x>p.x else -1
  elif p.y!=b.y: p.y+=1 if b.y>p.y else -1
  result.append(p)
 return result

func make_site(id: String, kind: String, at: Vector2, level: int = 1) -> Dictionary:
 return {"id":id,"type":kind,"position":at,"level":level,"paid":0,"legacy_depot":false,"input":[],"output":[],"clock":0.0,"mode":"deposit","worker_enabled":true,"worker":{"position":at,"target":-1,"clock":0.0,"wait":0.0,"cargo":[],"path":[],"cursor":0,"return_path":[],"phase":"idle","status":"木を探しています"}}

func site(id: String) -> Dictionary:
 for item in sites:
  if item.id==id: return item
 return {}

func capacity(id: String) -> int:
 var item=site(id)
 return 64*int(item.level) if not item.is_empty() else 0

func footprint(item: Dictionary) -> Rect2:
 return Rect2(item.position+Vector2(-4.2,2.9),Vector2(2.8,2.6)) if item.legacy_depot else Rect2(item.position+Vector2(-1.6,-3.8),Vector2(3.2,2.2))

func price(kind: String, level: int = 0) -> int:
 return int(round(FACILITIES[kind].price*pow(1.8,level))) if FACILITIES.has(kind) else 0

func placement_ok(game, kind: String, at: Vector2) -> bool:
 if not FACILITIES.has(kind) or sites.size()>=MAX_SITES: message="設備は16棟まで配置できます";return false
 if at!=Vector2(cell(at)): message="設備は地面のマスに合わせて配置します";return false
 var draft=make_site("preview",kind,at)
 var rect=footprint(draft).grow(0.5)
 # Both the building and its loading court must lie on accessible dry land.
 for offset in [Vector2(-2,-4.3),Vector2(2,-4.3),Vector2(-2,-1.1),Vector2(2,-1.1),Vector2(-1,0),Vector2(1,0),Vector2(0,1)]:
  var land=false
  for area in 3:
   if game.area_open(area) and Defs.in_area(at+offset,area,0.4): land=true
  if not land: message="岸辺・水・岩・未開放の森には建てられません";return false
 for other in game.building_rects():
  if rect.intersects(other.grow(0.5)) or other.grow(1.4).has_point(at): message="建物と重なっています";return false
 if rect.grow(0.35).has_point(game.position): message="主人公に重ならない場所を選んでください";return false
 for item in sites:
  if at.distance_to(item.position)<4.5 or rect.has_point(item.position) or footprint(item).grow(1.3).has_point(at): message="荷下ろし場の周囲を空けてください";return false
  if rect.grow(0.5).has_point(item.worker.position): message="作業員がいる場所には建てられません";return false
  for p in item.worker.path+item.worker.return_path:
   if rect.has_point(Vector2(p)): message="作業員の通路を空けてください";return false
 for tree in game.trees:
  if tree.hp>0 and (rect.grow(0.8).has_point(tree.position) or tree.position.distance_to(at)<1.5): message="先に木を伐採して敷地を空けてください";return false
 for p in roads:
  if rect.grow(0.4).has_point(Vector2(p)): message="道路と建物が重なっています";return false
 for cart in carts:
  if rect.grow(0.5).has_point(cart.position): message="荷車のいる場所には建てられません";return false
 for project in game.active_projects():
  if at.distance_to(project.position)<4 or rect.grow(1).has_point(project.position): message="橋の入口を空けてください";return false
 if at.distance_to(Defs.SALE)<4 or rect.grow(1).has_point(Defs.SALE): message="中央基地の出荷場を空けてください";return false
 message="配置できます"
 return true

func build(game, kind: String, at: Vector2) -> bool:
 if not placement_ok(game,kind,at): return false
 if game.money<price(kind): message="設備の建設資金が足りません";return false
 var item=make_site("site%d" % next_site,kind,at)
 item.paid=price(kind);game.money-=item.paid
 sites.append(item);next_site+=1
 revision+=1;invalidate_navigation();_paths.clear()
 message=FACILITIES[kind].name+"を建設しました。タップで設定・強化できます"
 return true

func upgrade(game, id: String) -> bool:
 var item=site(id)
 if item.is_empty() or item.level>=3: return false
 var cost=price(item.type,item.level)
 if game.money<cost: message="強化資金が足りません";return false
 game.money-=cost;item.paid+=cost;item.level+=1;item.clock=minf(item.clock,6.0/item.level)
 message="%s Lv.%d！" % [FACILITIES[item.type].name,item.level]
 return true

func endpoints(_game) -> Array:
 var list=[]
 for item in sites:
  list.append({"id":item.id,"name":FACILITIES[item.type].name+" "+item.id,"position":item.position,"type":item.type,"area":0})
 list.append({"id":"market0","name":"中央基地・出荷場","position":Defs.SALE,"type":"market","area":0})
 return list

func endpoint(game, id: String) -> Dictionary:
 for place in endpoints(game):
  if place.id==id: return place
 return {}

func inventory(_game, place: Dictionary) -> Array:
 return site(place.id).output

func accepts(id: String, log: Dictionary) -> bool:
 if id=="market0": return true
 var item=site(id)
 if item.is_empty(): return false
 return item.type=="storage" or int(log.get("stage",0))==(0 if item.type=="processor" else 1)

func incoming(id: String) -> Array:
 var item=site(id)
 return item.output if item.type=="storage" else item.input

func reserved(id: String, except_id: int = -1) -> int:
 var count=0
 for cart in carts:
  if cart.id!=except_id and cart.destination==id: count+=cart.cargo.size()
 var item=site(id)
 if not item.is_empty() and item.type=="storage":
  count+=item.worker.cargo.size()
  if item.worker.cargo.is_empty() and item.worker.target>=0: count+=5
 return count

func free_space(id: String, except_id: int = -1) -> int:
 return maxi(0,capacity(id)-incoming(id).size()-reserved(id,except_id))

func edge_ok(game, a: Vector2i, b: Vector2i) -> bool:
 if abs(a.x-b.x)+abs(a.y-b.y)!=1: return false
 for fraction in [0.25,0.5,0.75]:
  if not game.walkable(Vector2(a).lerp(Vector2(b),fraction)): return false
 return true

func road_valid(game, p: Vector2i) -> bool:
 if not game.walkable(Vector2(p)): return false
 for tree in game.trees:
  if tree.hp>0 and tree.position.distance_to(Vector2(p))<1.25: return false
 return true

func path_between(game, a: Vector2i, b: Vector2i) -> Array:
 var key="%d,%d:%d,%d" % [a.x,a.y,b.x,b.y]
 if _paths.has(key): return _paths[key].duplicate()
 if not roads.has(a) or not roads.has(b): return []
 var queue=[a]
 var previous={a:a}
 var head=0
 while head<queue.size():
  var p=queue[head];head+=1
  if p==b: break
  for direction in DIRS:
   var next=p+direction
   if roads.has(next) and not previous.has(next) and edge_ok(game,p,next):
    previous[next]=p;queue.append(next)
 if not previous.has(b): return []
 var result=[b]
 var p=b
 while p!=a: p=previous[p];result.push_front(p)
 # Cache only the bounded endpoint/route queries; never every editor pixel.
 if _paths.size()>48: _paths.clear()
 _paths[key]=result.duplicate()
 return result

func used_cells(game) -> Dictionary:
 var used={}
 for cart in carts:
  used[cell(cart.position)]=true
  for p in cart.path: used[p]=true
  if not cart.source.is_empty():
   var source=endpoint(game,cart.source);var dest=endpoint(game,cart.destination)
   if not source.is_empty() and not dest.is_empty():
    for p in path_between(game,cell(source.position),cell(dest.position)): used[p]=true
 return used

func edit_roads(game, cells: Array, remove: bool = false) -> bool:
 if cells.is_empty() or cells.size()>160: message="一度に160マスまで選べます";return false
 var unique={}
 for p in cells:
  if not p is Vector2i: return false
  unique[p]=true
 var changes=[]
 var used=used_cells(game) if remove else {}
 for p in unique:
  if remove:
   if used.has(p): message="荷車やルートが使う道路です。空荷でルートを解除してから撤去できます";return false
   if roads.has(p): changes.append(p)
  else:
   if not road_valid(game,p): message="水・建物・生きた木には敷けません。先に木を切ろう";return false
   if not roads.has(p): changes.append(p)
 if changes.is_empty(): message="変更する道路がありません";return false
 if not remove:
  if roads.size()+changes.size()>MAX_ROADS: message="道路の上限に達しました";return false
  if game.money<changes.size()*ROAD_PRICE: message="資金不足。道路は1マス2です";return false
  # Validate proposed adjacent segments before charging anything.
  for i in range(1,cells.size()):
   if cells[i]!=cells[i-1] and not edge_ok(game,cells[i-1],cells[i]): message="途切れた道は敷けません";return false
  game.money-=changes.size()*ROAD_PRICE
  road_paid+=changes.size()
 for p in changes:
  if remove: roads.erase(p)
  else: roads[p]=true
 revision+=1;_paths.clear()
 message="%dマス撤去（払い戻しなし）" % changes.size() if remove else "%dマスの道が完成！" % changes.size()
 return true

func blocks_regrowth(at: Vector2) -> bool:
 for item in sites:
  if footprint(item).grow(1.0).has_point(at) or item.position.distance_to(at)<1.8: return true
  if item.worker.position.distance_to(at)<1.1: return true
  for p in item.worker.path+item.worker.return_path:
   if Vector2(p).distance_to(at)<1.25: return true
 var center=cell(at)
 for x in range(-2,3):
  for y in range(-2,3):
   var p=center+Vector2i(x,y)
   if roads.has(p) and Vector2(p).distance_to(at)<1.4: return true
 return false

func cart_price() -> int:
 return 120

func cart_capacity(cart: Dictionary) -> int:
 return 4+cart.level*4

func upgrade_price(cart: Dictionary, level: int = -1) -> int:
 return int(round(90*pow(2,cart.level-1 if level<0 else level-1)))

func route_ok(game, source: String, destination: String) -> bool:
 var a=endpoint(game,source);var b=endpoint(game,destination)
 if a.is_empty() or b.is_empty() or source==destination or a.type=="market" :
  message="設備から、別の設備か中央基地を選んでください";return false
 if path_between(game,cell(a.position),cell(b.position)).is_empty():
  message="出発地と目的地の円の中心まで道路をつなごう";return false
 return true

func add_cart(game, source: String, destination: String) -> bool:
 if carts.size()>=MAX_CARTS: message="荷車は6台までです";return false
 if game.money<cart_price(): message="荷車の購入資金が足りません";return false
 if not route_ok(game,source,destination): return false
 var a=endpoint(game,source)
 game.money-=cart_price()
 carts.append({"id":carts.size()+1,"level":1,"source":source,"destination":destination,"position":a.position,"cargo":[],"phase":"loading","pause_requested":false,"path":[],"cursor":0,"clock":0.0,"status":"積み込み待ち"})
 message="荷車%dが運行を開始！" % carts.size()
 return true

func upgrade_cart(game, index: int) -> bool:
 if index<0 or index>=carts.size(): return false
 var cart=carts[index]
 if cart.level>=3 or game.money<upgrade_price(cart): return false
 game.money-=upgrade_price(cart);cart.level+=1
 message="荷車%dを強化！ 積載%d本" % [cart.id,cart_capacity(cart)]
 return true

func toggle_pause(index: int) -> bool:
 if index<0 or index>=carts.size(): return false
 var cart=carts[index]
 if cart.source.is_empty(): message="先にルートを設定してください";return false
 cart.pause_requested=not cart.pause_requested
 if not cart.pause_requested and cart.phase=="parked": cart.phase="returning"
 message="配送を終えてから休止します" if cart.pause_requested else "運行を再開します"
 return true

func set_route(game, index: int, source: String, destination: String) -> bool:
 if index<0 or index>=carts.size(): return false
 var cart=carts[index]
 if not cart.cargo.is_empty() or cart.phase not in ["loading","parked"]:
  message="ルート変更は、荷物を届けて休止してから行えます";return false
 if not route_ok(game,source,destination): return false
 var a=endpoint(game,source)
 var path=path_between(game,cell(cart.position),cell(a.position))
 if path.is_empty(): message="荷車のいる場所から新しい出発地まで道をつなごう";return false
 cart.source=source;cart.destination=destination;cart.pause_requested=false
 cart.path=[];cart.cursor=0;cart.clock=0.0;cart.phase="returning"
 message="荷車%dのルートを変更しました" % cart.id
 return true

func clear_route(index: int) -> bool:
 if index<0 or index>=carts.size(): return false
 var cart=carts[index]
 if not cart.cargo.is_empty() or cart.phase not in ["loading","parked"]:
  message="配送を終えて休止してから解除してください";return false
 cart.source="";cart.destination="";cart.phase="parked";cart.pause_requested=true;cart.path=[];cart.cursor=0
 message="ルートを解除。荷車はその場で待機します"
 return true

func begin_leg(game, cart: Dictionary, goal: Vector2, phase: String) -> bool:
 cart.path=path_between(game,cell(cart.position),cell(goal));cart.cursor=1
 if cart.path.is_empty(): cart.status="道がつながっていません";cart.path=[];cart.cursor=0;return false
 cart.phase=phase
 if cart.path.size()==1: cart.path=[];cart.cursor=0;return true
 return false

func advance(cart: Dictionary, dt: float) -> bool:
 var remaining=(2.8+cart.level*0.5)*dt
 while cart.cursor<cart.path.size() and remaining>0:
  var goal=Vector2(cart.path[cart.cursor]);var distance=cart.position.distance_to(goal)
  if distance<=remaining:
   cart.position=goal;remaining-=distance;cart.cursor+=1
  else:
   cart.position=cart.position.move_toward(goal,remaining);remaining=0
 if cart.cursor>=cart.path.size(): cart.path=[];cart.cursor=0;return true
 return false

func tick(game, dt: float) -> void:
 tick_production(game,dt)
 for cart in carts:
  if cart.source.is_empty(): cart.status="ルート未設定";continue
  var a=endpoint(game,cart.source);var b=endpoint(game,cart.destination)
  if a.is_empty() or b.is_empty(): cart.status="施設を確認してください";continue
  if cart.phase=="parked": cart.status="休止中";continue
  if cart.phase=="returning":
   if cart.pause_requested: cart.phase="parked";continue
   if cart.path.is_empty():
    if not begin_leg(game,cart,a.position,"to_source"): continue
    cart.phase="loading"
  if cart.phase=="to_source":
   cart.status="出発地へ移動中"
   if not advance(cart,dt): continue
   cart.phase="loading"
  if cart.phase=="loading":
   if cart.pause_requested: cart.phase="parked";continue
   var source=inventory(game,a)
   var room=free_space(b.id) if b.type!="market" else cart_capacity(cart)
   var eligible=[]
   for log in source:
    if accepts(b.id,log): eligible.append(log)
   var amount=mini(eligible.size(),mini(cart_capacity(cart),room))
   if amount<=0: cart.status="配送先の空き待ち" if room<=0 else "木材待ち";continue
   var path=path_between(game,cell(cart.position),cell(b.position))
   if path.is_empty(): cart.status="道がつながっていません";continue
   # Reservation becomes visible to every later cart in this same tick.
   for i in amount:
    cart.cargo.append(eligible[i]);source.erase(eligible[i])
   cart.path=path;cart.cursor=1;cart.phase="to_destination";cart.clock=0.0
  if cart.phase=="to_destination":
   cart.status="配送中 %d本" % cart.cargo.size()
   if not advance(cart,dt): continue
   cart.phase="unloading"
  if cart.phase=="unloading":
   cart.status="荷下ろし中"
   cart.clock+=dt
   while cart.clock>=0.105 and not cart.cargo.is_empty():
    if b.type!="market" and free_space(b.id,cart.id)<=0: cart.status="配送先の空き待ち";cart.clock=minf(cart.clock,0.105);break
    cart.clock-=0.105
    var log=cart.cargo.pop_front()
    if b.type!="market": incoming(b.id).append(log)
    else: game.sell_log(log,b.position,true)
   if cart.cargo.is_empty():
    cart.clock=0.0;cart.phase="parked" if cart.pause_requested else "returning"

func player_transfer(game, id: String, dt: float) -> void:
 var item=site(id)
 game.transfer_clock+=dt
 while game.transfer_clock>=0.04:
  if item.mode=="deposit":
   if free_space(id)<=0: break
   var chosen=-1
   for i in game.bag.size():
    if accepts(id,game.bag[i]): chosen=i;break
   if chosen<0: break
   var log=game.bag[chosen];game.bag.remove_at(chosen);incoming(id).append(log)
   game.events.append({"type":"deposit","to":item.position,"kind":log.kind,"id":log.id})
  else:
   if game.bag.size()>=game.capacity() or item.output.is_empty(): break
   var log=item.output.pop_front();game.bag.append(log)
   game.events.append({"type":"pickup","from":item.position,"kind":log.kind,"id":log.id})
  game.transfer_clock-=0.04
 game.transfer_clock=minf(game.transfer_clock,0.04)

func held(kind: int) -> int:
 var total=0
 for item in sites:
  for list in [item.input,item.output,item.worker.cargo]:
   for log in list: total+=1 if log.kind==kind else 0
 for cart in carts:
  for log in cart.cargo: total+=1 if log.kind==kind else 0
 return total

func costs() -> int:
 var total=road_paid*ROAD_PRICE+carts.size()*cart_price()
 for item in sites: total+=item.paid
 for cart in carts:
  for level in range(1,cart.level): total+=upgrade_price(cart,level)
 return total

func invalidate_navigation() -> void:
 _walk_cache.clear()

func can_walk(game, p: Vector2i) -> bool:
 if not _walk_cache.has(p): _walk_cache[p]=game.walkable(Vector2(p))
 return _walk_cache[p]

func find_job(game, item: Dictionary) -> bool:
 var worker=item.worker
 var radius=12.0+item.level*5
 var goals={}
 for i in game.trees.size():
  var tree=game.trees[i]
  if tree.hp<=0 or not game.area_open(tree.kind) or tree.position.distance_to(item.position)>radius: continue
  # Reach the trunk from any clear cardinal or diagonal approach.
  var center=cell(tree.position)
  for x in range(-1,2):
   for y in range(-1,2):
    var p=center+Vector2i(x,y)
    var distance=Vector2(p).distance_to(tree.position)
    if distance>=0.8 and distance<=1.7 and can_walk(game,p): goals[p]=i
 if goals.is_empty(): return false
 var start=cell(item.position)
 var queue=[start];var previous={start:start};var head=0;var found=start
 var success=false
 while head<queue.size() and head<5000:
  var p=queue[head];head+=1
  if goals.has(p): found=p;success=true;break
  for direction in DIRS:
   var next=p+direction
   if previous.has(next) or Vector2(next).distance_to(item.position)>radius+2 or not can_walk(game,next): continue
   if not edge_ok_cached(game,p,next): continue
   previous[next]=p;queue.append(next)
 if not success: return false
 var path=[found];var p=found
 while p!=start: p=previous[p];path.push_front(p)
 worker.path=path;worker.cursor=1;worker.return_path=path.duplicate();worker.return_path.reverse()
 worker.target=goals[found];worker.phase="walking";worker.clock=0.0
 return true

func edge_ok_cached(game, a: Vector2i, b: Vector2i) -> bool:
 # Cell centers plus midpoint prevent crossing narrow water or building corners.
 return game.walkable((Vector2(a)+Vector2(b))*0.5)

func worker_advance(game, worker: Dictionary, dt: float, speed: float) -> bool:
 var remaining=speed*dt
 while worker.cursor<worker.path.size() and remaining>0:
  var to=Vector2(worker.path[worker.cursor]);var distance=worker.position.distance_to(to)
  var next=worker.position.move_toward(to,remaining)
  if not game.walkable(next): worker.status="通路が塞がれています";return false
  worker.position=next
  if distance<=remaining: remaining-=distance;worker.cursor+=1
  else: remaining=0
 return worker.cursor>=worker.path.size()

func tick_production(game, dt: float) -> void:
 for item in sites:
  if item.type!="storage":
   if item.input.is_empty() or item.output.size()>=capacity(item.id): continue
   item.clock+=dt
   var interval=6.0/item.level
   while item.clock>=interval and not item.input.is_empty() and item.output.size()<capacity(item.id):
    var log=item.input.pop_front();log.stage=int(log.get("stage",0))+1;item.output.append(log);item.clock-=interval
   item.clock=minf(item.clock,interval)
   continue
  var worker=item.worker
  if worker.phase=="returning":
   worker.status="集積所へ納品中"
   if not worker_advance(game,worker,dt,3.0+item.level*0.4): continue
   item.output.append_array(worker.cargo);worker.cargo.clear();worker.path=[];worker.return_path=[];worker.cursor=0;worker.target=-1;worker.phase="idle"
  if worker.phase=="idle":
   worker.status="休止中" if not item.worker_enabled else "木を探しています"
   if not item.worker_enabled: continue
   worker.wait=maxf(0,worker.wait-dt)
   if worker.wait>0: continue
   worker.wait=2.0
   if free_space(item.id)<5: worker.status="集積所の空き待ち";continue
   if not find_job(game,item): worker.status="近くに伐採できる木がありません";continue
  if worker.phase=="walking":
   worker.status="木へ移動中"
   if not worker_advance(game,worker,dt,3.0+item.level*0.4): continue
   worker.phase="cutting"
  if worker.phase=="cutting":
   var tree=game.trees[worker.target]
   if tree.hp<=0 or not item.worker_enabled:
    worker.phase="returning";worker.path=worker.return_path.duplicate();worker.cursor=1;worker.target=-1;continue
   worker.status="伐採中";worker.clock+=dt
   if worker.clock<0.65: continue
   worker.clock-=0.65
   if game.ground.size()+Defs.KINDS[tree.kind]["yield"]>Defs.MAX_GROUND: continue
   tree.hp=maxi(0,tree.hp-int(item.level))
   game.events.append({"type":"auto_hit","position":tree.position,"tree":worker.target})
   if tree.hp>0: continue
   var first=game.next_id
   game.fell(worker.target)
   for i in range(game.ground.size()-1,-1,-1):
    var log=game.ground[i]
    if log.id>=first:
     worker.cargo.append({"id":log.id,"kind":log.kind,"quality":log.quality,"stage":0});game.ground.remove_at(i)
   worker.phase="returning";worker.path=worker.return_path.duplicate();worker.cursor=1;worker.target=-1

func snapshot() -> Dictionary:
 var data={"roads":[],"road_paid":road_paid,"sites":[],"next_site":next_site,"carts":[]}
 for p in roads: data.roads.append([p.x,p.y])
 for item in sites:
  var copy=item.duplicate(true);copy.position=[item.position.x,item.position.y]
  copy.worker.position=[item.worker.position.x,item.worker.position.y]
  copy.worker.path=[];copy.worker.return_path=[];copy.worker.erase("status")
  for p in item.worker.path: copy.worker.path.append([p.x,p.y])
  for p in item.worker.return_path: copy.worker.return_path.append([p.x,p.y])
  data.sites.append(copy)
 for cart in carts:
  var copy=cart.duplicate(true)
  copy.position=[cart.position.x,cart.position.y];copy.path=[];copy.erase("status")
  for p in cart.path: copy.path.append([p.x,p.y])
  data.carts.append(copy)
 return data

func restore_logs(game, list, out: Array, limit: int, ids: Dictionary, total: int, stage: int = -1) -> bool:
 if not list is Array or list.size()>limit: return false
 for log in list:
  if not log is Dictionary or not game.number(log.get("id"),1,total,true) or not game.number(log.get("kind"),0,2,true): return false
  var id=int(log.id);var kind=int(log.kind)
  if ids.has(id) or not game.area_open(kind): return false
  if not game.number(log.get("quality",0),0,2,true) or not game.number(log.get("stage",0),0,2,true): return false
  if stage>=0 and log.get("stage",0)!=stage: return false
  ids[id]=true;out.append({"id":id,"kind":kind,"quality":int(log.get("quality",0)),"stage":int(log.get("stage",0))})
 return true

func restore_path(game, raw, out: Array, road_only: bool = false) -> bool:
 if not raw is Array or raw.size()>6000: return false
 for pair in raw:
  if not game.pair(pair) or not game.number(pair[0],-98,98,true) or not game.number(pair[1],-224,70,true): return false
  var p=Vector2i(int(pair[0]),int(pair[1]))
  if not game.walkable(Vector2(p)) or (road_only and not roads.has(p)): return false
  if not out.is_empty() and not edge_ok(game,out.back(),p): return false
  out.append(p)
 return true

func restore(game, data, ids: Dictionary, total: int) -> bool:
 if not data is Dictionary or not data.get("sites") is Array or data.sites.size()>MAX_SITES: return false
 if not game.number(data.get("next_site"),1,1e6,true): return false
 next_site=int(data.next_site)
 var names={}
 for raw in data.sites:
  if not raw is Dictionary or not raw.get("id") is String or names.has(raw.id) or raw.id=="market0": return false
  if not raw.id.begins_with("site") and raw.id not in ["camp0","camp1","camp2","depot0","depot1","depot2"]: return false
  if raw.id.begins_with("site") and (not raw.id.substr(4).is_valid_int() or int(raw.id.substr(4))<1 or int(raw.id.substr(4))>=next_site): return false
  names[raw.id]=true
  if not FACILITIES.has(raw.get("type")) or not game.pair(raw.get("position")) or not game.number(raw.get("level"),1,3,true): return false
  if not raw.get("legacy_depot") is bool or not raw.get("worker_enabled") is bool or raw.get("mode") not in ["deposit","withdraw"]: return false
  var item=make_site(raw.id,raw.type,Vector2(raw.position[0],raw.position[1]),int(raw.level))
  if item.position!=Vector2(cell(item.position)): return false
  item.legacy_depot=raw.legacy_depot;item.worker_enabled=raw.worker_enabled;item.mode=raw.mode
  var legal=false
  for area in 3:
   if game.area_open(area) and Defs.in_area(item.position,area,0.4): legal=true
  if not legal: return false
  var rect=footprint(item)
  for other in game.building_rects():
   if rect.grow(0.3).intersects(other): return false
  # Buildings may cover felled trees, but never a live trunk.
  for tree in game.trees:
   if tree.hp>0 and rect.grow(0.76).has_point(tree.position): return false
  for offset in [Vector2.ZERO,rect.position-item.position,rect.end-item.position]:
   var on_land=false
   for area in 3:
    if game.area_open(area) and Defs.in_area(item.position+offset,area,0.2): on_land=true
   if not on_land: return false
  if not game.number(raw.get("clock"),0,6.0/item.level) or not game.number(raw.get("paid"),0,1e7,true): return false
  var full_price=0
  for level in item.level: full_price+=price(item.type,level)
  # Migrated free buildings may subsequently receive paid upgrades.
  var allowed=false
  for first in range(item.level+1):
   var paid=0
   for level in range(first,item.level): paid+=price(item.type,level)
   if raw.paid==paid: allowed=true
  if not allowed: return false
  item.paid=int(raw.paid);item.clock=float(raw.clock)
  sites.append(item)
  var input_stage=0 if item.type=="processor" else 1
  var output_stage=1 if item.type=="processor" else 2
  if not restore_logs(game,raw.get("input"),item.input,0 if item.type=="storage" else capacity(item.id),ids,total,input_stage): return false
  if not restore_logs(game,raw.get("output"),item.output,capacity(item.id),ids,total,-1 if item.type=="storage" else output_stage): return false
 # All buildings must exist before checking any saved worker path.
 for index in sites.size():
  var item=sites[index];var raw=data.sites[index].get("worker")
  if not raw is Dictionary or not game.pair(raw.get("position")) or not game.number(raw.get("clock"),0,0.65) or not game.number(raw.get("wait"),0,2): return false
  if raw.get("phase") not in ["idle","walking","cutting","returning"] or not game.number(raw.get("target"),-1,game.trees.size()-1,true): return false
  var w=item.worker;w.position=Vector2(raw.position[0],raw.position[1]);w.phase=raw.phase;w.clock=float(raw.clock);w.wait=float(raw.wait);w.target=int(raw.target)
  if not game.walkable(w.position): return false
  if not restore_logs(game,raw.get("cargo"),w.cargo,5 if item.type=="storage" else 0,ids,total,0): return false
  if not restore_path(game,raw.get("path"),w.path) or not restore_path(game,raw.get("return_path"),w.return_path): return false
  if not game.number(raw.get("cursor"),0,w.path.size(),true): return false
  w.cursor=int(raw.cursor)
  if item.type!="storage" and (w.phase!="idle" or not w.cargo.is_empty()): return false
  if w.phase=="idle":
   if not w.path.is_empty() or not w.return_path.is_empty() or not w.cargo.is_empty() or w.target!=-1 or w.position.distance_to(item.position)>0.002: return false
  else:
   if w.path.is_empty() or w.return_path.is_empty() or w.cursor<1 or w.cursor>w.path.size(): return false
   if Vector2(w.return_path.back()).distance_to(item.position)>0.002: return false
   if w.phase in ["walking","cutting"] and w.target<0: return false
   if w.phase=="returning" and w.target!=-1: return false
   if w.cursor<w.path.size() and Geometry2D.get_closest_point_to_segment(w.position,Vector2(w.path[w.cursor-1]),Vector2(w.path[w.cursor])).distance_to(w.position)>0.002: return false
   if w.cursor==w.path.size() and w.position.distance_to(Vector2(w.path.back()))>0.002: return false
   if w.phase=="cutting" and (w.cursor!=w.path.size() or w.position.distance_to(game.trees[w.target].position)>1.71): return false
  if item.output.size()+reserved(item.id)>capacity(item.id): return false
 if not data.get("roads") is Array or data.roads.size()>MAX_ROADS or not game.number(data.get("road_paid"),data.roads.size(),1e7,true): return false
 road_paid=int(data.road_paid)
 for pair in data.roads:
  if not game.pair(pair) or not game.number(pair[0],-98,98,true) or not game.number(pair[1],-224,70,true): return false
  var p=Vector2i(int(pair[0]),int(pair[1]))
  if roads.has(p) or not road_valid(game,p): return false
  roads[p]=true
 if not data.get("carts") is Array or data.carts.size()>MAX_CARTS: return false
 for raw in data.carts:
  if not raw is Dictionary or not game.number(raw.get("id"),carts.size()+1,carts.size()+1,true) or not game.number(raw.get("level"),1,3,true): return false
  if not raw.get("source") is String or not raw.get("destination") is String or not raw.get("pause_requested") is bool: return false
  if not game.pair(raw.get("position")) or not game.number(raw.get("clock"),0,0.21): return false
  if raw.get("phase") not in ["loading","to_source","returning","to_destination","unloading","parked"]: return false
  var copy={"id":int(raw.id),"level":int(raw.level),"source":raw.source,"destination":raw.destination,"position":Vector2(raw.position[0],raw.position[1]),"pause_requested":raw.pause_requested,"clock":float(raw.clock),"phase":raw.phase,"path":[],"cursor":0,"cargo":[],"status":"再開"}
  if not restore_logs(game,raw.get("cargo"),copy.cargo,cart_capacity(copy),ids,total): return false
  if not raw.get("path") is Array or raw.path.size()>MAX_ROADS or not game.number(raw.get("cursor"),0,raw.path.size(),true): return false
  for pair in raw.path:
   if not game.pair(pair) or not game.number(pair[0],Defs.WORLD_BOUNDS.position.x,Defs.WORLD_BOUNDS.end.x,true) or not game.number(pair[1],Defs.WORLD_BOUNDS.position.y,Defs.WORLD_BOUNDS.end.y,true): return false
   var point=Vector2i(int(pair[0]),int(pair[1]))
   if not roads.has(point): return false
   if not copy.path.is_empty() and not edge_ok(game,copy.path.back(),point): return false
   copy.path.append(point)
  copy.cursor=int(raw.cursor)
  var source=endpoint(game,copy.source);var dest=endpoint(game,copy.destination)
  if copy.source.is_empty():
   if not copy.destination.is_empty() or copy.phase!="parked" or not copy.cargo.is_empty(): return false
  elif not route_ok(game,copy.source,copy.destination): return false
  if copy.phase in ["to_source","to_destination"]:
   if copy.path.size()<2 or copy.cursor<1 or copy.cursor>=copy.path.size(): return false
   var a=Vector2(copy.path[copy.cursor-1]);var b=Vector2(copy.path[copy.cursor])
   if Geometry2D.get_closest_point_to_segment(copy.position,a,b).distance_to(copy.position)>0.002: return false
   var goal=source.position if copy.phase=="to_source" else dest.position
   if Vector2(copy.path.back()).distance_to(goal)>0.002: return false
  else:
   if not copy.path.is_empty() or copy.cursor!=0 or not roads.has(cell(copy.position)) or copy.position.distance_to(Vector2(cell(copy.position)))>0.002: return false
   if copy.phase=="loading" and copy.position.distance_to(source.position)>0.002: return false
   if copy.phase=="unloading" and copy.position.distance_to(dest.position)>0.002: return false
  if (copy.phase in ["to_destination","unloading"])==copy.cargo.is_empty(): return false
  if copy.phase=="parked" and not copy.pause_requested: return false
  for log in copy.cargo:
   if not accepts(copy.destination,log): return false
  carts.append(copy)
 for item in sites:
  if incoming(item.id).size()+reserved(item.id)>capacity(item.id): return false
 revision+=1;_paths.clear();invalidate_navigation()
 return true
