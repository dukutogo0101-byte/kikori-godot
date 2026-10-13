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
 var touch=InputEventScreenTouch.new()
 touch.index=0;touch.pressed=true;touch.position=ui.menu_button.get_global_rect().get_center()
 c._input(touch)
 check(c.active_touch==-1,"UI touches never start movement")
 touch.position=Vector2(160,400);c._input(touch)
 var drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(224,336)
 c._input(drag)
 check(absf(c.sample().length()-1)<0.001,"Touch diagonal speed normalized")
 touch.pressed=false;c._input(touch)
 check(c.sample()==Vector2.ZERO,"Touch release stops input")
 touch.pressed=true;c._input(touch)
 touch.canceled=true;c._input(touch)
 check(c.active_touch==-1,"Touch cancellation clears stick")
 touch.canceled=false;c._input(touch)
 drag.position=Vector2(-1,400);c._input(drag)
 check(c.sample()==Vector2.ZERO,"Leaving viewport cancels input")
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
