extends Node3D
const Defs = preload("res://scripts/adventure/definitions.gd")
const Art = preload("res://scripts/art.gd")
var game
var planning=false
var show_routes=false
var planning_focus=Vector3.ZERO
var road_preview: Array = []
var road_preview_remove=false
var logistics_view
var art = Art.new()
var hero: Node3D
var body: MeshInstance3D
var legs: Array = []
var axe: Node3D
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
 environment.environment.ambient_light_energy = 0.5
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 sun.light_energy = 0.6
 sun.shadow_opacity = 0.45
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 45
 add_child(sun)
 # A calm frozen river under the raised snowy banks.
 art.begin()
 art.box(Vector3(0,-1, -15),Vector3(60,0.1,100),Color("8dbacb"))
 for i in 25:
  art.box(Vector3(-12+fmod(i*7.3,24),-0.94,-47+i*2.8),Vector3(2.4,0.015,0.05),Color("a8d0df"))
 mesh(self,art.finish())
 for i in Defs.AREAS.size(): mesh(self,art.island(Defs.AREAS[i],i))
 market = mesh(self,art.station(),Vector3(4.2,0,6.3))
 markets.append(market)
 for i in range(1,Defs.MARKETS.size()):
  var sale=Defs.MARKETS[i]
  var p=sale.position
  var station=mesh(self,art.station(),Vector3(p.x,0,p.y-2.7))
  markets.append(station)
  label(self,sale.name,Vector3(p.x,0.7,p.y),Color("61471e"),43)
  mesh(self,art.ring(1.23,0.14,Color("e7b651")),Vector3(p.x,0.03,p.y))
 for area in 3:
  var p=Defs.CAMPS[area]
  art.begin()
  art.box(Vector3(p.x,0.012,p.y-2.7),Vector3(3.2,0.024,2.2),Color("b3cec1"))
  mesh(self,art.finish())
  var building=mesh(self,art.camp(),Vector3(p.x,0,p.y-2.7))
  mesh(self,art.ring(1.1,0.14,Color("69a973")),Vector3(p.x,0.035,p.y))
  var sign=label(self,"",Vector3(p.x,0.8,p.y),Color("3a7348"),40)
  var storage=batch(self,art.log_mesh(area),72)
  var saw=mesh(self,art.sawmill(),Vector3(p.x+1.7,0,p.y-2.7))
  camps.append({"building":building,"label":sign,"storage":storage,"saw":saw})
  for collection in [workers,carriers]:
   var worker=Node3D.new()
   add_child(worker)
   var body_mesh=mesh(worker,art.hero_body())
   body_mesh.scale=Vector3.ONE*0.9
   var feet=[]
   for x in [-0.14,0.14]: feet.append(mesh(worker,art.hero_leg(),Vector3(x,0.6,0)))
   var tool=mesh(worker,art.axe(),Vector3(0.3,1.0,0)) if collection==workers else mesh(worker,art.cart())
   var cargo=batch(worker,art.log_mesh(area),16)
   collection.append({"root":worker,"feet":feet,"tool":tool,"cargo":cargo,"previous":Vector3.ZERO})
 for i in [1,2]:
  label(self,"琥珀の森 · 24 / 本" if i==1 else "銀の森 · 50 / 本",Vector3(0,0.7,Defs.AREAS[i].end.y-1.1),Color("6b502e") if i==1 else Color("2e6c8b"),43)
 sale_label = label(self,"木材売り場",Vector3(4,0.7,9),Color("61471e"),43)
 mesh(self,art.ring(1.23,0.14,Color("e7b651")),Vector3(4,0.03,9))
 art.begin()
 for i in 4:
  art.box(Vector3(3.25+i*0.48,0.2,10.4),Vector3(0.42,0.34,0.72),CUT_COLOR())
 mesh(self,art.finish())
 for project in Defs.PROJECTS:
  var p = project.position
  mesh(self,art.ring(1.1,0.12,Color("54a7bd")),Vector3(p.x,0.045,p.y))
  labels.append(label(self,"",Vector3(p.x,0.74,p.y),Color("256379"),42))
 for rect in Defs.BRIDGES:
  var bridge_node = mesh(self,art.bridge(rect))
  bridges.append(bridge_node)
  # Unbuilt bridge has two visible bank posts but no walkable deck.
  art.begin()
  for x in [rect.position.x+0.1,rect.end.x-0.1]:
   art.box(Vector3(x,0.35,rect.end.y+0.1),Vector3(0.2,0.7,0.2),Color("976b49"))
   art.box(Vector3(x,0.72,rect.end.y+0.1),Vector3(0.27,0.1,0.27),Color("e8f4fa"))
  mesh(self,art.finish())
 art.begin()
 art.box(Vector3(-5,0.03,-21.2),Vector3(4,0.06,2.5),Color("83a9bb"))
 for x in [-6.7,-3.3]:
  for z in [-22.2,-20.2]: art.box(Vector3(x,0.65,z),Vector3(0.14,1.3,0.14),Art.WOOD)
 art.box(Vector3(-5,1.3,-22.2),Vector3(3.4,0.13,0.14),Art.CUT)
 mesh(self,art.finish())
 workshop = mesh(self,art.station(true),Vector3(-5,0,-21.2))
 workshop_sign = label(self,"",Vector3(-5,3.3,-21.2),Color("256379"),42)
 var shapes = [art.snow_tree(0),art.snow_tree(1),art.snow_tree(2)]
 pale_material = art.material.duplicate()
 pale_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 pale_material.albedo_color.a = 0.25
 pale_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
 for i in game.trees.size():
  var t = game.trees[i]
  var root = Node3D.new()
  root.position = Vector3(t.position.x,0,t.position.y)
  add_child(root)
  var tree = mesh(root,shapes[t.kind])
  tree.rotation.y = i*1.37
  art.begin()
  art.branch(Vector3.ZERO,Vector3(0,0.18,0),0.22,0.2,Art.WOOD,7)
  var stump = mesh(self,art.finish(),root.position)
  trees.append({"root":root,"mesh":tree,"stump":stump})
  shake.append(0.0)
 hero = Node3D.new()
 add_child(hero)
 hero.position = Vector3(game.position.x,0,game.position.y)
 body = mesh(hero,art.hero_body())
 for x in [-0.14,0.14]:
  var leg = mesh(hero,art.hero_leg(),Vector3(x,0.6,0))
  legs.append(leg)
 axe = Node3D.new()
 axe.position = Vector3(0.3,1.04,0.05)
 hero.add_child(axe)
 mesh(axe,art.axe()).scale = Vector3.ONE * 1.12
 mesh(hero,art.ring(0.5,0.08,Color("f1bc55")),Vector3(0,0.025,0))
 load_label = label(hero,"",Vector3(0,2.45,0),Color("234d67"),37)
 for kind in 3:
  var log_shape = art.log_mesh(kind)
  ground_batches.append(batch(self,log_shape,Defs.MAX_GROUND))
  cargo_batches.append(batch(hero,log_shape,30))
 target_ring = mesh(self,art.ring(0.61,0.09,Color("f4b952")))
 target_label = label(self,"",Vector3.ZERO,Color("51411e"),40)
 # Fixed pools: their object count doesn't depend on session length.
 for i in 24:
  var node = mesh(self,art.log_mesh())
  node.visible = false
  var text = label(self,"",Vector3.ZERO,Color("c57c17"),37)
  text.visible = false
  effects.append({"node":node,"label":text,"age":-1.0,"from":Vector3.ZERO,"to":Vector3.ZERO,"type":"","id":-1})
 art.begin()
 art.box(Vector3.ZERO,Vector3(0.12,0.07,0.07),Art.CUT)
 var chip_shape = art.finish()
 for i in 24:
  var node = mesh(self,chip_shape)
  node.visible = false
  chips.append({"node":node,"age":-1.0,"position":Vector3.ZERO,"velocity":Vector3.ZERO})
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 28.0
 camera.far = 90
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

