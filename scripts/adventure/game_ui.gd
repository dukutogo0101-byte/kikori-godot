extends CanvasLayer
const Defs = preload("res://scripts/adventure/definitions.gd")
signal upgrade_requested(key: String)
signal facility_requested(area: int,key: String)
signal view_changed
signal menu_changed(open: bool)
signal sound_changed(on: bool)
signal vibration_changed(on: bool)
var map_button: Button
var map_panel: PanelContainer
var map_canvas: Control
var map_close: Button
var logistics_button: Button
var logistics_panel
var root: Control
var money_label: Label
var bag_label: Label
var goal_label: Label
var hint_label: Label
var menu_button: Button
var sound_button: Button
var vibration_button: Button
var modal: PanelContainer
var rows = {}
var facility_rows = {}
var area_buttons: Array = []
var selected_area = 0
var view_button: Button
var stock_label: Label
var close_button: Button
var modal_open = false
var sound_on = false
var vibration_on = false
var font: Font
var game
var stick: Control
var navigation: Label
var toast_time = 0.0
var toast_text = ""
var last_money = -1
var save_available = true
var money_pulse = 0.0

func style(color: Color, radius: int = 18) -> StyleBoxFlat:
 var box = StyleBoxFlat.new()
 box.bg_color = color
 box.corner_radius_top_left = radius
 box.corner_radius_top_right = radius
 box.corner_radius_bottom_left = radius
 box.corner_radius_bottom_right = radius
 box.content_margin_left = 14
 box.content_margin_right = 14
 box.content_margin_top = 10
 box.content_margin_bottom = 10
 return box

func text(value: String, size: int, color: Color = Color("24485b")) -> Label:
 var node = Label.new()
 node.text = value
 node.add_theme_font_override("font",font)
 node.add_theme_font_size_override("font_size",size)
 node.add_theme_color_override("font_color",color)
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return node

func button(value: String) -> Button:
 var node = Button.new()
 node.text = value
 node.add_theme_font_override("font",font)
 node.add_theme_font_size_override("font_size",16)
 node.add_theme_color_override("font_color",Color("f3f9fc"))
 node.add_theme_color_override("font_disabled_color",Color("aec2ca"))
 node.add_theme_stylebox_override("normal",style(Color("286a80"),14))
 node.add_theme_stylebox_override("pressed",style(Color("184b60"),14))
 node.add_theme_stylebox_override("hover",style(Color("397f95"),14))
 node.add_theme_stylebox_override("disabled",style(Color("70909e"),14))
 node.custom_minimum_size = Vector2(64,48)
 node.focus_mode = Control.FOCUS_NONE
 return node

