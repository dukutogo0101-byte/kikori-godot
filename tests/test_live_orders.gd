extends "res://tests/test_transport.gd"

func loaded():
 var g=network(true);var n=g.logistics
 n.add_cart(g,"site1","site2");wood(g,3,n.sites[0].output);n.tick(g,0.1)
 check(n.carts[0].phase=="to_destination" and n.carts[0].cargo.size()==3,"Start with an actual loaded vehicle between road cells")
 return g

func until_idle(g, steps: int = 1500) -> void:
 for i in steps:
  g.logistics.tick(g,0.1)
  if g.logistics.carts[0].phase=="parked": return

func run() -> void:
 # A loaded delivery keeps the original destination reservation and physical path.
 var g=loaded();var n=g.logistics;var c=n.carts[0]
 var cargo=c.cargo.duplicate(true);var position=c.position;var route=c.path.duplicate();var cursor=c.cursor;var funds=g.money
 check(n.edit_order(g,0,0,"site4","market0"),"Edit a loaded moving vehicle")
 check(c.orders[0].destination=="site2" and c.pending_orders[0].source=="site4","Current delivery and next plan remain separate")
 check(c.cargo==cargo and c.position==position and c.path==route and c.cursor==cursor and g.money==funds,"Editing never moves, sells or discards current cargo")
 check(n.reserved("site2")==3 and n.reserved("site4")==0 and not c.pause_requested,"Reservation remains at original delivery and running state is retained")
 copy_of(g)
 # Every further edit operates on the proposed plan, even after queued clear.
 check(n.edit_order(g,0,1,"site2","site3") and n.command_orders(c).size()==2,"Append to pending plan")
 check(n.edit_order(g,0,2,"site3","market0") and not n.edit_order(g,0,3,"site1","market0"),"Three pending commands are accepted but a fourth is rejected")
 check(n.remove_order(g,0,0) and n.command_orders(c)[0].source=="site2","Delete from pending plan")
 check(n.clear_route(0) and n.command_orders(c).is_empty() and c.cargo==cargo,"Clear all while loaded queues a safe stop")
 copy_of(g)
 check(n.edit_order(g,0,0,"site4","market0") and n.command_orders(c).size()==1,"Replace a pending clear before delivery finishes")
 var before=JSON.stringify(n.snapshot())
 check(not n.edit_order(g,0,0,"missing","market0") and JSON.stringify(n.snapshot())==before,"Invalid edits preserve both delivery and prior pending plan")
 check(not n.edit_roads(g,[Vector2i(6,18)],true),"Pending independent-source roads are protected")
 wood(g,3,n.sites[3].output,2)
 var delivered=false;var continued=false
 for i in 1500:
  n.tick(g,0.1)
  if c.get("pending_orders")==null and not delivered:
   delivered=true
   check(c.position.distance_to(n.sites[1].position)<0.002 and c.cargo.is_empty(),"Queued commands apply only at the actual original delivery point")
   check(c.orders[0].source=="site4" and not c.pause_requested,"Running vehicle automatically continues with new command one")
   check(n.reserved("site2")==0 and n.sites[1].input.size()+n.sites[1].output.size()==3,"Old reservation releases only after real delivery")
   copy_of(g)
  if g.money==funds+120: continued=true;break
 check(delivered and continued and g.conserved(),"Original three logs arrive once; new product order then reaches base once")
 # Loaded clear and deleting the last order finish delivery before stopping.
 for remove_last in [false,true]:
  var clear_game=loaded();var net=clear_game.logistics;var cart=net.carts[0]
  check(net.remove_order(clear_game,0,0) if remove_last else net.clear_route(0),"Clear or remove final command during delivery")
  var restored=copy_of(clear_game);until_idle(restored)
  var vehicle=restored.logistics.carts[0]
  check(vehicle.phase=="parked" and vehicle.orders.is_empty() and vehicle.pending_orders==null and vehicle.cargo.is_empty(),"Queued clear survives reload and parks after delivery")
  check(restored.logistics.sites[1].input.size()+restored.logistics.sites[1].output.size()==3 and restored.conserved(),"Clearing never discards delivered goods")
 # Empty moving carts accept edits and finish their current empty leg safely.
 var empty_game=network(true);var en=empty_game.logistics
 en.add_cart(empty_game,"site1","site2");en.set_route(empty_game,0,"site4","market0");en.tick(empty_game,0.1)
 var ec=en.carts[0]
 check(ec.phase=="to_source" and ec.cargo.is_empty(),"Empty reposition is physically in transit")
 position=ec.position;route=ec.path.duplicate()
 check(en.set_route(empty_game,0,"site2","site3") and ec.position==position and ec.path==route,"Empty in-transit edit preserves fractional position and active road segment")
 copy_of(empty_game)
 var switched=false
 for i in 1500:
  en.tick(empty_game,0.1)
  if ec.pending_orders==null:
   switched=true;break
 check(switched and ec.position==en.sites[3].position and ec.source=="site2","Empty leg reaches previous source before switching, without teleporting")
 copy_of(empty_game)
 # Pause, pending edits and clear are independent controls.
 var paused=loaded();var pn=paused.logistics
 pn.toggle_pause(0);pn.set_route(paused,0,"site4","market0")
 var paused_copy=copy_of(paused);until_idle(paused_copy)
 var pc=paused_copy.logistics.carts[0]
 check(pc.phase=="parked" and pc.source=="site4" and pc.pause_requested,"A paused vehicle remains paused after applying queued edits")
 check(paused_copy.logistics.toggle_pause(0),"User can resume the new retained plan")
 copy_of(paused_copy)
 # Unloading is also editable, including after some cargo was already delivered.
 var unloading=loaded();var un=unloading.logistics;var uc=un.carts[0]
 for i in 5000:
  un.tick(unloading,0.01)
  if uc.phase=="unloading" and uc.cargo.size()==2: break
 check(uc.phase=="unloading" and uc.cargo.size()==2,"Reach a partially unloaded delivery")
 check(un.set_route(unloading,0,"site4","market0") and un.reserved("site2")==2,"Edit during unloading preserves remaining reservation")
 fixture("transport-live-edit-fixture",unloading)
 copy_of(unloading)
 un.clear_route(0);until_idle(unloading)
 check(un.sites[1].input.size()+un.sites[1].output.size()==3 and unloading.conserved(),"Partial unload followed by clear delivers total cargo exactly once")
 # Empty waiting, returning and parked states apply immediately, keeping pause.
 var waiting=network(true);var wn=waiting.logistics;wn.add_cart(waiting,"site1","site2")
 var wc=wn.carts[0]
 for phase in ["loading","returning","parked"]:
  wc.phase=phase;wc.pause_requested=phase=="parked";wc.position=wn.sites[0].position;wc.path=[];wc.cursor=0
  check(wn.set_route(waiting,0,"site4","market0") and wc.pending_orders==null,"Immediate edit when empty at a road cell: "+phase)
  check(wc.pause_requested==(phase=="parked") and wc.position==wn.sites[0].position,"Immediate edit preserves run/pause and physical position")
  copy_of(waiting)
 # Malformed queued state rejects the whole save, including duplicate reservations.
 var valid=loaded().snapshot()
 var corrupt=valid.duplicate(true);corrupt.logistics.carts[0].pending_orders="invalid"
 var target=State.new();var pristine=JSON.stringify(target.snapshot())
 check(not target.restore(corrupt) and JSON.stringify(target.snapshot())==pristine,"Non-array queued plan is atomically rejected")
 for plan in [[{"source":"missing","destination":"market0"}], [{"source":"site1","destination":"market0"},{"source":"site1","destination":"market0"},{"source":"site1","destination":"market0"},{"source":"site1","destination":"market0"}]]:
  corrupt=valid.duplicate(true);corrupt.logistics.carts[0].pending_orders=plan
  check(not target.restore(corrupt),"Invalid queued endpoint or fourth order is rejected")
 var old=valid.duplicate(true);old.logistics.carts[0].erase("pending_orders")
 check(State.new().restore(old),"Existing v9 saves without queued edits remain playable")
 # Browser fixture starts moving and loaded, not paused or empty.
 var browser=loaded();wood(browser,3,browser.logistics.sites[3].output,2)
 fixture("transport-moving-edit-fixture",browser)
 # Inspect the actual controls while carrying cargo, including a queued clear.
 var ui=preload("res://scripts/adventure/game_ui.gd").new()
 root.add_child(ui);ui.setup(browser,load("res://assets/fonts/KikoriSans.otf"));ui.show_logistics(true)
 var panel=ui.logistics_panel;var row=panel.routes[0]
 for phase in ["to_destination","unloading","to_source","loading","returning","parked"]:
  browser.logistics.carts[0].phase=phase;panel.refresh()
  check(not row.orders[0].apply.disabled and not row.orders[0].remove.disabled and not row.append.disabled and not row.clear.disabled,"Actual edit controls enabled in "+phase)
 browser.logistics.carts[0].phase="to_destination"
 browser.logistics.clear_route(0);panel.refresh()
 check(not row.append.disabled and row.clear.disabled and not row.orders[0].box.visible,"Queued clear still allows a replacement command")
 check("変更予約" in row.label.text,"Pending changes visibly identify deferred application")
 ui.free()
 print("KIKORI_LIVE_ORDER_TESTS assertions=%d failures=%d" % [assertions,failures])
 quit(1 if failures else 0)
