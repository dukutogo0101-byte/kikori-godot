extends Node3D
const Sim = preload("res://scripts/simulation.gd")
const Art = preload("res://scripts/art.gd")
const Store = preload("res://scripts/save_store.gd")
var sim = Sim.new()
var art = Art.new()
var store = Store.new()
var camera: Camera3D
var tree_nodes: Array[Node3D] = []
var worker_nodes: Array[Node3D] = []
var truck_node: Node3D
var cargo_nodes: Array[MeshInstance3D] = []
var loose_nodes: Array[MeshInstance3D] = []
var stock_nodes: Array[MeshInstance3D] = []
var saw_node: MeshInstance3D
var belt_log: MeshInstance3D
var hud: Control
var money_label: Label
var status_label: Label
var mission_label: Label
var toast_label: Label
var buttons: Dictionary = {}
var boost_button: Button
var save_label: Label
var sound_button: Button
var music_player: AudioStreamPlayer
var tutorial: Control
var paused = false
var muted = true
var accumulator = 0.0
var ui_clock = 0.0
var save_clock = 0.0
var toast_clock = 0.0
var animation_clock = 0.0
var yaw = 0.0
var zoom = 24.5
var dragging = false
var touches: Dictionary = {}
var pinch_distance = 0.0
var last_gesture = Vector2.ZERO
var hidden_at = 0.0
var process_calls = 0
var last_delta = 0.0
var web_document: JavaScriptObject
var visibility_callback: JavaScriptObject
var effect_nodes: Array = []
var font: Font
var native_smoke_test = false
const ROUTE = [Vector3(-2.8, 0, 2.9), Vector3(-0.5, 0, 3.1), Vector3(2.2, 0, 3), Vector3(5, 0, 2.5), Vector3(6.7, 0, 1.6)]

func _ready() -> void:
	native_smoke_test = "--smoke-test" in OS.get_cmdline_user_args()
	font = load("res://assets/fonts/KikoriSans.otf")
	var data = {} if native_smoke_test else store.read_save()
	var restored = false
	var offline_earned = 0.0
	if not data.is_empty():
		restored = sim.restore(data)
		if restored:
			var saved_at = data.get("saved_at", Time.get_unix_time_from_system())
			if Sim.valid_number(saved_at, 0, 1e12):
				var before = sim.money
				sim.advance(clampf(Time.get_unix_time_from_system() - float(saved_at), 0, 600))
				offline_earned = sim.money - before
		else:
			store.message = "保存データを復元できませんでした。新しく開始します。"
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_update_visuals(0.0)
	_update_hud()
	if not store.message.is_empty():
		_toast(store.message, 7.0)
	elif offline_earned > 0:
		_toast("おかえりなさい！ 留守中の売上 +%s" % _amount(offline_earned), 6.0)
	elif not restored and not native_smoke_test:
		_show_tutorial()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.kikoriReady = true;", true)
		# Retain the callback and read the real document state. Avoid JS eval every frame.
		web_document = JavaScriptBridge.get_interface("document")
		visibility_callback = JavaScriptBridge.create_callback(_on_web_visibility)
		web_document.addEventListener("visibilitychange", visibility_callback)
		_on_web_visibility([])
		get_tree().create_timer(0.2).timeout.connect(_save_browser_debug)
	if native_smoke_test:
		print("KIKORI_SCENE_READY trees=%d workers=%d" % [tree_nodes.size(), worker_nodes.size()])
		get_tree().create_timer(2).timeout.connect(func(): print("AUTO_PROCESS elapsed=", sim.elapsed, " enabled=", is_processing(), " acc=", accumulator, " paused=", paused); get_tree().quit())

