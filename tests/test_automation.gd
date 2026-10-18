extends SceneTree
const State=preload("res://scripts/adventure/legacy_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool,message: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(message)
func advance(game,seconds: float) -> void:
 for i in int(seconds*10): game.tick(0.1,Vector2.ZERO)
func json_copy(value):
 return JSON.parse_string(JSON.stringify(value,"",true,true))
func roundtrip(game) -> void:
 var restored=State.new()
 check(restored.restore(json_copy(game.snapshot())),"Automation save restores atomically")
 check(restored.conserved(),"All worker and storage inventories conserve resources")
 var original=game.automation.snapshot();var loaded=restored.automation.snapshot()
 for role in ["cutters","porters"]:
  for area in 3:
   check(absf(original[role][area].clock-loaded[role][area].clock)<1e-12,"JSON preserves work clock within floating-point precision")
   original[role][area].clock=0.0;loaded[role][area].clock=0.0
 check(restored.money==game.money and original==loaded,"Worker positions, cargo, equipment and money round trip")

func earned_start():
 var game=State.new()
 # Produce real identified logs and sell them to seed a legal economy fixture.
 for i in game.trees.size():
  if game.trees[i].kind!=0: continue
  game.trees[i].hp=0
  game.fell(i)
 while not game.ground.is_empty(): game.sell_log(game.ground.pop_back(),Defs.SALE)
 return game
func _initialize() -> void:
 var game=earned_start()
 check(game.conserved(),"Initial fixture is earned revenue, no free cash")
 check(not game.automation.buy(game,1,"camp"),"Locked forest cannot buy automation")
 check(not game.automation.buy(game,0,"porter"),"Transport needs a camp")
 var funds=game.money
 check(game.automation.buy(game,0,"camp") and game.money==funds-180,"Camp purchase pays exact cost")
 check(not game.automation.buy(game,-1,"camp") and not game.automation.buy(game,3,"camp") and not game.automation.buy(game,0,"invalid"),"Invalid purchase inputs are harmless")
 advance(game,110)
 check(game.automation.stocks[0].size()>0,"Cutter travels, chops real trees and brings timber to storage")
 check(game.money==funds-180,"A camp without transport stores logs instead of silently selling")
 roundtrip(game)
 game.position=Defs.CAMPS[0]
 advance(game,1)
 check(game.bag.size()>0,"Player can withdraw warehouse stock")
 check(game.conserved(),"Withdrawal transfers existing IDs only")
 game.position=Defs.SALE
 advance(game,1)
 game.position=Defs.SPAWN
 check(game.automation.buy(game,0,"porter"),"Buy visible transport")
 advance(game,110)
 check(game.money>funds-320,"Transport delivers stored timber and sells it")
 roundtrip(game)
 var before=game.value(0)
 var price=game.automation.price(0,"mill")
 var balance=game.money
 check(game.automation.buy(game,0,"mill"),"Spend earned automation revenue on processing")
 check(game.money==balance-price and game.value(0)>before,"Processing price and increased sale value agree")
 advance(game,60)
 roundtrip(game)
 # Save and resume with cargo in transit, without duplicating sale money.
 var saw_cargo=false
 for i in 1000:
  game.tick(0.1,Vector2.ZERO)
  if not game.automation.porters[0].cargo.is_empty():
   saw_cargo=true
   break
 check(saw_cargo,"Carrier has real cargo in transit")
 var restored=State.new()
 check(restored.restore(json_copy(game.snapshot())),"Cargo in transit survives reload")
 for i in 300:
  game.tick(0.1,Vector2.ZERO)
  restored.tick(0.1,Vector2.ZERO)
 check(restored.money==game.money and restored.sold==game.sold,"Reload neither repeats nor loses sales")
 check(restored.conserved(),"Reload keeps resource accounting")
 var valid=game.snapshot()
 var bads=[]
 var bad=valid.duplicate(true);bad.automation.levels[0].mill=4;bads.append(bad)
 bad=valid.duplicate(true);bad.automation.levels[1].camp=1;bads.append(bad)
 bad=valid.duplicate(true);bad.automation.porters[0].position=[0,-99];bads.append(bad)
 bad=valid.duplicate(true);bad.automation.stocks[0].append({"id":1,"kind":2});bads.append(bad)
 bad=valid.duplicate(true);bad.automation.cutters[0].clock=-1;bads.append(bad)
 bad=valid.duplicate(true);bad.automation.stocks[0].append({"id":valid.automation.porters[0].cargo[0].id if not valid.automation.porters[0].cargo.is_empty() else 1,"kind":0});bads.append(bad)
 for damaged in bads:
  var original=JSON.stringify(game.snapshot())
  check(not game.restore(damaged),"Invalid automation data is rejected")
  check(JSON.stringify(game.snapshot())==original,"Failed restore changes no live state")
 # New watershed map uses a distinct save format; old worlds are not misread.
 var old_world=earned_start().snapshot();old_world.version=4
 check(not State.new().restore(json_copy(old_world)),"Old world coordinates cannot enter the redesigned world")
 # Every species must physically return to the single central terminal.
 var regional=State.new()
 regional.projects.bridge=60;regional.projects.high_bridge=120
 regional.trees[0].cycle=60;regional.trees[0].hp=0;regional.trees[0].harvested=true;regional.trees[0].regrow=32.0
 regional.created[0]=180;regional.spent[0]=180;regional.next_id=181
 for area in 3:
  var index=-1
  for i in regional.trees.size():
   if regional.trees[i].kind==area and regional.trees[i].hp>0: index=i;break
  regional.trees[index].hp=0;regional.fell(index)
  while not regional.ground.is_empty():
   var log=regional.ground.pop_back()
   regional.bag.append({"id":log.id,"kind":log.kind,"quality":log.quality})
  regional.position=Defs.SALE
  var starting=regional.money
  advance(regional,1)
  check(regional.bag.is_empty() and regional.money==starting+Defs.KINDS[area]["yield"]*regional.value(area,regional.trees[index].quality),"Each forest's market sells correct local wood")
 roundtrip(regional)
 for area in 3:
  var cost=regional.automation.price(area,"camp")+regional.automation.price(area,"porter")
  while regional.money<cost:
   for i in regional.trees.size():
    if regional.trees[i].kind==area and regional.trees[i].hp>0: regional.trees[i].hp=0;regional.fell(i)
   while not regional.ground.is_empty(): regional.sell_log(regional.ground.pop_back(),regional.automation.market(area))
   advance(regional,49)
  regional.automation.buy(regional,area,"camp");regional.automation.buy(regional,area,"porter")
  regional.position=Defs.SPAWN
  var sold_before=regional.sold[area]
  advance(regional,180)
  check(regional.sold[area]>sold_before,"Every forest's cutter and carrier can reach the market")
  roundtrip(regional)
 advance(regional,3600)
 check(regional.conserved(),"One hour with three automated forests conserves resources")
 for area in 3:
  check(regional.automation.stocks[area].size()<=regional.automation.capacity(area),"Warehouse stays bounded")
 roundtrip(regional)
 var fixture=earned_start()
 advance(fixture,40)
 DirAccess.make_dir_recursive_absolute("res://reports")
 var file=FileAccess.open("res://reports/automation-fixture.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(fixture.snapshot(),"",true,true));file.close()
 print("KIKORI_AUTOMATION_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
