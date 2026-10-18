extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Legacy=preload("res://scripts/adventure/legacy_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool, label: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(label)
func advance(game, seconds: float) -> void:
 for i in ceili(seconds*10): game.tick(0.1,Vector2.ZERO)
func wood(game, amount: int, out: Array) -> void:
 while amount>0:
  var tree=game.trees[0];tree.hp=0;tree.harvested=false;game.fell(0)
  while not game.ground.is_empty():
   var log=game.ground.pop_back();log.erase("position");log.stage=0
   if amount>0: out.append(log);amount-=1
   else: game.sell_log(log,Defs.SALE)
  tree.hp=3;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
func earned(legacy: bool = false):
 var game=Legacy.new() if legacy else State.new()
 for i in 1000:
  var logs=[];wood(game,3,logs)
  for log in logs: game.sell_log(log,Defs.SALE)
 return game
func equivalent(a, b) -> bool:
 if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b))<1e-9
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size(): return false
  for key in a:
   if not b.has(key) or not equivalent(a[key],b[key]): return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size(): return false
  for i in a.size():
   if not equivalent(a[i],b[i]): return false
  return true
 return a==b
func roundtrip(game, label: String) -> void:
 var restored=State.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),label+": JSON restore")
 check(restored.conserved() and restored.money==game.money,label+": funds and wood conserved")
 check(equivalent(restored.logistics.snapshot().sites,JSON.parse_string(JSON.stringify(game.logistics.snapshot().sites,"",true,true))),label+": buildings, buffers, workers and progress retained")