func handle(event: Dictionary) -> void:
 if event.type in ["hit","auto_hit"]:
  if event.type=="hit": axe_impact = 0.11
  shake[event.tree] = 0.2
  burst(Vector3(event.position.x,0.9,event.position.y),4)
 elif event.type == "fell":
  burst(Vector3(event.position.x,0.7,event.position.y),9)
 elif event.type == "auto_sell":
  burst(Vector3(event.to.x,0.5,event.to.y),2)
 elif event.type in ["pickup","sell","deposit"]:
  for effect in effects:
   if effect.age < 0:
    effect.age = 0.0
    effect.type = event.type
    effect.id = event.get("id",-1)
    effect.node.mesh = cargo_batches[event.kind].multimesh.mesh
    effect.from = Vector3(event.from.x,0.2,event.from.y) if event.type == "pickup" else hero.to_global(Vector3(0,0.95+floori(float(game.bag.size())/2)*0.16,-0.42-(game.bag.size()%2)*0.2))
    effect.to = Vector3(event.to.x,0.4,event.to.y) if event.has("to") else hero.global_position
    effect.node.visible = true
    effect.node.scale = Vector3.ONE*0.6
    effect.node.rotation = Vector3(0,PI/2,0)
    effect.label.text = "+%d" % event.amount if event.type == "sell" else ""
    effect.label.visible = event.type == "sell"
    if event.type == "pickup": pending[effect.id] = true
    break
 elif event.type == "complete":
  completion_clock = 0.7
  completion_id = event.id
  burst(Vector3(event.position.x,1,event.position.y),18)

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
 var desired = Vector3(game.position.x,0,game.position.y)
 hero.position = hero.position.lerp(desired,1-exp(-35*delta)) if delta>0 else desired
 var angle = atan2(game.facing.x,game.facing.y)
 hero.rotation.y = lerp_angle(hero.rotation.y,angle,1-exp(-20*delta))
 var moving = game.velocity.length() > 0.1
 var gait = sin(clock*(10+game.levels.boots)) if moving else 0.0
 legs[0].rotation.x = gait*0.55
 legs[1].rotation.x = -gait*0.55
 body.position.y = absf(gait)*0.035
 body.rotation.z = sin(clock*6)*0.04 if moving and game.bag.size()>=game.capacity() else 0.0
 axe.rotation.x = 1.1 if axe_impact>0 else (-1.2+2.2*pow(game.chop_clock/game.cut_interval(),3) if game.target>=0 else -0.25+gait*0.12)
 axe.rotation.z = -0.25
 load_label.text = "%d / %d%s" % [game.bag.size(),game.capacity(),"  満載" if game.bag.size()>=game.capacity() else ""]
 load_label.position.y = 2.25+minf(game.bag.size()*0.10,1.7)
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
 for building in markets+[workshop]:
  var occluding = building.position.z > game.position.y and building.position.z < game.position.y+4 and absf(building.position.x-game.position.x)<2
  building.material_override = pale_material if occluding else null
 workshop.visible = game.complete("workshop")
 workshop.scale = Vector3.ONE*(1+sin(completion_clock/0.7*PI)*0.08) if completion_id=="workshop" else Vector3.ONE
 workshop_sign.text = "木工工房 · 売値 ×1.5" if workshop.visible else "工房の予定地"
 for i in Defs.PROJECTS.size():
  var p = Defs.PROJECTS[i]
  labels[i].text = "%s\n%d / %d 本" % [p.name,game.projects[p.id],p.need] if not game.complete(p.id) else "開通！" if p.id != "workshop" else "工房 完成"
 update_automation(delta)
 logistics_view.update(delta)
 var counts = [0,0,0]
 for log in game.ground:
  var transform = Transform3D(Basis(Vector3.UP,float(log.id)*1.7),Vector3(log.position.x,0.18,log.position.y))
  ground_batches[log.kind].multimesh.set_instance_transform(counts[log.kind],transform)
  counts[log.kind]+=1
 for i in 3: ground_batches[i].multimesh.visible_instance_count = counts[i]
 counts = [0,0,0]
 for i in game.bag.size():
  var log = game.bag[i]
  if pending.has(log.id): continue
  var row = floori(float(i)/2)
  var at = Vector3(0,0.95+row*0.16,-0.42-(i%2)*0.2)
  at.x += sin(clock*6+i*0.4)*0.025 if moving else 0.0
  var transform = Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.55),at)
  cargo_batches[log.kind].multimesh.set_instance_transform(counts[log.kind],transform)
  counts[log.kind]+=1
 for i in 3: cargo_batches[i].multimesh.visible_instance_count = counts[i]
 target_ring.visible = game.target>=0
 target_label.visible = game.target>=0
 if game.target>=0:
  var t = game.trees[game.target]
  target_ring.position = Vector3(t.position.x,0.035,t.position.y)
  target_label.position = Vector3(t.position.x,3.2,t.position.y)
  target_label.text = "%s · 売値 %d
