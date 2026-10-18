extends RefCounted
## Original faceted meshes, baked vertex colors. One surface per object.
## No downloaded models, copyrighted game assets, or runtime CSG.
const GRASS = Color("94be67")
const DARK_GREEN = Color("287653")
const GREEN = Color("4c9955")
const LIGHT_GREEN = Color("7cba5b")
const WOOD = Color("945f3d")
const CUT = Color("eac98d")
const CREAM = Color("f5e6bc")
const TEAL = Color("247f83")
const ROOF = Color("d06942")
const DARK = Color("304c49")
static var baking = false
static var baked_files = {}
var mesh_key = ""
var surface: SurfaceTool
var material: StandardMaterial3D

func _init() -> void:
 material = StandardMaterial3D.new()
 material.vertex_color_use_as_albedo = true
 material.vertex_color_is_srgb = false
 material.roughness = 0.92
 material.cull_mode = BaseMaterial3D.CULL_DISABLED

func cached(key: String) -> ArrayMesh:
 return load("res://assets/baked/%s.res" % key) as ArrayMesh

func begin(key: String) -> void:
 mesh_key=key
 if OS.has_feature("web"): return
 surface = SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func finish() -> ArrayMesh:
 if OS.has_feature("web"): return cached(mesh_key)
 surface.generate_normals()
 surface.set_material(material)
 var result=surface.commit()
 if baking:
  var path="res://assets/baked/%s.res" % mesh_key
  assert(not mesh_key.is_empty())
  if not baked_files.has(mesh_key):
   var error=ResourceSaver.save(result,path)
   assert(error==OK)
   baked_files[mesh_key]=path
  else:
   assert(result.surface_get_arrays(0)==cached(mesh_key).surface_get_arrays(0),"Baked key identifies identical geometry: "+mesh_key)
 return result

func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
 if OS.has_feature("web"): return
 # Compatibility does not implement the material sRGB vertex-color flag.
 surface.set_color(color.srgb_to_linear())
 surface.add_vertex(a)
 surface.add_vertex(b)
 surface.add_vertex(c)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
 if OS.has_feature("web"): return
 tri(a, b, c, color)
 tri(a, c, d, color)

func box(p: Vector3, size: Vector3, color: Color) -> void:
 if OS.has_feature("web"): return
 var x = size.x / 2.0
 var y = size.y / 2.0
 var z = size.z / 2.0
 var a = p + Vector3(-x, -y, -z)
 var b = p + Vector3(x, -y, -z)
 var c = p + Vector3(x, -y, z)
 var d = p + Vector3(-x, -y, z)
 var e = p + Vector3(-x, y, -z)
 var f = p + Vector3(x, y, -z)
 var g = p + Vector3(x, y, z)
 var h = p + Vector3(-x, y, z)
 quad(a, b, f, e, color.darkened(0.12))
 quad(b, c, g, f, color.darkened(0.2))
 quad(c, d, h, g, color)
 quad(d, a, e, h, color.lightened(0.05))
 quad(e, f, g, h, color.lightened(0.13))
 quad(d, c, b, a, color.darkened(0.25))

func branch(a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, sides: int = 7) -> void:
 if OS.has_feature("web"): return
 var direction = (b - a).normalized()
 var tangent = direction.cross(Vector3.RIGHT if absf(direction.y) > 0.9 else Vector3.UP).normalized()
 var bitangent = direction.cross(tangent).normalized()
 for i in sides:
  var angle = TAU * i / sides
  var next = TAU * (i + 1) / sides
  var r1 = tangent * cos(angle) + bitangent * sin(angle)
  var r2 = tangent * cos(next) + bitangent * sin(next)
  quad(a + r1 * radius_a, a + r2 * radius_a, b + r2 * radius_b, b + r1 * radius_b, color.lightened(0.04 * (i % 3)))
  tri(a, a + r2 * radius_a, a + r1 * radius_a, color.darkened(0.1))
  tri(b, b + r1 * radius_b, b + r2 * radius_b, CUT if color == WOOD else color)

