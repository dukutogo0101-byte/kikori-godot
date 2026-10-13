extends Node3D
const State = preload("res://scripts/adventure/game_state.gd")
const Defs = preload("res://scripts/adventure/definitions.gd")
const Art = preload("res://scripts/art.gd")
const Controller = preload("res://scripts/adventure/player_controller.gd")
var game = State.new()
var art = Art.new()
var controller = Controller.new()
var hero: Node3D
var camera: Camera3D
var tree_nodes: Array = []
var logs: Array = []
var cargo: Array = []
var status: Label
var diagnostic_clock = 0.0

func mesh(parent: Node3D, shape: Mesh, at: Vector3) -> MeshInstance3D:
 var item = MeshInstance3D.new()
 item.mesh = shape
 item.position = at
 parent.add_child(item)
 return item

func _ready() -> void:
 controller.blocked = func(_p): return false
 add_child(controller)
 var environment = WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("aac8dc")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("eef8ff")
 environment.environment.ambient_light_energy = 0.8
 add_child(environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-25,0)
 sun.light_energy = 1.2
 add_child(sun)
 art.begin()
 art.box(Vector3(0,-0.4,3),Vector3(18,0.8,20),Color("eff9fc"))
 mesh(self,art.finish(),Vector3.ZERO)
 var tree_mesh = art.tree()
 for tree in game.trees:
  var node = Node3D.new()
  node.position = Vector3(tree.position.x,0,tree.position.y)
  mesh(node,tree_mesh,Vector3.ZERO)
  add_child(node)
  tree_nodes.append(node)
 hero = Node3D.new()
 add_child(hero)
 mesh(hero,art.worker(),Vector3.ZERO).scale = Vector3.ONE * 1.25
 for i in 30:
  var log = mesh(self,art.log_mesh(),Vector3.ZERO)
  log.visible = false
  logs.append(log)
 for i in 6:
  var log = mesh(hero,art.log_mesh(),Vector3.ZERO)
  log.scale = Vector3.ONE * 0.5
  log.visible = false
  cargo.append(log)
 art.begin()
 art.box(Vector3(4,0.03,9),Vector3(2.4,0.06,2.4),Color("f1cb65"))
 mesh(self,art.finish(),Vector3.ZERO)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 14
 add_child(camera)
 var layer = CanvasLayer.new()
 add_child(layer)
 status = Label.new()
 status.position = Vector2(20,32)
 layer.add_child(status)
 if "--smoke-test" in OS.get_cmdline_user_args():
  print("KIKORI_DIRECT_LOOP_READY")
  get_tree().create_timer(2).timeout.connect(func(): get_tree().quit())

func _physics_process(delta: float) -> void:
 game.tick(delta,controller.sample())
 diagnostic_clock += delta
 if diagnostic_clock > 0.2:
  diagnostic_clock = 0
  diagnostics()
 hero.position = Vector3(game.position.x,0,game.position.y)
 hero.rotation.y = atan2(game.facing.x,game.facing.y)
 for i in tree_nodes.size(): tree_nodes[i].visible = game.trees[i].hp > 0
 for i in logs.size():
  logs[i].visible = i < game.ground.size()
  if i < game.ground.size(): logs[i].position = Vector3(game.ground[i].position.x,0.2,game.ground[i].position.y)
 for i in cargo.size():
  cargo[i].visible = i < game.bag.size()
  cargo[i].position = Vector3(0,0.8+i*0.19,-0.3)
 camera.position = hero.position + Vector3(0,18,16)
 camera.look_at(hero.position + Vector3(0,0.5,0))
 status.text = "KIKORI   資金 %d   荷物 %d/%d\n%s" % [game.money,game.bag.size(),game.capacity(),game.notice]

func diagnostics() -> void:
 if OS.has_feature("web"):
  JavaScriptBridge.eval("window.kikoriReady=true;window.kikoriState=" + JSON.stringify({"position": [game.position.x,game.position.y],"money":game.money,"bag":game.bag.size(),"elapsed":game.elapsed})+";",true)