func _mesh(parent: Node3D, mesh: Mesh, p: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = p
	parent.add_child(instance)
	return instance

func _build_world() -> void:
	var environment_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b9dbd9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e9f0d9")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = env
	add_child(environment_node)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("fff1d2")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	_mesh(self, art.world())
	var water = PlaneMesh.new()
	water.size = Vector2(180, 180)
	var water_node = _mesh(self, water, Vector3(0, -1.36, 0))
	var water_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ vec2 p=UV*95.0; float wave=sin(p.x*1.8+p.y*1.3+TIME*0.5); float fleck=smoothstep(0.97,1.0,wave)*0.08; ALBEDO=mix(vec3(0.54,0.75,0.74),vec3(0.66,0.83,0.81),UV.y)+fleck; }"
	water_material.shader = shader
	water_node.material_override = water_material
	water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 100
	camera.current = true
	add_child(camera)
	var meshes = [art.tree(0), art.tree(1), art.tree(2)]
	art.begin()
	art.branch(Vector3(0, 0, 0), Vector3(0, 0.24, 0), 0.22, 0.19, Art.WOOD, 8)
	var stump = art.finish()
	for i in Sim.TREE_COUNT:
		var node = Node3D.new()
		add_child(node)
		node.position = Sim.TREE_SPOTS[i]
		node.rotation.y = i * 2.4
		var foliage = _mesh(node, meshes[i % 3], Vector3(0, 0.19, 0))
		foliage.name = "Crown"
		_mesh(node, stump)
		tree_nodes.append(node)
	var person_mesh = art.worker()
	var axe_mesh = art.axe()
	for i in 5:
		var person = Node3D.new()
		add_child(person)
		_mesh(person, person_mesh)
		var pivot = Node3D.new()
		pivot.name = "Arm"
		pivot.position = Vector3(0.2, 0.74, 0)
		person.add_child(pivot)
		_mesh(pivot, axe_mesh)
		worker_nodes.append(person)
	truck_node = Node3D.new()
	add_child(truck_node)
	_mesh(truck_node, art.truck())
	var log_resource = art.log_mesh()
	for i in 12:
		var log_node = _mesh(truck_node, log_resource, Vector3(-0.39 + (i % 3) * 0.39, 0.87 + (i / 3) * 0.28, -0.57))
		cargo_nodes.append(log_node)
	# Bounded visual pools: stock counts can exceed the decorative representation.
	for i in 36:
		loose_nodes.append(_mesh(self, log_resource))
	for i in 12:
		var log_node = _mesh(self, log_resource, Vector3(7.65 + (i % 3) * 0.34, 0.2 + (i / 3) * 0.26, -0.6))
		stock_nodes.append(log_node)
	saw_node = _mesh(self, art.saw(), Vector3(5, 0.95, -0.25))
	belt_log = _mesh(self, log_resource)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

func _process(delta: float) -> void:
	process_calls += 1
	last_delta = delta
	if paused:
		return
	var dt = minf(delta, 1.0)
	animation_clock += dt
	accumulator += dt
	while accumulator >= 0.1:
		accumulator -= 0.1
		for event in sim.step(0.1):
			_handle_event(event)
	_update_visuals(dt)
	ui_clock += dt
	save_clock += dt
	toast_clock = maxf(0, toast_clock - dt)
	toast_label.visible = toast_clock > 0 and not toast_label.text.is_empty()
	if ui_clock >= 0.2:
		ui_clock = 0
		_update_hud()
	if save_clock >= 5:
		_save()
		_save_browser_debug()

func _handle_event(event: Dictionary) -> void:
	match event.type:
		"chop":
			_sound(190, 0.035)
		"fell":
			_effect(Sim.TREE_SPOTS[event.tree] + Vector3(0, 0.6, 0), Color("eed2a0"), 5)
		"sale":
			_effect(Vector3(5, 1.1, 0.4), Color("ffd17b"), 2)
			_sound(680, 0.05)

func _route_position(t: float) -> Vector3:
	var scaled = clampf(t, 0, 0.9999) * (ROUTE.size() - 1)
	var segment = int(scaled)
	return ROUTE[segment].lerp(ROUTE[segment + 1], scaled - segment)

