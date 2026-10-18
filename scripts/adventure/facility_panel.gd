extends PanelContainer
signal action(kind: String, value)
signal close_requested
var game
var ui
var selected=""
var title: Label
var description: Label
var upgrade: Button
var mode: Button
var worker: Button
var focus: Button
var close_button: Button

func setup(state, owner_ui) -> void:
 game=state;ui=owner_ui
 add_theme_stylebox_override("panel",ui.style(Color("eff6f1"),22))
 var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",10);add_child(layout)
 var header=HBoxContainer.new();layout.add_child(header)
 title=ui.text("設備",21);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 close_button=ui.button("閉じる");close_button.pressed.connect(func():close_requested.emit());header.add_child(close_button)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);scroll.add_child(body)
 description=ui.text("",15);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(description)
 upgrade=ui.button("");upgrade.pressed.connect(func():action.emit("site_upgrade",selected));body.add_child(upgrade)
 mode=ui.button("");mode.pressed.connect(func():action.emit("site_mode",selected));body.add_child(mode)
 worker=ui.button("");worker.pressed.connect(func():action.emit("site_worker",selected));body.add_child(worker)
 focus=ui.button("ここから道路を作る");focus.pressed.connect(func():action.emit("focus",selected));body.add_child(focus)
 var help=ui.text("手動搬入：入口の円で止まると受け渡し。\n道路：入口の円の中心どうしを接続。\n荷車：建設・物流から出発地と配送先を指定。\n売上：中央基地に届いた時だけ入金。",13);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(help)

func refresh() -> void:
 var network=game.logistics;var item=network.site(selected)
 if item.is_empty(): return
 title.text="%s Lv.%d" % [network.FACILITIES[item.type].name,item.level]
 var counts=[0,0,0]
 for log in item.output: counts[int(log.get("stage",0))]+=1
 description.text="入口 (%d, %d) · %s\n保管：丸太 %d / 加工材 %d / 製品 %d\n出荷在庫 %d / %d 本\n入荷予定 %d 本" % [item.position.x,item.position.y,item.id,counts[0],counts[1],counts[2],item.output.size(),network.capacity(item.id),network.reserved(item.id)]
 if item.type=="storage":
  description.text+="\n木こり：%s · 運搬 %d 本\n伐採半径 %d m · 威力 %d" % [item.worker.status,item.worker.cargo.size(),12+item.level*5,item.level]
 else:
  description.text+="\n加工待ち %d / %d 本\n%s → %s · %.1f秒 / 本\n進捗 %d%% · 中央基地で売価 ×%d" % [item.input.size(),network.capacity(item.id),"丸太" if item.type=="processor" else "加工材","加工材" if item.type=="processor" else "製品",6.0/item.level,int(item.clock/(6.0/item.level)*100),2 if item.type=="processor" else 4]
 upgrade.text="強化 MAX" if item.level>=3 else "Lv.%d に強化 · %d" % [item.level+1,network.price(item.type,item.level)]
 upgrade.disabled=item.level>=3 or game.money<network.price(item.type,item.level)
 mode.text="手動：搬入中 → 取り出しに切替" if item.mode=="deposit" else "手動：取り出し中 → 搬入に切替"
 worker.visible=item.type=="storage";worker.text="木こりを休止する" if item.worker_enabled else "木こりを再開する"

func summary() -> Dictionary:
 var result={"selected_site":selected,"site_open":visible}
 for entry in [["site_close",close_button],["site_upgrade",upgrade],["site_mode",mode],["site_worker",worker],["site_focus",focus]]:
  var at=entry[1].get_global_rect().get_center();result[entry[0]]={"x":at.x,"y":at.y}
 return result
