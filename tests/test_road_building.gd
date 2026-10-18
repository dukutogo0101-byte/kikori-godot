extends SceneTree
const State=preload("res://scripts/adventure/game_state.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
var assertions=0
var failures=0
func check(ok: bool, label: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(label)
func fixture(name: String, game) -> void:
 check(State.new().restore(game.snapshot()),"Validated browser road fixture")
 var file=FileAccess.open("res://reports/"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(game.snapshot(),"",true,true));file.close()
func _initialize() -> void:
 call_deferred("run")
func stroke(scene, points: Array, canceled: bool = false) -> void:
 var touch=InputEventScreenTouch.new();touch.index=7;touch.pressed=true
 touch.position=scene.world.camera.unproject_position(Defs.point(points[0]));scene.roads._input(touch)
 for p in points.slice(1):
  var drag=InputEventScreenDrag.new();drag.index=7;drag.position=scene.world.camera.unproject_position(Defs.point(p));scene.roads._input(drag)
 touch.pressed=false;touch.canceled=canceled;touch.position=scene.world.camera.unproject_position(Defs.point(points.back()));scene.roads._input(touch)
func run() -> void:
 var fresh=State.new();var net=fresh.logistics
 var initial=net.path_between(fresh,Vector2i(-12,9),Vector2i(4,9))
 check(initial.size()==17 and net.roads.is_empty() and net.costs()==0,"Visible starting trail is a free connected cart road")
 check(not net.has_road(fresh,Vector2i(0,-41)),"Unbuilt river crossing stays closed")
 fresh.projects.bridge=60
 var hills=net.path_between(fresh,Vector2i(-28,-64),Vector2i(4,9))
 check(not hills.is_empty() and hills.has(Vector2i(0,-41)),"Completed first bridge immediately joins both natural road networks")
 fresh.projects.high_bridge=120
 var high=net.path_between(fresh,Vector2i(-34,-157),Vector2i(4,9))
 check(high.size()>170 and high.has(Vector2i(6,-117)) and high.has(Vector2i(0,-41)),"Highland route crosses both completed bridges without paving their decks")
 var continuous=true
 for i in range(1,high.size()):
  if not net.edge_ok(fresh,high[i-1],high[i]) or not net.has_road(fresh,high[i]): continuous=false
 check(continuous,"Every natural road and bridge seam is physically traversable")
 fresh.projects.bridge=0
 check(net.path_between(fresh,Vector2i(-28,-64),Vector2i(4,9)).is_empty(),"Unlock changes invalidate old cached routes")
 fresh=State.new();fresh.money=100;net=fresh.logistics
 check(not net.edit_roads(fresh,net.line(Vector2i(-12,9),Vector2i(4,9))) and fresh.money==100,"Existing trails never charge another construction fee")
 check(net.edit_roads(fresh,net.line(Vector2i(4,9),Vector2i(4,12))) and fresh.money==94 and net.roads.size()==3,"Only a new branch is charged; the existing junction is free")
 check(not net.edit_roads(fresh,[Vector2i(4,9)],true) and fresh.money==94,"Permanent natural roads cannot be demolished")
 # A legally earned highland fixture drives cargo over two public bridges.
 var game=State.new()
 var saved=JSON.parse_string(FileAccess.get_file_as_string("res://reports/watersheds-fixture.json"))
 check(game.restore(saved),"Earned highland save restores")
 net=game.logistics
 check(net.build(game,"storage",Vector2(-34,-157)),"Storage can connect directly to an existing distant trail")
 var site=net.sites[0];site.worker_enabled=false
 var target=-1
 for i in game.trees.size():
  if game.trees[i].kind==2 and game.trees[i].quality==2 and game.trees[i].hp>0: target=i;break
 game.trees[target].hp=0;game.fell(target)
 for log in game.ground:
  site.output.append({"id":log.id,"kind":log.kind,"quality":log.quality,"stage":0})
 game.ground.clear()
 check(net.add_cart(game,site.id,"market0") and net.roads.is_empty(),"A cart can operate entirely on the existing network")
 var funds=game.money;var crossed=false;var reloaded=false
 for i in 1500:
  game.tick(0.1,Vector2.ZERO)
  var cart=net.carts[0]
  if cart.position.y>-120 and cart.position.y<-113 and not cart.cargo.is_empty():
   crossed=true
   if not reloaded:
    var copy=State.new();check(copy.restore(JSON.parse_string(JSON.stringify(game.snapshot(),"",true,true))),"Loaded cart on a free bridge restores without any paid road cells")
    check(copy.conserved() and copy.logistics.carts[0].cargo==cart.cargo,"Bridge reload retains every cargo ID")
    reloaded=true
  if game.money>=funds+750: break
 check(crossed and reloaded and game.money==funds+750 and game.conserved(),"Distant cargo crosses the river and is paid only after base arrival")
 # Exercise real screen gestures against the actual editor and camera.
 root.size=Vector2i(390,844)
 var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
 var bank=JSON.parse_string(FileAccess.get_file_as_string("res://reports/production-start-fixture.json"))
 check(scene.game.restore(bank),"Road editor bank fixture restores")
 var direct=State.new();direct.restore(bank);direct.logistics.build(direct,"storage",Vector2(-12,9))
 var supply=direct.logistics.sites[0];supply.worker_enabled=false
 direct.trees[0].hp=0;direct.fell(0)
 for log in direct.ground: supply.output.append({"id":log.id,"kind":log.kind,"quality":log.quality,"stage":0})
 direct.ground.clear()
 fixture("roads-existing-fixture",direct)
 var editor=scene.roads;editor.start(Vector2(-12,9));scene.world.update(0)
 check(not scene.ui.root.get_node("Top").visible and editor.toolbar.position.y==12,"Editor frees the top of the screen for drawing")
 var money=scene.game.money
 stroke(scene,[Vector2(-12,9),Vector2(-11,10),Vector2(-12,12),Vector2(-11,14),Vector2(-12,17)])
 var straight=true
 for p in editor.preview:
  if p.x!=-12: straight=false
 check(straight and editor.preview.back()==Vector2i(-12,17),"Finger jitter becomes a single straight grid line")
 check(scene.game.money==money and scene.game.logistics.roads.is_empty(),"Drafting never buys road cells")
 var prior=editor.preview.duplicate();var cost=editor.cost()
 editor.select_mode("pan")
 check(editor.preview==prior and editor.cost()==cost,"Switching to pan keeps the full draft")
 var focus=scene.world.planning_focus
 var touch=InputEventScreenTouch.new();touch.index=8;touch.pressed=true;touch.position=Vector2(195,390);editor._input(touch)
 var drag=InputEventScreenDrag.new();drag.index=8;drag.position=Vector2(140,390);editor._input(drag)
 touch.pressed=false;touch.position=drag.position;editor._input(touch)
 check(scene.world.planning_focus.distance_to(focus)>1 and editor.preview==prior,"Panning moves only the camera and preserves pending roads")
 editor.select_mode("build")
 stroke(scene,[Vector2(-12,17),Vector2(-12,21)])
 check(editor.preview.back()==Vector2i(-12,21) and editor.preview[0]==Vector2i(-12,9),"A new stroke extends the draft after camera movement")
 editor.undo();check(editor.preview==prior,"Undo removes exactly the last extension")
 stroke(scene,[Vector2(-12,17),Vector2(-12,23)],true)
 check(editor.preview==prior,"Touch cancellation discards only its current stroke")
 var old_size=root.size;root.size=Vector2i(844,390);await process_frame
 check(editor.preview==prior and editor.confirm.get_global_rect().position.y>=0,"Rotation preserves the draft and keeps confirmation on screen")
 root.size=old_size;await process_frame
 editor.reset();editor.orthogonal=true;scene.world.update(0)
 stroke(scene,[Vector2(-12,9),Vector2(-6,15)])
 var connected=true
 for i in range(1,editor.preview.size()):
  var d=editor.preview[i]-editor.preview[i-1]
  if absi(d.x)+absi(d.y)!=1: connected=false
 check(connected and editor.preview.back()==Vector2i(-6,15),"Corner mode creates a fully connected right-angle route")
 editor.reset();editor.orthogonal=false;editor.pan_by(Vector2(-scene.world.planning_focus.x,10-scene.world.planning_focus.z))
 # Hold a horizontal stroke at the right edge and advance real editor updates.
 touch.index=8;touch.pressed=true;touch.position=Vector2(170,380);editor._input(touch)
 drag.index=8;drag.position=Vector2(376,380);editor._input(drag)
 focus=scene.world.planning_focus
 for i in 90: editor.update(1.0/60)
 check(scene.world.planning_focus.x>focus.x+8 and editor.preview.size()>10,"Holding the screen edge scrolls the map and extends the straight draft")
 touch.pressed=false;touch.position=drag.position;editor._input(touch)
 check(editor.history.size()==1,"Auto-scrolling remains one undoable section")
 # Long routes no longer inherit the old 160-cell purchase limit.
 editor.reset();editor.preview=scene.game.logistics.line(Vector2i(0,20),Vector2i(0,-160));editor.sync_preview()
 check(editor.preview.size()==181 and scene.world.road_preview.size()==181,"A complete long route can be previewed before a single confirmation")
 editor.reset();editor.finish()
 check(scene.ui.root.get_node("Top").visible and scene.controller.enabled,"Leaving the editor restores the normal HUD and movement")
 scene.queue_free()
 print("KIKORI_ROAD_BUILDING_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
