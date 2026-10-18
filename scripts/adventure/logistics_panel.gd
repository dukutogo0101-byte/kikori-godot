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
 body.add_child(ui.text("輸送車の運送命令",20))
 source=option();destination=option();body.add_child(source);body.add_child(destination)
 source.item_selected.connect(func(index):source_id=choices[index].id)
 destination.item_selected.connect(func(index):destination_id=choices[index].id)
 source_focus=ui.button("出発地を地図で見る・道を敷く")
 source_focus.pressed.connect(func():action.emit("focus",source_id));body.add_child(source_focus)
 purchase=ui.button("人力の輸送車を購入  120")
 purchase.pressed.connect(func():action.emit("cart",[source_id,destination_id]));body.add_child(purchase)
 for i in game.logistics.MAX_CARTS:
  var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",ui.style(Color("dce9e5"),14));body.add_child(panel)
  var col=VBoxContainer.new();panel.add_child(col)
  var label=ui.text("",14);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(label)
  var row=HBoxContainer.new();col.add_child(row)
  var pause=ui.button("休止");pause.pressed.connect(func():action.emit("pause",i));row.add_child(pause)
  var upgrade=ui.button("強化");upgrade.pressed.connect(func():action.emit("upgrade_cart",i));upgrade.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(upgrade)
  var orders=[]
  for slot in game.logistics.MAX_ORDERS:
   var order_box=VBoxContainer.new();col.add_child(order_box)
   var order_label=ui.text("",14);order_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;order_box.add_child(order_label)
   var controls=HBoxContainer.new();order_box.add_child(controls)
   var apply=ui.button("選択区間に変更");apply.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   apply.pressed.connect(func():action.emit("order",[i,slot,source_id,destination_id]));controls.add_child(apply)
   var remove=ui.button("削除");remove.pressed.connect(func():action.emit("remove_order",[i,slot]));controls.add_child(remove)
   orders.append({"box":order_box,"label":order_label,"apply":apply,"remove":remove})
  var append=ui.button("選択区間を命令に追加")
  append.pressed.connect(func():action.emit("order",[i,game.logistics.carts[i].orders.size(),source_id,destination_id]));col.add_child(append)
  var clear=ui.button("全命令を解除");clear.pressed.connect(func():action.emit("clear",i));col.add_child(clear)
  routes.append({"panel":panel,"label":label,"pause":pause,"upgrade":upgrade,"orders":orders,"append":append,"clear":clear})
 var note=ui.text("1台に最大3件の命令を設定でき、上から順に繰り返します。区間の間は空荷で移動。木材なし・満杯の区間は次の周回で再確認します。命令の編集は荷物を届けて休止してから。設定後に「再開」で運行。各車種はLv.5まで。人力・馬車はLv.5で次の車種へ更新できます。",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(note)
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
 info.text="設備 %d / 16 棟 · 輸送車 %d / %d 台\n上限＝中央基地を含む全建物数＋1台\n新設道路 %d マス · 既存道と橋 %d マス\n加工所は丸太、工場は加工材のみ受け入れます。\n下の出発地・配送先を選び、各車の命令に追加・変更できます。" % [logistics.sites.size(),logistics.carts.size(),logistics.cart_limit(),logistics.roads.size(),logistics.public_roads(game).size()]
 for kind in build_buttons: build_buttons[kind].disabled=game.money<logistics.price(kind) or logistics.sites.size()>=16
 purchase.disabled=game.money<120 or logistics.carts.size()>=logistics.cart_limit() or source_id.is_empty()
 for i in routes.size():
  var row=routes[i];row.panel.visible=i<logistics.carts.size()
  if i>=logistics.carts.size(): continue
  var cart=logistics.carts[i]
  row.label.text="%s · %s\n荷物 %d / %d 本 · 速度 %.1f\n運送命令 %d / 3 件（繰り返し）" % [logistics.cart_name(cart),cart.status,cart.cargo.size(),logistics.cart_capacity(cart),logistics.cart_speed(cart),cart.orders.size()]
  row.pause.text="再開" if cart.pause_requested else "休止"
  row.pause.disabled=cart.source.is_empty()
  var cost=logistics.upgrade_price(cart)
  if logistics.cart_maxed(cart): row.upgrade.text="最高レベル"
  elif cart.level==5: row.upgrade.text="%sへ更新 · %d" % [logistics.VEHICLES[cart.tier+1].name,cost]
  else: row.upgrade.text="Lv.%dへ強化 · %d" % [cart.level+1,cost]
  row.upgrade.disabled=logistics.cart_maxed(cart) or game.money<cost
  var can_change=logistics.can_edit_orders(cart)
  for slot in row.orders.size():
   var command=row.orders[slot];command.box.visible=slot<cart.orders.size()
   if slot>=cart.orders.size(): continue
   var order=cart.orders[slot];var a=logistics.endpoint(game,order.source);var b=logistics.endpoint(game,order.destination)
   command.label.text="%s 命令%d：%s → %s" % ["▶" if slot==cart.order_index else "",slot+1,a.get("name","未設定"),b.get("name","未設定")]
   command.apply.disabled=not can_change;command.remove.disabled=not can_change
  row.append.disabled=not can_change or cart.orders.size()>=3
  row.clear.disabled=not can_change or cart.orders.is_empty()

func summary() -> Dictionary:
 var result={"source_id":source_id,"destination_id":destination_id,"cart_limit":game.logistics.cart_limit()}
 var buttons={"road_editor":road_button,"log_close":close_button,"cart_buy":purchase,"route_source":source,"route_destination":destination,"source_focus":source_focus}
 for kind in build_buttons: buttons["build_"+kind]=build_buttons[kind]
 for i in routes.size():
  buttons["cart_pause%d" % i]=routes[i].pause
  buttons["cart_clear%d" % i]=routes[i].clear
  buttons["cart_upgrade%d" % i]=routes[i].upgrade
  buttons["cart_append%d" % i]=routes[i].append
  for slot in routes[i].orders.size():
   buttons["cart_order%d_%d" % [i,slot]]=routes[i].orders[slot].apply
   buttons["cart_remove%d_%d" % [i,slot]]=routes[i].orders[slot].remove
 for key in buttons:
  var p=buttons[key].get_global_rect().get_center();result[key]={"x":p.x,"y":p.y}
 return result
