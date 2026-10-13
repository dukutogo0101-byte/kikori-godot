extends Control
var active = false
var origin = Vector2.ZERO
var pointer = Vector2.ZERO
func _draw() -> void:
 if not active: return
 var offset = (pointer-origin).limit_length(64)
 draw_circle(origin,64,Color(0.16,0.37,0.48,0.16))
 draw_arc(origin,64,0,TAU,48,Color(1,1,1,0.72),3,true)
 draw_circle(origin+offset,25,Color(0.96,0.81,0.46,0.88))
 draw_circle(origin+offset,22,Color(1,0.96,0.84,0.3))
