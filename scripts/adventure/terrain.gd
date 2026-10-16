extends RefCounted
const Defs=preload("res://scripts/adventure/definitions.gd")
const Art=preload("res://scripts/art.gd")
var art=Art.new()

func land(area: int) -> ArrayMesh:
 var key="watershed_%d" % area
 if OS.has_feature("web"): return art.cached(key)
 art.begin(key)
 var outline=PackedVector2Array(Defs.OUTLINES[area])
 var bounds=Defs.AREAS[area]
 # Clip the height grid to the actual bank outline; collision uses that outline.
 for x in range(int(bounds.position.x),int(bounds.end.x),3):
  for z in range(int(bounds.position.y),int(bounds.end.y),3):
   var square=PackedVector2Array([Vector2(x,z),Vector2(x+3,z),Vector2(x+3,z+3),Vector2(x,z+3)])
   for piece in Geometry2D.intersect_polygons(outline,square):
    var indices=Geometry2D.triangulate_polygon(piece)
    for i in range(0,indices.size(),3):
     var a=piece[indices[i]];var b=piece[indices[i+1]];var c=piece[indices[i+2]]
     var center=(a+b+c)/3.0
     var height=Defs.height_at(center)
     var color=[Color("aec59e"),Color("b6bf9c"),Color("c4d6d5")][area]
     if height>2.1: color=color.lerp(Color("7f997f"),minf(0.45,(height-2.1)*0.15))
     color=color.darkened(float(posmod(x*7+z*13,5))*0.003)
     # Godot's front face is clockwise, independent of clipping orientation.
     if (b-a).cross(c-a)<0: art.tri(Defs.point(a),Defs.point(b),Defs.point(c),color)
     else: art.tri(Defs.point(c),Defs.point(b),Defs.point(a),color)
 for i in outline.size():
  var p=outline[i];var q=outline[(i+1)%outline.size()]
  var count=maxi(1,ceili(p.distance_to(q)/3.0))
  for j in count:
   var a=Defs.point(p.lerp(q,float(j)/count));var b=Defs.point(p.lerp(q,float(j+1)/count))
   art.quad(b,a,Vector3(a.x,-1.8,a.z),Vector3(b.x,-1.8,b.z),Color("839b86").darkened((i%3)*0.04))
 return art.finish()

func water() -> ArrayMesh:
 var key="watershed_water"
 if OS.has_feature("web"): return art.cached(key)
 art.begin(key)
 art.box(Vector3(0,-0.7,-78),Vector3(250,0.08,350),Color("6fa7b2"))
 # Ripples break up long stretches of river and the inset lakes.
 for i in 170:
  var p=Vector2(-116+posmod(i*43,232),-232+posmod(i*71,320))
  art.box(Vector3(p.x,-0.65,p.y),Vector3(2.8+sin(i)*1.4,0.015,0.06),Color("a1ccd0"))
 return art.finish()

func rock() -> ArrayMesh:
 var key="watershed_rock"
 if OS.has_feature("web"): return art.cached(key)
 art.begin(key)
 art.crown(Vector3(0,0.7,0),Vector3(2.3,1.8,2.0),Color("84918b"),3)
 art.crown(Vector3(-0.7,1.5,-0.2),Vector3(1.8,1.4,1.6),Color("a2aca2"),7)
 art.crown(Vector3(-0.7,2.05,-0.3),Vector3(1.55,0.35,1.3),Color("e4ebdf"),7)
 return art.finish()

func scenery() -> ArrayMesh:
 var key="watershed_scenery"
 if OS.has_feature("web"): return art.cached(key)
 art.begin(key)
 for area in 3:
  for i in 90:
   var p=Defs.AREAS[area].position+Vector2(posmod(i*47+13,roundi(Defs.AREAS[area].size.x)),posmod(i*29+7,roundi(Defs.AREAS[area].size.y)))
   if not Defs.in_area(p,area,2) or Defs.corridor(p): continue
   var clear=true
   for rect in Defs.building_rects():
    if rect.grow(3).has_point(p): clear=false
   if not clear: continue
   var at=Defs.point(p)
   if i%3==0: art.crown(at+Vector3(0,0.12,0),Vector3(0.45,0.3,0.35),Color("9eac99"),i)
   else:
    for j in 3:
     var stem=at+Vector3(j*0.13,0,cos(i+j)*0.15)
     art.branch(stem,stem+Vector3(sin(i)*0.1,0.35+j*0.09,0),0.025,0.01,Color("8c9c71"),3)
 return art.finish()

func trails() -> ArrayMesh:
 var key="watershed_trails"
 if OS.has_feature("web"): return art.cached(key)
 art.begin(key)
 for area in 3:
  var routes=[Defs.porter_route(area)]
  if area==0: routes.append([Vector2(0,13),Vector2(0,-38)])
  if area==1: routes.append([Vector2(0,-106),Vector2(6,-106),Vector2(6,-113)])
  for route in routes:
   for i in range(route.size()-1):
    var direction=(route[i+1]-route[i]).normalized()
    var side=Vector2(-direction.y,direction.x)*0.65
    var steps=ceili(route[i].distance_to(route[i+1]))
    for j in steps:
     var a=route[i].lerp(route[i+1],float(j)/steps)
     var b=route[i].lerp(route[i+1],float(j+1)/steps)
     var center=(a+b)*0.5
     if not Defs.in_area(center,area): continue
     var color=[Color("c7b58e"),Color("c6b38b"),Color("b2c0b5")][area]
     art.quad(Defs.point(a-side,0.018),Defs.point(a+side,0.018),Defs.point(b+side,0.018),Defs.point(b-side,0.018),color)
 return art.finish()
