extends SceneTree
const State = preload("res://scripts/adventure/game_state.gd")
const Defs = preload("res://scripts/adventure/definitions.gd")
const Store = preload("res://scripts/save_store.gd")
var assertions = 0
var failures = 0
var game = State.new()
func check(ok: bool, message: String) -> void:
 assertions += 1
 if not ok:
  failures += 1
  push_error(message)
func idle(seconds: float) -> void:
 for i in int(ceil(seconds*60)): game.tick(1.0/60,Vector2.ZERO)
func move(to: Vector2) -> bool:
 for i in 2400:
  var offset = to-game.position
  if offset.length()<0.055: return true
  game.tick(1.0/60,offset.normalized()*minf(1,offset.length()/0.055))
 check(false,"Stuck at %s toward %s" % [game.position,to])
 return false
func path(to: Vector2) -> bool:
 if not move(Vector2(0,game.position.y)): return false
 if not move(Vector2(0,to.y)): return false
 return move(to)
func harvest(kind: int) -> bool:
 for retry in 200:
  var chosen=-1
  var distance=1e9
  for i in game.trees.size():
   var t=game.trees[i]
   if t.kind==kind and t.hp>0 and absf(t.position.x)<4:
    var d=t.position.distance_to(game.position)
    if d<distance: distance=d;chosen=i
  if chosen>=0:
   var t=game.trees[chosen]
   var destination=t.position+Vector2(-signf(t.position.x)*0.95,0)
   if not path(destination): return false
   if game.bag.size()>=game.capacity(): return true
   var before=game.bag.size()
   for i in 1200:
    game.tick(1.0/60,Vector2.ZERO)
    if game.bag.size()>=game.capacity(): return true
    if game.trees[chosen].hp==0 and game.bag.size()>before:
     # Last scatter may be just outside the radius; step closer after the tree falls.
     move(t.position)
     return true
  idle(0.2)
 check(false,"No regenerating reachable tree")
 return false
func fill(kind: int, amount: int = 12) -> bool:
 for i in 80:
  if game.bag.size()>=mini(amount,game.capacity()): return true
  if not harvest(kind): return false
 check(false,"Couldn't fill bag")
 return false
func sell() -> void:
 path(Defs.SALE)
 idle(4)
 check(game.bag.is_empty(),"Unload is fast and complete")
 check(game.conserved(),"Sale resource accounting")
func snapshot_ok() -> void:
 var restored=State.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),"JSON restore accepts valid game")
 check(restored.conserved(),"Restored resource ledger")
 check(restored.money==game.money and restored.bag.size()==game.bag.size() and restored.projects==game.projects,"Restored purchases, cargo, construction")