func _update_visuals(dt: float) -> void:
	for i in tree_nodes.size():
		var crown_node = tree_nodes[i].get_node("Crown") as MeshInstance3D
		var t = sim.trees[i]
		if t.hp <= 0:
			var since_fall = Sim.REGROW_SECONDS - float(t.regrow)
			if since_fall < 1.3:
				crown_node.visible = true
				var f = clampf(since_fall / 1.0, 0, 1)
				crown_node.rotation.z = -pow(f, 1.7) * 1.45
				crown_node.scale = Vector3.ONE * (1.0 - maxf(0, since_fall - 1.0) * 2.5)
			else:
				crown_node.visible = t.regrow < 7.0
				crown_node.rotation.z = 0
				crown_node.scale = Vector3.ONE * clampf(1.0 - float(t.regrow) / 7.0, 0.05, 1.0)
		else:
			crown_node.visible = true
			crown_node.scale = Vector3.ONE
			crown_node.rotation.z = sin(animation_clock * 1.2 + i) * 0.014
	for i in worker_nodes.size():
		var person = worker_nodes[i]
		person.visible = i < sim.workers.size()
		if not person.visible:
			continue
		var w = sim.workers[i]
		var start = Sim.TREE_SPOTS[w.from] + Vector3(0, 0, 0.6) if w.from >= 0 else Vector3(-3 + i * 0.2, 0, 2)
		var target = Sim.TREE_SPOTS[w.target] + Vector3(0, 0, 0.6) if w.target >= 0 else start
		if w.phase == "travel":
			person.position = start.lerp(target, clampf(float(w.clock) / float(w.travel), 0, 1))
			person.position.y += absf(sin(animation_clock * 11)) * 0.055
			if start.distance_squared_to(target) > 0.01:
				person.rotation.y = atan2(target.x - start.x, target.z - start.z)
			person.get_node("Arm").rotation.x = sin(animation_clock * 11) * 0.22
		elif w.phase == "chop":
			person.position = target
			person.rotation.y = PI
			person.get_node("Arm").rotation.x = -0.2 + sin(float(w.clock) / sim.chop_seconds() * TAU) * 0.85
		else:
			person.position = start
	var travel = clampf(sim.truck_clock / sim.trip_seconds(), 0, 1)
	var pos = ROUTE[0]
	var direction = Vector3.RIGHT
	match sim.truck_phase:
		"outbound":
			pos = _route_position(travel)
			direction = _route_position(minf(0.9999, travel + 0.015)) - _route_position(maxf(0, travel - 0.015))
		"unloading":
			pos = ROUTE[-1]
			direction = Vector3(1, 0, -1)
		"returning":
			pos = _route_position(1.0 - travel)
			direction = _route_position(maxf(0, 1.0 - travel - 0.015)) - _route_position(minf(0.9999, 1.0 - travel + 0.015))
	truck_node.position = pos
	if sim.truck_phase in ["outbound", "returning"]:
		truck_node.position.y = sin(animation_clock * 13) * 0.025
	truck_node.rotation.y = atan2(direction.x, direction.z)
	for i in cargo_nodes.size():
		cargo_nodes[i].visible = i < sim.cargo.size()
	var counts: Dictionary = {}
	for i in loose_nodes.size():
		loose_nodes[i].visible = i < sim.ground_logs.size()
		if loose_nodes[i].visible:
			var source = int(sim.ground_logs[i])
			var count = int(counts.get(source, 0))
			counts[source] = count + 1
			loose_nodes[i].position = Sim.TREE_SPOTS[source] + Vector3(0.65 + (count % 3) * 0.3, 0.19 + (count / 3) * 0.28, 0.15)
			loose_nodes[i].rotation.y = source * 0.8
	for i in stock_nodes.size():
		stock_nodes[i].visible = i < sim.mill_stock
	belt_log.visible = sim.mill_stock > 0
	if belt_log.visible:
		belt_log.position = Vector3(5, 0.84, 1.35 - clampf(sim.mill_clock / sim.process_seconds(), 0, 1) * 1.8)
		saw_node.rotation.x += dt * 14.0
	for i in range(effect_nodes.size() - 1, -1, -1):
		var effect = effect_nodes[i]
		effect.life -= dt
		effect.node.position += effect.velocity * dt
		effect.velocity.y -= dt * 3
		effect.node.scale = Vector3.ONE * maxf(0.01, effect.life)
		if effect.life <= 0:
			effect.node.queue_free()
			effect_nodes.remove_at(i)

func _effect(p: Vector3, color: Color, count: int) -> void:
	if effect_nodes.size() > 35:
		return
	var mesh = SphereMesh.new()
	mesh.radius = 0.065
	mesh.height = 0.13
	mesh.radial_segments = 5
	mesh.rings = 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	for i in count:
		var node = _mesh(self, mesh, p)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect_nodes.append({"node": node, "life": 0.7, "velocity": Vector3(cos(i * 2.4) * 0.8, 1.5, sin(i * 2.4) * 0.8)})

func _style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	return style

func _label(text: String, size: int, color: Color = Color("f1f5df")) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("163e37") if primary else Color("edf3dd"))
	button.add_theme_color_override("font_disabled_color", Color("95ad99"))
	button.add_theme_stylebox_override("normal", _style(Color("f0c77b") if primary else Color("285a4c"), 12))
	button.add_theme_stylebox_override("hover", _style(Color("ffdb98") if primary else Color("33715a"), 12))
	button.add_theme_stylebox_override("pressed", _style(Color("ddb065") if primary else Color("1b4238"), 12))
	button.add_theme_stylebox_override("disabled", _style(Color("244d40"), 12))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 12, Color("f0c77b")))
	return button

