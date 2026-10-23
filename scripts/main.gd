extends Node3D
# Scene wiring only. Input, simulation, presentation and menus have separate owners.
const State = preload("res://scripts/adventure/game_state.gd")
const Controller = preload("res://scripts/adventure/player_controller.gd")
const World = preload("res://scripts/adventure/world_view.gd")
const UI = preload("res://scripts/adventure/game_ui.gd")
const Feedback = preload("res://scripts/adventure/feedback.gd")
const Store = preload("res://scripts/save_store.gd")
var roads=preload("res://scripts/adventure/road_editor.gd").new()
var game = State.new()
var controller = Controller.new()
var world = World.new()
var ui = UI.new()
var feedback = Feedback.new()
var store = Store.new()
var paused = false
var web_modal_open = false
var native_smoke = false
var save_clock = 0.0
var diagnostic_clock = 0.0
var document: JavaScriptObject
var window: JavaScriptObject
var visibility_callback: JavaScriptObject
var reset_callback: JavaScriptObject
var update_callback: JavaScriptObject
var web_modal_callback: JavaScriptObject
var purchase_lock_until = 0

func _ready() -> void:
 _configure_viewport()
 get_window().size_changed.connect(_configure_viewport)
 native_smoke = "--smoke-test" in OS.get_cmdline_user_args()
 var data = {} if native_smoke else store.read_save()
 var restored = false
 if not data.is_empty():
  restored = game.restore(data)
  if not restored: store.message = "保存データを復元できません。新しく始めます"
 var font = load("res://assets/fonts/KikoriSans.otf")
 add_child(world)
 world.setup(game,font)
 add_child(ui)
 ui.setup(game,font)
 ui.save_available = store.available
 add_child(controller)
 controller.blocked = func(at): return ui.blocked(at) or (not roads.editing and not roads.hit_site(at).is_empty())
 add_child(roads)
 roads.setup(game,ui,world)
 roads.applied.connect(_save)
 ui.logistics_panel.action.connect(_logistics_action)
 ui.site_panel.action.connect(_logistics_action)
 add_child(feedback)
 ui.upgrade_requested.connect(_buy)
 ui.view_changed.connect(func(): game.wide_view=not game.wide_view; controller.reset(); _save())
 ui.menu_changed.connect(func(open): controller.reset(); controller.enabled = not open and not paused and not roads.editing; game.velocity = Vector2.ZERO)
 ui.sound_changed.connect(_sound)
 ui.vibration_changed.connect(func(on): feedback.vibration = on)
 get_viewport().size_changed.connect(controller.reset)
 if not store.message.is_empty(): ui.toast(store.message)
 elif restored: ui.toast("設備を新方式に移行。旧設備などの費用 %d を返金しました" % game.migrated_refund if game.migrated_refund>0 else "おかえりなさい。続きの森へ！")
 else: ui.toast("ドラッグで歩こう。木のそばで止まると伐採")
 if OS.has_feature("web"):
  document = JavaScriptBridge.get_interface("document")
  window = JavaScriptBridge.get_interface("window")
  visibility_callback = JavaScriptBridge.create_callback(_visibility)
  reset_callback = JavaScriptBridge.create_callback(_reset_input)
  update_callback = JavaScriptBridge.create_callback(_prepare_update)
  web_modal_callback = JavaScriptBridge.create_callback(_web_modal)
  document.addEventListener("visibilitychange",visibility_callback)
  window.addEventListener("kikori-input-reset",reset_callback)
  window.addEventListener("kikori-save-before-update",update_callback)
  window.addEventListener("kikori-web-modal-change",web_modal_callback)
  _visibility([])
  diagnostics()
 if restored and data.get("version")!=10: _save()
 if native_smoke:
  print("KIKORI_ADVENTURE_READY trees=%d objects=%s" % [game.trees.size(),world.counts()])
  get_tree().create_timer(2).timeout.connect(func(): get_tree().quit())

func _physics_process(delta: float) -> void:
 if world.hero == null: return
 if not paused and not ui.modal_open and not roads.editing:
  game.tick(delta,controller.sample())
  for event in game.events:
   world.handle(event)
   feedback.event(event)
   if event.type == "complete":
    ui.toast(game.notice)
    _save()
 save_clock += delta if not paused else 0.0
 if save_clock>=(30.0 if game.logistics.stored_count()>8192 else 3.0):
  _save()

func _process(delta: float) -> void:
 if world.hero == null: return
 world.show_routes=ui.logistics_panel.visible
 world.update(minf(delta,0.1))
 ui.update(minf(delta,0.1),controller,world.camera)
 roads.update(minf(delta,0.1))
 diagnostic_clock += delta
 if diagnostic_clock>=(1.0 if game.logistics.stored_count()>8192 else 0.1):
  diagnostic_clock=0
  diagnostics()

func _buy(key: String) -> void:
 if Time.get_ticks_msec() < purchase_lock_until: return
 if game.buy(key):
  purchase_lock_until = Time.get_ticks_msec()+300
  world.handle({"type":"upgrade","id":key})
  feedback.event({"type":"upgrade"})
  ui.toast(game.notice)
  _save()

