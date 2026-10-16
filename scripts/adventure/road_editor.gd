extends Node
const Defs=preload("res://scripts/adventure/definitions.gd")
signal applied
var game
var ui
var world
var editing=false
var mode="build"
var preview: Array = []
var active=-1
var last=Vector2.ZERO
var canceled=false
var toolbar: HBoxContainer
var confirm: Button
var actions: Array = []

func setup(state, owner_ui, view) -> void:
 game=state;ui=owner_ui;world=view
 toolbar=HBoxContainer.new();toolbar.add_theme_constant_override("separation",5);ui.root.add_child(toolbar)
 for item in [["build","敷設"],["remove","撤去"],["pan","移動"],["done","完了"]]:
  var button=ui.button(item[1]);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.x=70
  button.pressed.connect(func():
   if item[0]=="done": finish()
   else: reset();mode=item[0]
  );toolbar.add_child(button);actions.append(button)
 confirm=ui.button("道を確定");confirm.pressed.connect(commit);ui.root.add_child(confirm)
 get_viewport().size_changed.connect(func():reset();resize())
 resize();update()

func resize() -> void:
 var size=get_viewport().get_visible_rect().size
 toolbar.position=Vector2((size.x-minf(size.x-28,560))/2,132)
 toolbar.size=Vector2(minf(size.x-28,560),48)
 confirm.position=Vector2(toolbar.position.x,size.y-132)
 confirm.size=Vector2(toolbar.size.x,48)

func start(at: Vector2) -> void:
 reset();editing=true;mode="build";world.planning=true;world.planning_focus=Defs.point(at)
 ui.show_menu(false);ui.show_logistics(false);ui.modal_open=false
 ui.menu_changed.emit(false);update()

func finish() -> void:
 reset();editing=false;world.planning=false
 ui.menu_changed.emit(false);update()

func reset() -> void:
 active=-1;preview.clear();canceled=false
 if world!=null: world.road_preview=[]

func blocked(at: Vector2) -> bool:
 return ui.blocked(at) or toolbar.get_global_rect().has_point(at) or (confirm.visible and confirm.get_global_rect().has_point(at)) or ui.root.get_node("Hint").get_global_rect().has_point(at)

func ground(at: Vector2):
 var origin=world.camera.project_ray_origin(at)
 var direction=world.camera.project_ray_normal(at)
 if absf(direction.y)<0.001: return null
 # Bracket the first heightfield hit so steep lake banks cannot send the
 # pointer iteration to the opposite bank. Terrain elevations lie in [-2,8].
 var start=(8.0-origin.y)/direction.y
 var end=(-2.0-origin.y)/direction.y
 var previous=start
 for step in range(1,65):
  var distance=lerpf(start,end,float(step)/64)
  var p=origin+direction*distance
  if p.y<=Defs.height_at(Vector2(p.x,p.z)):
   var low=previous;var high=distance
   for i in 18:
    var mid=(low+high)*0.5
    var hit=origin+direction*mid
    if hit.y>Defs.height_at(Vector2(hit.x,hit.z)): low=mid
    else: high=mid
   return origin+direction*((low+high)*0.5)
  previous=distance
 return null

func append_point(at: Vector2) -> void:
 var hit=ground(at)
 if hit==null: return
 var point=Vector2i(roundi(hit.x),roundi(hit.z))
 if preview.is_empty(): preview.append(point)
 else:
  var extension=game.logistics.line(preview.back(),point)
  for p in extension.slice(1):
   if preview.size()>=160: canceled=true;break
   preview.append(p)
 world.road_preview=preview.duplicate()
 world.road_preview_remove=mode=="remove"

func _input(event: InputEvent) -> void:
 if not editing or ui.modal_open: return
 var at=Vector2.ZERO;var press=false;var release=false;var movement=false;var id=-2
 if event is InputEventScreenTouch:
  if event.canceled: reset();return
  at=event.position;id=event.index;press=event.pressed;release=not press
 elif event is InputEventScreenDrag:
  at=event.position;id=event.index;movement=true
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.canceled: reset();return
  at=event.position;id=100;press=event.pressed;release=not press
 elif event is InputEventMouseMotion:
  at=event.position;id=100;movement=true
 else: return
 if press and active<0 and not blocked(at):
  active=id;last=at;preview.clear();canceled=false
  if mode!="pan": append_point(at)
 elif movement and id==active:
  if not get_viewport().get_visible_rect().has_point(at): reset();return
  if mode=="pan":
   var before=ground(last);var after=ground(at)
   if before!=null and after!=null:
    world.planning_focus+=before-after
    world.planning_focus.x=clampf(world.planning_focus.x,Defs.WORLD_BOUNDS.position.x,Defs.WORLD_BOUNDS.end.x)
    world.planning_focus.z=clampf(world.planning_focus.z,Defs.WORLD_BOUNDS.position.y,Defs.WORLD_BOUNDS.end.y)
    world.planning_focus.y=Defs.height_at(Vector2(world.planning_focus.x,world.planning_focus.z))
  elif not blocked(at): append_point(at)
  last=at
 elif release and id==active:
  active=-1
  if canceled: preview.clear();world.road_preview=[]
 update()

func commit() -> void:
 if preview.is_empty() or canceled: return
 if game.logistics.edit_roads(game,preview,mode=="remove"):
  applied.emit();reset()
 ui.toast(game.logistics.message);update()

func update() -> void:
 ui.map_button.visible=not editing
 ui.view_button.visible=not editing
 ui.logistics_button.visible=not editing
 toolbar.visible=editing and not ui.modal_open
 confirm.visible=editing and not ui.modal_open and not preview.is_empty() and mode!="pan"
 confirm.text="%dマス撤去を確定" % preview.size() if mode=="remove" else "道を確定 · %d" % cost()
 for i in actions.size(): actions[i].modulate=Color("f4d79a") if ["build","remove","pan","done"][i]==mode else Color.WHITE
 if editing and not ui.modal_open:
  ui.navigation.visible=false
  if ui.toast_time<=0: ui.hint_label.text="敷設・撤去はドラッグ後に確定。移動で地図をずらせます"
  ui.stick.active=false;ui.stick.queue_redraw()

func cost() -> int:
 var unique={}
 for p in preview:
  if not game.logistics.roads.has(p): unique[p]=true
 return unique.size()*game.logistics.ROAD_PRICE

func summary() -> Dictionary:
 var result={"road_editing":editing,"road_mode":mode,"road_preview_count":preview.size()}
 var nodes={"road_confirm":confirm}
 for i in actions.size(): nodes[["road_build","road_remove","road_pan","road_done"][i]]=actions[i]
 for key in nodes:
  var at=nodes[key].get_global_rect().get_center();result[key]={"x":at.x,"y":at.y}
 return result