func crown(p: Vector3, size: Vector3, color: Color, seed_value: int = 0) -> void:
 if OS.has_feature("web"): return
 var rings = [Vector2(0.0, -0.72), Vector2(0.72, -0.43), Vector2(1.0, 0.0), Vector2(0.69, 0.57), Vector2(0.0, 0.92)]
 for j in 4:
  for i in 7:
   var a = TAU * i / 7 + j * 0.19
   var b = TAU * (i + 1) / 7 + j * 0.19
   var c = TAU * (i + 1) / 7 + (j + 1) * 0.19
   var d = TAU * i / 7 + (j + 1) * 0.19
   var r0: Vector2 = rings[j]
   var r1: Vector2 = rings[j + 1]
   var v0 = p + Vector3(cos(a) * r0.x * size.x, r0.y * size.y, sin(a) * r0.x * size.z)
   var v1 = p + Vector3(cos(b) * r0.x * size.x, r0.y * size.y, sin(b) * r0.x * size.z)
   var v2 = p + Vector3(cos(c) * r1.x * size.x, r1.y * size.y, sin(c) * r1.x * size.z)
   var v3 = p + Vector3(cos(d) * r1.x * size.x, r1.y * size.y, sin(d) * r1.x * size.z)
   quad(v0, v1, v2, v3, color.lightened(0.025 * ((i + j + seed_value) % 5)))

func log_mesh(kind: int = 0) -> ArrayMesh:
 var bark = [WOOD, Color("b5793e"), Color("d8e8ed")][kind]
 var key="log_%d" % kind
 if OS.has_feature("web"): return cached(key)
 begin(key)
 branch(Vector3(0, 0, -0.65), Vector3(0, 0, 0.65), 0.16, 0.14, bark, 8)
 branch(Vector3(0, 0, -0.655), Vector3(0, 0, -0.66), 0.125, 0.125, CUT, 8)
 branch(Vector3(0, 0, 0.655), Vector3(0, 0, 0.66), 0.11, 0.11, CUT, 8)
 for i in 3:
  branch(Vector3(0.02 * i, 0, 0.663 + i * 0.002), Vector3(0.02 * i, 0, 0.665 + i * 0.002), 0.065 - i * 0.018, 0.065 - i * 0.018, bark.lightened(0.18 * i), 8)
 return finish()

func axe() -> ArrayMesh:
 var key="axe"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 branch(Vector3(0, 0, 0), Vector3(0.03, 0.14, 0.55), 0.05, 0.045, WOOD, 6)
 box(Vector3(0.03, 0.13, 0.51), Vector3(0.04, 0.31, 0.22), Color("acc5c2"))
 box(Vector3(0, 0, 0.03), Vector3(0.12, 0.12, 0.17), Color("edb27e"))
 return finish()

func forestry_tool(tier: int) -> ArrayMesh:
 if tier==0: return axe()
 var key="forestry_tool_%d" % tier
 if OS.has_feature("web"): return cached(key)
 begin(key)
 box(Vector3.ZERO,Vector3(0.15,0.15,0.2),Color("edb27e"))
 if tier==1:
  branch(Vector3.ZERO,Vector3(0,0.06,1.2),0.055,0.045,WOOD,8)
  box(Vector3(0,0.06,1.08),Vector3(0.08,0.52,0.38),Color("8faeb9"))
  box(Vector3(0,0.3,1.13),Vector3(0.09,0.06,0.32),Color("e9f5f7"))
 else:
  branch(Vector3.ZERO,Vector3(0,0,0.9),0.06,0.04,DARK,8)
  box(Vector3(0,0,0.2),Vector3(0.3,0.24,0.45),Color("d78a37") if tier==2 else TEAL)
  box(Vector3(0,0.18,0.2),Vector3(0.2,0.08,0.28),DARK)
  if tier==3:
   box(Vector3(0,0,0.93),Vector3(1.25,0.1,0.12),DARK)
 return finish()

