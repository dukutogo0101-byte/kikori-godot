extends RefCounted
# All inventory mutations are synchronous. Cargo reserves depot capacity at load.
const Defs = preload("res://scripts/adventure/definitions.gd")
const ROAD_PRICE = 2
const MAX_ROADS = 1200
const MAX_CARTS = 6
const DEPOTS = [Vector2(0,13),Vector2(0,-66),Vector2(6,-157)]
const DIRS = [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var roads = {}
var road_paid = 0
var depot_levels = [0,0,0]
var stocks: Array = [[],[],[]]
var carts: Array = []
var depot_mode = "deposit"
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

func capacity(area: int) -> int:
 return 48+maxi(0,int(depot_levels[area])-1)*32

func depot_price(area: int, level: int = -1) -> int:
 return int(round(160*pow(1.45,area)*pow(1.8,depot_levels[area] if level<0 else level)))

func buy_depot(game, area: int) -> bool:
 if area<0 or area>2 or not game.area_open(area) or depot_levels[area]>=3: return false
 if game.money<depot_price(area): message="倉庫の建設資金が足りません";return false
 game.money-=depot_price(area)
 depot_levels[area]+=1
 message="%sの集積倉庫 Lv.%d！" % [Defs.AREA_NAMES[area],depot_levels[area]]
 return true

func endpoints(game) -> Array:
 var list=[]
 for area in 3:
  if not game.area_open(area): continue
  if game.automation.levels[area].camp>0: list.append({"id":"camp%d" % area,"name":Defs.AREA_NAMES[area]+" 伐採所","position":Defs.CAMPS[area],"type":"camp","area":area})
  if depot_levels[area]>0: list.append({"id":"depot%d" % area,"name":Defs.AREA_NAMES[area]+" 集積倉庫","position":DEPOTS[area],"type":"depot","area":area})
 for i in Defs.MARKETS.size():
  var market=Defs.MARKETS[i]
  if game.area_open(market.area): list.append({"id":"market%d" % i,"name":market.name,"position":market.position,"type":"market","area":market.area})
 return list

func endpoint(game, id: String) -> Dictionary:
 for place in endpoints(game):
  if place.id==id: return place
 return {}

func inventory(game, place: Dictionary) -> Array:
 return game.automation.stocks[place.area] if place.type=="camp" else stocks[place.area]

func reserved(area: int, except_id: int = -1) -> int:
 var count=0
 for cart in carts:
  if cart.id!=except_id and cart.destination=="depot%d" % area: count+=cart.cargo.size()
 return count

func free_space(area: int, except_id: int = -1) -> int:
 return maxi(0,capacity(area)-stocks[area].size()-reserved(area,except_id))

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
 if a.is_empty() or b.is_empty() or source==destination or a.type=="market" or b.type=="camp":
  message="伐採所・倉庫から、別の倉庫・中央基地を選んでください";return false
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
   var room=free_space(b.area) if b.type=="depot" else cart_capacity(cart)
   var amount=mini(source.size(),mini(cart_capacity(cart),room))
   if amount<=0: cart.status="配送先の空き待ち" if room<=0 else "木材待ち";continue
   var path=path_between(game,cell(cart.position),cell(b.position))
   if path.is_empty(): cart.status="道がつながっていません";continue
   # Reservation becomes visible to every later cart in this same tick.
   for i in amount: cart.cargo.append(source.pop_front())
   cart.path=path;cart.cursor=1;cart.phase="to_destination";cart.clock=0.0
  if cart.phase=="to_destination":
   cart.status="配送中 %d本" % cart.cargo.size()
   if not advance(cart,dt): continue
   cart.phase="unloading"
  if cart.phase=="unloading":
   cart.status="荷下ろし中"
   cart.clock+=dt
   while cart.clock>=0.105 and not cart.cargo.is_empty():
    if b.type=="depot" and free_space(b.area,cart.id)<=0: cart.status="配送先の空き待ち";cart.clock=minf(cart.clock,0.105);break
    cart.clock-=0.105
    var log=cart.cargo.pop_front()
    if b.type=="depot": stocks[b.area].append(log)
    else: game.sell_log(log,b.position,true)
   if cart.cargo.is_empty():
    cart.clock=0.0;cart.phase="parked" if cart.pause_requested else "returning"

func player_transfer(game, area: int, dt: float) -> void:
 game.transfer_clock+=dt
 while game.transfer_clock>=0.105:
  if depot_mode=="deposit":
   if game.bag.is_empty() or free_space(area)<=0: break
   var log=game.bag.pop_back();stocks[area].append(log)
   game.events.append({"type":"deposit","to":DEPOTS[area],"kind":log.kind,"id":log.id})
  else:
   if game.bag.size()>=game.capacity() or stocks[area].is_empty(): break
   var log=stocks[area].pop_front();game.bag.append(log)
   game.events.append({"type":"pickup","from":DEPOTS[area],"kind":log.kind,"id":log.id})
  game.transfer_clock-=0.105
 game.transfer_clock=minf(game.transfer_clock,0.105)

func held(kind: int) -> int:
 var total=0
 for inventory in stocks:
  for log in inventory: total+=1 if log.kind==kind else 0
 for cart in carts:
  for log in cart.cargo: total+=1 if log.kind==kind else 0
 return total

func costs() -> int:
 var total=road_paid*ROAD_PRICE+carts.size()*cart_price()
 for area in 3:
  for level in depot_levels[area]: total+=depot_price(area,level)
 for cart in carts:
  for level in range(1,cart.level): total+=upgrade_price(cart,level)
 return total

func snapshot() -> Dictionary:
 var data={"roads":[],"road_paid":road_paid,"depot_levels":depot_levels.duplicate(),"stocks":stocks.duplicate(true),"carts":[],"depot_mode":depot_mode}
 for p in roads: data.roads.append([p.x,p.y])
 for cart in carts:
  var copy=cart.duplicate(true)
  copy.position=[cart.position.x,cart.position.y];copy.path=[];copy.erase("status")
  for p in cart.path: copy.path.append([p.x,p.y])
  data.carts.append(copy)
 return data

func restore_logs(game, list, out: Array, limit: int, ids: Dictionary, total: int) -> bool:
 if not list is Array or list.size()>limit: return false
 for log in list:
  if not log is Dictionary or not game.number(log.get("id"),1,total,true) or not game.number(log.get("kind"),0,2,true): return false
  var id=int(log.id);var kind=int(log.kind)
  if ids.has(id) or not game.area_open(kind): return false
  if not game.number(log.get("quality",0),0,2,true): return false
  ids[id]=true;out.append({"id":id,"kind":kind,"quality":int(log.get("quality",0))})
 return true

func restore(game, data, ids: Dictionary, total: int) -> bool:
 if not data is Dictionary or not data.get("roads") is Array or data.roads.size()>MAX_ROADS: return false
 if not game.number(data.get("road_paid"),data.roads.size(),1e7,true): return false
 if data.get("depot_mode")!="deposit" and data.get("depot_mode")!="withdraw": return false
 depot_mode=data.depot_mode;road_paid=int(data.road_paid)
 for pair in data.roads:
  if not game.pair(pair) or not game.number(pair[0],Defs.WORLD_BOUNDS.position.x,Defs.WORLD_BOUNDS.end.x,true) or not game.number(pair[1],Defs.WORLD_BOUNDS.position.y,Defs.WORLD_BOUNDS.end.y,true): return false
  var p=Vector2i(int(pair[0]),int(pair[1]))
  if roads.has(p) or not road_valid(game,p): return false
  roads[p]=true
 for group in ["depot_levels","stocks"]:
  if not data.get(group) is Array or data[group].size()!=3: return false
 for area in 3:
  if not game.number(data.depot_levels[area],0,3,true): return false
  depot_levels[area]=int(data.depot_levels[area])
  if depot_levels[area]>0 and not game.area_open(area): return false
  if not restore_logs(game,data.stocks[area],stocks[area],capacity(area) if depot_levels[area]>0 else 0,ids,total): return false
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
  carts.append(copy)
 for area in 3:
  if stocks[area].size()+reserved(area)>capacity(area): return false
 revision+=1;_paths.clear()
 return true
