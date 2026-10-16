extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Logic=preload("res://scripts/adventure/logistics.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool, label: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(label)
func advance(game, seconds: float) -> void:
 for i in int(seconds*10): game.tick(0.1,Vector2.ZERO)
func fresh():
 var game=State.new()
 for cycle in 8:
  for i in game.trees.size():
   if game.trees[i].kind!=0: continue
   var tree=game.trees[i]
   tree.hp=0;tree.harvested=false;game.fell(i)
   while not game.ground.is_empty(): game.sell_log(game.ground.pop_back(),Defs.SALE)
   tree.hp=Defs.KINDS[0].hp;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
 return game
func create_logs(game, amount: int, out: Array) -> void:
 while amount>0:
  var tree=game.trees[0];tree.hp=0;tree.harvested=false;game.fell(0)
  while not game.ground.is_empty():
   var log=game.ground.pop_back()
   if amount>0: out.append({"id":log.id,"kind":log.kind,"quality":log.get("quality",0)});amount-=1
   else: game.sell_log(log,Defs.SALE)
  tree.hp=Defs.KINDS[0].hp;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
func clone(game):
 var next=State.new()
 check(next.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),"Legal logistics snapshot restores")
 check(next.conserved(),"Restored cargo and stock balance")
 check(next.money==game.money and next.logistics.snapshot()==game.logistics.snapshot(),"Exact logistics snapshot round trip")
 return next
func roads(game, a: Vector2i, b: Vector2i) -> void:
 check(game.logistics.edit_roads(game,Logic.line(a,b)),"Build contiguous walkable road")
func setup_network():
 var game=fresh()
 check(game.automation.buy(game,0,"camp"),"Buy camp with earned revenue")
 check(game.logistics.buy_depot(game,0),"Buy collection depot")
 roads(game,Vector2i(-12,9),Vector2i(0,9));roads(game,Vector2i(0,9),Vector2i(0,13))
 roads(game,Vector2i(0,13),Vector2i(4,13));roads(game,Vector2i(4,13),Vector2i(4,9))
 return game
