extends Node
var direction = Vector2.ZERO
var active_touch = -1
var origin = Vector2.ZERO
var pointer = Vector2.ZERO
var radius = 64.0
var mouse_active = false
var blocked: Callable
var enabled = true

func reset() -> void:
 direction = Vector2.ZERO
 active_touch = -1
 mouse_active = false

func _input(event: InputEvent) -> void:
 if not enabled: return
 if event is InputEventScreenTouch:
  if event.pressed and active_touch < 0 and not blocked.call(event.position):
   active_touch = event.index
   origin = event.position
   pointer = origin
  elif event.index == active_touch and not event.pressed:
   reset()
 elif event is InputEventScreenDrag and event.index == active_touch:
  pointer = event.position
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if event.pressed and active_touch < 0 and not blocked.call(event.position):
   mouse_active = true
   origin = event.position
   pointer = origin
  elif not event.pressed and mouse_active: reset()
 elif event is InputEventMouseMotion and mouse_active:
  pointer = event.position

func sample() -> Vector2:
 if not enabled: return Vector2.ZERO
 var key = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if active_touch >= 0 or mouse_active:
  var stick = (pointer - origin) / radius
  direction = Vector2.ZERO if stick.length() < 0.12 else stick.limit_length(1)
 else:
  direction = key.limit_length(1)
 return direction
