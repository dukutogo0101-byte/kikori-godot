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
var surface: SurfaceTool
var material: StandardMaterial3D

func _init() -> void:
 material = StandardMaterial3D.new()
 material.vertex_color_use_as_albedo = true
 material.vertex_color_is_srgb = true
 material.roughness = 0.92
 material.cull_mode = BaseMaterial3D.CULL_DISABLED

func begin() -> void:
 surface = SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func finish() -> ArrayMesh:
 surface.generate_normals()
 surface.set_material(material)
 return surface.commit()

func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
 surface.set_color(color)
 surface.add_vertex(a)
 surface.add_vertex(b)
 surface.add_vertex(c)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
 tri(a, b, c, color)
 tri(a, c, d, color)

func box(p: Vector3, size: Vector3, color: Color) -> void:
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

func tree(variant: int = 0) -> ArrayMesh:
 begin()
 branch(Vector3.ZERO, Vector3(0.06, 2.1, 0), 0.19, 0.1, WOOD)
 for i in 4:
  var angle = i * 1.7 + variant
  var end = Vector3(cos(angle) * 0.75, 1.9 + i * 0.16, sin(angle) * 0.65)
  branch(Vector3(0, 1.3, 0), end, 0.09, 0.035, WOOD, 5)
  crown(end + Vector3(0, 0.25, 0), Vector3(0.85, 0.65, 0.78), GREEN if i % 2 else DARK_GREEN, i)
 crown(Vector3(0.04, 2.75, 0), Vector3(0.83, 0.85, 0.8), LIGHT_GREEN if variant % 3 == 0 else GREEN)
 for i in 4:
  var angle = i * PI / 2
  branch(Vector3(cos(angle) * 0.4, 0.04, sin(angle) * 0.4), Vector3(0, 0.26, 0), 0.045, 0.1, WOOD, 5)
 return finish()

func log_mesh(kind: int = 0) -> ArrayMesh:
 var bark = [WOOD, Color("b5793e"), Color("d8e8ed")][kind]
 begin()
 branch(Vector3(0, 0, -0.65), Vector3(0, 0, 0.65), 0.16, 0.14, bark, 8)
 branch(Vector3(0, 0, -0.655), Vector3(0, 0, -0.66), 0.125, 0.125, CUT, 8)
 branch(Vector3(0, 0, 0.655), Vector3(0, 0, 0.66), 0.11, 0.11, CUT, 8)
 for i in 3:
  branch(Vector3(0.02 * i, 0, 0.663 + i * 0.002), Vector3(0.02 * i, 0, 0.665 + i * 0.002), 0.065 - i * 0.018, 0.065 - i * 0.018, bark.lightened(0.18 * i), 8)
 return finish()

func worker() -> ArrayMesh:
 begin()
 box(Vector3(0, 0.61, 0), Vector3(0.36, 0.38, 0.24), ROOF)
 # Plaid shirt, belt, boots, face, beard, brimmed safety helmet.
 for x in [-0.1, 0.1]:
  box(Vector3(x, 0.61, 0.128), Vector3(0.035, 0.36, 0.01), CREAM.darkened(0.15))
 box(Vector3(0, 0.56, 0.13), Vector3(0.35, 0.028, 0.01), DARK)
 box(Vector3(0, 0.43, 0), Vector3(0.37, 0.075, 0.25), DARK)
 for x in [-0.1, 0.1]:
  branch(Vector3(x, 0.12, 0), Vector3(x, 0.44, 0), 0.085, 0.09, TEAL, 6)
  box(Vector3(x, 0.085, 0.04), Vector3(0.17, 0.12, 0.29), DARK)
 branch(Vector3(0, 0.83, 0), Vector3(0, 1.08, 0), 0.15, 0.13, Color("edb27e"), 8)
 box(Vector3(0, 0.86, 0.12), Vector3(0.24, 0.1, 0.065), WOOD)
 for x in [-0.06, 0.06]:
  box(Vector3(x, 0.98, 0.135), Vector3(0.025, 0.025, 0.018), DARK)
 branch(Vector3(0, 1.07, 0), Vector3(0, 1.17, 0), 0.2, 0.13, Color("f2ba48"), 8)
 box(Vector3(0, 1.07, 0.025), Vector3(0.44, 0.035, 0.36), Color("f2ba48"))
 branch(Vector3(-0.18, 0.75, 0), Vector3(-0.23, 0.52, 0.14), 0.075, 0.06, ROOF, 6)
 return finish()

func axe() -> ArrayMesh:
 begin()
 branch(Vector3(0, 0, 0), Vector3(0.03, 0.14, 0.55), 0.05, 0.045, WOOD, 6)
 box(Vector3(0.03, 0.13, 0.51), Vector3(0.04, 0.31, 0.22), Color("acc5c2"))
 box(Vector3(0, 0, 0.03), Vector3(0.12, 0.12, 0.17), Color("edb27e"))
 return finish()


func snow_tree(kind: int) -> ArrayMesh:
 begin()
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
 begin()
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
 begin()
 branch(Vector3(0,0,0),Vector3(0,-0.42,0),0.115,0.11,Color("27546d"),6)
 box(Vector3(0,-0.47,0.07),Vector3(0.22,0.18,0.36),Color("334b59"))
 box(Vector3(0,-0.56,0.07),Vector3(0.23,0.05,0.36),Color("f2d5a0"))
 return finish()

func island(rect: Rect2, kind: int) -> ArrayMesh:
 begin()
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
 begin()
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
 begin()
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
 begin()
 for i in 40:
  var a = TAU*i/40; var b = TAU*(i+1)/40
  quad(Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),Vector3(cos(b)*(radius-width),0,sin(b)*(radius-width)),Vector3(cos(a)*(radius-width),0,sin(a)*(radius-width)),color)
 return finish()
