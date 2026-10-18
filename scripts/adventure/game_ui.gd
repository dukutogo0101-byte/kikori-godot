extends CanvasLayer
const Defs = preload("res://scripts/adventure/definitions.gd")
signal upgrade_requested(key: String)
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
var site_panel
var root: Control
var money_label: Label
var bag_label: Label
var goal_label: Label
var hint_label: Label
var menu_button: Button
var sound_button: Button
var vibration_button: Button
var install_button: Button
var modal: PanelContainer
var rows = {}
var view_button: Button
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
 bag_label = text("荷物 0 / 128",15)
 root.add_child(bag_label)
 menu_button = button("道具")
 menu_button.pressed.connect(func(): show_menu(not modal_open))
 root.add_child(menu_button)
 view_button=button("視野：広い")
 view_button.add_theme_font_size_override("font_size",13)
 view_button.pressed.connect(func(): view_changed.emit())
 root.add_child(view_button)
 logistics_button=button("建設・物流")
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
 var title = text("道具",22)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 close_button = button("閉じる")
 close_button.pressed.connect(func(): show_menu(false))
 header.add_child(close_button)
 content.add_child(text("移動 6.5 m/s · 積載 128 本が標準装備",13,Color("678698")))
 for key in ["axe","cut_range","collect_range"]:
  var panel = PanelContainer.new()
  panel.add_theme_stylebox_override("panel",style(Color("e0edf2"),15))
  content.add_child(panel)
  var row = HBoxContainer.new()
  row.add_theme_constant_override("separation",10)
  panel.add_child(row)
  var description = text("",15)
  description.custom_minimum_size.y = 76
  description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(description)
  var purchase = button("")
  purchase.custom_minimum_size.x = 82
  purchase.pressed.connect(func(): upgrade_requested.emit(key))
  row.add_child(purchase)
  rows[key] = {"description":description,"button":purchase}
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
 if OS.has_feature("web"):
  install_button=button("ホーム画面に追加 / アプリの更新")
  install_button.pressed.connect(func(): JavaScriptBridge.eval("window.KikoriInstall && window.KikoriInstall.open()",true))
  content.add_child(install_button)
 content.add_child(text("PCはWASD / 矢印キー。木のそばで止まろう",12,Color("678698")))
 logistics_panel=preload("res://scripts/adventure/logistics_panel.gd").new()
 root.add_child(logistics_panel)
 logistics_panel.setup(game,self)
 logistics_panel.visible=false
 logistics_panel.close_requested.connect(func():show_logistics(false))
 site_panel=preload("res://scripts/adventure/facility_panel.gd").new()
 root.add_child(site_panel);site_panel.setup(game,self);site_panel.visible=false
 site_panel.close_requested.connect(func():show_site(""))
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
 var label_width=font.get_string_size("● %d" % game.money,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
 money_label.add_theme_font_size_override("font_size",clampi(int(25*minf(1,96.0/maxf(1,label_width))),14,25))
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

 if site_panel!=null:
  site_panel.size=Vector2(minf(size.x-28,390),minf(size.y-24,580))
  site_panel.position=(size-site_panel.size)/2

func show_menu(open: bool) -> void:
 if site_panel!=null: site_panel.visible=false
 modal_open = open
 if map_panel!=null: map_panel.visible=false
 if logistics_panel!=null: logistics_panel.visible=false
 modal.visible = open
 root.get_node("Shade").visible = open
 menu_changed.emit(open)
 resize()

func show_logistics(open: bool) -> void:
 site_panel.visible=false
 map_panel.visible=false
 modal.visible=false
 logistics_panel.visible=open
 modal_open=open
 root.get_node("Shade").visible=open
 if open: logistics_panel.refresh()
 menu_changed.emit(open)
 resize()

func show_map(open: bool) -> void:
 site_panel.visible=false
 modal.visible=false;logistics_panel.visible=false
 map_panel.visible=open;modal_open=open
 root.get_node("Shade").visible=open
 menu_changed.emit(open);resize()
 map_canvas.queue_redraw()

func show_site(id: String) -> void:
 modal.visible=false;map_panel.visible=false;logistics_panel.visible=false
 site_panel.selected=id;site_panel.visible=not id.is_empty();modal_open=site_panel.visible
 root.get_node("Shade").visible=modal_open
 if modal_open: site_panel.refresh()
 menu_changed.emit(modal_open);resize()

func blocked(at: Vector2) -> bool:
 if modal_open: return true
 for node in [map_button,root.get_node("Top"),view_button,logistics_button]:
  if node.visible and node.get_global_rect().has_point(at): return true
 return false

func toast(value: String) -> void:
 toast_text = value
 toast_time = 4.0

func update(delta: float, controller, camera: Camera3D) -> void:
 toast_time = maxf(0,toast_time-delta)
 if last_money != game.money:
  money_pulse = 0.14
  last_money = game.money
  var label_width=font.get_string_size("● %d" % game.money,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
  money_label.add_theme_font_size_override("font_size",clampi(int(25*minf(1,96.0/maxf(1,label_width))),14,25))
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
 for project in game.active_projects():
  if game.position.distance_to(project.position)<1.3 and not game.complete(project.id):
   hint = "%s · 止まると木材を投入" % project.name
 for item in game.logistics.sites:
  if game.position.distance_to(item.position)<1.3:
   hint="%s · %s · タップで設定・強化" % [game.logistics.FACILITIES[item.type].name,"搬入中" if item.mode=="deposit" else "取り出し中"]
 hint_label.text = toast_text if toast_time>0 else hint
 view_button.text="視野：最大" if game.wide_view else "視野：広い"
 if site_panel.visible: site_panel.refresh()
 for key in rows:
  var level = game.levels[key]
  var next = mini(Defs.MAX_LEVEL,level+1)
  var effect = "威力 %d → %d" % [game.damage(),1+next] if key=="axe" else ("半径 %.1f → %.1f m" % [game.cut_radius(),Defs.CUT_RADII[next]] if key=="cut_range" else "半径 %.1f → %.1f m" % [game.collect_radius(),Defs.COLLECT_RADII[next]])
  var title=Defs.UPGRADE_NAMES[key]
  rows[key].description.text = "%s  %d / %d\n%s\n%s" % [title,level,Defs.MAX_LEVEL,effect,(Defs.TOOL_NAMES[next]+"へ" if level<Defs.MAX_LEVEL else game.tool_name()) if key=="cut_range" else ("近くの丸太を自動収集" if key=="collect_range" else "道具の切れ味を強化")]
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
 if install_button!=null: nodes["install"]=install_button
 for key in rows: nodes[key] = rows[key].button
 for key in nodes:
  var center = nodes[key].get_global_rect().get_center()
  result[key] = {"x":center.x,"y":center.y}
 if logistics_panel!=null:
  result.merge(logistics_panel.summary())
  result["logistics_open"]=logistics_panel.visible
 if site_panel!=null: result.merge(site_panel.summary())
 return result
