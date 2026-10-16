extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
const Store=preload("res://scripts/save_store.gd")
var assertions=0
var failures=0
func check(ok: bool, label: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(label)
func _initialize() -> void:
 var game=State.new()
 var area_total=0.0
 var trees_valid=true
 for area in 3:
  var polygon=Defs.OUTLINES[area]
  var twice_area=0.0
  for i in polygon.size(): twice_area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
  area_total+=absf(twice_area)*0.5
 for tree in game.trees:
  if not Defs.in_area(tree.position,tree.kind,0.8): trees_valid=false
  for rect in Defs.building_rects():
   if rect.grow(0.8).has_point(tree.position): trees_valid=false
 check(area_total>2016*10,"Natural banks provide over ten times the previous land area")
 check(game.trees.size()>250 and trees_valid,"Hundreds of trees grow on accessible land, clear of buildings and water")
 check(Defs.MARKETS.size()==1 and game.nearest_sale()==Defs.SALE,"Only the central base is a terminal")
 check(Defs.SPAWN.distance_to(Defs.SALE)<6 and game.walkable(Defs.SPAWN),"Start beside the central base")
 for lake in Defs.LAKES: check(not game.walkable(lake.get_center()),"Lake interiors are not traversable")
 check(not game.walkable(Vector2(0,-41)) and not game.walkable(Vector2(0,-53)),"First river and hills stay locked")
 game.projects.bridge=60;game.projects.high_bridge=120
 var clear=true
 for area in 3:
  var route=Defs.porter_route(area)
  for i in range(route.size()-1):
   var steps=ceili(route[i].distance_to(route[i+1])*4)
   for step in steps+1:
    if not game.walkable(route[i].lerp(route[i+1],float(step)/steps)): clear=false
 check(clear,"Every base-return route is clear including both bridge seams and depot structures")
 # Flood the open world with a 1m walking grid, rather than only checking bounds.
 var visited={Vector2i(0,10):true};var queue=[Vector2i(0,10)];var head=0
 while head<queue.size():
  var p=queue[head];head+=1
  for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next=p+d
   if not visited.has(next) and game.walkable(Vector2(next)):
    visited[next]=true;queue.append(next)
 var all_reachable=true
 for tree in game.trees:
  var accessible=false
  var cell=Vector2i(roundi(tree.position.x),roundi(tree.position.y))
  for x in range(-1,2):
   for y in range(-1,2):
    var candidate=cell+Vector2i(x,y)
    if visited.has(candidate) and Vector2(candidate).distance_to(tree.position)<1.62: accessible=true
  if not accessible: all_reachable=false;print("UNREACHABLE_TREE ",tree.position)
 check(all_reachable,"Every grove has a connected route to the central base")
 check(visited.size()>18000,"Expanded map is traversable land, not just a large backdrop")
 check(Defs.height_at(Vector2(45,-200))>1.5 and Defs.height_at(Vector2(0,-80))==0,"Actual slopes rise above the flat trade valley")
 check(Defs.surface(Vector2(26,-90)).y.distance_to(Vector3.UP)>0.01,"Road orientation follows the hillside")
 # Three species, including far-grown quality, retain their price through storage.
 var wood_game=State.new();wood_game.projects.bridge=60;wood_game.projects.high_bridge=120
 wood_game.trees[0].cycle=60;wood_game.trees[0].hp=0;wood_game.trees[0].harvested=true;wood_game.trees[0].regrow=32.0
 wood_game.created[0]=180;wood_game.spent[0]=180;wood_game.next_id=181
 var far=-1
 for i in wood_game.trees.size():
  if wood_game.trees[i].kind==2 and wood_game.trees[i].quality==2: far=i;break
 wood_game.trees[far].hp=0;wood_game.fell(far)
 for log in wood_game.ground: wood_game.bag.append({"id":log.id,"kind":log.kind,"quality":log.quality})
 wood_game.ground.clear()
 var log=wood_game.bag[0]
 check(wood_game.log_value(log)==150 and wood_game.log_value(log)==wood_game.value(2)*3,"Distant highland timber rewards the journey at triple value")
 var before=wood_game.money
 check(not wood_game.sell_log(log,Vector2(12,-30)) and wood_game.money==before,"Removed markets cannot create money")
 wood_game.position=Vector2(6,-157)
 for tick in 20: wood_game.tick(0.1,Vector2.ZERO)
 check(wood_game.money==before and not wood_game.bag.is_empty(),"Merely arriving at a remote depot never pays")
 var restored=State.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(wood_game.snapshot(),"",true,true))),"High-quality cargo and its source ledger survive reload")
 check(restored.bag==wood_game.bag,"Quality and unique IDs survive reload")
 restored.position=Defs.SALE
 for tick in 10: restored.tick(0.1,Vector2.ZERO)
 check(restored.money==750 and restored.bag.is_empty() and restored.conserved(),"Only delivery to the base pays, once per log")
 restored.position=Vector2(-22,-182)
 check(restored.walkable(restored.position),"Far landscape fixture starts on a traversable hillside")
 var fixture_file=FileAccess.open("res://reports/watersheds-fixture.json",FileAccess.WRITE);fixture_file.store_string(JSON.stringify(restored.snapshot(),"",true,true));fixture_file.close()
 check(Store.KEY!="kikori.adventure.v2","New map does not overwrite the previous world's save key")
 print("KIKORI_WATERSHED_TESTS assertions=%d failures=%d land_m2=%.0f reachable_cells=%d trees=%d" % [assertions,failures,area_total,visited.size(),game.trees.size()])
 quit(1 if failures else 0)
