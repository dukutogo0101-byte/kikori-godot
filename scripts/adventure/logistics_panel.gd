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
var road_button: Button
var build_buttons={}

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
 var title=ui.text("建設・物流",22);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 close_button=ui.button("閉じる");close_button.pressed.connect(func():close_requested.emit());header.add_child(close_button)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
 var help=ui.text("既存の道と完成した橋も荷車で通れます。設備の入口の円から道へ接続しよう。中間集積所 → 加工所 → 工場 → 中央基地。加工材は2倍、製品は4倍。設備をタップで強化。",14);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(help)
 road_button=ui.button("道路を作る・撤去する");road_button.pressed.connect(func():action.emit("editor",null));body.add_child(road_button)
 for kind in ["storage","processor","factory"]:
  var build=ui.button("%sを配置 · %d" % [game.logistics.FACILITIES[kind].name,game.logistics.price(kind)])
  build.pressed.connect(func():action.emit("place",kind));body.add_child(build);build_buttons[kind]=build
 info=ui.text("",14);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(info)
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
 var note=ui.text("道路は1マス2、撤去時の払い戻しはありません。配送中の道は撤去できません。休止は荷物を届けてから。中間集積所の木こりは近くの木を伐採して納品します。",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(note)
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
 info.text="設備 %d / 16 棟 · 荷車 %d / 6 台\n新設道路 %d マス · 既存道と橋 %d マス\n加工所は丸太、工場は加工材のみ受け入れます。" % [logistics.sites.size(),logistics.carts.size(),logistics.roads.size(),logistics.public_roads(game).size()]
 for kind in build_buttons: build_buttons[kind].disabled=game.money<logistics.price(kind) or logistics.sites.size()>=16
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
 var buttons={"road_editor":road_button,"log_close":close_button,"cart_buy":purchase,"route_source":source,"route_destination":destination,"source_focus":source_focus}
 for kind in build_buttons: buttons["build_"+kind]=build_buttons[kind]
 for i in routes.size():
  buttons["cart_pause%d" % i]=routes[i].pause
  buttons["cart_clear%d" % i]=routes[i].clear
 for key in buttons:
  var p=buttons[key].get_global_rect().get_center();result[key]={"x":p.x,"y":p.y}
 return result