func setup(state, ui_font: Font) -> void:
 game = state
 font = ui_font
 root = Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(root)
 var top = Panel.new()
 top.name = "Top"
 top.mouse_filter = Control.MOUSE_FILTER_IGNORE
 top.add_theme_stylebox_override("panel",style(Color(0.97,0.99,1,0.91),22))
 root.add_child(top)
 var brand = text("KIKORI  /  SNOW TRAIL",11,Color("6b8d9c"))
 brand.name = "Brand"
 brand.position = Vector2(30,22)
 root.add_child(brand)
 money_label = text("● 0",25,Color("a97121"))
 root.add_child(money_label)
 bag_label = text("荷物 0 / 6",15)
 root.add_child(bag_label)
 menu_button = button("道具・設備")
 menu_button.pressed.connect(func(): show_menu(not modal_open))
 root.add_child(menu_button)
 view_button=button("視野：広い")
 view_button.add_theme_font_size_override("font_size",13)
 view_button.pressed.connect(func(): view_changed.emit())
 root.add_child(view_button)
 logistics_button=button("道路・物流")
 logistics_button.add_theme_font_size_override("font_size",14)
 logistics_button.pressed.connect(func():show_logistics(not logistics_panel.visible))
 root.add_child(logistics_button)
 map_button=button("全体地図")
 map_button.pressed.connect(func():show_map(not map_panel.visible))
 root.add_child(map_button)
 goal_label = text("",15)
 goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 root.add_child(goal_label)
 var hint = Panel.new()
 hint.name = "Hint"
 hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hint.add_theme_stylebox_override("panel",style(Color(0.12,0.29,0.36,0.9),17))
 root.add_child(hint)
 hint_label = text("",14,Color("eff9fc"))
 hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 hint.add_child(hint_label)
 navigation = text("",15,Color("655026"))
 navigation.add_theme_color_override("font_outline_color",Color("f7fcff"))
 navigation.add_theme_constant_override("outline_size",4)
 root.add_child(navigation)
 stick = Control.new()
 stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
 stick.set_script(preload("res://scripts/adventure/stick_view.gd"))
 root.add_child(stick)
 var shade = ColorRect.new()
 shade.name = "Shade"
 shade.color = Color(0.07,0.18,0.26,0.55)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.visible = false
 root.add_child(shade)
 modal = PanelContainer.new()
 modal.add_theme_stylebox_override("panel",style(Color("f0f7fa"),24))
 modal.visible = false
 root.add_child(modal)
 var layout=VBoxContainer.new()
 layout.add_theme_constant_override("separation",10)
 modal.add_child(layout)
 var scroll = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 layout.add_child(scroll)
 var content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",10)
 scroll.add_child(content)
 var header = HBoxContainer.new()
 layout.add_child(header)
 layout.move_child(header,0)
 var title = text("道具・設備",22)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 close_button = button("閉じる")
 close_button.pressed.connect(func(): show_menu(false))
 header.add_child(close_button)
 content.add_child(text("道具を磨き、お金で働く拠点を育てよう",13,Color("678698")))
 for key in ["axe","pack","boots"]:
  var panel = PanelContainer.new()
  panel.add_theme_stylebox_override("panel",style(Color("e0edf2"),15))
  content.add_child(panel)
  var row = HBoxContainer.new()
  row.add_theme_constant_override("separation",10)
  panel.add_child(row)
  var description = text("",15)
  description.custom_minimum_size.y = 60
  description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(description)
  var purchase = button("")
  purchase.custom_minimum_size.x = 82
  purchase.pressed.connect(func(): upgrade_requested.emit(key))
  row.add_child(purchase)
  rows[key] = {"description":description,"button":purchase}
 content.add_child(text("森の自動化",21))
 var tabs=HBoxContainer.new()
 tabs.add_theme_constant_override("separation",6)
 content.add_child(tabs)
 for area in 3:
  var tab=button(Defs.SHORT_NAMES[area])
  tab.custom_minimum_size.x=80
  tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  tab.pressed.connect(func(): selected_area=area)
  tabs.add_child(tab)
  area_buttons.append(tab)
 stock_label=text("",13,Color("678698"))
 stock_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(stock_label)
 for key in ["camp","porter","mill"]:
  var panel=PanelContainer.new()
  panel.add_theme_stylebox_override("panel",style(Color("e3eee2"),15))
  content.add_child(panel)
  var column=VBoxContainer.new()
  panel.add_child(column)
  var description=text("",14)
  description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  column.add_child(description)
  var purchase=button("")
  purchase.pressed.connect(func(): facility_requested.emit(selected_area,key))
  column.add_child(purchase)
  facility_rows[key]={"description":description,"button":purchase}
 content.add_child(text("倉庫の緑の円で止まると木材を取り出せます。\n自動化はプレイ中に稼働。留守中の作業はありません。",12,Color("678698")))
 var options = HBoxContainer.new()
 options.add_theme_constant_override("separation",8)
 content.add_child(options)
 sound_button = button("音 OFF")
 sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 sound_button.pressed.connect(func(): sound_on = not sound_on; sound_button.text = "音 ON" if sound_on else "音 OFF"; sound_changed.emit(sound_on))
 options.add_child(sound_button)
 vibration_button = button("振動 OFF")
 vibration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 vibration_button.pressed.connect(func(): vibration_on = not vibration_on; vibration_button.text = "振動 ON" if vibration_on else "振動 OFF"; vibration_changed.emit(vibration_on))
 options.add_child(vibration_button)
 content.add_child(text("PCはWASD / 矢印キー。木のそばで止まろう",12,Color("678698")))
 logistics_panel=preload("res://scripts/adventure/logistics_panel.gd").new()
 root.add_child(logistics_panel)
 logistics_panel.setup(game,self)
 logistics_panel.visible=false
 logistics_panel.close_requested.connect(func():show_logistics(false))
 map_panel=PanelContainer.new()
 map_panel.add_theme_stylebox_override("panel",style(Color("eff6f1"),22))
 root.add_child(map_panel)
 var map_layout=VBoxContainer.new();map_panel.add_child(map_layout)
 var map_header=HBoxContainer.new();map_layout.add_child(map_header)
 var map_title=text("流域の地図",21);map_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_header.add_child(map_title)
 map_close=button("閉じる");map_close.pressed.connect(func():show_map(false));map_header.add_child(map_close)
 map_canvas=preload("res://scripts/adventure/map_view.gd").new();map_canvas.game=game;map_canvas.font=font
 map_canvas.custom_minimum_size=Vector2(200,200);map_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;map_layout.add_child(map_canvas)
 var map_note=text("金：中央基地　赤：現在地\n遠方の良質材は2〜3倍。\n倉庫では入金されません。基地へ届けよう。",13)
 map_layout.add_child(map_note)
 map_panel.visible=false
 get_viewport().size_changed.connect(resize)
 resize()

