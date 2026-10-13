extends SceneTree
const State = preload("res://scripts/adventure/game_state.gd")
var state = State.new()
var assertions = 0
var failures = 0
func check(ok: bool, message: String) -> void:
 assertions += 1
 if not ok:
  failures += 1
  push_error(message)
func travel(to: Vector2) -> void:
 for step in 1000:
  var offset = to - state.position
  if offset.length() < 0.08: return
  state.tick(1.0/60.0, offset.normalized() * minf(1, offset.length()/0.06))
 check(false, "Movement stuck: %s to %s" % [state.position,to])
func _initialize() -> void:
 travel(Vector2(-2.2,3.1))
 for step in 180: state.tick(1.0/60.0,Vector2.ZERO)
 check(state.bag.size() == 3,"Tree should yield and collect three logs")
 check(state.conserved(),"Resources conserved after collection")
 var cut = state.first_cut
 travel(Vector2(0,3.1))
 travel(Vector2(0,9))
 travel(Vector2(4,9))
 for step in 90: state.tick(1.0/60.0,Vector2.ZERO)
 check(state.bag.is_empty(),"Sale unloads bag")
 check(state.money == 30,"Sale earns actual value")
 check(state.conserved(),"Resources conserved after sale")
 print("KIKORI_DIRECT_LOOP assertions=%d first_cut=%.2fs first_sale=%.2fs" % [assertions,cut,state.first_sale])
 quit(1 if failures else 0)
