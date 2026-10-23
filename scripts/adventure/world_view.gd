extends Node3D
const Defs = preload("res://scripts/adventure/definitions.gd")
const Art = preload("res://scripts/art.gd")
var game
var planning=false
var show_routes=false
var planning_focus=Vector3.ZERO
var road_preview: Array = []
var road_preview_remove=false
var facility_preview={}
var logistics_view
var art = Art.new()
var hero: Node3D
var walker: Node3D
var player_vehicles: Array = []
var player_wheels: Array = []
var body: MeshInstance3D
var legs: Array = []
var axe: Node3D
var tools: Array = []
var saw_blades: Array = []
var cut_ring: MeshInstance3D
var collect_ring: MeshInstance3D
var extra_target_rings: MultiMeshInstance3D
var camera: Camera3D
var trees: Array = []
var bridges: Array = []
var workshop: Node3D
var market: MeshInstance3D
var markets: Array = []
var camps: Array = []
var workers: Array = []
var carriers: Array = []
var ground_batches: Array = []
var cargo_batches: Array = []
var labels: Array = []
var effects: Array = []
var chips: Array = []
var target_ring: MeshInstance3D
var target_label: Label3D
var load_label: Label3D
var sale_label: Label3D
var font: Font
var clock = 0.0
var pending = {}
var shake: Array = []
var pale_material: StandardMaterial3D
var hero_material: StandardMaterial3D
var last_projects = {}
var completion_clock = 0.0
var completion_id = ""
var axe_impact = 0.0
var camera_anchor = Vector3.ZERO
var workshop_sign: Label3D