func saw_blade() -> ArrayMesh:
 var key="tool_saw_blade"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 branch(Vector3(0,-0.025,0),Vector3(0,0.025,0),0.4,0.4,Color("bdced5"),20)
 for i in 20:
  var a=TAU*i/20
  var b=a+0.16
  tri(Vector3(cos(a)*0.36,0.03,sin(a)*0.36),Vector3(cos(b)*0.47,0.03,sin(b)*0.47),Vector3(cos(a+0.29)*0.36,0.03,sin(a+0.29)*0.36),Color("e3edf1"))
 branch(Vector3(0,-0.04,0),Vector3(0,0.06,0),0.1,0.1,Color("bd7635"),10)
 return finish()

func cargo_frame() -> ArrayMesh:
 var key="cargo_frame"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 for x in [-0.35,0.35]:
  branch(Vector3(x,0.55,-0.31),Vector3(x,1.6,-0.31),0.035,0.035,DARK,6)
 box(Vector3(0,0.52,-0.6),Vector3(0.85,0.08,0.8),WOOD)
 return finish()


func snow_tree(kind: int) -> ArrayMesh:
 var key="tree_%d" % kind
 if OS.has_feature("web"): return cached(key)
 begin(key)
 var bark = Color("8c684e") if kind != 2 else Color("e4eceb")
 var height = 2.8 + kind * 0.25
 branch(Vector3.ZERO,Vector3(0.06,height,0),0.2+kind*0.03,0.07,bark,7)
 for i in 4:
  var a = i*1.7
  branch(Vector3(0,0.2,0),Vector3(cos(a)*0.36,0.02,sin(a)*0.36),0.08,0.025,bark,5)
 var foliage = [Color("3b857d"),Color("d79045"),Color("97beca")][kind]
 if kind < 2:
  for i in 4:
   var y = 0.65 + i*0.55
   var r = 1.03-i*0.18
   branch(Vector3(0,y,0),Vector3(0,y+0.95,0),r,0.03,foliage.lightened(i*0.04),9)
   branch(Vector3(0,y+0.42,0),Vector3(0,y+0.98,0),r*0.61,0.025,Color("effaff"),9)
   for j in 4:
    var a = j*TAU/4+i*0.7
    branch(Vector3(0,y,0),Vector3(cos(a)*r*0.92,y-0.08,sin(a)*r*0.92),0.06,0.02,bark,5)
 else:
  for i in 5:
   var a = i*1.9
   var end = Vector3(cos(a)*0.65,1.8+i*0.22,sin(a)*0.65)
   branch(Vector3(0,1.2+i*0.2,0),end,0.09,0.025,bark,5)
   crown(end,Vector3(0.7,0.55,0.68),foliage,i)
   crown(end+Vector3(0,0.19,0),Vector3(0.6,0.38,0.56),Color("f5fcff"),i)
  for i in 6:
   box(Vector3(0,0.4+i*0.27,0.19),Vector3(0.21,0.055,0.03),DARK)
 return finish()

func hero_body() -> ArrayMesh:
 var key="hero_body"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 box(Vector3(0,0.94,0),Vector3(0.5,0.55,0.34),Color("e46c48"))
 box(Vector3(0,0.69,0),Vector3(0.52,0.1,0.36),Color("244c62"))
 for x in [-0.16,0.16]:
  box(Vector3(x,0.94,0.18),Vector3(0.04,0.52,0.02),Color("fff0d1"))
 box(Vector3(0,1.13,0.19),Vector3(0.5,0.055,0.06),Color("f7d176"))
 branch(Vector3(0,1.25,0),Vector3(0,1.52,0),0.2,0.18,Color("edb27e"),8)
 box(Vector3(0,1.31,0.18),Vector3(0.32,0.13,0.08),WOOD.darkened(0.1))
 for x in [-0.08,0.08]:
  box(Vector3(x,1.45,0.18),Vector3(0.034,0.032,0.028),DARK)
 branch(Vector3(0,1.51,0),Vector3(0,1.68,0),0.24,0.15,Color("247f9c"),9)
 box(Vector3(0,1.51,0),Vector3(0.49,0.07,0.44),Color("f1c776"))
 crown(Vector3(0,1.73,0),Vector3(0.1,0.1,0.1),CREAM)
 branch(Vector3(-0.27,1.11,0),Vector3(-0.31,0.84,0.15),0.1,0.09,ROOF,6)
 crown(Vector3(-0.31,0.82,0.16),Vector3(0.1,0.12,0.1),Color("e9be81"))
 box(Vector3(0,0.89,-0.25),Vector3(0.47,0.44,0.24),Color("bd985a"))
 box(Vector3(0,0.86,-0.39),Vector3(0.41,0.08,0.05),Color("795638"))
 return finish()

