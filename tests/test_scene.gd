extends SceneTree
var failures=0
var assertions=0
func check(ok: bool,message: String) -> void:
 assertions+=1
 if not ok: failures+=1;push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var c=scene.controller
 var ui=scene.ui
 var test_y=minf(400,root.get_visible_rect().size.y*0.6)
 var touch=InputEventScreenTouch.new()
 touch.index=0;touch.pressed=true;touch.position=ui.menu_button.get_global_rect().get_center()
 c._input(touch)
 check(c.active_touch==-1,"UI touches never start movement")
 touch.position=ui.view_button.get_global_rect().get_center();c._input(touch)
 check(c.active_touch==-1,"View button touches never start movement")
 check(scene.world.camera.size>=18,"Default camera shows a broader scene")
 touch.position=Vector2(160,test_y);c._input(touch)
 var drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(224,test_y-64)
 c._input(drag)
 check(absf(c.sample().length()-1)<0.001,"Touch diagonal speed normalized")
 touch.pressed=false;c._input(touch)
 check(c.sample()==Vector2.ZERO,"Touch release stops input")
 touch.pressed=true;c._input(touch)
 touch.canceled=true;c._input(touch)
 check(c.active_touch==-1,"Touch cancellation clears stick")
 touch.canceled=false;c._input(touch)
 drag.position=Vector2(-1,test_y);c._input(drag)
 check(c.sample()==Vector2.ZERO,"Leaving viewport cancels input")
 var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=Vector2(160,test_y)
 c._input(mouse)
 var motion=InputEventMouseMotion.new();motion.position=Vector2(224,test_y);c._input(motion)
 check(c.sample().x==1,"Mouse stick moves right")
 mouse.pressed=false;c._input(mouse)
 check(c.sample()==Vector2.ZERO,"Mouse release stops input")
 var key=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true;c._input(key)
 check(c.sample().y==-1,"PC physical keys move upward")
 c.reset();check(c.sample()==Vector2.ZERO,"Reset clears held keyboard input")
 ui.show_menu(true)
 c._input(key)
 check(c.sample()==Vector2.ZERO,"Upgrade modal blocks movement")
 var before=scene.game.elapsed
 scene._physics_process(1.0/60)
 check(scene.game.elapsed==before,"Modal does not consume player's wood")
 ui.show_menu(false)
 var old_size=root.size
 root.size=Vector2i(844,390)
 await process_frame
 check(root.get_visible_rect().size.x>root.get_visible_rect().size.y,"Landscape viewport expands")
 root.size=old_size
 await process_frame
 # Real screen events preview a road, require confirmation and never move the hero.
 ui.show_logistics(true)
 check(ui.modal_open and ui.logistics_panel.visible,"Logistics menu blocks game controls")
 ui.show_logistics(false)
 var at=scene.game.position
 scene.roads.start(Vector2(-12,9));scene.world.update(0)
 check(not c.enabled,"Road editing disables the movement controller")
 var start=scene.world.camera.unproject_position(Vector3(-12,0,9))
 var end=scene.world.camera.unproject_position(Vector3(-12,0,12))
 var road_touch=InputEventScreenTouch.new();road_touch.index=3;road_touch.pressed=true;road_touch.position=start
 scene.roads._input(road_touch)
 var road_drag=InputEventScreenDrag.new();road_drag.index=3;road_drag.position=end;scene.roads._input(road_drag)
 road_touch.pressed=false;road_touch.position=end;scene.roads._input(road_touch)
 check(scene.roads.preview.size()>=3 and scene.game.logistics.roads.is_empty(),"A road stroke is only a preview until confirmed")
 check(scene.game.position==at,"Drawing roads never moves the hero")
 scene.roads.reset();check(scene.roads.preview.is_empty(),"Canceling input discards an unconfirmed road")
 scene.roads.finish();check(c.enabled,"Leaving the editor restores movement")
 ui.show_map(true)
 await process_frame
 check(ui.map_close.get_global_rect().position.y>=0 and ui.map_panel.size.y<=root.get_visible_rect().size.y-12,"Map and its close button fit inside the viewport")
 check(ui.modal_open and ui.map_panel.visible and not c.enabled,"World map pauses play and blocks movement")
 ui.show_map(false)
 check(c.enabled,"Closing the map restores movement")
 scene.roads.start(Vector2(28,-90));scene.world.update(0)
 var hill=scene.game.Defs.point(Vector2(28,-90))
 var projected=scene.world.camera.unproject_position(hill)
 var hit=scene.roads.ground(projected)
 check(hit!=null and hit.distance_to(hill)<0.025,"Screen drawing intersects the actual elevated terrain")
 scene.roads.finish()
 # Real placement touches preview before charging, and building taps pause input.
 var production=JSON.parse_string(FileAccess.get_file_as_string("res://reports/production-start-fixture.json"))
 check(scene.game.restore(production),"Facility scene fixture restores")
 scene.roads.start_placement("processor");scene.world.update(0)
 var place_at=Vector2(-4,14)
 var place_screen=scene.world.camera.unproject_position(scene.game.Defs.point(place_at))
 var place_touch=InputEventScreenTouch.new();place_touch.index=5;place_touch.pressed=true;place_touch.position=place_screen
 scene.roads._input(place_touch);place_touch.pressed=false;scene.roads._input(place_touch)
 check(scene.roads.has_placement and scene.game.logistics.sites.is_empty(),"Facility tap is only a placement preview")
 var funds=scene.game.money
 scene.roads.commit()
 check(scene.game.logistics.sites.size()==1 and scene.game.money==funds-320,"Explicit confirmation builds and charges once")
 check(ui.site_panel.visible and ui.modal_open and not c.enabled,"New building opens its local settings and pauses movement")
 ui.show_site("");scene.world.update(0)
 var item=scene.game.logistics.sites[0]
 var building_screen=scene.world.camera.unproject_position(scene.game.Defs.point(scene.game.logistics.footprint(item).get_center(),1.0))
 place_touch.position=building_screen;place_touch.pressed=true
 c._input(place_touch);scene.roads._input(place_touch)
 check(c.active_touch==-1,"Tapping a placed building never starts the movement stick")
 place_touch.pressed=false;scene.roads._input(place_touch)
 check(ui.site_panel.visible and ui.site_panel.selected==item.id,"Tapping the rendered building opens the correct equipment")
 var before_level=item.level
 scene._logistics_action("site_upgrade",item.id)
 check(item.level==before_level+1 and scene.game.conserved(),"Local upgrade uses the selected building only")
 ui.show_site("")
 # Exercise every baked tool and a real validated inventory above 100 logs.
 var loaded=JSON.parse_string(FileAccess.get_file_as_string("res://reports/tools-loaded-fixture.json"))
 check(scene.game.restore(loaded),"Large cargo render fixture restores")
 scene.world.update(0)
 check(scene.world.counts().rendered_cargo==128,"All 128 carried logs are instanced")
 var positions={}
 for i in 128:
  var p=scene.world.cargo_position(i)
  positions[p]=true
  check(p.y<2.7 and absf(p.x)<0.6 and absf(p.z)<1.0,"Cargo stays in a compact bounded bundle")
 check(positions.size()==128,"Every carried log has a distinct slot")
 for level in 7:
  scene.game.levels.cut_range=level
  scene.world.update(0.1)
  var visible=0
  for tool in scene.world.tools: visible+=1 if tool.visible else 0
  check(visible==1 and scene.world.tools[scene.game.tool_tier()].visible,"Exactly the equipped tool is visible")
  check(absf(scene.world.cut_ring.basis.x.length()-scene.game.cut_radius())<0.001,"Range outline follows the equipped tool")
 var count=scene.world.counts().nodes
 # Many presentation events stress the fixed pools; logical resources are untouched.
 for i in 36000:
  if i%3==0: scene.world.handle({"type":"pickup","from":Vector2(-3,3),"kind":0,"id":i})
  if i%7==0: scene.world.handle({"type":"sell","to":Vector2(4,9),"kind":1,"amount":24,"id":i})
  if i%11==0: scene.world.handle({"type":"fell","position":Vector2(-3,3),"tree":0})
  scene.world.update(0.1)
  if i%1200==0:
   check(scene.world.counts().nodes==count,"Presentation node count stays bounded")
   check(scene.world.counts().active_effects<=48,"Presentation pool never grows")
 for i in 10: scene.world.update(0.1)
 check(scene.world.pending.is_empty(),"Pickup pending IDs retire")
 check(scene.world.counts().active_effects==0,"Presentation pools settle after interruption")
 check(scene.game.conserved(),"Cosmetic events cannot create logical resources")
 scene.queue_free()
 print("KIKORI_SCENE_TESTS assertions=%d failures=%d fixed_nodes=%d" % [assertions,failures,count])
 quit(1 if failures else 0)