func mesh(parent: Node3D, shape: Mesh, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
 var node = MeshInstance3D.new()
 node.mesh = shape
 node.position = at
 parent.add_child(node)
 return node

func label(parent: Node3D, text: String, at: Vector3, color: Color = Color("243f55"), size: int = 40) -> Label3D:
 var node = Label3D.new()
 node.text = text
 node.font = font
 node.font_size = size
 node.pixel_size = 0.008
 node.position = at
 node.modulate = color
 node.outline_modulate = Color("f6fbff")
 node.outline_size = 6
 node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 node.no_depth_test = true
 parent.add_child(node)
 return node

func batch(parent: Node3D, shape: Mesh, count: int) -> MultiMeshInstance3D:
 var node = MultiMeshInstance3D.new()
 node.multimesh = MultiMesh.new()
 node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 node.multimesh.mesh = shape
 node.multimesh.instance_count = count
 node.multimesh.visible_instance_count = 0
 parent.add_child(node)
 return node

func setup(state, ui_font: Font) -> void:
 game = state
 font = ui_font
 var environment = WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("b9dbea")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("e4f4ff")
 environment.environment.ambient_light_energy = 0.45
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 sun.light_energy = 0.5
 sun.shadow_opacity = 0.45
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 45
 add_child(sun)
 var terrain=preload("res://scripts/adventure/terrain.gd").new()
 mesh(self,terrain.water())
 for i in 3: mesh(self,terrain.land(i))
 mesh(self,terrain.scenery())
 mesh(self,terrain.trails())
 for rock in Defs.ROCKS: mesh(self,terrain.rock(),Defs.point(Vector2(rock.x,rock.z)))
 market = mesh(self,art.station(),Vector3(4.2,0,6.3))
 markets.append(market)
 for i in range(1,Defs.MARKETS.size()):
  var sale=Defs.MARKETS[i]
  var p=sale.position
  var station=mesh(self,art.station(),Defs.point(p+Vector2(0,-2.7)))
  markets.append(station)
  label(self,sale.name,Vector3(p.x,0.7,p.y),Color("61471e"),43)
  mesh(self,art.ring(1.23,0.14,Color("e7b651")),Vector3(p.x,0.03,p.y))
 for i in [1,2]:
  label(self,"琥珀の丘陵 · 良質材 48 / 本" if i==1 else "白樺の高原 · 良質材 150 / 本",Vector3(0,0.7,Defs.AREAS[i].end.y-1.1),Color("6b502e") if i==1 else Color("2e6c8b"),43)
 sale_label = label(self,"中央基地 · ここで出荷・入金",Vector3(4,0.7,9),Color("61471e"),43)
 mesh(self,art.ring(1.23,0.14,Color("e7b651")),Vector3(4,0.03,9))
 art.begin("sale_stack")
 for i in 4:
  art.box(Vector3(3.25+i*0.48,0.2,10.4),Vector3(0.42,0.34,0.72),CUT_COLOR())
 mesh(self,art.finish())
 for project in game.active_projects():
  var p = project.position
  mesh(self,art.ring(1.1,0.12,Color("54a7bd")),Vector3(p.x,0.045,p.y))
  labels.append(label(self,"",Vector3(p.x,0.74,p.y),Color("256379"),42))
 for rect in Defs.BRIDGES:
  var bridge_node = mesh(self,art.bridge(rect))
  bridges.append(bridge_node)
  # Unbuilt bridge has two visible bank posts but no walkable deck.
  art.begin("bridge_posts_%d_%d" % [roundi(rect.position.x),roundi(rect.position.y)])
  for x in [rect.position.x+0.1,rect.end.x-0.1]:
   art.box(Vector3(x,0.35,rect.end.y+0.1),Vector3(0.2,0.7,0.2),Color("976b49"))
   art.box(Vector3(x,0.72,rect.end.y+0.1),Vector3(0.27,0.1,0.27),Color("e8f4fa"))
  mesh(self,art.finish())
 var shapes = [art.snow_tree(0),art.snow_tree(1),art.snow_tree(2)]
 pale_material = art.material.duplicate()
 pale_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 pale_material.albedo_color.a = 0.25
 pale_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
 for i in game.trees.size():
  var t = game.trees[i]
  var root = Node3D.new()
  root.position = Defs.point(t.position)
  add_child(root)
  var tree = mesh(root,shapes[t.kind])
  tree.rotation.y = i*1.37
  art.begin("stump")
  art.branch(Vector3.ZERO,Vector3(0,0.18,0),0.22,0.2,Art.WOOD,7)
  var stump = mesh(self,art.finish(),root.position)
  trees.append({"root":root,"mesh":tree,"stump":stump})
  shake.append(0.0)
 hero = Node3D.new()
 add_child(hero)
 hero.position = Defs.point(game.position)
 walker=Node3D.new()
 hero.add_child(walker)
 body = mesh(walker,art.hero_body())
 for x in [-0.14,0.14]:
  var leg = mesh(walker,art.hero_leg(),Vector3(x,0.6,0))
  legs.append(leg)
 axe = Node3D.new()
 axe.position = Vector3(0.3,1.04,0.05)
 hero.add_child(axe)
 for tier in 4:
  var tool=Node3D.new()
  axe.add_child(tool)
  mesh(tool,art.forestry_tool(tier)).scale=Vector3.ONE*1.12
  if tier>=2:
   for x in ([0.0] if tier==2 else [-0.63,0.63]):
    var blade=mesh(tool,art.saw_blade(),Vector3(x,0,1.05))
    saw_blades.append(blade)
  tools.append(tool)
 mesh(walker,art.cargo_frame())
 var wheel_shape=art.player_wheel()
 for vehicle_tier in [1,2]:
  var vehicle=Node3D.new()
  hero.add_child(vehicle)
  mesh(vehicle,art.player_vehicle(vehicle_tier))
  player_vehicles.append(vehicle)
  for x in ([-0.79,0.79] if vehicle_tier==2 else [-0.6,0.6]):
   for z in ([-1.18,1.03] if vehicle_tier==2 else [-0.88,0.73]):
    var wheel=mesh(vehicle,wheel_shape,Vector3(x,0.3,z))
    player_wheels.append(wheel)
 mesh(hero,art.ring(0.5,0.08,Color("f1bc55")),Vector3(0,0.025,0))
 load_label = label(hero,"",Vector3(0,2.45,0),Color("234d67"),37)
 for kind in 3: ground_batches.append(batch(self,art.log_mesh(kind),Defs.MAX_GROUND))
 for stage in 3:
  for kind in 3: cargo_batches.append(batch(hero,art.goods(kind,stage),Defs.CARGO_VISUAL_LIMIT))
 cut_ring=mesh(self,art.ring(1.0,0.018,Color("e1aa43")))
 collect_ring=mesh(self,art.ring(1.0,0.014,Color("5fae9e")))
 extra_target_rings=batch(self,art.ring(0.58,0.055,Color("e3ad48")),game.trees.size())
 target_ring = mesh(self,art.ring(0.61,0.09,Color("f4b952")))
 target_label = label(self,"",Vector3.ZERO,Color("51411e"),40)
 # Fixed pools: their object count doesn't depend on session length.
 for i in 24:
  var node = mesh(self,art.log_mesh())
  node.visible = false
  var text = label(self,"",Vector3.ZERO,Color("c57c17"),37)
  text.visible = false
  effects.append({"node":node,"label":text,"age":-1.0,"from":Vector3.ZERO,"to":Vector3.ZERO,"type":"","id":-1})
 art.begin("chip")
 art.box(Vector3.ZERO,Vector3(0.12,0.07,0.07),Art.CUT)
 var chip_shape = art.finish()
 for i in 24:
  var node = mesh(self,chip_shape)
  node.visible = false
  chips.append({"node":node,"age":-1.0,"position":Vector3.ZERO,"velocity":Vector3.ZERO})
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 28.0
 camera.far = 160
 add_child(camera)
 camera.position = hero.position+Vector3(0,18,16)
 camera.look_at(hero.position+Vector3(0,0.6,0))
 logistics_view=preload("res://scripts/adventure/logistics_view.gd").new()
 add_child(logistics_view)
 logistics_view.setup(game,self)
 last_projects = game.projects.duplicate()
 update(0)

func CUT_COLOR() -> Color:
 return Art.CUT

func cargo_position(index: int) -> Vector3:
 # Eight small logs per layer, sixteen layers: a bounded bundle of 128 logs.
 var slot=clampi(index,0,Defs.CARGO_VISUAL_LIMIT-1)
 if game.vehicle_tier>0:
  var wide=game.vehicle_tier==2
  return Vector3((-0.48 if wide else -0.39)+(slot%4)*(0.32 if wide else 0.26),0.8+floori(float(slot)/32)*0.17,(-0.12 if wide else -0.13)-floori(float(slot%32)/4)*(0.21 if wide else 0.15))
 return Vector3(-0.27+(slot%2)*0.54,0.64+floori(float(slot)/8)*0.13,-0.43-(floori(float(slot%8)/2))*0.14)

func handle(event: Dictionary) -> void:
 if event.type in ["hit","auto_hit"]:
  if event.type=="hit": axe_impact = 0.11
  shake[event.tree] = 0.2
  burst(Defs.point(event.position,0.9),4)
 elif event.type == "fell":
  burst(Defs.point(event.position,0.7),9)
 elif event.type == "auto_sell":
  burst(Vector3(event.to.x,0.5,event.to.y),2)
 elif event.type in ["pickup","sell","deposit"]:
  for effect in effects:
   if effect.age < 0:
    effect.age = 0.0
    effect.type = event.type
    effect.id = event.get("id",-1)
    effect.node.mesh = cargo_batches[event.kind].multimesh.mesh
    effect.from = Defs.point(event.from,0.2) if event.type == "pickup" else hero.to_global(cargo_position(game.bag.size()))
    effect.to = Defs.point(event.to,0.4) if event.has("to") else hero.global_position
    effect.node.visible = true
    effect.node.scale = Vector3.ONE*0.4
    effect.node.rotation = Vector3(0,PI/2,0)
    effect.label.text = "+%d" % event.amount if event.type == "sell" else ""
    effect.label.visible = event.type == "sell"
    if event.type == "pickup": pending[effect.id] = true
    break
 elif event.type == "complete":
  completion_clock = 0.7
  completion_id = event.id
  burst(Defs.point(event.position,1),18)

func burst(at: Vector3, amount: int) -> void:
 var emitted = 0
 for chip in chips:
  if chip.age < 0:
   chip.age = 0.0
   chip.position = at
   var angle = emitted*2.4+clock
   chip.velocity = Vector3(cos(angle)*2.2,2.5+(emitted%3)*0.3,sin(angle)*2.2)
   chip.node.visible = true
   emitted += 1
   if emitted >= amount: break

func update(delta: float) -> void:
 clock += delta
 completion_clock = maxf(0,completion_clock-delta)
 axe_impact = maxf(0,axe_impact-delta)
 var desired = Defs.point(game.position)
 hero.position = hero.position.lerp(desired,1-exp(-35*delta)) if delta>0 else desired
 var angle = atan2(game.facing.x,game.facing.y)
 hero.rotation.y = lerp_angle(hero.rotation.y,angle,1-exp(-20*delta))
 walker.visible=game.vehicle_tier==0
 for i in player_vehicles.size(): player_vehicles[i].visible=game.vehicle_tier==i+1
 for wheel in player_wheels: wheel.rotation.x+=game.velocity.length()*delta/0.3
 axe.position=Vector3(0.3,1.04,0.05) if game.vehicle_tier==0 else Vector3(0.72 if game.vehicle_tier==1 else 0.94,1.13,0.05)
 var moving = game.velocity.length() > 0.1
 var gait = sin(clock*16) if moving else 0.0
 legs[0].rotation.x = gait*0.55
 legs[1].rotation.x = -gait*0.55
 body.position.y = absf(gait)*0.035
 body.rotation.z = sin(clock*6)*0.04 if moving and game.bag.size()>=game.capacity() else 0.0
 var tier=game.tool_tier()
 for i in tools.size(): tools[i].visible=i==tier
 tools[tier].scale=Vector3.ONE*(1.12 if game.levels.cut_range in [2,4,6] else 1.0)
 axe.rotation.x = (0.0 if game.target>=0 else -0.25+gait*0.12) if tier>=2 else (1.1 if axe_impact>0 else (-1.2+2.2*pow(game.chop_clock/game.cut_interval(),3) if game.target>=0 else -0.25+gait*0.12))
 for blade in saw_blades: blade.rotation.y=clock*(30 if game.target>=0 else 3)
 axe.rotation.z = -0.25
 load_label.text = "%d / %d%s" % [game.bag.size(),game.capacity(),"  満載" if game.bag.size()>=game.capacity() else ""]
 load_label.position.y = 2.2 if game.vehicle_tier>0 else maxf(2.15,0.96+floori(float(maxi(0,game.bag.size()-1))/8)*0.13)
 for ring in [cut_ring,collect_ring]:
  ring.visible=not planning and not show_routes
  ring.position=Defs.point(game.position,0.045 if ring==cut_ring else 0.035)
  var radius=game.cut_radius() if ring==cut_ring else game.collect_radius()
  ring.basis=Defs.surface(game.position).scaled(Vector3(radius,1,radius))
 for i in trees.size():
  var t = game.trees[i]
  var view = trees[i]
  view.root.visible = t.hp > 0 or t.fall > 0
  view.stump.visible = t.hp <= 0
  shake[i] = maxf(0,shake[i]-delta)
  view.root.rotation.z = sin(shake[i]*70)*shake[i]*0.35
  view.root.rotation.x = 0 if t.hp>0 else (1-pow(t.fall/0.72,2))*PI/2
  var occluding = t.position.y > game.position.y-0.3 and t.position.y < game.position.y+2 and absf(t.position.x-game.position.x)<0.85
  view.mesh.material_override = pale_material if occluding else null
  view.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if occluding else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 for i in bridges.size():
  var id = "bridge" if i==0 else "high_bridge"
  bridges[i].visible = game.complete(id)
  bridges[i].scale.y = 1+sin(completion_clock/0.7*PI)*0.15 if completion_id==id else 1
 for building in markets:
  var occluding = building.position.z > game.position.y and building.position.z < game.position.y+4 and absf(building.position.x-game.position.x)<2
  building.material_override = pale_material if occluding else null
 for i in game.active_projects().size():
  var p = game.active_projects()[i]
  labels[i].text = "%s\n%d / %d 本" % [p.name,game.projects[p.id],p.need] if not game.complete(p.id) else "開通！"
 logistics_view.update(delta)
 var counts = [0,0,0]
 for log in game.ground:
  var transform = Transform3D(Basis(Vector3.UP,float(log.id)*1.7),Defs.point(log.position,0.18))
  ground_batches[log.kind].multimesh.set_instance_transform(counts[log.kind],transform)
  counts[log.kind]+=1
 for i in 3: ground_batches[i].multimesh.visible_instance_count = counts[i]
 counts = [0,0,0,0,0,0,0,0,0]
 for i in mini(game.bag.size(),Defs.CARGO_VISUAL_LIMIT):
  var log = game.bag[i]
  if pending.has(log.id): continue
  var at = cargo_position(i)
  at.x += sin(clock*6+i*0.4)*0.025 if moving else 0.0
  var transform = Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.4),at)
  var material_index=log.kind+3*int(log.get("stage",0))
  cargo_batches[material_index].multimesh.set_instance_transform(counts[material_index],transform)
  counts[material_index]+=1
 for i in 9: cargo_batches[i].multimesh.visible_instance_count = counts[i]
 target_ring.visible = game.target>=0
 target_label.visible = game.target>=0
 extra_target_rings.multimesh.visible_instance_count=game.targets.size()
 for i in game.targets.size():
  extra_target_rings.multimesh.set_instance_transform(i,Transform3D(Defs.surface(game.trees[game.targets[i]].position),Defs.point(game.trees[game.targets[i]].position,0.04)))
 if game.target>=0:
  var t = game.trees[game.target]
  target_ring.position = Defs.point(t.position,0.035)
  target_label.position = Defs.point(t.position,3.2)
  target_label.text = "%s · %d 本を伐採\n%d / %d" % [game.tool_name(),game.targets.size(),t.hp,Defs.KINDS[t.kind].hp]
 for effect in effects:
  if effect.age < 0: continue
  effect.age += delta
  var progress = minf(1,effect.age/0.34)
  var index = 0
  for i in game.bag.size():
   if game.bag[i].id == effect.id: index = i; break
  var destination = hero.to_global(cargo_position(index))
  var end = destination if effect.type == "pickup" else effect.to
  effect.node.position = effect.from.lerp(end,progress)+Vector3(0,sin(progress*PI)*1.1,0)
  if effect.type == "pickup": effect.node.rotation.y = hero.rotation.y+PI/2
  effect.label.position = effect.to+Vector3(0,1.2+effect.age*1.5,0)
  if progress>=1:
   var waiting_for_batch = pending.has(effect.id)
   pending.erase(effect.id)
   effect.node.visible = waiting_for_batch
  if effect.age>=0.7:
   effect.age=-1.0
   effect.node.visible=false
   effect.label.visible=false
 for chip in chips:
  if chip.age<0: continue
  chip.age+=delta
  chip.velocity.y-=7*delta
  chip.position+=chip.velocity*delta
  chip.node.position=chip.position
  chip.node.rotation+=Vector3(delta*5,delta*3,delta*2)
  chip.node.scale=Vector3.ONE*maxf(0,1-chip.age/0.6)
  if chip.age>=0.6:
   chip.age=-1.0
   chip.node.visible=false
 # Follow without rotating the screen's movement axes.
 update_camera(delta)

