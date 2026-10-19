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
 for i in 100000:
  var logs=[];wood(game,3,logs,2)
  for log in logs: game.sell_log(log,Defs.SALE)
 return game
func copy_of(game):
 var copy=State.new()
 check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),"Strict JSON restore with building tier, size and inventories")
 check(copy.conserved() and copy.money==game.money,"Building restore conserves every log and purchase")
 return copy
func fixture(name: String, game) -> void:
 check(State.new().restore(game.snapshot()),"Valid building fixture "+name)
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(game.snapshot(),"",true,true));file.close()
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var rich=earned();fixture("building-start-fixture",rich)
 for kind in ["storage","processor","factory"]:
  var game=State.new();check(game.restore(rich.snapshot()),"Earned building funds")
  var net=game.logistics;var initial=game.money
  check(net.build(game,kind,Vector2(-12,9)),"Normal building placement")
  check(net.build(game,kind,Vector2(-12,23),true),"Large building placement")
  var a=net.sites[0];var b=net.sites[1];a.worker_enabled=false;b.worker_enabled=false
  check(initial-game.money==net.price(kind)*6,"Large construction is exactly five times normal")
  wood(game,3,a.output,0 if kind=="storage" else (1 if kind=="processor" else 2))
  wood(game,3,b.output,0 if kind=="storage" else (1 if kind=="processor" else 2))
  var inventory=JSON.stringify([a.output,b.output]);var paid=a.paid+b.paid
  for step in 15:
   check(a.tier==step/5 and a.level==step%5+1 and b.tier==a.tier and b.level==a.level,"Five levels in each of three structures")
   check(net.capacity(b.id)==net.capacity(a.id)*6,"Large capacity stays exactly six times matching normal level")
   check(is_equal_approx(net.processing_interval(a),net.processing_interval(b)*6),"Large processing speed stays exactly six times")
   check(is_equal_approx(net.footprint(b).get_area(),net.footprint(a).get_area()*4),"Large footprint has four times the area")
   check(net.workers(b).size()==(6 if kind=="storage" else 1),"Large storage has six independently conserved workers")
   check(a.position==Vector2(-12,9) and b.position==Vector2(-12,23) and JSON.stringify([a.output,b.output])==inventory,"Upgrades preserve ports and stocked IDs")
   var copy=copy_of(game)
   check(copy.logistics.site(a.id).tier==a.tier and copy.logistics.site(b.id).large,"Structure and size survive reload")
   if step<14:
    var cost=net.site_upgrade_price(a);var large_cost=net.site_upgrade_price(b);var funds=game.money
    check(large_cost==cost*5,"Large improvement and promotion cost exactly five times")
    check(net.upgrade(game,a.id) and net.upgrade(game,b.id),"Purchase the next level or material")
    paid+=cost+large_cost
    check(game.money==funds-cost-large_cost and a.paid+b.paid==paid,"Each upgrade charges exactly once")
  var before=game.money
  check(not net.upgrade(game,a.id) and not net.upgrade(game,b.id) and game.money==before,"Steel level five is final and never charges")
  check(initial-game.money==paid,"All building investments reconcile with earned revenue")
  if kind=="processor": fixture("building-steel-fixture",game)
 # Browser starts one purchase before a material promotion, using earned funds.
 var ui_game=State.new();check(ui_game.restore(rich.snapshot()),"Promotion fixture funds")
 ui_game.logistics.build(ui_game,"processor",Vector2(-12,23),true)
 for i in 4: check(ui_game.logistics.upgrade(ui_game,"site1"),"Prepare wood level five")
 ui_game.position=Vector2(-12,23)
 fixture("building-promote-fixture",ui_game)
 # Existing v8 wood levels and inherited free buildings keep paid costs, cargo,
 # workers and cart data. No refund is granted for structure migration.
 var old=State.new();check(old.restore(rich.snapshot()),"Old-save fixture funds")
 old.logistics.build(old,"storage",Vector2(-12,9));old.logistics.upgrade(old,"site1");old.logistics.upgrade(old,"site1")
 var v8=old.snapshot();v8.version=8
 for site in v8.logistics.sites:
  for key in ["tier","large","free_steps","crew"]: site.erase(key)
 var migrated=State.new();check(migrated.restore(v8) and migrated.money==old.money and migrated.logistics.sites[0].level==3,"v8 level-three storage migrates with no extra refund")
 v8.logistics.sites[0].paid=0;v8.money+=old.logistics.sites[0].paid
 check(migrated.restore(v8) and migrated.logistics.sites[0].free_steps==3,"Inherited free levels remain credited once")
 check(migrated.logistics.upgrade(migrated,"site1"),"Migrated building can buy its new fourth level")
 copy_of(migrated)
 # Six workers must select different live trees and reserve aggregate space.
 var npc=State.new();check(npc.restore(rich.snapshot()),"NPC funds")
 check(npc.logistics.build(npc,"storage",Vector2(-12,10),true),"Large NPC depot")
 var depot=npc.logistics.sites[0];var targets={}
 npc.logistics.tick_production(npc,0.1)
 for worker in npc.logistics.workers(depot):
  check(worker.target>=0 and not targets.has(worker.target),"Large-depot workers claim distinct reachable trees")
  targets[worker.target]=true
 check(npc.logistics.reserved(depot.id)==30,"Six workers reserve five slots each before harvesting")
 copy_of(npc)
 var returning=false
 for i in 800:
  npc.tick(0.1,Vector2.ZERO)
  for worker in npc.logistics.workers(depot):
   if not worker.cargo.is_empty() and not returning: copy_of(npc);returning=true
  if depot.output.size()>=18: break
 check(returning and depot.output.size()>=18 and npc.conserved(),"All six NPCs physically harvest and deliver without duplicate IDs")
 depot.worker_enabled=false
 for i in 300: npc.tick(0.1,Vector2.ZERO)
 var idle=true
 for worker in npc.logistics.workers(depot): idle=idle and worker.phase=="idle" and worker.cargo.is_empty()
 check(idle and npc.conserved(),"All six workers finish delivery before pausing")
 copy_of(npc);fixture("building-large-npc-fixture",npc)
 depot.worker_enabled=true
 for i in 36000: npc.tick(0.1,Vector2.ZERO)
 check(npc.conserved() and depot.output.size()+npc.logistics.reserved(depot.id)<=npc.logistics.capacity(depot.id),"One hour with six NPCs never overbooks large storage")
 copy_of(npc)
 # Real elapsed processing, stage preservation and full-buffer backpressure.
 for kind in ["processor","factory"]:
  var g=State.new();check(g.restore(rich.snapshot()),"Processing funds")
  var n=g.logistics;n.build(g,kind,Vector2(-12,9));n.build(g,kind,Vector2(-12,23),true)
  var normal=n.sites[0];var large=n.sites[1];var stage=0 if kind=="processor" else 1
  wood(g,12,normal.input,stage);wood(g,12,large.input,stage)
  for i in 60: n.tick_production(g,0.1)
  n.tick_production(g,0.001) # Allow floating-point rounding at the six-second boundary.
  check(normal.output.size()==1 and large.output.size()==6,"Six seconds processes one normal versus six large logs")
  check(large.output[0].stage==stage+1 and g.conserved(),"Processing preserves resource IDs and advances stage once")
  wood(g,n.capacity(large.id)-large.output.size(),large.output,stage+1)
  var count=large.input.size();n.tick_production(g,1)
  check(large.input.size()==count,"Full large output retains input logs")
  g.bag.append(large.output.pop_back());n.tick_production(g,1.1)
  check(large.input.size()==count-1 and large.output.size()==n.capacity(large.id) and g.conserved(),"Large processing resumes with one exact free slot")
  copy_of(g)
 # Full lot, not only a center point: surrounding roads and buildings block it.
 var collision=State.new();check(collision.restore(rich.snapshot()),"Placement funds")
 var n=collision.logistics;var money=collision.money
 check(not n.build(collision,"factory",Vector2(4,9),true) and collision.money==money,"Large building cannot cover central base")
 check(not n.build(collision,"factory",Vector2(0,-38),true) and collision.money==money,"Large building cannot cover river")
 check(not n.build(collision,"factory",Vector2(-3,4),true) and collision.money==money,"Large building cannot cover live trees")
 check(n.edit_roads(collision,[Vector2i(-12,5)]),"Place road inside candidate large footprint")
 money=collision.money
 check(not n.build(collision,"storage",Vector2(-12,10),true) and collision.money==money,"Entire large footprint rejects an interior road before charging")
 var poor=State.new();poor.money=0
 check(not poor.logistics.build(poor,"storage",Vector2(-12,10),true) and poor.logistics.sites.is_empty(),"Unaffordable large building has no partial placement")
 # Invalid new fields fail atomically without erasing a running game.
 var valid=npc.snapshot();var original=JSON.stringify(npc.snapshot())
 for key in ["tier","large","free_steps","crew","paid"]:
  var bad=valid.duplicate(true)
  bad.logistics.sites[0][key]={"tier":3,"large":1,"free_steps":4,"crew":[],"paid":1}[key]
  check(not npc.restore(bad) and JSON.stringify(npc.snapshot())==original,"Malformed "+key+" rejected atomically")
 # Compression permits maximum-size stocks under a mobile storage budget.
 var store=Store.new("user://building-storage-test.json")
 var payload=rich.snapshot();payload.future_metadata=[]
 for i in 491520: payload.future_metadata.append({"id":i+1,"kind":i%3,"quality":i%3,"stage":i%3})
 check(store.write_save(payload),"Maximum sixteen-building stock-sized save fits storage")
 check(FileAccess.get_file_as_string(store.file_path).begins_with(Store.PREFIX),"Large saves use synchronous gzip envelope")
 var loaded=store.read_save()
 check(loaded.get("future_metadata",[]).size()==491520 and State.new().restore(loaded),"Compressed large stock payload round-trips without loss")
 var file=FileAccess.open(store.file_path,FileAccess.WRITE);file.store_string(JSON.stringify(rich.snapshot()));file.close()
 check(State.new().restore(store.read_save()),"Existing plain JSON storage stays readable")
 DirAccess.remove_absolute(store.file_path)
 # Fixed-size artwork pools, all structures, both sizes and six worker views.
 var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
 check(scene.game.restore(npc.snapshot()),"Restore six-worker scene")
 var view=scene.world.logistics_view;var nodes=view.get_child_count()
 for tier in 3:
  scene.game.logistics.sites[0].tier=tier;scene.world.update(0)
  check(view.sites[0].shapes[tier].visible and view.sites[0].root.scale==Vector3.ONE*2,"Visible structure mesh and large scale")
  var visible=0
  for actor in view.sites[0].crew:
   if actor.root.visible: visible+=1
  check(visible==6,"All six NPCs have rendered workers")
 check(view.get_child_count()==nodes,"Structure updates reuse bounded rendering pools")
 scene.queue_free()
 print("KIKORI_BUILDING_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
