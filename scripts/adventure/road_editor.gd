extends Node
const Defs=preload("res://scripts/adventure/definitions.gd")
signal applied
var game
var ui
var world
var editing=false
var placing=""
var placing_large=false
var placement_at=Vector2.ZERO
var has_placement=false
var tapped_site=""
var tap_origin=Vector2.ZERO
var mode="build"
var draft_mode="build"
var orthogonal=false
var preview: Array = []
var history: Array = []
var stroke_base: Array = []
var stroke_origin=Vector2i.ZERO
var stroke_axis=-1
var active=-1
var last=Vector2.ZERO
var canceled=false
var toolbar: HBoxContainer
var secondary: HBoxContainer
var confirm: Button
var undo_button: Button
var clear_button: Button
var shape_button: Button
var actions: Array = []

func setup(state, owner_ui, view) -> void:
 game=state;ui=owner_ui;world=view
 toolbar=HBoxContainer.new();toolbar.add_theme_constant_override("separation",5);ui.root.add_child(toolbar)
 for item in [["build","敷設"],["remove","撤去"],["pan","移動"],["done","完了"]]:
  var button=ui.button(item[1]);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.x=70
  button.pressed.connect(func():
   if item[0]=="done":
    if not placing.is_empty() or preview.is_empty(): finish()
    else: ui.toast("未確定の道があります。確定するか、消去して終了できます")
   else: select_mode(item[0])
  );toolbar.add_child(button);actions.append(button)
 secondary=HBoxContainer.new();secondary.add_theme_constant_override("separation",5);ui.root.add_child(secondary)
 shape_button=ui.button("形状：直線");shape_button.pressed.connect(func():cancel_stroke();orthogonal=not orthogonal;update());secondary.add_child(shape_button)
 undo_button=ui.button("一区間戻す");undo_button.pressed.connect(undo);secondary.add_child(undo_button)
 clear_button=ui.button("下書き消去");clear_button.pressed.connect(func():reset();update());secondary.add_child(clear_button)
 for button in [shape_button,undo_button,clear_button]: button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",14);button.custom_minimum_size.x=64
 confirm=ui.button("道を確定");confirm.pressed.connect(func():
  if placing.is_empty(): commit()
  else: commit_placement()
 );ui.root.add_child(confirm)
 get_viewport().size_changed.connect(func():cancel_stroke();resize())
 resize();update()

func resize() -> void:
 var size=get_viewport().get_visible_rect().size
 var width=minf(size.x-28,560)
 toolbar.position=Vector2((size.x-width)/2,12);toolbar.size=Vector2(width,48)
 secondary.position=Vector2(toolbar.position.x,66);secondary.size=Vector2(width,44)
 confirm.position=Vector2(toolbar.position.x,size.y-132);confirm.size=Vector2(width,48)

func start(at: Vector2) -> void:
 reset();placing="";placing_large=false;editing=true;mode="build";draft_mode="build";world.planning=true;world.planning_focus=Defs.point(at)
 ui.show_menu(false);ui.show_logistics(false);ui.modal_open=false
 ui.menu_changed.emit(false);world.update_camera(0);update()

func start_placement(kind: String, large: bool = false) -> void:
 start(game.position+Vector2(-6,0))
 placing=kind;placing_large=large;mode="build";update()

func finish() -> void:
 reset();editing=false;placing="";placing_large=false;world.planning=false
 ui.menu_changed.emit(false);update()

func select_mode(value: String) -> void:
 cancel_stroke()
 if value!="pan" and value!=draft_mode and placing.is_empty(): reset();draft_mode=value
 mode=value
 update()

func reset() -> void:
 active=-1;preview.clear();history.clear();stroke_base.clear();canceled=false;stroke_axis=-1
 if world!=null: world.road_preview=[];world.facility_preview={}
 has_placement=false

func cancel_stroke() -> void:
 # Focus loss / rotation cancels only the current gesture, not earlier sections.
 if active>=0 and mode!="pan" and placing.is_empty(): preview=stroke_base.duplicate();sync_preview()
 active=-1;stroke_axis=-1;tapped_site="";canceled=false
 if not placing.is_empty(): has_placement=false;world.facility_preview={}

func undo() -> void:
 cancel_stroke()
 if not history.is_empty(): preview=history.pop_back();sync_preview()
 update()

func sync_preview() -> void:
 world.road_preview=preview.duplicate();world.road_preview_remove=draft_mode=="remove"

func blocked(at: Vector2) -> bool:
 return ui.blocked(at) or toolbar.get_global_rect().has_point(at) or (secondary.visible and secondary.get_global_rect().has_point(at)) or (confirm.visible and confirm.get_global_rect().has_point(at)) or ui.root.get_node("Hint").get_global_rect().has_point(at)

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

func picked_point(at: Vector2):
 var hit=ground(at)
 if hit==null: return null
 var point=Vector2(hit.x,hit.z)
 var distance=1.3
 for place in game.logistics.endpoints(game):
  var d=point.distance_to(place.position)
  if d<distance: point=place.position;distance=d
 return game.logistics.cell(point)