func _initialize() -> void:
 # Cardinal and diagonal distance must match at multiple frame rates.
 for fps in [30,60,120]:
  var a=State.new(); var b=State.new()
  a.position=Vector2(-20,45);b.position=a.position
  for i in fps:
   a.tick(1.0/fps,Vector2(1,0));b.tick(1.0/fps,Vector2(1,-1))
  check(absf(a.position.distance_to(Vector2(-20,45))-b.position.distance_to(Vector2(-20,45)))<0.002,"No diagonal boost at %dfps" % fps)
  check(absf(a.position.x+13.5)<0.002,"Frame independent movement at %dfps" % fps)
 # Trees, building, shore, closed bridge.
 check(not game.walkable(Vector2(-3.4,3.1)),"Tree trunk collision")
 check(not game.walkable(Vector2(4,6)),"Building collision")
 check(not game.walkable(Vector2(64,3)),"Shore collision")
 check(not game.walkable(Vector2(0,-41.5)),"Unbuilt bridge is impassable")
 check(not game.walkable(Vector2(0,-52)),"Locked island is impassable")
 game.position=Vector2(-3.4,4.2)
 idle(0.21)
 var hp=game.trees[1].hp
 game.tick(1.0/60,Vector2(1,0))
 check(game.target==-1 and game.chop_clock==0,"Movement cancels chopping immediately")
 check(game.trees[1].hp==hp,"No committed damage before hit interval")
 # Start a fresh game and play real routes: no economy grants or position teleporting.
 game=State.new()
 fill(0,6)
 check(game.capacity()==128 and game.bag.size()>=6,"Standard pack holds 128 from the beginning")
 check(game.speed()==6.5,"Standard speed equals the former maximum")
 var created=game.created.duplicate()
 game.fell(1)
 check(game.created==created,"Repeating a fall never duplicates resources")
 check(not game.buy("pack") and not game.buy("boots"),"Retired upgrades cannot be purchased")
 snapshot_ok()
 sell()
 check(game.money>=60,"Starter pine delivery pays for the first range upgrade")
 check(game.buy("cut_range"),"First affordable upgrade")
 check(game.cut_radius()==2.6 and game.capacity()==128,"Tool purchase increases cutting radius with fixed capacity")
 check(not game.buy("cut_range"),"Second purchase cannot spend the same money")
 var first_upgrade=game.first_upgrade
 fill(0);sell()
 check(game.buy("axe"),"Earned axe upgrade")
 check(game.damage()==2,"Axe noticeably increases damage")
 fill(0);sell()
 check(game.buy("collect_range"),"Earned collection upgrade")
 check(game.collect_radius()==2.6 and game.speed()==6.5,"Collection upgrade leaves standard speed fixed")
 snapshot_ok()
 # Partially construct then interrupt, JSON reload and complete with more trips.
 fill(0)
 path(Defs.PROJECTS[0].position)
 idle(0.35)
 var partial=game.projects.bridge
 check(partial>0 and partial<12,"Construction transfers gradually")
 var old=game.snapshot()
 game.tick(1.0/60,Vector2(1,0))
 var stopped=game.projects.bridge
 for i in 30: game.tick(1.0/60,Vector2(1,0))
 check(game.projects.bridge==stopped,"Movement interrupts construction")
 check(game.restore(JSON.parse_string(JSON.stringify(old,"",true,true))),"Partial project reload")
 check(game.projects.bridge==partial,"Partial contributions are durable")
 for trip in 20:
  if game.complete("bridge"): break
  if game.bag.is_empty(): fill(0)
  path(Defs.PROJECTS[0].position);idle(4)
  check(game.conserved(),"Bridge trip conserves wood")
 check(game.complete("bridge"),"First bridge can be completed without buying anything else")
 check(game.walkable(Vector2(0,-41.5)),"Completed bridge is walkable")
 check(game.walkable(Vector2(0,-52)),"New island unlocks")
 snapshot_ok()
 var bridge_time=game.bridge_time
 sell()
 fill(1)
 check(game.bag.size()>0 and game.bag[0].kind==1,"Harvest new valuable species")
 var funds=game.money
 var expected=0
 for log in game.bag: expected+=game.log_value(log)
 sell()
 check(game.money==funds+expected,"New species sells for correct value")
 # Build the workshop, then the final bridge: an achievable ten-minute progression.
 for project in [Defs.PROJECTS[2]]:
  for trip in 35:
   if game.complete(project.id): break
   if game.bag.is_empty(): fill(1)
   path(project.position);idle(4)
  check(game.complete(project.id),"Project %s is reachable" % project.id)
  snapshot_ok()
 check(game.value(1,1)==48 and game.value(1,1,1)==96 and game.value(1,1,2)==192,"Only physical processing improves sale value")
 sell()
 # Cross the second bridge with physical movement, not teleportation.
 path(Vector2(0,-106));move(Vector2(6,-106));move(Vector2(6,-130));move(Vector2(0,-130))
 fill(2)
 check(game.bag[0].kind==2,"Third forest has a distinct species")
 snapshot_ok()
 print("KIKORI_ROUTE_TIMINGS cut=%.2f sale=%.2f upgrade=%.2f bridge=%.2f all_projects=%.2f" % [game.first_cut,game.first_sale,first_upgrade,bridge_time,game.elapsed])
 # Regrowth waits if the player occupies a stump; it never traps them.
 var t=game.trees[game.trees.size()-1]
 game.position=t.position;t.hp=0;t.harvested=true;t.regrow=0.1;t.fall=0
 idle(2)
 check(t.hp==0,"Regrowth defers under player")
 game.position=Defs.SPAWN;idle(0.2)
 check(t.hp>0,"Regrowth resumes after player leaves")
 # Fresh valid snapshot for hostile-data tests.
 game=State.new();fill(0);sell()
 var valid=game.snapshot()
 var before=JSON.stringify(valid)
 var bads=[]
 var bad=valid.duplicate(true);bad.version=1;bads.append(bad)
 bad=valid.duplicate(true);bad.money=-1;bads.append(bad)
 bad=valid.duplicate(true);bad.levels.axe=0.5;bads.append(bad)
 bad=valid.duplicate(true);bad.projects.bridge=61;bads.append(bad)
 bad=valid.duplicate(true);bad.projects.workshop=1;bads.append(bad)
 bad=valid.duplicate(true);bad.created[0]+=1;bads.append(bad)
 bad=valid.duplicate(true);bad.position[0]=NAN;bads.append(bad)
 bad=valid.duplicate(true);bad.money=1e10;bads.append(bad)
 bad=valid.duplicate(true);bad.trees[0].hp=999;bads.append(bad)
 bad=valid.duplicate(true);bad.next_id+=1;bads.append(bad)
 for invalid in bads:
  check(not game.restore(invalid),"Corrupt state rejected")
  check(JSON.stringify(game.snapshot())==before,"Rejected restore is atomic")
 bad=valid.duplicate(true);bad.position=[0,-41.5]
 check(game.restore(bad) and game.position==Defs.SPAWN,"Unsafe resume position uses safe spawn")
 var store=Store.new("user://kikori_adventure_test.json")
 check(store.write_save(game.snapshot()),"Atomic native save")
 check(State.new().restore(store.read_save()),"Native save restore")
 var damaged=FileAccess.open("user://kikori_adventure_test.json",FileAccess.WRITE)
 damaged.store_string("{invalid");damaged.close()
 check(store.read_save().is_empty(),"Malformed JSON becomes a fresh state without console errors")
 check(not store.message.is_empty(),"Malformed JSON gives a friendly explanation")
 DirAccess.remove_absolute("user://kikori_adventure_test.json")
 # Inventory IDs and upgrades must reject duplication and respect hard limits.
 game=State.new();fill(0)
 var duplicate=game.snapshot();duplicate.bag[1].id=duplicate.bag[0].id
 check(not State.new().restore(duplicate),"Duplicate cargo ID rejected")
 var maximal=State.new();maximal.money=100000
 for key in Defs.UPGRADE_NAMES:
  for level in Defs.MAX_LEVEL:
   var debit_balance=maximal.money
   var cost=maximal.price(key)
   check(maximal.buy(key),"Upgrade is purchasable")
   check(maximal.money==debit_balance-cost,"Exactly current price charged")
  var max_balance=maximal.money
  check(not maximal.buy(key) and maximal.money==max_balance,"Maximum level never charges")
 check(maximal.capacity()==128 and maximal.speed()==6.5,"Upgrades never change standard capacity or speed")
 # Long capped simulation: no growing ground stock or extra logical resources.
 var long=State.new();long.position=Vector2(-2.45,3.1)
 for i in 36000:
  long.tick(0.1,Vector2.ZERO)
 check(long.ground.size()<=Defs.MAX_GROUND and long.bag.size()<=long.capacity(),"One-hour stock bounds")
 check(long.conserved(),"One-hour resource conservation")
 check(long.elapsed>3599,"One-hour run completed")
 print("KIKORI_ADVENTURE_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