func resize() -> void:
 var size = get_viewport().get_visible_rect().size
 var width = minf(size.x-28,560)
 root.get_node("Top").position = Vector2((size.x-width)/2,12)
 root.get_node("Top").size = Vector2(width,112)
 var left = (size.x-width)/2
 money_label.position = Vector2(left+16,39)
 money_label.size = Vector2(110,38)
 money_label.add_theme_font_size_override("font_size",20 if game.money>=100000 else 25)
 bag_label.position = Vector2(left+125,49)
 menu_button.position = Vector2(left+width-106,30)
 menu_button.size = Vector2(94,48)
 logistics_button.position=Vector2(left,132)
 logistics_button.size=Vector2(112,44)
 map_button.position=Vector2(left+(width-100)/2,132)
 map_button.size=Vector2(100,44)
 view_button.position=Vector2(left+width-100,132)
 view_button.size=Vector2(100,44)
 goal_label.position = Vector2(left+16,86)
 goal_label.size = Vector2(width-32,32)
 root.get_node("Hint").position = Vector2(left,size.y-76)
 root.get_node("Hint").size = Vector2(width,58)
 hint_label.position = Vector2(14,9)
 hint_label.size = Vector2(width-28,42)
 modal.size = Vector2(minf(size.x-28,370),minf(size.y-24,660))
 # Bounded scroll viewport keeps all facility purchases usable in both orientations.
 modal.position = Vector2((size.x-modal.size.x)/2,maxf(8,(size.y-modal.size.y)/2))
 root.get_node("Brand").position = Vector2(left+16,22)
 stick.size = size
 if map_panel!=null:
  map_panel.size=Vector2(minf(size.x-28,390),minf(size.y-24,720))
  map_panel.position=(size-map_panel.size)/2
 if logistics_panel!=null:
  logistics_panel.size=Vector2(minf(size.x-28,390),minf(size.y-24,720))
  logistics_panel.position=(size-logistics_panel.size)/2

func show_menu(open: bool) -> void:
 modal_open = open
 if map_panel!=null: map_panel.visible=false
 if logistics_panel!=null: logistics_panel.visible=false
 modal.visible = open
 root.get_node("Shade").visible = open
 menu_changed.emit(open)
 resize()

func show_logistics(open: bool) -> void:
 map_panel.visible=false
 modal.visible=false
 logistics_panel.visible=open
 modal_open=open
 root.get_node("Shade").visible=open
 if open: logistics_panel.refresh()
 menu_changed.emit(open)
 resize()

func show_map(open: bool) -> void:
 modal.visible=false;logistics_panel.visible=false
 map_panel.visible=open;modal_open=open
 root.get_node("Shade").visible=open
 menu_changed.emit(open);resize()
 map_canvas.queue_redraw()

func blocked(at: Vector2) -> bool:
 return modal_open or map_button.get_global_rect().has_point(at) or root.get_node("Top").get_global_rect().has_point(at) or view_button.get_global_rect().has_point(at) or logistics_button.get_global_rect().has_point(at)

func toast(value: String) -> void:
 toast_text = value
 toast_time = 4.0