func append_point(at: Vector2) -> void:
 var point=picked_point(at)
 if point==null: return
 if not placing.is_empty():
  placement_at=Vector2(point);has_placement=true
  var valid=game.logistics.placement_ok(game,placing,placement_at,placing_large)
  world.facility_preview={"type":placing,"position":placement_at,"large":placing_large,"valid":valid}
  return
 var delta=point-stroke_origin
 if stroke_axis<0 and maxi(absi(delta.x),absi(delta.y))>=2: stroke_axis=0 if absi(delta.x)>=absi(delta.y) else 1
 var axis=stroke_axis if stroke_axis>=0 else (0 if absi(delta.x)>=absi(delta.y) else 1)
 var end=point
 if not orthogonal:
  end=Vector2i(point.x,stroke_origin.y) if axis==0 else Vector2i(stroke_origin.x,point.y)
 var segment=[]
 if orthogonal and axis==1:
  segment=game.logistics.line(stroke_origin,Vector2i(stroke_origin.x,end.y))
  segment.append_array(game.logistics.line(Vector2i(stroke_origin.x,end.y),end).slice(1))
 else: segment=game.logistics.line(stroke_origin,end)
 var proposed=stroke_base.duplicate()
 proposed.append_array(segment if proposed.is_empty() else segment.slice(1))
 if proposed.size()>game.logistics.MAX_NETWORK:
  ui.toast("下書きの上限です。一度確定してから延長できます");return
 preview=proposed;sync_preview()

func hit_site(at: Vector2) -> String:
 if world==null or world.camera==null: return ""
 var nearest="";var distance=1e9
 for item in game.logistics.sites:
  var roof=Defs.point(game.logistics.footprint(item).get_center(),1.0)
  var screen=world.camera.unproject_position(roof)
  var port=world.camera.unproject_position(Defs.point(item.position,0.5))
  var scale=game.logistics.site_scale(item)
  var radius=clampf(get_viewport().get_visible_rect().size.y/world.camera.size*1.7*scale,22,58*scale)
  var d=minf(screen.distance_to(at),port.distance_to(at))
  if d<radius and d<distance: nearest=item.id;distance=d
 return nearest

func tap_building(event: InputEvent) -> void:
 var at=Vector2.ZERO;var pressed=false;var released=false;var motion=false;var id=-1
 if event is InputEventScreenTouch:
  if event.canceled: tapped_site="";active=-1;return
  at=event.position;pressed=event.pressed;released=not pressed;id=event.index
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.canceled: tapped_site="";active=-1;return
  at=event.position;pressed=event.pressed;released=not pressed;id=100
 elif event is InputEventScreenDrag: at=event.position;id=event.index;motion=true
 elif event is InputEventMouseMotion: at=event.position;id=100;motion=true
 else: return
 if pressed and not ui.blocked(at) and active<0:
  tapped_site=hit_site(at);tap_origin=at
  if not tapped_site.is_empty(): active=id
 if id!=active: return
 if motion and at.distance_to(tap_origin)>14: tapped_site=""
 if released:
  var selected=tapped_site;tapped_site="";active=-1
  if not selected.is_empty() and at.distance_to(tap_origin)<=14: ui.show_site(selected)

func _input(event: InputEvent) -> void:
 if ui.modal_open: return
 if not editing: tap_building(event);return
 var at=Vector2.ZERO;var press=false;var release=false;var movement=false;var id=-2
 if event is InputEventScreenTouch:
  if event.canceled: cancel_stroke();update();return
  at=event.position;id=event.index;press=event.pressed;release=not press
 elif event is InputEventScreenDrag: at=event.position;id=event.index;movement=true
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.canceled: cancel_stroke();update();return
  at=event.position;id=100;press=event.pressed;release=not press
 elif event is InputEventMouseMotion: at=event.position;id=100;movement=true
 else: return
 if press and active<0 and not blocked(at):
  var point=picked_point(at)
  if point==null: return
  active=id;last=at;canceled=false;stroke_axis=-1;stroke_base=preview.duplicate()
  stroke_origin=point if preview.is_empty() else preview.back()
  if mode!="pan": append_point(at)
 elif movement and id==active:
  if not get_viewport().get_visible_rect().has_point(at): cancel_stroke();return
  if mode=="pan":
   var before=ground(last);var after=ground(at)
   if before!=null and after!=null: pan_by(Vector2(before.x-after.x,before.z-after.z))
  elif not blocked(at): append_point(at)
  last=at
 elif release and id==active:
  if mode!="pan" and placing.is_empty() and preview!=stroke_base:
   history.append(stroke_base.duplicate())
   if history.size()>64: history.pop_front()
  active=-1;stroke_axis=-1
 update()

func pan_by(offset: Vector2) -> void:
 world.planning_focus.x=clampf(world.planning_focus.x+offset.x,Defs.WORLD_BOUNDS.position.x,Defs.WORLD_BOUNDS.end.x)
 world.planning_focus.z=clampf(world.planning_focus.z+offset.y,Defs.WORLD_BOUNDS.position.y,Defs.WORLD_BOUNDS.end.y)
 world.planning_focus.y=Defs.height_at(Vector2(world.planning_focus.x,world.planning_focus.z))
 world.update_camera(0)