func fixture(name: String, game) -> void:
 var snapshot=game.snapshot();check(State.new().restore(snapshot),"Valid fixture "+name)
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(snapshot,"",true,true));file.close()
func _initialize() -> void:
 var game=earned();fixture("production-start-fixture",game)
 var net=game.logistics
 var before=game.money
 check(not net.build(game,"factory",Vector2(0,-80)) and game.money==before,"Locked regions reject construction without charging")
 check(not net.build(game,"processor",Vector2(4,9)) and game.money==before,"Central delivery court stays clear")
 check(not net.build(game,"storage",Vector2(-3,4)) and game.money==before,"Live trees cannot be covered")
 check(net.build(game,"storage",Vector2(-12,9)),"Storage can be freely placed")
 check(net.build(game,"processor",Vector2(-4,14)),"Processor can be freely placed")
 check(net.build(game,"factory",Vector2(10,14)),"Factory can be freely placed")
 check(game.money==before-1100,"Exactly the three displayed construction prices charged")
 var storage=net.sites[0];var processor=net.sites[1];var factory=net.sites[2]
 storage.worker_enabled=false
 check(not net.build(game,"storage",Vector2(-12,9)),"Buildings cannot overlap")
 check(not game.walkable(Vector2(-12,6.3)) and game.walkable(storage.position),"Building blocks movement but delivery court remains open")
 check(not net.edit_roads(game,[Vector2i(-12,6)]),"Roads cannot cross a placed building")
 var route=[]
 for segment in [[Vector2i(-12,9),Vector2i(-12,14)],[Vector2i(-12,14),Vector2i(10,14)],[Vector2i(4,14),Vector2i(4,9)]]:
  check(net.edit_roads(game,net.line(segment[0],segment[1])),"Road segment builds on open land")
 check(net.add_cart(game,storage.id,processor.id) and net.add_cart(game,processor.id,factory.id) and net.add_cart(game,factory.id,"market0"),"Three connected carts form the complete production chain")
 wood(game,12,game.bag)
 game.position=storage.position;before=game.money
 advance(game,0.6)
 check(game.bag.is_empty() and net.held(0)==12 and game.money==before,"Player deposit transfers wood without paying")
 roundtrip(game,"In-transit raw logs")
 game.position=Defs.SPAWN
 for step in 2000:
  game.tick(0.1,Vector2.ZERO)
  if game.sold[0]==3012: break
 check(game.sold[0]==3012 and game.money==before+12*40,"Only completed products delivered to the central base pay four times")
 check(game.conserved() and net.held(0)==0,"Every production input becomes exactly one delivered product")
 check(game.value(0,2,2)==120 and game.value(2,2,2)==600,"Processing preserves species and distant timber quality")
 roundtrip(game,"Finished chain")
 for cart in net.carts: cart.pause_requested=true
 advance(game,30)
 # Player can transport stage-1 output manually; mismatched cargo stays in bag.
 wood(game,3,processor.input);advance(game,6.1)
 check(processor.output.size()==1 and processor.output[0].stage==1,"Processing takes real active-play time")
 processor.mode="withdraw";game.position=processor.position;advance(game,0.1)
 check(game.bag.size()==1 and game.bag[0].stage==1,"Player withdraws actual processed output")
 # Pause carts after deliveries so manual checks are isolated.
 for cart in net.carts: cart.pause_requested=true
 advance(game,30)
 wood(game,3,game.bag)
 game.position=factory.position;advance(game,0.2)
 check(game.bag.size()==3 and factory.input.size()>=1,"Factory accepts processed materials while leaving raw timber with player")
 before=game.money;advance(game,6.1)
 check(factory.output.size()>=1 and game.money==before,"Manufacturing alone never awards money")
 roundtrip(game,"Mixed materials and paused carts")
 # Reserve destination capacity against simultaneous carts and manual deposits.
 var crowded=earned();var n=crowded.logistics
 n.build(crowded,"storage",Vector2(-12,9));n.build(crowded,"processor",Vector2(-4,14))
 n.sites[0].worker_enabled=false
 n.edit_roads(crowded,n.line(Vector2i(-12,9),Vector2i(-12,14)))
 n.edit_roads(crowded,n.line(Vector2i(-12,14),Vector2i(-4,14)))
 wood(crowded,62,n.sites[1].input);wood(crowded,12,n.sites[0].output)
 n.add_cart(crowded,n.sites[0].id,n.sites[1].id);n.add_cart(crowded,n.sites[0].id,n.sites[1].id)
 advance(crowded,0.1)
 check(n.carts[0].cargo.size()==2 and n.carts[1].cargo.is_empty(),"Concurrent carts reserve the final two input slots exactly once")
 wood(crowded,3,crowded.bag);crowded.position=n.sites[1].position;advance(crowded,0.1)
 check(crowded.bag.size()==3 and n.free_space(n.sites[1].id)==0,"Player cannot consume slots reserved for an incoming cart")
 roundtrip(crowded,"Reserved full input buffer")
 check(not n.edit_roads(crowded,[Vector2i(-12,10)],true),"Active delivery roads cannot be demolished")
 # A full output buffer stalls with original IDs still in input, then resumes.
 var stall=earned();stall.logistics.build(stall,"processor",Vector2(-4,14));var mill=stall.logistics.sites[0]
 wood(stall,64,mill.output)
 for log in mill.output: log.stage=1
 wood(stall,3,mill.input);advance(stall,20)
 check(mill.input.size()==3 and mill.output.size()==64,"Full output stops processing without discarding input")
 var first=mill.output.pop_back();stall.bag.append(first);advance(stall,6.1)
 check(mill.input.size()==2 and mill.output.size()==64 and stall.conserved(),"Processing resumes when output space is freed")
 roundtrip(stall,"Blocked processing")
 # NPC walks a real path, shares trees, returns wood to its placed storage.
 var npc=earned();npc.logistics.build(npc,"storage",Vector2(-12,9));var depot=npc.logistics.sites[0]
 var delivered=false;var reloaded=false
 for step in 1800:
  npc.tick(0.1,Vector2.ZERO)
  if not reloaded and not depot.worker.cargo.is_empty(): roundtrip(npc,"NPC carrying harvested wood");reloaded=true
  if not depot.output.is_empty(): delivered=true;break
 check(delivered and reloaded and npc.conserved(),"NPC physically harvests and delivers to the freely placed intermediate storage")
 depot.worker_enabled=false;advance(npc,30)
 check(depot.worker.phase=="idle" and depot.worker.cargo.is_empty(),"Paused NPC completes delivery before stopping")
 check(npc.logistics.upgrade(npc,depot.id) and npc.logistics.capacity(depot.id)==128,"Tapping upgrade increases this storage only")
 roundtrip(npc,"Upgraded storage")
 fixture("production-network-fixture",game)
 var browser_network=earned();var bn=browser_network.logistics
 bn.build(browser_network,"storage",Vector2(-12,9));bn.build(browser_network,"processor",Vector2(-4,14));bn.build(browser_network,"factory",Vector2(10,14))
 bn.sites[0].worker_enabled=false
 wood(browser_network,12,bn.sites[0].output)
 for segment in [[Vector2i(-12,9),Vector2i(-12,14)],[Vector2i(-12,14),Vector2i(10,14)],[Vector2i(4,14),Vector2i(4,9)]]: bn.edit_roads(browser_network,bn.line(segment[0],segment[1]))
 fixture("production-route-fixture",browser_network)
 # Validate and convert actual old inventories, paths and purchased facilities.
 var old=earned(true)
 old.automation.buy(old,0,"camp");old.automation.buy(old,0,"porter");old.automation.buy(old,0,"mill")
 old.logistics.buy_depot(old,0)
 wood(old,12,old.automation.stocks[0]);wood(old,3,old.automation.cutters[0].cargo);wood(old,8,old.automation.porters[0].cargo);wood(old,12,old.logistics.stocks[0])
 old.logistics.edit_roads(old,old.logistics.line(Vector2i(-12,9),Vector2i(4,9)))
 old.logistics.add_cart(old,"camp0","market0")
 # Captures in-flight cart wood as well as worker cargo, without advancing workers.
 old.logistics.tick(old,0.1)
 var old_ids=old.created[0]-old.sold[0];var old_money=old.money
 var refund=old.automation.costs()+old.logistics.depot_price(0,0)
 var migrated=State.new()
 check(migrated.restore(JSON.parse_string(JSON.stringify(old.snapshot(),"",true,true))),"Real v6 facility network migrates atomically")
 check(migrated.money==old_money+refund and migrated.logistics.held(0)==old_ids and migrated.conserved(),"Retired costs refunded and every warehouse/worker/cart log retained")
 check(migrated.logistics.roads==old.logistics.roads and migrated.logistics.carts[0].cargo.size()==old.logistics.carts[0].cargo.size(),"Existing roads and loaded cart survive migration")
 var again=State.new();check(again.restore(migrated.snapshot()) and again.money==migrated.money and again.migrated_refund==0,"Saving schema 7 prevents repeated migration credits")
 fixture("production-migration-fixture",migrated)
 # Malformed buffers, duplicated IDs, unsupported stages and paths fail atomically.
 var valid=stall.snapshot();var before_state=JSON.stringify(stall.snapshot())
 var bad=valid.duplicate(true);bad.logistics.sites[0].input[0].stage=2
 check(not stall.restore(bad) and JSON.stringify(stall.snapshot())==before_state,"Invalid processor input rejected without changing live state")
 bad=valid.duplicate(true);bad.logistics.sites[0].input[0].id=bad.logistics.sites[0].output[0].id
 check(not stall.restore(bad),"Duplicate IDs across input/output buffers rejected")
 bad=valid.duplicate(true);bad.logistics.next_site=1
 check(not stall.restore(bad),"Site identifiers cannot collide after reload")
 # One hour with a physical NPC and no shipments reaches bounded storage safely.
 for i in 36000: npc.tick(0.1,Vector2.ZERO)
 check(npc.conserved() and npc.logistics.held(0)<=npc.logistics.capacity(depot.id),"One-hour facility simulation stays bounded and conserves wood")
 print("KIKORI_FACILITY_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