func hero_leg() -> ArrayMesh:
 var key="hero_leg"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 branch(Vector3(0,0,0),Vector3(0,-0.42,0),0.115,0.11,Color("27546d"),6)
 box(Vector3(0,-0.47,0.07),Vector3(0.22,0.18,0.36),Color("334b59"))
 box(Vector3(0,-0.56,0.07),Vector3(0.23,0.05,0.36),Color("f2d5a0"))
 return finish()

func island(rect: Rect2, kind: int) -> ArrayMesh:
 var key="island_%d" % kind
 if OS.has_feature("web"): return cached(key)
 begin(key)
 var r = rect.grow(0.45)
 var points = [Vector2(r.position.x+0.6,r.position.y),Vector2(r.end.x-0.6,r.position.y),Vector2(r.end.x,r.position.y+0.6),Vector2(r.end.x,r.end.y-0.6),Vector2(r.end.x-0.6,r.end.y),Vector2(r.position.x+0.6,r.end.y),Vector2(r.position.x,r.end.y-0.6),Vector2(r.position.x,r.position.y+0.6)]
 var snow = [Color("dceaf1"),Color("dedde9"),Color("d3eaf4")][kind]
 for i in points.size():
  var p = points[i]; var q = points[(i+1)%points.size()]
  var a = Vector3(p.x,0,p.y); var b = Vector3(q.x,0,q.y)
  tri(Vector3(r.get_center().x,0,r.get_center().y),a,b,snow.darkened(0.015*(i%3)))
  quad(a,b,b+Vector3(0,-0.2,0),a+Vector3(0,-0.2,0),Color("d4e5ec"))
  quad(a+Vector3(0,-0.2,0),b+Vector3(0,-0.2,0),b+Vector3(0,-0.9,0),a+Vector3(0,-0.9,0),Color("64879a").darkened((i%3)*0.05))
 # Inset footprints/path; geometry shares a single material and draw call.
 box(Vector3(0,0.005,rect.get_center().y),Vector3(2.1,0.015,rect.size.y),Color("d4e5e8"))
 for i in 24:
  var z = rect.position.y+0.35+i*(rect.size.y-0.7)/24
  for x in [-0.2,0.2]:
   box(Vector3(x,0.021,z+x),Vector3(0.13,0.012,0.24),Color("bbcfd8"))
 for i in 10:
  var z = rect.position.y+1+i*1.6
  var x = rect.position.x+0.06 if i%2 else rect.end.x-0.06
  crown(Vector3(x,0.12,z),Vector3(0.42,0.35,0.4),Color("a9bdcb"),i)
  crown(Vector3(x,0.32,z),Vector3(0.39,0.13,0.36),snow,i)
 return finish()

