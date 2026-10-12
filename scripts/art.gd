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

func log_mesh() -> ArrayMesh:
	begin()
	branch(Vector3(0, 0, -0.65), Vector3(0, 0, 0.65), 0.16, 0.14, WOOD, 8)
	branch(Vector3(0, 0, -0.655), Vector3(0, 0, -0.66), 0.125, 0.125, CUT, 8)
	branch(Vector3(0, 0, 0.655), Vector3(0, 0, 0.66), 0.11, 0.11, CUT, 8)
	for i in 3:
		branch(Vector3(0.02 * i, 0, 0.663 + i * 0.002), Vector3(0.02 * i, 0, 0.665 + i * 0.002), 0.065 - i * 0.018, 0.065 - i * 0.018, WOOD.lightened(0.18 * i), 8)
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

func truck() -> ArrayMesh:
	begin()
	box(Vector3(0, 0.42, 0), Vector3(1.15, 0.15, 2.55), DARK)
	box(Vector3(0, 0.87, 0.75), Vector3(1.13, 0.78, 0.9), TEAL)
	box(Vector3(0, 1.3, 0.7), Vector3(1.23, 0.12, 1.0), TEAL.lightened(0.2))
	box(Vector3(0, 0.64, 1.28), Vector3(1.1, 0.36, 0.35), TEAL)
	box(Vector3(0, 1.03, 1.211), Vector3(0.89, 0.35, 0.022), Color("b8e6dd"))
	box(Vector3(0, 1.03, 1.23), Vector3(0.055, 0.35, 0.01), TEAL)
	for x in [-0.572, 0.572]:
		box(Vector3(x, 1.02, 0.75), Vector3(0.025, 0.34, 0.6), Color("b8e6dd"))
		box(Vector3(x, 0.7, 0.72), Vector3(0.045, 0.035, 0.13), CREAM)
	for x in [-0.39, 0.39]:
		box(Vector3(x, 0.66, 1.465), Vector3(0.2, 0.11, 0.03), Color("ffefbd"))
	box(Vector3(0, 0.49, 1.47), Vector3(1.25, 0.1, 0.08), CREAM)
	box(Vector3(0, 0.64, -0.55), Vector3(1.15, 0.13, 1.63), WOOD.lightened(0.25))
	for x in [-0.6, 0.6]:
		for z in [-1.2, -0.55, 0.1]:
			box(Vector3(x, 0.94, z), Vector3(0.065, 0.65, 0.065), WOOD)
		for z in [-0.86, 0.84]:
			branch(Vector3(x - 0.09, 0.33, z), Vector3(x + 0.09, 0.33, z), 0.3, 0.3, DARK, 10)
			branch(Vector3(x + signf(x) * 0.1, 0.33, z), Vector3(x + signf(x) * 0.115, 0.33, z), 0.13, 0.13, CREAM, 8)
	return finish()

