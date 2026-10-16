extends PanelContainer
signal action(kind: String, value)
signal close_requested
var game
var ui
var area = 0
var source: OptionButton
var destination: OptionButton
var depot_button: Button
var mode_button: Button
var purchase: Button
var info: Label
var routes: Array = []
var choices: Array = []
var source_id = ""
var destination_id = ""
var close_button: Button
var source_focus: Button

func option() -> OptionButton:
 var node=OptionButton.new()
 node.add_theme_font_override("font",ui.font)
 node.add_theme_font_size_override("font_size",15)
 node.custom_minimum_size=Vector2(0,48)
 node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 node.get_popup().add_theme_font_override("font",ui.font)
 node.get_popup().add_theme_font_size_override("font_size",15)
 node.fit_to_longest_item=false
 return node

func setup(state, owner_ui) -> void:
 game=state;ui=owner_ui
 add_theme_stylebox_override("panel",ui.style(Color("eff6f4"),22))
 var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",10);add_child(layout)
 var header=HBoxContainer.new();layout.add_child(header)
 var title=ui.text("道路・物流",22);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 close_button=ui.button("閉じる");close_button.pressed.connect(func():close_requested.emit());header.add_child(close_button)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
 var help=ui.text("道の中心をつなぐと荷車が往復。伐採所 → 集積倉庫 → 中央基地と、複数のルートを組めます。倉庫では入金されません。",14);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(help)
 var road=ui.button("道路を作る・撤去する");road.pressed.connect(func():action.emit("editor",null));body.add_child(road)
 var tabs=HBoxContainer.new();body.add_child(tabs)
 for i in 3:
  var tab=ui.button(Defs_name(i));tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.custom_minimum_size.x=80
  tab.pressed.connect(func():area=i;refresh());tabs.add_child(tab)
 depot_button=ui.button("");depot_button.pressed.connect(func():action.emit("depot",area));body.add_child(depot_button)
 info=ui.text("",14);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(info)
 mode_button=ui.button("");mode_button.pressed.connect(func():action.emit("mode",null));body.add_child(mode_button)
 body.add_child(ui.text("荷車のルート",20))
 source=option();destination=option();body.add_child(source);body.add_child(destination)
 source.item_selected.connect(func(index):source_id=choices[index].id)
 destination.item_selected.connect(func(index):destination_id=choices[index].id)
 source_focus=ui.button("出発地を地図で見る・道を敷く")
 source_focus.pressed.connect(func():action.emit("focus",source_id));body.add_child(source_focus)
 purchase=ui.button("荷車を購入して運行  120")
 purchase.pressed.connect(func():action.emit("cart",[source_id,destination_id]));body.add_child(purchase)
 for i in 6:
  var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",ui.style(Color("dce9e5"),14));body.add_child(panel)
  var col=VBoxContainer.new();panel.add_child(col)
  var label=ui.text("",14);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(label)
  var row=HBoxContainer.new();col.add_child(row)
  var pause=ui.button("休止");pause.pressed.connect(func():action.emit("pause",i));row.add_child(pause)
  var upgrade=ui.button("強化");upgrade.pressed.connect(func():action.emit("upgrade_cart",i));upgrade.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(upgrade)
  var apply=ui.button("選択中のルートに変更");apply.pressed.connect(func():action.emit("route",[i,source_id,destination_id]));col.add_child(apply)
  var clear=ui.button("ルートを解除");clear.pressed.connect(func():action.emit("clear",i));col.add_child(clear)
  routes.append({"panel":panel,"label":label,"pause":pause,"upgrade":upgrade,"route":apply,"clear":clear})
 var note=ui.text("道路は1マス2、撤去時の払い戻しはありません。配送中の道は撤去できません。休止は荷物を届けてから。運搬係も橋を渡って中央基地まで往復します。",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(note)
 refresh()

func Defs_name(index: int) -> String:
 return ["雪松","琥珀","白樺"][index]

func refresh() -> void:
 var logistics=game.logistics
 var places=logistics.endpoints(game)
 var signature=""
 for p in places: signature+=p.id+";"
 var previous=""
 for p in choices: previous+=p.id+";"
 if signature!=previous:
  choices=places;source.clear();destination.clear()
  for p in choices:
   source.add_item(p.name);destination.add_item(p.name)
  if source_id.is_empty() or logistics.endpoint(game,source_id).is_empty():
   source_id=""
   for p in choices:
    if p.type!="market": source_id=p.id;break
  if destination_id.is_empty() or logistics.endpoint(game,destination_id).is_empty():
   destination_id="market0"
  for i in choices.size():
   if choices[i].id==source_id: source.select(i)
   if choices[i].id==destination_id: destination.select(i)
 var level=logistics.depot_levels[area]
 depot_button.text="%s 集積倉庫 %s" % [Defs_name(area),"MAX" if level>=3 else "Lv.%d → %d  / %d" % [level,level+1,logistics.depot_price(area)]]
 depot_button.disabled=not game.area_open(area) or level>=3 or game.money<logistics.depot_price(area)
 info.text="%s：在庫 %d / %d 本 · 入荷予定 %d 本\n道路 %d マス · 荷車 %d / 6台" % [Defs_name(area),logistics.stocks[area].size(),logistics.capacity(area) if level>0 else 0,logistics.reserved(area),logistics.roads.size(),logistics.carts.size()]
 mode_button.text="集積倉庫：預ける → 取り出すに切替" if logistics.depot_mode=="deposit" else "集積倉庫：取り出す → 預けるに切替"
 purchase.disabled=game.money<120 or logistics.carts.size()>=6 or source_id.is_empty()
 for i in routes.size():
  var row=routes[i];row.panel.visible=i<logistics.carts.size()
  if i>=logistics.carts.size(): continue
  var cart=logistics.carts[i]
  var a=logistics.endpoint(game,cart.source);var b=logistics.endpoint(game,cart.destination)
  row.label.text="荷車%d Lv.%d / 3 · %s\n%s → %s\n荷物 %d / %d 本" % [cart.id,cart.level,cart.status,a.get("name","未設定"),b.get("name","未設定"),cart.cargo.size(),logistics.cart_capacity(cart)]
  row.pause.text="再開" if cart.pause_requested else "休止"
  row.pause.disabled=cart.source.is_empty()
  row.upgrade.text="MAX" if cart.level>=3 else "強化 %d" % logistics.upgrade_price(cart)
  row.upgrade.disabled=cart.level>=3 or game.money<logistics.upgrade_price(cart)
  var can_change=cart.cargo.is_empty() and cart.phase in ["loading","parked"]
  row.route.disabled=not can_change;row.clear.disabled=not can_change

func summary() -> Dictionary:
 var result={"source_id":source_id,"destination_id":destination_id}
 var buttons={"log_close":close_button,"depot_buy":depot_button,"depot_mode":mode_button,"cart_buy":purchase,"route_source":source,"route_destination":destination,"source_focus":source_focus}
 for i in routes.size():
  buttons["cart_pause%d" % i]=routes[i].pause
  buttons["cart_clear%d" % i]=routes[i].clear
 for key in buttons:
  var p=buttons[key].get_global_rect().get_center();result[key]={"x":p.x,"y":p.y}
 return result