func station(workshop: bool = false) -> ArrayMesh:
 var key="station_%d" % int(workshop)
 if OS.has_feature("web"): return cached(key)
 begin(key)
 var wall = Color("47798b") if workshop else Color("bb8156")
 box(Vector3(0,1,0),Vector3(3.1,2,2.1),wall)
 for i in 13:
  box(Vector3(-1.5+i*0.25,1,1.07),Vector3(0.04,1.95,0.04),wall.lightened(0.16))
 for x in [-1.5,1.5]: box(Vector3(x,1,1.1),Vector3(0.14,2.05,0.12),CUT)
 for x in [-0.95,0.95]:
  box(Vector3(x,1.1,1.1),Vector3(0.65,0.7,0.1),CUT)
  box(Vector3(x,1.1,1.17),Vector3(0.5,0.56,0.06),Color("8ebcce"))
  box(Vector3(x,1.1,1.21),Vector3(0.06,0.56,0.02),CREAM)
 box(Vector3(0,0.78,1.1),Vector3(0.65,1.55,0.12),WOOD.darkened(0.25))
 tri(Vector3(-1.65,2,1.2),Vector3(0,2.9,1.2),Vector3(1.65,2,1.2),CUT)
 quad(Vector3(-1.85,2,-1.3),Vector3(-1.85,2,1.3),Vector3(0,3,1.3),Vector3(0,3,-1.3),Color("49798e"))
 quad(Vector3(0,3,-1.3),Vector3(0,3,1.3),Vector3(1.85,2,1.3),Vector3(1.85,2,-1.3),Color("568ba0"))
 for i in 7:
  var z = -1.2+i*0.4
  branch(Vector3(-1.83,2.06,z),Vector3(0,3.06,z),0.05,0.05,Color("f0f9ff"),5)
  branch(Vector3(0,3.06,z),Vector3(1.83,2.06,z),0.05,0.05,Color("f0f9ff"),5)
 box(Vector3(0,1.95,1.32),Vector3(1.45,0.36,0.08),Color("f1c66a"))
 box(Vector3(0,0.05,1.55),Vector3(0.95,0.1,0.55),CUT)
 if workshop:
  box(Vector3(0.95,2.9,-0.55),Vector3(0.4,1.1,0.4),DARK)
  box(Vector3(0.95,3.48,-0.55),Vector3(0.5,0.1,0.5),CUT)
 return finish()

func bridge(rect: Rect2) -> ArrayMesh:
 var key="bridge_%d_%d" % [roundi(rect.position.x),roundi(rect.position.y)]
 if OS.has_feature("web"): return cached(key)
 begin(key)
 for i in 12:
  var z = rect.position.y+(i+0.5)*rect.size.y/12
  box(Vector3(rect.get_center().x,0.015,z),Vector3(rect.size.x,0.1,rect.size.y/12-0.025),CUT.darkened(0.015*(i%3)))
 for x in [rect.position.x+0.12,rect.end.x-0.12]:
  box(Vector3(x,-0.16,rect.get_center().y),Vector3(0.17,0.26,rect.size.y+0.4),WOOD)
  for i in 4:
   var z = rect.position.y+i*rect.size.y/3
   box(Vector3(x,0.52,z),Vector3(0.15,1.1,0.15),WOOD)
  box(Vector3(x,0.9,rect.get_center().y),Vector3(0.12,0.13,rect.size.y),CUT)
 return finish()

func ring(radius: float, width: float, color: Color) -> ArrayMesh:
 var key="ring_%d_%d_%s" % [roundi(radius*1000),roundi(width*1000),color.to_html()]
 if OS.has_feature("web"): return cached(key)
 begin(key)
 for i in 40:
  var a = TAU*i/40; var b = TAU*(i+1)/40
  quad(Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(b)*(radius-width),0,sin(b)*(radius-width)),Vector3(cos(a)*(radius-width),0,sin(a)*(radius-width)),color)
 return finish()


func camp() -> ArrayMesh:
 var key="camp"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 box(Vector3(0,0.07,0),Vector3(3.2,0.14,2.2),CUT)
 for x in [-1.45,1.45]:
  for z in [-0.95,0.95]: box(Vector3(x,0.9,z),Vector3(0.18,1.8,0.18),WOOD)
 box(Vector3(0,1.85,0),Vector3(3.6,0.22,2.6),Color("52866b"))
 box(Vector3(0,1.99,0),Vector3(3.6,0.06,2.6),Color("eaf8fb"))
 box(Vector3(0,1.5,1.02),Vector3(1.8,0.4,0.09),Color("72b182"))
 for x in [-1.2,-0.8,-0.4,0.0,0.4,0.8,1.2]:
  branch(Vector3(x,0.3,-0.85),Vector3(x,0.3,0.65),0.18,0.18,WOOD)
 return finish()

