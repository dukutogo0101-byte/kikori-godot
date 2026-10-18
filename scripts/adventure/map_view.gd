extends Control
const Defs=preload("res://scripts/adventure/definitions.gd")
var game
var font: Font
func project(p: Vector2) -> Vector2:
 var scale_value=minf((size.x-24)/Defs.WORLD_BOUNDS.size.x,(size.y-20)/Defs.WORLD_BOUNDS.size.y)
 var offset=(size-Defs.WORLD_BOUNDS.size*scale_value)/2
 return offset+(p-Defs.WORLD_BOUNDS.position)*scale_value
func _draw() -> void:
 if game==null: return
 draw_style_box(panel(),Rect2(Vector2.ZERO,size))
 for area in 3:
  var points=PackedVector2Array()
  for p in Defs.OUTLINES[area]: points.append(project(p))
  draw_colored_polygon(points,[Color("c2d5ae"),Color("d5c09a"),Color("d6e5e9")][area] if game.area_open(area) else Color("77908c"))
  points.append(points[0]);draw_polyline(points,Color("a8c6bc"),1.2,true)
 for lake in Defs.LAKES:
  var points=PackedVector2Array()
  for i in 24: points.append(project(lake.get_center()+Vector2(cos(i*TAU/24),sin(i*TAU/24))*lake.size/2))
  draw_colored_polygon(points,Color("5e9da9"))
 for cell in game.logistics.roads: draw_circle(project(Vector2(cell)),1.4,Color("a77d47"))
 for i in 2:
  var rect=Defs.BRIDGES[i];draw_line(project(rect.get_center()+Vector2(0,-rect.size.y/2)),project(rect.get_center()+Vector2(0,rect.size.y/2)),Color("efbe72") if game.complete("bridge" if i==0 else "high_bridge") else Color("d16e55"),4)
 for area in 3:
  var p=Defs.CAMPS[area]

  draw_string(font,project([Vector2(-45,41),Vector2(-18,-87),Vector2(-44,-200)][area]),["雪松の盆地  10〜20","琥珀の丘陵  48","白樺の高原  150"][area],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("203e42"))
  if not game.area_open(area): draw_string(font,project(p)+Vector2(6,0),"橋で解放",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f7f0d3"))
 for item in game.logistics.sites:
  draw_circle(project(item.position),3.5,Color(game.logistics.FACILITIES[item.type].color))
 draw_circle(project(Defs.SALE),6,Color("eebd58"))
 draw_string(font,project(Defs.SALE)+Vector2(8,-5),"中央基地",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("243c39"))
 var here=project(game.position)
 draw_circle(here,4.5,Color("ef7156"));draw_arc(here,6,0,TAU,24,Color.WHITE,1.4,true)
 draw_string(font,Vector2(size.x-42,22),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("edf5eb"))
func panel() -> StyleBoxFlat:
 var box=StyleBoxFlat.new();box.bg_color=Color("6398a3");box.corner_radius_top_left=12;box.corner_radius_top_right=12;box.corner_radius_bottom_left=12;box.corner_radius_bottom_right=12
 return box