func update(delta: float, controller, camera: Camera3D) -> void:
 toast_time = maxf(0,toast_time-delta)
 if last_money != game.money:
  money_pulse = 0.14
  last_money = game.money
 money_pulse = maxf(0,money_pulse-delta)
 root.get_node("Brand").text = "KIKORI / SNOW TRAIL" if save_available else "KIKORI / 保存不可"
 money_label.text = "● %d" % game.money
 money_label.scale = Vector2.ONE*(1+money_pulse*0.24)
 bag_label.text = "%d / %d 本" % [game.bag.size(),game.capacity()]
 goal_label.text = game.goal().text
 var hint = "ドラッグで移動 · 木のそばで止まると伐採"
 if game.position.distance_to(game.nearest_sale())<1.3: hint = "中央基地 · 止まると出荷して入金"
 elif game.bag.size()>=game.capacity(): hint = "満載！ 中央基地か建設の青い円へ運ぼう"
 elif game.target>=0: hint = "伐採中 · 動くとすぐに中断できる"
 if game.target>=0 and game.ground.size()+Defs.KINDS[game.trees[game.target].kind]["yield"]>Defs.MAX_GROUND: hint = "落ちている丸太を先に運ぼう"
 for project in Defs.PROJECTS:
  if game.position.distance_to(project.position)<1.3 and not game.complete(project.id):
   hint = "%s · 止まると木材を投入" % project.name
 for area in 3:
  if game.automation.levels[area].camp>0 and game.position.distance_to(Defs.CAMPS[area])<1.3:
   hint="倉庫 · 止まると木材を取り出す（建設にも使える）"
 for area in 3:
  if game.logistics.depot_levels[area]>0 and game.position.distance_to(game.Logistics.DEPOTS[area])<1.3:
   hint="集積倉庫 · "+("預ける" if game.logistics.depot_mode=="deposit" else "取り出す")+"（道路・物流で切替）"
 hint_label.text = toast_text if toast_time>0 else hint
 view_button.text="視野：最大" if game.wide_view else "視野：広い"
 for area in 3:
  area_buttons[area].text=("● " if selected_area==area else "")+Defs.SHORT_NAMES[area]
 var auto=game.automation
 var open=game.area_open(selected_area)
 stock_label.text="倉庫 %d / %d 本 · 作業員の荷物 %d 本" % [auto.stocks[selected_area].size(),auto.capacity(selected_area),auto.cutters[selected_area].cargo.size()+auto.porters[selected_area].cargo.size()] if open else "橋を完成すると、この森にも設備を建てられます"
 for key in facility_rows:
  var level=int(auto.levels[selected_area][key])
  var effect="威力 %d → %d / 倉庫 %d 本" % [level,mini(level+1,Defs.AUTO_MAX_LEVEL),12+mini(level+1,Defs.AUTO_MAX_LEVEL)*8] if key=="camp" else ("一度に %d → %d 本運搬" % [4+level*4,4+mini(level+1,Defs.AUTO_MAX_LEVEL)*4] if key=="porter" else "売値 +%d%% → +%d%%" % [level*25,mini(level+1,Defs.AUTO_MAX_LEVEL)*25])
  facility_rows[key].description.text="%s  Lv.%d / %d\n%s\n%s" % [Defs.AUTOMATION[key].name,level,Defs.AUTO_MAX_LEVEL,Defs.AUTOMATION[key].description,effect]
  facility_rows[key].button.text="橋で解放" if not open else ("伐採所が必要" if key!="camp" and auto.levels[selected_area].camp==0 else ("MAX" if level>=Defs.AUTO_MAX_LEVEL else "%d  ·  %s" % [auto.price(selected_area,key),"建設" if level==0 else "強化"]))
  facility_rows[key].button.disabled=not auto.can_buy(game,selected_area,key)
 for key in rows:
  var level = game.levels[key]
  var next = mini(Defs.MAX_LEVEL,level+1)
  var effect = "威力 %d → %d" % [game.damage(),1+next] if key=="axe" else ("積載 %d → %d 本" % [game.capacity(),6+next*4] if key=="pack" else "移動 %.1f → %.1f m/s" % [game.speed(),3.2+next*0.55])
  rows[key].description.text = "%s  Lv.%d / %d\n%s" % [Defs.UPGRADE_NAMES[key],level+1,Defs.MAX_LEVEL+1,effect]
  rows[key].button.text = "%d\n購入" % game.price(key) if level<Defs.MAX_LEVEL else "MAX"
  rows[key].button.disabled = level>=Defs.MAX_LEVEL or game.money<game.price(key)
 stick.active = controller.active_touch>=0 or controller.mouse_active
 stick.origin = controller.origin
 stick.pointer = controller.pointer
 stick.queue_redraw()
 if logistics_panel.visible: logistics_panel.refresh()
 var p = game.goal().position
 var projected = camera.unproject_position(Defs.point(p,0.4))
 var size = get_viewport().get_visible_rect().size
 var safe = Rect2(38,190,size.x-76,size.y-305)
 navigation.visible = not modal_open and not safe.has_point(projected)
 var at = Vector2(clampf(projected.x,40,size.x-100),clampf(projected.y,190,size.y-110))
 navigation.position = at
 var distance = game.position.distance_to(p)
 navigation.text = "%s %s %dm" % ["↑" if projected.y<190 else ("↓" if projected.y>size.y-110 else ("←" if projected.x<40 else "→")),game.goal().label,int(distance)]

func summary() -> Dictionary:
 var result = {"width":get_viewport().get_visible_rect().size.x,"height":get_viewport().get_visible_rect().size.y,"modal":modal_open,"map_open":map_panel.visible}
 var nodes = {"menu":menu_button,"close":close_button,"sound":sound_button,"vibration":vibration_button,"view":view_button,"logistics":logistics_button,"map":map_button,"map_close":map_close}
 for key in rows: nodes[key] = rows[key].button
 for key in facility_rows: nodes[key]=facility_rows[key].button
 for area in 3: nodes["area%d" % area]=area_buttons[area]
 for key in nodes:
  var center = nodes[key].get_global_rect().get_center()
  result[key] = {"x":center.x,"y":center.y}
 if logistics_panel!=null:
  result.merge(logistics_panel.summary())
  result["logistics_open"]=logistics_panel.visible
 return result