func update_camera(delta: float) -> void:
 var camera_size = (46.0 if game.wide_view else 32.0) if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else (30.0 if game.wide_view else 22.0)
 if planning: camera_size=42.0 if get_viewport().get_visible_rect().size.x<get_viewport().get_visible_rect().size.y else 24.0
 camera.size = lerpf(camera.size,camera_size,1-exp(-3*delta)) if delta>0 else camera_size
 var follow=planning_focus if planning else hero.position
 camera_anchor = camera_anchor.lerp(follow,1-exp(-7*delta)) if delta>0 and not planning else follow
 camera.position = camera_anchor+Vector3(0,18,16)
 camera.look_at(camera_anchor+Vector3(0,0.6,0))

func counts() -> Dictionary:
 var active=0
 for effect in effects: active+=1 if effect.age>=0 else 0
 for chip in chips: active+=1 if chip.age>=0 else 0
 var rendered_cargo=0
 for batch_node in cargo_batches: rendered_cargo+=batch_node.multimesh.visible_instance_count
 return {"nodes":get_child_count(),"effect_pool":effects.size()+chips.size(),"active_effects":active,"ground_instances":game.ground.size(),"cargo_instances":game.bag.size(),"rendered_cargo":rendered_cargo,"tool_tier":game.tool_tier(),"vehicle_tier":game.vehicle_tier,"vehicle_visible":0 if walker.visible else (1 if player_vehicles[0].visible else 2)}
