extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Store=preload("res://scripts/save_store.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool, label: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(label)
func wood(game, amount: int, out: Array, stage: int = 0) -> void:
 while amount>0:
  var tree=game.trees[0];tree.hp=0;tree.harvested=false;game.fell(0)
  while not game.ground.is_empty():
   var log=game.ground.pop_back();log.erase("position");log.stage=stage
   if amount>0: out.append(log);amount-=1
   else: game.sell_log(log,Defs.SALE)
  tree.hp=3;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
func earned():
 var game=State.new()
 for i in 20000:
  var logs=[];wood(game,3,logs)
  for log in logs: game.sell_log(log,Defs.SALE)
 return game
func copy_of(game):
 var copy=State.new()
 check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),"Vehicle and commands survive strict JSON restoration")
 check(copy.conserved() and copy.money==game.money,"Restore conserves money and material IDs")
 return copy
func fixture(name: String, game) -> void:
 check(State.new().restore(game.snapshot()),"Valid earned transport fixture: "+name)
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(game.snapshot(),"",true,true));file.close()
func network(four: bool = false):
 var game=earned();var net=game.logistics
 check(net.cart_limit()==2,"Central base plus one yields two initial vehicle slots")
 check(net.build(game,"storage",Vector2(-12,9)),"Build transport source")
 check(net.cart_limit()==3,"One facility increases vehicle limit immediately")
 check(net.build(game,"processor",Vector2(-4,14)) and net.build(game,"factory",Vector2(10,14)),"Build processing destinations")
 net.sites[0].worker_enabled=false
 for segment in [[Vector2i(-12,9),Vector2i(-12,14)],[Vector2i(-12,14),Vector2i(10,14)],[Vector2i(4,14),Vector2i(4,9)]]:
  check(net.edit_roads(game,net.line(segment[0],segment[1])),"Connect transport fixture")
 if four:
  check(net.build(game,"storage",Vector2(2,20)),"Build independent fourth source")
  net.sites[3].worker_enabled=false
  for segment in [[Vector2i(6,14),Vector2i(6,20)],[Vector2i(6,20),Vector2i(2,20)]]:
   check(net.edit_roads(game,net.line(segment[0],segment[1])),"Connect empty reposition leg")
 return game
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=network();var net=game.logistics
 check(net.add_cart(game,"site1","market0"),"Purchase initial human vehicle")
 var cart=net.carts[0];wood(game,12,net.sites[0].output);net.tick(game,0.1)
 check(cart.cargo.size()==8 and cart.phase=="to_destination","Initial vehicle keeps the original eight-unit cargo")
 var cargo=cart.cargo.duplicate(true);var at=cart.position;var funds=game.money
 var paid=120
 for tier in 3:
  if tier>0:
   var previous_capacity=net.cart_capacity(cart);var previous_speed=net.cart_speed(cart);var promotion=net.upgrade_price(cart)
   check(cart.level==5 and net.upgrade_cart(game,0) and cart.tier==tier and cart.level==1,"Level five promotes to next vehicle at level one")
   paid+=promotion
   check(net.cart_capacity(cart)>=previous_capacity*4 and net.cart_speed(cart)>=previous_speed*2,"New vehicle sharply increases both capacity and speed")
  for level in range(1,6):
   check(cart.tier==tier and cart.level==level,"Five levels per vehicle tier")
   check(cart.cargo==cargo and cart.position==at,"Upgrading in transit preserves cargo IDs and physical position")
   var restored=copy_of(game)
   check(restored.logistics.carts[0].tier==tier and restored.logistics.carts[0].level==level,"Restored vehicle retains tier and level")
   if level<5:
    var cost=net.upgrade_price(cart);var old_capacity=net.cart_capacity(cart);var old_speed=net.cart_speed(cart)
    check(net.upgrade_cart(game,0),"Purchase within-tier improvement")
    paid+=cost
    check(net.cart_capacity(cart)>old_capacity and net.cart_speed(cart)>old_speed,"Each upgrade improves speed and capacity")
 check(net.cart_capacity(cart)==2048 and is_equal_approx(net.cart_speed(cart),52.0),"Truck level five reaches 2,048 units and speed 52")
 check(game.money==funds-(paid-120) and net.cart_investment(cart)==paid,"Exact cumulative vehicle purchases remain in the save ledger")
 var before=game.money
 check(not net.upgrade_cart(game,0) and game.money==before,"Maximum truck never charges another upgrade")
 # No teleporting even when a fast truck consumes several road cells per frame.
 var previous=cart.position
 net.tick(game,0.1)
 check(cart.position.distance_to(previous)<=5.201 and game.conserved(),"Fast movement remains bounded and follows a road path")
 copy_of(game)
 # Very large inventories render as a bounded representative bundle, with exact
 # logical counts and IDs retained; every unit still arrives at the sole base.
 wood(game,2048-cart.cargo.size(),cart.cargo)
 fixture("transport-truck-loaded-fixture",game)
 before=game.money
 var total=cart.cargo.size()
 for i in 200:
  net.tick(game,0.1)
  if cart.cargo.is_empty(): break
 check(cart.cargo.is_empty() and game.money==before+total*10 and game.conserved(),"Full truck unloads every actual unit once at the central base")
 copy_of(game)
 # Purchase limit is derived from all buildings, not the old six-vehicle limit.
 var fleet=network(true);var f=fleet.logistics
 check(f.cart_limit()==6,"Four facilities plus central base plus one gives six vehicles")
 for i in f.cart_limit(): check(f.add_cart(fleet,"site1","market0"),"Buy up to current building-based limit")
 before=fleet.money
 check(not f.add_cart(fleet,"site1","market0") and fleet.money==before,"Excess vehicle purchase fails without charging")
 var built_extra=false
 for x in range(-25,26):
  for y in range(15,32):
   if f.placement_ok(fleet,"storage",Vector2(x,y)):
    built_extra=f.build(fleet,"storage",Vector2(x,y));break
  if built_extra: break
 check(built_extra and f.cart_limit()==7 and f.add_cart(fleet,"site1","market0"),"A new building unlocks the seventh vehicle beyond the retired fixed cap")
 copy_of(fleet)
 # A legally occupied old six-cart fleet is kept even if its building limit fell.
 var legacy=network();var l=legacy.logistics
 for i in 3: l.add_cart(legacy,"site1","market0")
 for i in 2: l.upgrade_cart(legacy,0)
 wood(legacy,12,l.sites[0].output);l.tick(legacy,0.1)
 var old=legacy.snapshot();old.version=7
 for raw in old.logistics.carts:
  raw.erase("tier");raw.erase("orders");raw.erase("order_index")
 var migrated=State.new()
 check(migrated.restore(JSON.parse_string(JSON.stringify(old,"",true,true))),"Real schema-seven vehicle fields migrate")
 check(migrated.money==legacy.money and migrated.logistics.carts[0].cargo==l.carts[0].cargo and migrated.logistics.carts[0].level==3,"Legacy paid upgrades and in-flight cargo stay unchanged")
 check(migrated.logistics.carts[0].tier==0 and migrated.logistics.carts[0].orders.size()==1,"Old route becomes one looping human-vehicle command")
 copy_of(migrated)
 var file=FileAccess.open("res://reports/transport-v7-fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(old,"",true,true));file.close()
 # Three commands with a separate D -> base leg and a real empty C -> D move.
 var loop=network(true);var n=loop.logistics
 check(n.add_cart(loop,"site1","site2"),"Buy multi-order vehicle")
 var orders=[{"source":"site1","destination":"site2"},{"source":"site2","destination":"site3"},{"source":"site4","destination":"market0"}]
 check(n.set_orders(loop,0,orders),"Three independent commands form a connected repeating cycle")
 var vehicle=n.carts[0];wood(loop,6,n.sites[0].output);wood(loop,6,n.sites[3].output,2)
 # Editing an empty vehicle is transactional, and its planned roads are protected.
 vehicle.phase="parked";vehicle.pause_requested=true
 var roads_before=n.roads.size()
 check(not n.edit_roads(loop,[Vector2i(6,18)],true) and n.roads.size()==roads_before,"Future empty connector is protected from demolition")
 fixture("transport-orders-fixture",loop)
 n.toggle_pause(0)
 var seen={};var empty_move=false;var sequence=[];var prior=0;var checked_phases={};before=loop.money
 for i in 2200:
  var old_position=vehicle.position;var old_destination=vehicle.destination;var was_loaded=not vehicle.cargo.is_empty()
  n.tick(loop,0.1)
  seen[vehicle.order_index]=true
  if vehicle.order_index!=prior:
   sequence.append(vehicle.order_index)
   if was_loaded: check(vehicle.position.distance_to(n.endpoint(loop,old_destination).position)<0.002,"Next command activates at the real previous destination")
   else: check(vehicle.position==old_position,"Skipping an empty order never teleports the vehicle")
   prior=vehicle.order_index
  if vehicle.phase=="to_source" and vehicle.source=="site4":
   empty_move=empty_move or vehicle.position!=old_position
   check(vehicle.cargo.is_empty() and vehicle.path.back()==Vector2i(2,20),"Reposition to independent source is an empty physical road journey")
  if not checked_phases.has(vehicle.phase):
   checked_phases[vehicle.phase]=true;copy_of(loop)
  if not vehicle.cargo.is_empty():
   var active=vehicle.orders.duplicate(true)
   check(not n.edit_order(loop,0,0,"site1","market0") and vehicle.orders==active,"Loaded vehicle rejects route edits without touching active orders or cargo")
  if sequence.size()>=3 and loop.money==before+240: break
 check(seen.size()==3 and sequence.slice(0,3)==[1,2,0] and empty_move,"Execution follows 1 -> 2 -> 3 -> 1 including empty connector")
 check(loop.money==before+240 and loop.conserved(),"Only the independent finished-product delivery earns money")
 n.toggle_pause(0)
 for i in 600:
  n.tick(loop,0.1)
  if vehicle.phase=="parked": break
 check(vehicle.phase=="parked" and vehicle.cargo.is_empty(),"Pause safely completes the current delivery before parking")
 var saved_index=vehicle.order_index;var resumed=copy_of(loop)
 check(resumed.logistics.carts[0].orders==vehicle.orders and resumed.logistics.carts[0].order_index==saved_index,"Paused command cycle and exact next order survive reload")
 check(n.remove_order(loop,0,1) and vehicle.orders.size()==2,"Delete a middle command")
 vehicle.phase="parked";vehicle.pause_requested=true
 check(n.edit_order(loop,0,1,"site3","market0") and vehicle.orders[1].source=="site3","Replace one command while retaining the other")
 vehicle.phase="parked";vehicle.pause_requested=true
 check(n.edit_order(loop,0,2,"site4","market0") and not n.edit_order(loop,0,3,"site1","market0"),"Append third command but reject fourth")
 vehicle.phase="parked";vehicle.pause_requested=true
 check(n.clear_route(0) and vehicle.orders.is_empty() and vehicle.source.is_empty(),"Clear all commands keeps the purchased vehicle parked")
 copy_of(loop)
 check(n.set_route(loop,0,"site1","market0") and vehicle.orders.size()==1,"Reassign a cleared vehicle through original single-route API")
 # Empty or full sources must not block useful later orders forever.
 var skip=network(true);var sn=skip.logistics
 sn.add_cart(skip,"site1","site2");sn.set_orders(skip,0,orders);sn.toggle_pause(0)
 wood(skip,64,sn.sites[1].input);wood(skip,64,sn.sites[1].output,1)
 wood(skip,3,sn.sites[0].output);wood(skip,3,sn.sites[3].output,2)
 wood(skip,64,sn.sites[2].input,1)
 before=skip.money
 for i in 1600:
  sn.tick(skip,0.1)
  if skip.money>=before+120: break
 check(skip.money>=before+120 and skip.conserved(),"Full first destination is skipped so independent third order can deliver")
 copy_of(skip)
 # Concurrent large vehicles reserve only real destination space.
 var crowded=network();var cn=crowded.logistics
 cn.add_cart(crowded,"site1","site2");cn.add_cart(crowded,"site1","site2")
 for index in 2:
  for upgrade in 5: cn.upgrade_cart(crowded,index)
 wood(crowded,62,cn.sites[1].input);wood(crowded,64,cn.sites[0].output)
 cn.tick(crowded,0.1)
 check(cn.carts[0].cargo.size()==2 and cn.carts[1].cargo.is_empty() and cn.reserved("site2")==2,"Two horse wagons cannot overbook the last destination slots")
 copy_of(crowded)
 # Malformed tier/level/command state is rejected atomically.
 var valid=migrated.snapshot();var target=State.new();var pristine=JSON.stringify(target.snapshot())
 var cases=[]
 var bad=valid.duplicate(true);bad.logistics.carts[0].tier=3;cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].level=6;cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].order_index=1;cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].orders[0].destination="missing";cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].orders[0].source="market0";cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].orders=[];cases.append(bad)
 bad=valid.duplicate(true);bad.logistics.carts[0].orders.resize(4);cases.append(bad)
 for invalid in cases: check(not target.restore(invalid) and JSON.stringify(target.snapshot())==pristine,"Malformed transport restore is atomic")
 # Browser-ready promotion fixture is earned, connected and paused, so UI clicks
 # alone can promote twice, configure orders and buy up to the building limit.
 var browser=network(true);var bn=browser.logistics
 bn.add_cart(browser,"site1","site2")
 for i in 4: bn.upgrade_cart(browser,0)
 bn.toggle_pause(0);bn.tick(browser,0.1)
 for id in ["site2","site3"]:
  for i in 2: bn.upgrade(browser,id)
 wood(browser,12,bn.sites[0].output);wood(browser,3,bn.sites[3].output,2)
 fixture("transport-ui-fixture",browser)
 # Render all vehicle types and maximum logical cargo without creating one node
 # or mesh instance per cargo unit.
 var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
 check(scene.game.restore(JSON.parse_string(FileAccess.get_file_as_string("res://reports/transport-truck-loaded-fixture.json"))),"Loaded truck render fixture restores")
 scene.world.update(0)
 var view=scene.world.logistics_view
 check(view.carts[0].shapes[2].visible and not view.carts[0].shapes[0].visible,"Truck has distinct rendered equipment")
 var count=0
 for batch in view.carts[0].cargo: count+=batch.multimesh.visible_instance_count
 check(count==24 and scene.game.logistics.carts[0].cargo.size()==2048,"Large cargo has exactly 24 visual bundles and all 2,048 logical units")
 scene.game.logistics.carts[0].tier=1;scene.world.update(0.1)
 check(view.carts[0].shapes[1].visible and view.carts[0].horse_legs[0].visible and not view.carts[0].shapes[2].visible,"Horse wagon includes visible animated horse legs")
 scene.game.logistics.carts[0].tier=0;scene.world.update(0.1)
 check(view.carts[0].shapes[0].visible and not view.carts[0].horse_legs[0].visible,"Human tier retains original handcart artwork")
 scene.queue_free()
 # The larger fleet must never write a save that its own reader rejects.
 var store=Store.new("user://transport-storage-test.json")
 var payload=game.snapshot();payload.future_metadata="x".repeat(600000)
 check(store.write_save(payload),"Large fleet-sized save writes atomically beyond the former 512 KB limit")
 var loaded=store.read_save()
 check(not loaded.is_empty() and State.new().restore(loaded),"Large save reads back through the same storage contract")
 payload.future_metadata="x".repeat(Store.MAX_BYTES)
 check(not store.write_save(payload),"Oversized save is refused before overwriting a valid previous save")
 check(State.new().restore(store.read_save()),"Failed oversized save retains previous playable progress")
 DirAccess.remove_absolute(store.file_path)
 print("KIKORI_TRANSPORT_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
