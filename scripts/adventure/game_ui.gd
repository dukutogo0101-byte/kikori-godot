extends CanvasLayer
const Defs = preload("res://scripts/adventure/definitions.gd")
signal upgrade_requested(key: String)
signal menu_changed(open: bool)
signal sound_changed(on: bool)
signal vibration_changed(on: bool)
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
 menu_button = button("強化")
 menu_button.pressed.connect(func(): show_menu(not modal_open))
 root.add_child(menu_button)
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
 var scroll = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 modal.add_child(scroll)
 var content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",10)
 scroll.add_child(content)
 var header = HBoxContainer.new()
 content.add_child(header)
 var title = text("旅の道具を強化",22)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 close_button = button("閉じる")
 close_button.pressed.connect(func(): show_menu(false))
 header.add_child(close_button)
 content.add_child(text("切る・背負う・歩くが、もっと快適に",13,Color("678698")))
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
 bag_label.position = Vector2(left+132,49)
 menu_button.position = Vector2(left+width-80,30)
 menu_button.size = Vector2(64,48)
 goal_label.position = Vector2(left+16,86)
 goal_label.size = Vector2(width-32,32)
 root.get_node("Hint").position = Vector2(left,size.y-76)
 root.get_node("Hint").size = Vector2(width,58)
 hint_label.position = Vector2(14,9)
 hint_label.size = Vector2(width-28,42)
 modal.size = Vector2(minf(size.x-28,370),minf(size.y-24,490))
 # Container calculates height from its content; scrolling is unnecessary in portrait.
 modal.position = Vector2((size.x-modal.size.x)/2,maxf(8,(size.y-modal.size.y)/2))
 root.get_node("Brand").position = Vector2(left+16,22)
 stick.size = size

func show_menu(open: bool) -> void:
 modal_open = open
 modal.visible = open
 root.get_node("Shade").visible = open
 menu_changed.emit(open)
 resize()

func blocked(at: Vector2) -> bool:
 return modal_open or root.get_node("Top").get_global_rect().has_point(at)

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
 if game.position.distance_to(Defs.SALE)<1.3: hint = "売り場 · 止まると一本ずつ荷下ろし"
 elif game.bag.size()>=game.capacity(): hint = "満載！ 売り場か建設の青い円へ運ぼう"
 elif game.target>=0: hint = "伐採中 · 動くとすぐに中断できる"
 for project in Defs.PROJECTS:
  if game.position.distance_to(project.position)<1.3 and not game.complete(project.id):
   hint = "%s · 止まると木材を投入" % project.name
 hint_label.text = toast_text if toast_time>0 else hint
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
 var p = game.goal().position
 var projected = camera.unproject_position(Vector3(p.x,0.4,p.y))
 var size = get_viewport().get_visible_rect().size
 var safe = Rect2(38,155,size.x-76,size.y-270)
 navigation.visible = not modal_open and not safe.has_point(projected)
 var at = Vector2(clampf(projected.x,40,size.x-100),clampf(projected.y,155,size.y-110))
 navigation.position = at
 var distance = game.position.distance_to(p)
 navigation.text = "%s %dm" % ["↑" if projected.y<155 else ("↓" if projected.y>size.y-110 else ("←" if projected.x<40 else "→")),int(distance)]

func summary() -> Dictionary:
 var result = {"width":get_viewport().get_visible_rect().size.x,"height":get_viewport().get_visible_rect().size.y,"modal":modal_open}
 var nodes = {"menu":menu_button,"close":close_button,"sound":sound_button,"vibration":vibration_button}
 for key in rows: nodes[key] = rows[key].button
 for key in nodes:
  var center = nodes[key].get_global_rect().get_center()
  result[key] = {"x":center.x,"y":center.y}
 return result