func _place(node: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	hud.theme = theme
	var top = Control.new()
	top.name = "Header"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	_place(_label("KIKORI", 30, Color("163e37")), top, Rect2(22, 16, 230, 40))
	_place(_label("小さな森から、大きな未来へ。", 11, Color("3d6d58")), top, Rect2(23, 54, 290, 20))
	sound_button = _button("音 OFF")
	sound_button.name = "Sound"
	top.add_child(sound_button)
	sound_button.pressed.connect(func(): muted = not muted; sound_button.text = "音 OFF" if muted else "音 ON"; _sound(440, 0.08))
	var coins = PanelContainer.new()
	coins.name = "Coins"
	coins.add_theme_stylebox_override("panel", _style(Color("173f36"), 18))
	top.add_child(coins)
	var row = HBoxContainer.new()
	coins.add_child(row)
	var gold_icon = _label("●", 29, Color("f0c77b"))
	row.add_child(gold_icon)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_theme_constant_override("separation", 0)
	column.add_child(_label("資金", 10, Color("a7c4ac")))
	money_label = _label("30", 26)
	money_label.name = "Money"
	column.add_child(money_label)
	var income = _label("丸太 1本\n売上 +12", 12, Color("f0c77b"))
	income.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(income)
	status_label = _label("", 11, Color("315f4c"))
	status_label.name = "Stock"
	top.add_child(status_label)
	mission_label = _label("", 12, Color("315f4c"))
	mission_label.name = "Mission"
	top.add_child(mission_label)
	var bottom = PanelContainer.new()
	bottom.name = "Bottom"
	bottom.add_theme_stylebox_override("panel", _style(Color("173f36"), 23))
	hud.add_child(bottom)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	bottom.add_child(content)
	var heading = HBoxContainer.new()
	content.add_child(heading)
	var title = _label("森の経営", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var help = _button("？")
	help.custom_minimum_size = Vector2(44, 44)
	help.pressed.connect(_show_tutorial)
	heading.add_child(help)
	boost_button = _button("応援する · 15秒間 作業速度 ×2", true)
	boost_button.name = "Boost"
	boost_button.pressed.connect(func():
		if sim.activate_boost():
			_toast("森のみんながやる気に！ 作業速度 ×2")
			_sound(520, 0.12)
			_save()
			_update_hud())
	content.add_child(boost_button)
	for kind in ["wood", "truck", "mill"]:
		var button = _button("")
		button.name = kind.capitalize() + "Upgrade"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_upgrade.bind(kind))
		content.add_child(button)
		buttons[kind] = button
	var footer = HBoxContainer.new()
	content.add_child(footer)
	save_label = _label("自動保存 · このブラウザ", 10, Color("a7c4ac"))
	save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(save_label)
	var home = _button("視点を戻す")
	home.custom_minimum_size.y = 30
	home.add_theme_font_size_override("font_size", 10)
	home.pressed.connect(func(): yaw = 0; zoom = 24.5; _update_camera())
	footer.add_child(home)
	toast_label = _label("", 13, Color("173f36"))
	toast_label.name = "Toast"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_stylebox_override("normal", _style(Color("fff0c7"), 12))
	hud.add_child(toast_label)
	toast_label.visible = false

func _resize() -> void:
	if hud == null:
		return
	# Keep touch targets at CSS-sized dimensions in either orientation, including Retina.
	var pixels = get_window().size
	var reference = Vector2i(844, 390) if pixels.x > pixels.y * 1.15 else Vector2i(390, 844)
	if get_window().content_scale_size != reference:
		get_window().content_scale_size = reference
		call_deferred("_resize")
		return
	var size = get_viewport().get_visible_rect().size
	var w = size.x
	var h = size.y
	var header = hud.get_node("Header") as Control
	header.size = Vector2(w, 186)
	sound_button.position = Vector2(w - 105, 20)
	sound_button.size = Vector2(83, 44)
	var coins = header.get_node("Coins") as Control
	coins.position = Vector2(22, 83)
	coins.size = Vector2(w - 44, 68)
	status_label.position = Vector2(24, 159)
	status_label.size = Vector2(w - 48, 20)
	mission_label.position = Vector2(24, 183)
	mission_label.size = Vector2(w - 48, 20)
	var bottom = hud.get_node("Bottom") as Control
	var bottom_height = 355.0
	if w > h * 1.15:
		bottom.position = Vector2(w - 330, 18)
		bottom.size = Vector2(312, minf(bottom_height, h - 36))
		header.size.x = w - 350
		coins.size.x = maxf(220, w - 396)
		sound_button.position.x = w - 435
		toast_label.position = Vector2(24, h - 66)
		toast_label.size = Vector2(w - 380, 52)
	else:
		bottom.position = Vector2(14, h - bottom_height - 12)
		bottom.size = Vector2(w - 28, bottom_height)
		toast_label.position = Vector2(22, h - bottom_height - 72)
		toast_label.size = Vector2(w - 44, 48)
	_update_camera()
	if tutorial != null:
		_layout_tutorial()

func _update_camera() -> void:
	var size = get_viewport().get_visible_rect().size
	var landscape = size.x > size.y * 1.15
	camera.keep_aspect = Camera3D.KEEP_HEIGHT if landscape else Camera3D.KEEP_WIDTH
	camera.size = zoom * 0.63 if landscape else zoom
	var target = Vector3(0.0, 0, -0.8)
	var offset = Vector3(17, 23, 25).rotated(Vector3.UP, yaw)
	camera.position = target + offset
	camera.look_at(target)
	# Lift the island into the available area above the bottom sheet.
	camera.v_offset = -0.8 if landscape else -3.7
	camera.h_offset = 3.4 if landscape else 0.0

func _update_hud() -> void:
	money_label.text = _amount(sim.money)
	status_label.text = "伐採待ち %d本   ·   丸太 %d本   ·   加工待ち %d本" % [_ready_trees(), sim.ground_logs.size(), sim.mill_stock]
	var goal = 10 if sim.processed < 10 else (50 if sim.processed < 50 else (150 if sim.processed < 150 else 500))
	mission_label.text = "次の目標：木材を %d本 出荷  %d / %d" % [goal, sim.processed, goal] if sim.processed < 500 else "森のマスター！ 累計 %d本 出荷" % sim.processed
	var descriptions = {"wood": "木こり  %d人 · 伐採力 UP" % sim.workers.size(), "truck": "トラック  %d本積み · 運搬力 UP" % sim.capacity(), "mill": "製材所  %.1f秒/本 · 加工速度 UP" % sim.process_seconds()}
	for kind in buttons:
		var price = sim.cost(kind)
		buttons[kind].text = "%s\nLv.%d     %s" % [descriptions[kind], sim.levels[kind] + 1, ("強化  " + _amount(price)) if price > 0 else "最大レベル"]
		buttons[kind].disabled = price == 0 or sim.money < price
		buttons[kind].tooltip_text = "売上を貯めて強化できます。" if sim.money < price else "タップして強化"
	if sim.boost_left > 0:
		boost_button.text = "応援中！ ×2  あと %d秒" % int(ceil(sim.boost_left))
	elif sim.boost_cooldown > 0:
		boost_button.text = "次の応援まで %d秒" % int(ceil(sim.boost_cooldown))
	else:
		boost_button.text = "応援する · 15秒間 作業速度 ×2"
	boost_button.disabled = sim.boost_cooldown > 0
	if not store.available:
		save_label.text = "保存不可 · このタブ内で進行"

func _ready_trees() -> int:
	var count = 0
	for t in sim.trees:
		if t.hp > 0:
			count += 1
	return count

func _amount(value: float) -> String:
	if value >= 1000000:
		return "%.2fM" % (value / 1000000)
	if value >= 10000:
		return "%.1fk" % (value / 1000)
	return str(int(value))

func _upgrade(kind: String) -> void:
	if sim.buy(kind):
		_toast({"wood": "木こりを強化しました！", "truck": "トラックを強化しました！", "mill": "製材所を強化しました！"}[kind])
		_sound(880, 0.13)
		_save()
		_update_hud()
		_save_browser_debug()

func _toast(text: String, seconds: float = 3.0) -> void:
	if text.is_empty():
		return
	toast_label.text = text
	toast_clock = seconds
	toast_label.visible = true

func _save() -> void:
	save_clock = 0
	if native_smoke_test:
		return
	var success = store.write_save(sim.snapshot())
	save_label.text = "保存済み · このブラウザ" if success else "保存不可 · このタブ内で進行"
	if not success:
		_toast(store.message, 5)

func _save_browser_debug() -> void:
	if OS.has_feature("web"):
		# Read-only diagnostics for automated real-browser smoke tests. No game mutation.
		var summary = {"money": sim.money, "processed": sim.processed, "felled": sim.felled, "levels": sim.levels, "elapsed": sim.elapsed, "fps": Engine.get_frames_per_second(), "calls": process_calls, "delta": last_delta, "paused": paused, "processing": is_processing(), "notice": toast_label.text, "save_text": save_label.text,
			"cargo": sim.cargo.size(), "ground": sim.ground_logs.size(), "mill": sim.mill_stock, "saved": store.available}
		JavaScriptBridge.eval("window.kikoriState = %s;" % JSON.stringify(summary), true)
		var size = get_viewport().get_visible_rect().size
		var positions = {"width": size.x, "height": size.y}
		for key in buttons:
			var p = buttons[key].get_global_rect().get_center()
			positions[key] = {"x": p.x, "y": p.y}
		var b = boost_button.get_global_rect().get_center()
		positions["boost"] = {"x": b.x, "y": b.y}
		if tutorial != null:
			var start = tutorial.get_node("Card").find_child("Start", true, false) as Control
			if start:
				var p = start.get_global_rect().get_center()
				positions["start"] = {"x": p.x, "y": p.y}
		JavaScriptBridge.eval("window.kikoriUi = %s;" % JSON.stringify(positions), true)

func _show_tutorial() -> void:
	if tutorial != null:
		return
	tutorial = ColorRect.new()
	tutorial.name = "Guide"
	tutorial.color = Color(0.06, 0.18, 0.15, 0.7)
	hud.add_child(tutorial)
	tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	panel.name = "Card"
	panel.add_theme_stylebox_override("panel", _style(Color("f4f0db"), 24))
	tutorial.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(_label("ようこそ、森のオーナー。", 23, Color("163e37")))
	var info = _label("木こりが木を切り、トラックが運び、\n製材所が木材にして売上を生みます。\n\n1  森を眺めながら、売上を貯める\n2  木こり・運搬・加工をバランスよく強化\n3  「応援する」で15秒間、作業速度が2倍\n\n木は24秒で再生。5秒ごとに自動保存。\n留守中の進行は最大10分です。\n\nドラッグで視点を回転、ピンチで拡大。", 14, Color("315f4c"))
	column.add_child(info)
	var start = _button("森を育てる", true)
	start.name = "Start"
	start.pressed.connect(func(): tutorial.queue_free(); tutorial = null; _save(); _save_browser_debug())
	column.add_child(start)
	_layout_tutorial()

func _layout_tutorial() -> void:
	var size = get_viewport().get_visible_rect().size
	var panel = tutorial.get_node("Card") as Control
	panel.size = Vector2(minf(406, size.x - 36), 437)
	panel.position = (size - panel.size) / 2.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_distance = 0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var points = touches.values()
			var distance = points[0].distance_to(points[1])
			if pinch_distance > 0:
				zoom = clampf(zoom * pinch_distance / maxf(distance, 1), 18.5, 31)
				_update_camera()
			pinch_distance = distance
		else:
			yaw = clampf(yaw - event.relative.x * 0.004, -0.45, 0.45)
			_update_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 18.5, 31)
			_update_camera()
	elif event is InputEventMouseMotion and dragging and touches.is_empty():
		yaw = clampf(yaw - event.relative.x * 0.004, -0.45, 0.45)
		_update_camera()

func _sound(frequency: float, duration: float) -> void:
	if muted or native_smoke_test:
		return
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var length = int(duration * 22050)
	var samples = PackedByteArray()
	samples.resize(length * 2)
	for i in length:
		var fade = pow(1.0 - float(i) / length, 2)
		var value = int(sin(TAU * frequency * i / 22050.0) * 3500 * fade)
		samples.encode_s16(i * 2, value)
	wave.data = samples
	music_player.stream = wave
	music_player.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if save_label != null:
			_save()

func _on_web_visibility(_arguments: Array) -> void:
	var hidden = bool(web_document.hidden)
	if hidden and not paused:
		_save()
		hidden_at = Time.get_unix_time_from_system()
		paused = true
	elif not hidden and paused:
		var before = sim.money
		sim.advance(clampf(Time.get_unix_time_from_system() - hidden_at, 0, 600))
		paused = false
		accumulator = 0
		if sim.money > before:
			_toast("留守中の売上 +%s" % _amount(sim.money - before))
		_save()

func _exit_tree() -> void:
	if web_document != null and visibility_callback != null:
		web_document.removeEventListener("visibilitychange", visibility_callback)