func world() -> ArrayMesh:
	begin()
	# Hand-shaped island shoreline with a faceted, layered earthen edge.
	var border = [Vector2(-10, -5), Vector2(-8.5, -8), Vector2(-2, -8.5), Vector2(5, -7), Vector2(9.5, -4.5), Vector2(11, 1), Vector2(8, 5.6), Vector2(2.5, 7), Vector2(-4, 6), Vector2(-9.8, 2.6)]
	for i in border.size():
		var p: Vector2 = border[i]
		var q: Vector2 = border[(i + 1) % border.size()]
		var a = Vector3(p.x, -0.02, p.y)
		var b = Vector3(q.x, -0.02, q.y)
		tri(Vector3(0, -0.02, -1), a, b, GRASS.lightened(0.012 * (i % 3)))
		quad(a, Vector3(p.x * 0.99, -0.24, p.y * 0.99), Vector3(q.x * 0.99, -0.24, q.y * 0.99), b, Color("71834a"))
		quad(Vector3(p.x * 0.99, -0.24, p.y * 0.99), Vector3(p.x * 0.96, -1.05, p.y * 0.96), Vector3(q.x * 0.96, -1.05, q.y * 0.96), Vector3(q.x * 0.99, -0.24, q.y * 0.99), Color("be9872").darkened(0.02 * (i % 3)))
		quad(Vector3(p.x * 0.96, -1.05, p.y * 0.96), Vector3(p.x * 0.94, -1.3, p.y * 0.94), Vector3(q.x * 0.94, -1.3, q.y * 0.94), Vector3(q.x * 0.96, -1.05, q.y * 0.96), Color("d6b887"))
	# Curved dirt road, laid out to match the truck's route.
	var road = [Vector3(-3.0, 0.015, 2.9), Vector3(-0.5, 0.015, 3.1), Vector3(2.2, 0.015, 3.0), Vector3(5, 0.015, 2.5), Vector3(6.7, 0.015, 1.6)]
	for i in road.size() - 1:
		var side = (road[i + 1] - road[i]).normalized().cross(Vector3.UP) * 0.92
		quad(road[i] - side, road[i] + side, road[i + 1] + side, road[i + 1] - side, Color("d4bb84"))
	for i in 35:
		var p = Vector3(-8.7 + fmod(i * 3.74, 18.3), 0.025, -6.8 + fmod(i * 5.37, 11.4))
		if p.z > 1.6 and p.z < 4.3:
			continue
		for j in 3:
			var d = Vector3(cos(j * 2.1), 0, sin(j * 2.1)) * 0.07
			tri(p - d, p + Vector3(0.02, 0.2 + j * 0.04, 0), p + d, DARK_GREEN.lightened(j * 0.08))
	# Rocks: irregular faceted silhouettes, plus flowers and shrubs at the shoreline.
	for i in 15:
		var p = Vector3(-9 + fmod(i * 4.7, 18), 0.1, -6.7 + fmod(i * 7.3, 12))
		if p.x > -1 and p.x < 8 and p.z > -3 and p.z < 4:
			continue
		crown(p, Vector3(0.32, 0.27, 0.38), Color("9fa89d"), i)
		crown(p + Vector3(0.44, 0.09, -0.28), Vector3(0.36, 0.29, 0.3), GREEN, i)
		for j in 3:
			var f = p + Vector3(0.45 + j * 0.15, 0.08, 0.4)
			branch(f, f + Vector3(0, 0.19, 0), 0.018, 0.015, GREEN, 4)
			crown(f + Vector3(0, 0.2, 0), Vector3(0.07, 0.05, 0.07), Color("ffe0a2"))
	# Wooden fence with posts and rails.
	for i in 10:
		var p = Vector3(-1.5 + i * 0.92, 0.5, -5.5)
		box(p, Vector3(0.12, 1.0, 0.12), WOOD.lightened(0.16))
		if i < 9:
			for y in [0.32, 0.7]:
				box(Vector3(p.x + 0.45, y, p.z), Vector3(0.9, 0.1, 0.09), CUT)
	# Mill: planked walls, framed windows, gabled roof, visible conveyor.
	box(Vector3(5, 0.13, -1.75), Vector3(4.8, 0.26, 3.6), Color("8e9a87"))
	box(Vector3(5, 1.19, -2), Vector3(4.0, 2.1, 2.6), CREAM)
	for i in 17:
		box(Vector3(3.05 + i * 0.24, 1.18, -0.688), Vector3(0.025, 2.03, 0.035), CUT.darkened(0.13))
	for x in [3.04, 6.96]:
		box(Vector3(x, 1.19, -0.66), Vector3(0.14, 2.18, 0.13), WOOD)
	for x in [3.7, 6.3]:
		box(Vector3(x, 1.4, -0.655), Vector3(0.73, 0.77, 0.08), WOOD)
		box(Vector3(x, 1.4, -0.59), Vector3(0.59, 0.63, 0.07), Color("629992"))
		box(Vector3(x, 1.4, -0.54), Vector3(0.065, 0.63, 0.04), CREAM)
		box(Vector3(x, 1.4, -0.54), Vector3(0.59, 0.065, 0.04), CREAM)
	box(Vector3(5, 0.98, -0.62), Vector3(1.14, 1.62, 0.1), DARK)
	box(Vector3(5, 1.84, -0.51), Vector3(1.6, 0.3, 0.1), WOOD)
	# Gable end triangles and two roof pitches, with raised metal seams.
	tri(Vector3(2.76, 2.25, -0.46), Vector3(5, 3.42, -0.46), Vector3(7.24, 2.25, -0.46), WOOD)
	quad(Vector3(2.65, 2.2, -3.55), Vector3(2.65, 2.2, -0.35), Vector3(5, 3.5, -0.35), Vector3(5, 3.5, -3.55), ROOF.lightened(0.13))
	quad(Vector3(5, 3.5, -3.55), Vector3(5, 3.5, -0.35), Vector3(7.35, 2.2, -0.35), Vector3(7.35, 2.2, -3.55), ROOF)
	for i in 9:
		var z = -3.5 + i * 0.39
		branch(Vector3(2.65, 2.21, z), Vector3(5, 3.51, z), 0.025, 0.025, ROOF.lightened(0.25), 4)
		branch(Vector3(5, 3.51, z), Vector3(7.35, 2.21, z), 0.025, 0.025, ROOF.darkened(0.1), 4)
	box(Vector3(6.22, 2.87, -2.75), Vector3(0.42, 1.1, 0.42), DARK)
	box(Vector3(6.22, 3.46, -2.75), Vector3(0.57, 0.14, 0.57), DARK.lightened(0.18))
	# Conveyor: supports, rollers, rubber belt and safety railing.
	box(Vector3(5, 0.62, 0.6), Vector3(0.98, 0.12, 2.85), DARK)
	for z in [-0.25, 0.6, 1.45]:
		for x in [4.58, 5.42]:
			box(Vector3(x, 0.32, z), Vector3(0.09, 0.62, 0.09), TEAL)
	for z in range(12):
		branch(Vector3(4.49, 0.68, -0.68 + z * 0.23), Vector3(5.51, 0.68, -0.68 + z * 0.23), 0.055, 0.055, Color("91aaa1"), 6)
	# Outgoing lumber pallet and stacked, individually edged boards.
	for z in [-3.7, -3.0]:
		box(Vector3(2.1, 0.13, z), Vector3(1.5, 0.12, 0.13), WOOD)
	for row in 5:
		for column in 4:
			box(Vector3(1.62 + column * 0.32, 0.23 + row * 0.12, -3.35), Vector3(0.28, 0.09, 1.65), CUT.lightened(0.035 * column))
	# Forest staging bay, timber racks and a small striped awning.
	box(Vector3(-2.8, 0.025, 1.55), Vector3(2.2, 0.06, 1.55), Color("b4a17a"))
	for x in [-3.85, -1.75]:
		for z in [0.85, 2.25]:
			box(Vector3(x, 0.5, z), Vector3(0.1, 1, 0.1), WOOD)
	for i in 5:
		box(Vector3(-2.1 + i * 0.34, 1.84, 3.95), Vector3(0.32, 0.06, 1.0), CREAM if i % 2 else TEAL)
	for x in [-2.25, -0.45]:
		box(Vector3(x, 0.9, 3.62), Vector3(0.08, 1.8, 0.08), WOOD)
	box(Vector3(-1.3, 0.65, 3.92), Vector3(1.8, 0.15, 0.66), CUT)
	return finish()

func saw() -> ArrayMesh:
	begin()
	for i in 24:
		var a = TAU * i / 24
		var b = TAU * (i + 1) / 24
		var mid = (a + b) * 0.5
		tri(Vector3.ZERO, Vector3(0, cos(a) * 0.4, sin(a) * 0.4), Vector3(0, cos(b) * 0.4, sin(b) * 0.4), Color("acc5c2"))
		tri(Vector3(0, cos(a) * 0.4, sin(a) * 0.4), Vector3(0, cos(mid) * 0.49, sin(mid) * 0.49), Vector3(0, cos(b) * 0.4, sin(b) * 0.4), CREAM)
	branch(Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), 0.09, 0.09, DARK, 8)
	return finish()