%d / %d" % [Defs.KINDS[t.kind].name,game.value(t.kind),t.hp,Defs.KINDS[t.kind].hp]
 for effect in effects:
  if effect.age < 0: continue
  effect.age += delta
  var progress = minf(1,effect.age/0.34)
  var index = 0
  for i in game.bag.size():
   if game.bag[i].id == effect.id: index = i; break
  var destination = hero.to_global(Vector3(0,0.95+floori(float(index)/2)*0.16,-0.42-(index%2)*0.2))
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
 var camera_size = (38.0 if game.wide_view else 28.0) if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else (24.0 if game.wide_view else 18.0)
 if planning: camera_size=42.0 if get_viewport().get_visible_rect().size.x<get_viewport().get_visible_rect().size.y else 24.0
 camera.size = lerpf(camera.size,camera_size,1-exp(-3*delta)) if delta>0 else camera_size
 var follow=planning_focus if planning else hero.position
 camera_anchor = camera_anchor.lerp(follow,1-exp(-7*delta)) if delta>0 else follow
 camera.position = camera_anchor+Vector3(0,18,16)
 camera.look_at(camera_anchor+Vector3(0,0.6,0))

func update_automation(delta: float) -> void:
 for area in 3:
  var p=Defs.CAMPS[area]
  var auto=game.automation
  var camp=camps[area]
  var active=auto.levels[area].camp>0
  camp.building.visible=active
  camp.saw.visible=auto.levels[area].mill>0
  camp.saw.rotation.y=sin(clock*2)*0.06
  camp.label.text="%s 倉庫 %d/%d 本" % [Defs.AREA_NAMES[area],auto.stocks[area].size(),auto.capacity(area)] if active else "%s 伐採所予定地\n道具・設備で建設" % Defs.AREA_NAMES[area]
  var stock=auto.stocks[area]
  for i in stock.size():
   var at=Vector3(p.x-1.0+(i%6)*0.35,0.22+floori(float(i)/6)*0.26,p.y-1.4)
   camp.storage.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.7),at))
  camp.storage.multimesh.visible_instance_count=stock.size()
  for role in 2:
   var view=workers[area] if role==0 else carriers[area]
   var logic=auto.cutters[area] if role==0 else auto.porters[area]
   view.root.visible=active if role==0 else auto.levels[area].porter>0
   var at=Vector3(logic.position.x,0,logic.position.y)
   var difference=at-view.previous
   if difference.length()>0.001: view.root.rotation.y=atan2(difference.x,difference.z)
   elif role==0 and logic.target>=0:
    var direction=game.trees[logic.target].position-logic.position
    view.root.rotation.y=atan2(direction.x,direction.y)
   view.previous=at
   view.root.position=at
   var gait=sin(clock*10+area)*0.5 if difference.length()>0.001 else 0.0
   view.feet[0].rotation.x=gait
   view.feet[1].rotation.x=-gait
   if role==0: view.tool.rotation.x=sin(logic.clock/0.65*PI)*1.7 if logic.target>=0 and difference.length()<0.001 else -0.25
   for i in logic.cargo.size():
    var cargo_at=Vector3(0,1.0+i*0.15,-0.5) if role==0 else Vector3(0,0.55+floori(float(i)/4)*0.2,-0.8-(i%4)*0.25)
    view.cargo.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.6),cargo_at))
   view.cargo.multimesh.visible_instance_count=logic.cargo.size()

func counts() -> Dictionary:
 var active=0
 for effect in effects: active+=1 if effect.age>=0 else 0
 for chip in chips: active+=1 if chip.age>=0 else 0
 return {"nodes":get_child_count(),"effect_pool":effects.size()+chips.size(),"active_effects":active,"ground_instances":game.ground.size(),"cargo_instances":game.bag.size()}