func ui_summary() -> Dictionary:
 var result=ui.summary();result.merge(roads.summary())
 result["site_points"]={}
 for item in game.logistics.sites:
  var at=world.camera.unproject_position(game.Defs.point(game.logistics.footprint(item).get_center(),1.0))
  result.site_points[item.id]={"x":at.x,"y":at.y}
 return result

func _logistics_action(kind: String, value) -> void:
 if kind=="place":
  if value is Dictionary: roads.start_placement(str(value.type),bool(value.large))
  else: roads.start_placement(str(value))
  world.update(0);return
 if kind=="editor" or kind=="focus":
  var place=game.logistics.endpoint(game,str(value)) if kind=="focus" else {}
  var at=place.get("position",game.position+Vector2(-4,0))
  roads.start(at);world.update(0);return
 if Time.get_ticks_msec()<purchase_lock_until: return
 var ok=false
 match kind:
  "site_upgrade": ok=game.logistics.upgrade(game,str(value))
  "site_mode":
   var item=game.logistics.site(str(value))
   if not item.is_empty(): item.mode="withdraw" if item.mode=="deposit" else "deposit";game.logistics.message="手動の受け渡しを切り替えました";ok=true
  "site_worker":
   var item=game.logistics.site(str(value))
   if not item.is_empty(): item.worker_enabled=not item.worker_enabled;game.logistics.message="木こりの稼働を切り替えました。運搬中の荷物は先に届けます";ok=true
  "cart": ok=game.logistics.add_cart(game,value[0],value[1])
  "pause": ok=game.logistics.toggle_pause(int(value))
  "clear": ok=game.logistics.clear_route(int(value))
  "route": ok=game.logistics.set_route(game,int(value[0]),value[1],value[2])
  "order": ok=game.logistics.edit_order(game,int(value[0]),int(value[1]),value[2],value[3])
  "remove_order": ok=game.logistics.remove_order(game,int(value[0]),int(value[1]))
  "upgrade_cart": ok=game.logistics.upgrade_cart(game,int(value))
 if ok:
  purchase_lock_until=Time.get_ticks_msec()+250
  _save()
 ui.toast(game.logistics.message)
 ui.logistics_panel.refresh()
 if ui.site_panel.visible: ui.site_panel.refresh()

func _save() -> void:
 save_clock=0
 if native_smoke or ui.root == null: return
 var previously_available = store.available
 if not store.write_save(game.snapshot()) and previously_available: ui.toast("保存不可。このタブでは遊べます")
 ui.save_available = store.available

func _visibility(_args: Array) -> void:
 var hidden = bool(document.hidden) or web_modal_open
 controller.reset()
 roads.cancel_stroke()
 game.velocity = Vector2.ZERO
 if hidden: _save()
 paused = hidden
 controller.enabled = not hidden and not ui.modal_open and not roads.editing
 # No offline actions: the hero acts only while the player is here.

func _reset_input(_args: Array) -> void:
 controller.reset()
 roads.cancel_stroke()
 game.velocity = Vector2.ZERO

func _prepare_update(_args: Array) -> void:
 _reset_input([])
 _save()
 JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('kikori-update-saved',{detail:"+str(store.available).to_lower()+"}))",true)

func _web_modal(args: Array) -> void:
 web_modal_open=bool(args[0].detail)
 _visibility([])

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
  controller.reset()
  roads.cancel_stroke()
  game.velocity=Vector2.ZERO
  if ui.root != null: _save()

func diagnostics() -> void:
 if not OS.has_feature("web"): return
 var state = game.summary()
 state["saved"] = store.available
 state["paused"] = paused
 state["fps"] = Engine.get_frames_per_second()
 state["objects"] = world.counts()
 state["render"] = {"frames_drawn":Engine.get_frames_drawn(),"process_frames":Engine.get_process_frames(),"hero":[world.hero.position.x,world.hero.position.z],"money_text":ui.money_label.text,"hero_height":world.hero.position.y,"camera_size":world.camera.size,"camera_focus":[world.camera_anchor.x,world.camera_anchor.y,world.camera_anchor.z]}
 JavaScriptBridge.eval("window.kikoriReady=true;window.kikoriState="+JSON.stringify(state)+";window.kikoriUi="+JSON.stringify(ui_summary())+";",true)

func _exit_tree() -> void:
 if document != null and visibility_callback != null: document.removeEventListener("visibilitychange",visibility_callback)
 if window != null and reset_callback != null: window.removeEventListener("kikori-input-reset",reset_callback)
 if window != null and update_callback != null: window.removeEventListener("kikori-save-before-update",update_callback)
 if window != null and web_modal_callback != null: window.removeEventListener("kikori-web-modal-change",web_modal_callback)

func _sound(on: bool) -> void:
 feedback.sound = on
 if on: feedback.event({"type":"pickup"})

func _configure_viewport() -> void:
 var window_size = get_window().size
 if window_size.x<=0 or window_size.y<=0: return
 # Keep phone-sized controls while letting the world fill both orientations.
 var reference = Vector2i(390,int(round(390.0*window_size.y/window_size.x))) if window_size.y>=window_size.x else Vector2i(int(round(390.0*window_size.x/window_size.y)),390)
 if get_window().content_scale_size != reference:
  get_window().content_scale_size = reference
 controller.reset()
