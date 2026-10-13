extends Node
var direction = Vector2.ZERO
var active_touch = -1
var origin = Vector2.ZERO
var pointer = Vector2.ZERO
var radius = 64.0
var mouse_active = false
var blocked: Callable
var enabled = true
var keys = {}

func reset() -> void:
 direction = Vector2.ZERO
 active_touch = -1
 mouse_active = false
 keys.clear()

func _input(event: InputEvent) -> void:
 if not enabled: return
 if event is InputEventKey:
  if event.echo: return
  if event.pressed: keys[event.physical_keycode] = true
  else: keys.erase(event.physical_keycode)
 if event is InputEventScreenTouch:
  if event.canceled:
   reset()
   return
  if event.pressed and active_touch < 0 and not blocked.call(event.position):
   active_touch = event.index
   origin = event.position
   pointer = origin
  elif event.index == active_touch and not event.pressed:
   reset()
 elif event is InputEventScreenDrag and event.index == active_touch:
  pointer = event.position
  if not get_viewport().get_visible_rect().has_point(pointer): reset()
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if event.canceled:
   reset()
   return
  if event.pressed and active_touch < 0 and not blocked.call(event.position):
   mouse_active = true
   origin = event.position
   pointer = origin
  elif not event.pressed and mouse_active: reset()
 elif event is InputEventMouseMotion and mouse_active:
  pointer = event.position
  if not get_viewport().get_visible_rect().has_point(pointer): reset()

func sample() -> Vector2:
 if not enabled: return Vector2.ZERO
 var key = Vector2(float(keys.has(KEY_D) or keys.has(KEY_RIGHT)) - float(keys.has(KEY_A) or keys.has(KEY_LEFT)), float(keys.has(KEY_S) or keys.has(KEY_DOWN)) - float(keys.has(KEY_W) or keys.has(KEY_UP)))
 if active_touch >= 0 or mouse_active:
  var stick = (pointer - origin) / radius
  direction = Vector2.ZERO if stick.length() < 0.12 else stick.limit_length(1)
 else:
  direction = key.limit_length(1)
 return direction
