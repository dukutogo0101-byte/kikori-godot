extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Legacy=preload("res://scripts/adventure/legacy_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool, message: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(message)
func advance(game, seconds: float) -> void:
 for i in ceili(seconds*10): game.tick(0.1,Vector2.ZERO)
func produce(game, keep: int = 0) -> void:
 var tree=game.trees[0]
 tree.hp=0;tree.harvested=false;game.fell(0)
 while not game.ground.is_empty():
  var log=game.ground.pop_back()
  if game.bag.size()<keep: game.bag.append({"id":log.id,"kind":log.kind,"quality":log.quality,"stage":0})
  else: game.sell_log(log,Defs.SALE)
 tree.hp=Defs.KINDS[0].hp;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
func earned():
 var game=State.new()
 for i in 1000: produce(game)
 return game
func fixture(name: String, game) -> void:
 var data=JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))
 check(State.new().restore(data),"Browser fixture passes strict save validation: "+name)
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()
func _initialize() -> void:
 var fresh=State.new()
 check(fresh.speed()==6.5 and fresh.capacity()==128,"Fast movement and 128-log capacity are standard")
 check(not fresh.buy("boots") and not fresh.buy("pack"),"Retired progression has no purchase path")
 var game=State.new();game.position=Vector2(0,-0.2);game.levels.cut_range=2
 advance(game,0.5)
 check(game.trees[5].hp==2 and game.trees[6].hp==2,"One swing damages both trees inside the radius")
 check(game.trees[4].hp==3 and game.trees[7].hp==3,"Trees outside the radius remain untouched")
 advance(game,1.0)
 check(game.created[0]==6 and game.conserved(),"Two felled trees produce exactly their combined yield")
 var before=game.created.duplicate();game.fell(5);game.fell(6)
 check(game.created==before,"Simultaneous cuts cannot be repeated for duplicate timber")
 game.levels.collect_range=2
 advance(game,0.1)
 check(game.bag.size()>0 and game.ground.size()<6 and game.conserved(),"Wider collection draws distant logs into the same resource ledger")
 var stopped=State.new();stopped.position=Vector2(0,-0.2);stopped.levels.cut_range=6
 stopped.tick(0.1,Vector2.RIGHT)
 check(stopped.targets.is_empty() and stopped.target==-1 and stopped.created[0]==0,"Moving cancels every target, including wide tools")
 var blocked=State.new();blocked.position=Vector2(0,-37)
 check(not blocked.resource_reachable(Vector2(0,-46)),"Unbuilt river cannot be reached through")
 check(not blocked.resource_reachable(Vector2(0,-41)),"Unbuilt bridge remains a resource barrier")
 blocked.projects.bridge=60
 check(blocked.resource_reachable(Vector2(0,-46)),"Completed bridge opens the resource corridor")
 blocked.position=Vector2(4,9)
 check(not blocked.resource_reachable(Vector2(4,4)),"Buildings block an expanded collection ray")
 blocked.position=Vector2(22,28)
 check(not blocked.resource_reachable(Vector2(43,28)),"Lake blocks an expanded collection ray")
 # Leave only two ground slots, then swing a broad tool. No fall may overrun it.
 var capped=State.new();capped.levels.cut_range=6;capped.position=Vector2(0,-0.2)
 for i in 53:
  var t=capped.trees[24];t.hp=0;t.harvested=false;capped.fell(24)
  t.hp=3;t.regrow=0.0;t.fall=0.0;t.harvested=false
 for log in capped.ground: log.position=Vector2(-20,40)
 var original=capped.created.duplicate()
 advance(capped,3)
 check(capped.ground.size()==159 and capped.created==original and capped.trees[5].hp==3,"Ground cap refuses multi-cut before damaging or losing wood")
 check(capped.conserved(),"Capped multi-cut conserves all resources")
 # Validate every old purchase level and refund exactly the retired expenditure.
 var bank=earned()
 var old_bank=Legacy.new()
 for i in 1000: produce(old_bank)
 for pack in range(7):
  for boots in range(7):
   var old=old_bank.snapshot();old.version=5;old.levels={"axe":0,"pack":pack,"boots":boots}
   var refund=0
   for key in ["pack","boots"]:
    for level in int(old.levels[key]): refund+=int(round((60 if key=="pack" else 80)*pow(1.65,level)))
   old.money-=refund
   var migrated=State.new()
   check(migrated.restore(old) and migrated.money==bank.money,"Legacy purchase costs refund once (%d/%d)" % [pack,boots])
   check(migrated.capacity()==128 and migrated.speed()==6.5 and migrated.levels=={"axe":0,"cut_range":0,"collect_range":0},"Legacy gear converts to fixed equipment and fresh range levels")
   var again=State.new()
   check(again.restore(migrated.snapshot()) and again.money==migrated.money and again.migrated_refund==0,"Saving v7 prevents a second refund")
 var legacy=old_bank.snapshot();legacy.version=5;legacy.levels={"axe":0,"pack":0,"boots":0}
 legacy.money+=1000000
 var live=State.new();var original_state=JSON.stringify(live.snapshot())
 check(not live.restore(legacy) and JSON.stringify(live.snapshot())==original_state,"Invalid legacy cash fails atomically before refund")
 # Seed real, uniquely identified wood for large-inventory browser/render checks.
 bank.position=Vector2(0,-0.2)
 fixture("tools-fixture",bank)
 for key in Defs.UPGRADE_NAMES:
  for level in Defs.MAX_LEVEL:
   check(bank.buy(key),"Every new upgrade can be bought with earned revenue")
 check(bank.cut_radius()==7.6 and bank.collect_radius()==8.5 and bank.tool_tier()==3,"Maximum ranges and the twin-blade tool agree")
 for i in 43: produce(bank,128)
 check(bank.bag.size()==128 and bank.conserved(),"128 distinct logs fit without losing or duplicating timber")
 fixture("tools-loaded-fixture",bank)
 var copy=State.new();check(copy.restore(bank.snapshot()) and copy.bag==bank.bag,"All 128 IDs survive reload")
 copy.position=Defs.SALE;var expected=copy.money
 for log in copy.bag: expected+=copy.log_value(log)
 advance(copy,6)
 check(copy.bag.is_empty() and copy.money==expected and copy.conserved(),"A full 128-log delivery pays exactly once")
 print("KIKORI_TOOLS_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
