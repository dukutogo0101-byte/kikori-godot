extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var failures=0
var assertions=0
func check(ok: bool, message: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(message)
func produce(game, keep: int = 0) -> void:
 var tree=game.trees[0]
 tree.hp=0;tree.harvested=false;game.fell(0)
 while not game.ground.is_empty():
  var log=game.ground.pop_back()
  if game.bag.size()<keep: game.bag.append({"id":log.id,"kind":log.kind,"quality":log.quality,"stage":0})
  else: game.sell_log(log,Defs.SALE)
 tree.hp=Defs.KINDS[0].hp;tree.regrow=0.0;tree.fall=0.0;tree.harvested=false
func fixture(name: String, game) -> void:
 var data=JSON.parse_string(JSON.stringify(game.snapshot()))
 check(State.new().restore(data),"Fixture validates: "+name)
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=State.new()
 check(not game.buy("vehicle") and game.vehicle_tier==0 and game.money==0,"Unaffordable purchase is atomic")
 for i in 6000: produce(game)
 game.position=Vector2(0,25)
 fixture("player-vehicle-start",game)
 var old=game.snapshot();old.version=9;old.erase("vehicle_tier")
 var migrated=State.new()
 check(migrated.restore(old) and migrated.vehicle_tier==0 and migrated.money==game.money,"v9 preserves progress and starts on foot")
 check(migrated.snapshot().version==10,"Old saves upgrade to the new schema")
 for tier in [1,2]:
  var before=game.money
  check(game.buy("vehicle") and game.vehicle_tier==tier and game.money==before-Defs.PLAYER_VEHICLES[tier].price,"Sequential purchase deducts its exact price")
  check(game.speed()==Defs.PLAYER_VEHICLES[tier].speed and game.capacity()==Defs.PLAYER_VEHICLES[tier].capacity,"Each tier applies speed and capacity together")
  var restored=State.new()
  check(restored.restore(game.snapshot()) and restored.vehicle_tier==tier and restored.money==game.money,"Vehicle and purchase accounting survive reload")
  for i in ceili(float(game.capacity())/3): produce(game,game.capacity())
  check(game.bag.size()==game.capacity() and game.conserved(),"Full vehicle load preserves unique wood IDs")
  fixture("player-vehicle-loaded-%d" % tier,game)
  check(restored.restore(game.snapshot()) and restored.bag==game.bag,"Loaded inventory above 128 survives reload")
  restored.position=Defs.SALE
  var expected=restored.money
  for log in restored.bag: expected+=restored.log_value(log)
  for i in ceili(restored.capacity()*0.04/0.1)+2: restored.tick(0.1,Vector2.ZERO)
  check(restored.bag.is_empty() and restored.money==expected and restored.conserved(),"Large delivery pays exactly once")
  game.position=Vector2(0,-37)
  game.move(Vector2.UP,0.5)
  check(game.position.y>=-38+Defs.PLAYER_RADIUS,"Fast vehicle cannot tunnel across an unbuilt river")
  game.position=Vector2(4,9)
  game.move(Vector2.UP,0.5)
  check(game.position.y>=7.4+Defs.PLAYER_RADIUS,"Fast vehicle cannot tunnel through a building")
  game.position=Vector2(0,25)
  game.move(Vector2(1,1),0.05)
  check(is_equal_approx(game.velocity.length(),game.speed()),"Diagonal input remains normalized at vehicle speed")
  game.position=Vector2(0,25)
 var final_money=game.money
 check(not game.buy("vehicle") and game.money==final_money and game.vehicle_tier==2,"Maximum tier cannot be purchased again")
 var live=State.new();var unchanged=JSON.stringify(live.snapshot())
 for invalid in [-1,3,0.5,"1",null]:
  var bad=game.snapshot();bad.vehicle_tier=invalid
  check(not live.restore(bad) and JSON.stringify(live.snapshot())==unchanged,"Invalid vehicle tier fails atomically")
 var overfull=game.snapshot();overfull.vehicle_tier=0
 check(not live.restore(overfull),"Inventory cannot exceed the restored vehicle capacity")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false);scene.set_physics_process(false)
 for character in "軽トラスタイリッシュなトラック最高到達乗換":
  check(scene.ui.font.has_char(character.unicode_at(0)),"Vehicle label glyph exists: "+character)
 var base_nodes=scene.world.counts().nodes
 var shapes=[]
 for vehicle in scene.world.player_vehicles: shapes.append(vehicle.get_child(0).mesh)
 check(shapes.size()==2 and shapes[0]!=shapes[1],"Kei and premium trucks have distinct meshes")
 for tier in [0,1,2]:
  var data=JSON.parse_string(FileAccess.get_file_as_string("res://reports/player-vehicle-start.json" if tier==0 else "res://reports/player-vehicle-loaded-%d.json" % tier))
  check(scene.game.restore(data),"Presentation fixture restores")
  scene.world.pending.clear();scene.world.update(0)
  scene.ui.update(0,scene.controller,scene.world.camera)
  var counts=scene.world.counts()
  check(counts.vehicle_visible==tier and scene.world.walker.visible==(tier==0),"Only the selected vehicle or walker is visible")
  check(counts.rendered_cargo==mini(scene.game.bag.size(),Defs.CARGO_VISUAL_LIMIT),"Cargo rendering stays bounded for large inventories")
  check(counts.nodes==base_nodes,"Purchases and reloads do not grow the scene node count")
  check(scene.ui.rows.vehicle.button.disabled==(tier==2),"UI purchase state follows available funds and maximum tier")
  for i in Defs.CARGO_VISUAL_LIMIT:
   var at=scene.world.cargo_position(i)
   check(at.y<2.7 and absf(at.x)<0.9 and absf(at.z)<1.9,"Cargo stays inside a compact load bed")
 print("KIKORI_PLAYER_VEHICLES assertions=%d failures=%d" % [assertions,failures])
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