func _initialize() -> void:
 var game=fresh();var logistics=game.logistics
 var money=game.money
 check(not logistics.edit_roads(game,[Vector2i(0,10),Vector2i(-3,3)]),"Discontinuous or blocked road fails atomically")
 check(game.money==money and logistics.roads.is_empty(),"Failed stroke never charges or partly builds")
 check(not logistics.edit_roads(game,[Vector2i(0,-41)]),"Cannot pave an unfinished bridge")
 check(not logistics.edit_roads(game,[Vector2i(0,-52)]),"Cannot pave locked land")
 check(not logistics.edit_roads(game,[Vector2i(4,6)]),"Cannot pave through a building")
 check(not logistics.edit_roads(game,[Vector2i(-3,3)]),"Clear a tree before paving")
 roads(game,Vector2i(0,10),Vector2i(0,13))
 check(game.money==money-8 and logistics.road_paid==4,"Road cost matches unique new cells")
 var paid=game.money
 check(not logistics.edit_roads(game,Logic.line(Vector2i(0,10),Vector2i(0,13))) and game.money==paid,"Duplicate road costs nothing")
 check(logistics.edit_roads(game,[Vector2i(0,12)],true),"Unused road can be removed")
 check(game.money==paid and logistics.road_paid==4,"Demolition never creates refund money")
 roads(game,Vector2i(0,12),Vector2i(0,12));clone(game)
 var poor=State.new()
 check(not poor.logistics.edit_roads(poor,Logic.line(Vector2i(0,10),Vector2i(0,12))) and poor.logistics.roads.is_empty(),"Insufficient cash cannot leave half a road")
 game=setup_network();logistics=game.logistics
 check(not logistics.add_cart(game,"market0","camp0"),"Direction and endpoint types validated")
 check(not logistics.add_cart(game,"camp0","camp0"),"Self route rejected")
 check(logistics.add_cart(game,"camp0","depot0"),"Camp-to-depot cart purchased")
 check(logistics.add_cart(game,"depot0","market0"),"Depot-to-market cart purchased")
 var before=game.money
 advance(game,180)
 check(game.money>before,"Linked two-stage transport creates actual sales")
 check(game.conserved(),"Multi-stage transport conserves every log")
 clone(game)
 var saw=false
 for i in 1000:
  game.tick(0.1,Vector2.ZERO)
  if not logistics.carts[0].cargo.is_empty() and logistics.carts[0].phase=="to_destination": saw=true;break
 check(saw,"Can observe loaded cart between stations")
 var copy=clone(game)
 for i in 600:
  game.tick(0.1,Vector2.ZERO);copy.tick(0.1,Vector2.ZERO)
 check(copy.money==game.money and copy.sold==game.sold and copy.logistics.snapshot()==game.logistics.snapshot(),"Reload during transit produces identical deliveries and revenue")
 check(not logistics.edit_roads(game,[Vector2i(-8,9)],true),"Road used by assigned route cannot strand a cart")
 check(not logistics.clear_route(0) and not logistics.set_route(game,0,"camp0","market0"),"Cannot discard loaded or moving cart cargo by changing route")
 check(logistics.toggle_pause(0),"Request a safe stop")
 advance(game,40)
 check(logistics.carts[0].phase=="parked" and logistics.carts[0].cargo.is_empty(),"Pause completes delivery before parking")
 var balance=game.money
 check(logistics.set_route(game,0,"camp0","market0"),"An empty parked cart can change its route")
 check(game.money==balance,"Changing route doesn't charge for another cart")
 advance(game,20);logistics.toggle_pause(0);advance(game,40)
 check(logistics.clear_route(0),"Empty parked cart can release its route")
 check(logistics.edit_roads(game,[Vector2i(-8,9)],true),"Released route can be demolished")
 var held=logistics.held(0);advance(game,30)
 check(logistics.held(0)>=0 and game.conserved(),"Disconnected empty cart retains all resource accounting")
 clone(game)
 # Two vehicles and player compete for one remaining depot slot.
 game=setup_network();logistics=game.logistics
 create_logs(game,47,logistics.stocks[0]);create_logs(game,12,game.automation.stocks[0]);create_logs(game,1,game.bag)
 logistics.add_cart(game,"camp0","depot0");logistics.add_cart(game,"camp0","depot0")
 game.tick(0.1,Vector2.ZERO)
 check(logistics.reserved(0)==1,"Only one cart reserves the last free depot slot")
 check(logistics.carts[0].cargo.size()+logistics.carts[1].cargo.size()==1,"Concurrent loads cannot overbook")
 game.position=Logic.DEPOTS[0];advance(game,0.5)
 check(game.bag.size()==1,"Player deposit respects incoming cargo reservation")
 clone(game);advance(game,50)
 check(logistics.stocks[0].size()==48 and logistics.reserved(0)==0,"Reserved cargo arrives without overflow")
 check(game.conserved(),"Full destination neither loses nor duplicates goods")
 logistics.depot_mode="withdraw";advance(game,1)
 check(game.bag.size()==game.capacity(),"Warehouse withdrawal is bounded by pack capacity")
 game.position=Defs.SPAWN;advance(game,15);clone(game)
 # Cross a physically completed bridge and retain species/value at another depot.
 var cross=fresh();var consumed=[];create_logs(cross,60,consumed)
 cross.spent[0]+=consumed.size();cross.projects.bridge=60
 check(cross.automation.buy(cross,0,"camp") and cross.logistics.buy_depot(cross,1),"Unlock a regional collection depot")
 roads(cross,Vector2i(-12,9),Vector2i(0,9));roads(cross,Vector2i(0,9),Vector2i(0,-66))
 roads(cross,Vector2i(0,9),Vector2i(4,9))
 check(cross.logistics.add_cart(cross,"camp0","depot1"),"Route crosses the completed bridge")
 check(cross.logistics.add_cart(cross,"depot1","market0"),"Regional depot forwards incoming goods")
 var sold_before=cross.sold[0];advance(cross,240)
 check(cross.sold[0]>sold_before and cross.sold[1]==0,"Wood retains its kind through a different forest and regional market")
 clone(cross)
 # Bad restores must leave the live game untouched.
 var valid=game.snapshot();var bads=[]
 var bad=valid.duplicate(true);bad.logistics.roads.append(bad.logistics.roads[0]);bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.road_paid=0;bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.depot_levels[1]=1;bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].position=[999,999];bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].path=[[0,10],[9,10]];bad.logistics.carts[0].phase="to_destination";bad.logistics.carts[0].cursor=1;bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].source="market0";bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].level=4;bads.append(bad)
 bad=valid.duplicate(true);bad.logistics.stocks[0].append(bad.logistics.stocks[0][0]);bads.append(bad)
 bad=valid.duplicate(true);bad.money+=100000;bads.append(bad)
 for invalid in bads:
  var current=JSON.stringify(game.snapshot())
  check(not game.restore(invalid),"Malformed roads, routes, IDs or cash are rejected")
  check(JSON.stringify(game.snapshot())==current,"Failed logistics restore is atomic")
 # No compatibility guess can silently turn a previous map into new terrain.
 var legacy=fresh().snapshot();legacy.version=4
 check(not State.new().restore(legacy),"Previous world format is rejected safely")
 # Paving a cleared tree prevents a later respawn from blocking the route.
 game=fresh();var tree=game.trees[0];tree.hp=0;tree.harvested=false;game.fell(0)
 while not game.ground.is_empty(): game.sell_log(game.ground.pop_back(),Defs.SALE)
 check(game.logistics.edit_roads(game,[Vector2i(-6,3)]),"Can pave a cleared tree")
 advance(game,40)
 check(tree.hp==0,"Tree cannot respawn into a road")
 clone(game)
 # Long run and frequent reloads retain reservations, fixed caps and cash.
 game=setup_network();logistics=game.logistics
 for i in 6: check(logistics.add_cart(game,"camp0","depot0" if i<3 else "market0"),"Fleet has bounded purchasable vehicles")
 check(not logistics.add_cart(game,"camp0","market0"),"Fleet hard limit enforced")
 var fleet_money=game.money
 check(logistics.upgrade_cart(game,0) and logistics.carts[0].level==2 and logistics.cart_capacity(logistics.carts[0])==12,"Cart first upgrade expands capacity")
 check(game.money==fleet_money-90,"Cart first upgrade charges exactly once")
 check(logistics.upgrade_cart(game,0) and logistics.carts[0].level==3 and logistics.cart_capacity(logistics.carts[0])==16,"Cart second upgrade reaches capacity limit")
 check(not logistics.upgrade_cart(game,0) and game.money==fleet_money-270,"Cart maximum prevents another charge")
 check(logistics.buy_depot(game,0) and logistics.buy_depot(game,0),"Collection depot supports both upgrades")
 check(logistics.capacity(0)==112 and not logistics.buy_depot(game,0),"Collection depot capacity and purchase cap")

 for i in 36000:
  game.tick(0.1,Vector2.ZERO)
  if i%3000==0:
   check(game.conserved(),"Long-run logistics conservation")
   game=clone(game);logistics=game.logistics
 check(logistics.carts.size()==6 and logistics.stocks[0].size()+logistics.reserved(0)<=logistics.capacity(0),"One hour respects fleet and depot capacity")
 check(game.conserved(),"One hour resource balance")
 # Usable demo fixture for browser UI verification, earned revenue only.
 var fixture=setup_network();DirAccess.make_dir_recursive_absolute("res://reports")
 var file=FileAccess.open("res://reports/logistics-fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(fixture.snapshot(),"",true,true));file.close()
 print("KIKORI_LOGISTICS_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