func edge_scroll(delta: float) -> void:
 if active<0 or mode=="pan" or not placing.is_empty() or delta<=0: return
 var size=get_viewport().get_visible_rect().size
 var edge=Vector2.ZERO
 var top=120.0;var bottom=size.y-146.0
 if last.x<38: edge.x=-clampf((38-last.x)/26,0,1)
 elif last.x>size.x-38: edge.x=clampf((last.x-size.x+38)/26,0,1)
 if last.y<top+24 and last.y>110: edge.y=-clampf((top+24-last.y)/24,0,1)
 elif last.y>bottom-24 and last.y<bottom+10: edge.y=clampf((last.y-bottom+24)/24,0,1)
 if not orthogonal:
  if stroke_axis==0: edge.y=0
  elif stroke_axis==1: edge.x=0
 if edge==Vector2.ZERO: return
 pan_by(edge*minf(18,world.camera.size*0.3)*minf(delta,0.1))
 append_point(last)

func commit() -> void:
 if not placing.is_empty(): commit_placement();return
 cancel_stroke()
 if preview.is_empty(): return
 var all_existing=draft_mode=="build" and cost()==0
 if all_existing:
  for p in preview:
   if not game.logistics.road_valid(game,p): all_existing=false;break
 if all_existing: reset();ui.toast("既存の道と橋は、そのまま荷車で使えます")
 elif game.logistics.edit_roads(game,preview,draft_mode=="remove"): applied.emit();reset();ui.toast(game.logistics.message)
 else: ui.toast(game.logistics.message)
 update()

func commit_placement() -> void:
 if has_placement and game.logistics.build(game,placing,placement_at,placing_large):
  var id=game.logistics.sites.back().id
  applied.emit();finish();ui.show_site(id)
 ui.toast(game.logistics.message);update()

func update(delta: float = 0.0) -> void:
 if editing and not ui.modal_open: edge_scroll(delta)
 for node in [ui.root.get_node("Top"),ui.root.get_node("Brand"),ui.money_label,ui.bag_label,ui.menu_button,ui.goal_label]: node.visible=not editing
 ui.map_button.visible=not editing;ui.view_button.visible=not editing;ui.logistics_button.visible=not editing
 toolbar.visible=editing and not ui.modal_open;secondary.visible=toolbar.visible and placing.is_empty()
 confirm.visible=editing and not ui.modal_open and (not preview.is_empty() or has_placement)
 confirm.text="%dマス撤去を確定" % preview.size() if draft_mode=="remove" else "道を確定 · %d（所持 %d）" % [cost(),game.money]
 if not placing.is_empty():
  confirm.text=("大型建設を確定 · %d" if placing_large else "建設を確定 · %d") % game.logistics.price(placing,0,placing_large)
  confirm.disabled=not has_placement or not game.logistics.placement_ok(game,placing,placement_at,placing_large) or game.money<game.logistics.price(placing,0,placing_large)
 else: confirm.disabled=false
 actions[0].text="配置" if not placing.is_empty() else "敷設"
 actions[1].visible=placing.is_empty()
 shape_button.text="形状：直角" if orthogonal else "形状：直線"
 undo_button.disabled=history.is_empty();clear_button.disabled=preview.is_empty()
 for i in actions.size(): actions[i].modulate=Color("f4d79a") if ["build","remove","pan","done"][i]==mode else Color.WHITE
 if editing and not ui.modal_open:
  ui.navigation.visible=false
  if ui.toast_time<=0: ui.hint_label.text="建設位置をタップして確定。移動で地図をずらせます" if not placing.is_empty() else "始点→終点で直線。移動しても延長可能\n画面端でスクロール／戻すで取消"
  ui.stick.active=false;ui.stick.queue_redraw()

func cost() -> int:
 if preview.is_empty(): return 0
 var unique={}
 var available=game.logistics.network(game)
 for p in preview:
  if not available.has(p): unique[p]=true
 return unique.size()*game.logistics.ROAD_PRICE

func summary() -> Dictionary:
 var result={"road_editing":editing,"road_mode":mode,"road_preview_count":preview.size(),"road_preview":[],"road_shape":"corner" if orthogonal else "straight","road_cost":cost(),"road_history":history.size(),"planning_focus":[world.planning_focus.x,world.planning_focus.z],"placing":placing,"placing_large":placing_large,"placement_at":[placement_at.x,placement_at.y],"has_placement":has_placement}
 for p in preview: result.road_preview.append([p.x,p.y])
 var nodes={"road_confirm":confirm,"road_undo":undo_button,"road_clear":clear_button,"road_shape":shape_button}
 # Keep the shape value and button coordinates under separate names.
 nodes["road_shape_button"]=nodes["road_shape"];nodes.erase("road_shape")
 for i in actions.size(): nodes[["road_build","road_remove","road_pan","road_done"][i]]=actions[i]
 for key in nodes:
  var at=nodes[key].get_global_rect().get_center();result[key]={"x":at.x,"y":at.y}
 return result