func cart() -> ArrayMesh:
 var key="cart"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 box(Vector3(0,0.4,-1.0),Vector3(1.1,0.12,1.65),CUT)
 for x in [-0.54,0.54]:
  box(Vector3(x,0.65,-1.0),Vector3(0.08,0.5,1.65),WOOD)
  for z in [-0.5,-1.5]: branch(Vector3(x-0.08,0.25,z),Vector3(x+0.08,0.25,z),0.23,0.23,DARK,10)
 for x in [-0.3,0.3]: box(Vector3(x,0.4,0.0),Vector3(0.07,0.07,0.65),WOOD)
 return finish()

func sawmill() -> ArrayMesh:
 var key="sawmill"
 if OS.has_feature("web"): return cached(key)
 begin(key)
 box(Vector3(0,0.5,0),Vector3(0.9,1,1.8),TEAL)
 box(Vector3(0,1.1,0),Vector3(1.2,0.1,2),CUT)
 branch(Vector3(-0.045,1.35,0),Vector3(0.045,1.35,0),0.42,0.42,Color("b7cbd2"),16)
 for i in 16:
  var angle=TAU*i/16
  box(Vector3(0,1.35+sin(angle)*0.44,cos(angle)*0.44),Vector3(0.12,0.08,0.08),DARK)
 return finish()

func goods(kind: int, stage: int) -> Mesh:
 if stage==0: return log_mesh(kind)
 begin("goods_%d_%d" % [kind,stage])
 var color=[Color("b58053"),Color("bd8344"),Color("dfd8c4")][kind]
 if stage==1:
  for y in [0.0,0.13]:
   for x in [-0.13,0.13]: box(Vector3(x,y,0),Vector3(0.24,0.11,0.95),color.lightened(y))
 else:
  box(Vector3(0,0.1,0),Vector3(0.52,0.44,0.78),color)
  for z in [-0.25,0.25]: box(Vector3(0,0.1,z),Vector3(0.55,0.47,0.05),Color("607a7b"))
 return finish()

func facility(kind: String) -> Mesh:
 begin("facility_"+kind)
 box(Vector3(0,0.1,0),Vector3(3.2,0.2,2.2),Color("8dada4"))
 if kind=="storage":
  for x in [-1.4,1.4]:
   for z in [-0.9,0.9]: box(Vector3(x,0.9,z),Vector3(0.16,1.6,0.16),WOOD)
  box(Vector3(0,1.8,0),Vector3(3.4,0.18,2.4),Color("4b8b70"))
  for x in [-0.9,-0.3,0.3,0.9]: box(Vector3(x,0.3,0),Vector3(0.5,0.2,1.5),WOOD)
 elif kind=="processor":
  box(Vector3(0,0.55,0),Vector3(2.8,0.8,1.6),Color("527f90"))
  box(Vector3(0,1.02,0),Vector3(2.9,0.14,1.7),Color("c9d9d3"))
  for z in [-0.5,0,0.5]: box(Vector3(0,1.15,z),Vector3(2.2,0.15,0.2),CUT)
  box(Vector3(-0.7,1.5,0),Vector3(0.18,0.9,1.0),Color("94b6b9"))
  box(Vector3(-1.2,1.8,-0.7),Vector3(0.25,0.25,0.25),Color("edbe65"))
 else:
  box(Vector3(0,0.95,0),Vector3(2.9,1.7,1.9),Color("bb996c"))
  box(Vector3(0,1.85,0),Vector3(3.2,0.24,2.2),Color("547785"))
  box(Vector3(1.05,2.3,-0.55),Vector3(0.4,1.1,0.45),Color("657c81"))
  for x in [-0.9,0.1,0.9]: box(Vector3(x,1.05,0.98),Vector3(0.55,0.6,0.06),Color("b9dce1"))
  box(Vector3(-0.2,0.6,1.03),Vector3(0.65,1.0,0.08),WOOD)
 return finish()
