extends Node3D
const Art=preload("res://scripts/art.gd")
const Logic=preload("res://scripts/adventure/logistics.gd")
var game
var world
var art=Art.new()
var road_batch: MultiMeshInstance3D
var preview_batch: MultiMeshInstance3D
var depots: Array = []
var carts: Array = []
var revision=-1
var preview_key=""
var preview_materials=[]
var arrows: MultiMeshInstance3D
var route_key=""

func setup(state, view) -> void:
 game=state;world=view
 art.begin();art.box(Vector3.ZERO,Vector3(0.96,0.035,0.96),Color("ba9874"))
 road_batch=world.batch(self,art.finish(),Logic.MAX_ROADS)
 art.begin();art.box(Vector3.ZERO,Vector3(0.88,0.045,0.88),Color("6bcbad"))
 preview_batch=world.batch(self,art.finish(),160)
 for color in [Color("64d3a5"),Color("e68b70")]:
  var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;preview_materials.append(material)
 art.begin();art.tri(Vector3(-0.16,0,0),Vector3(0.16,0,0),Vector3(0,0,0.42),Color("f5be58"))
 arrows=world.batch(self,art.finish(),512)
 for area in 3:
  var p=Logic.DEPOTS[area]
  art.begin()
  art.box(Vector3(2.1,0.08,0),Vector3(2.7,0.16,2.5),Color("638f9e"))
  for x in [1.0,3.2]:
   for z in [-1.0,1.0]: art.box(Vector3(x,0.55,z),Vector3(0.13,1.1,0.13),Art.WOOD)
  var building=world.mesh(self,art.finish(),Vector3(p.x,0,p.y))
  var ring=world.mesh(self,art.ring(1.0,0.15,Color("6a9ac1")),Vector3(p.x,0.05,p.y))
  var label=world.label(self,"",Vector3(p.x,0.85,p.y),Color("32617c"),38)
  var batches=[]
  for kind in 3: batches.append(world.batch(self,art.log_mesh(kind),112))
  depots.append({"building":building,"ring":ring,"label":label,"stocks":batches})
 for i in Logic.MAX_CARTS:
  var root=Node3D.new();add_child(root)
  world.mesh(root,art.hero_body()).scale=Vector3.ONE*0.85
  world.mesh(root,art.cart())
  var legs=[]
  for x in [-0.14,0.14]: legs.append(world.mesh(root,art.hero_leg(),Vector3(x,0.6,0)))
  var batches=[]
  for kind in 3: batches.append(world.batch(root,art.log_mesh(kind),16))
  var label=world.label(root,"",Vector3(0,2.25,0),Color("346f94"),35)
  carts.append({"root":root,"legs":legs,"cargo":batches,"label":label,"previous":Vector3.ZERO})
 update(0)

func update(delta: float) -> void:
 var logistics=game.logistics
 if revision!=logistics.revision:
  revision=logistics.revision
  var index=0
  for p in logistics.roads:
   road_batch.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(p.x,0.045,p.y)));index+=1
  road_batch.multimesh.visible_instance_count=index
 var key=str(world.road_preview)+str(world.road_preview_remove)+str(revision)
 if key!=preview_key:
  preview_key=key
  var i=0
  for p in world.road_preview:
   preview_batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(p.x,0.085,p.y)));i+=1
  preview_batch.multimesh.visible_instance_count=i
  var valid=not world.road_preview_remove
  for p in world.road_preview:
   if not logistics.road_valid(game,p): valid=false;break
  preview_batch.material_override=preview_materials[0 if valid else 1]
 var signature=str(revision)
 for cart in logistics.carts: signature+=cart.source+":"+cart.destination+";"
 if signature!=route_key:
  route_key=signature
  var count=0
  for cart in logistics.carts:
   var a=logistics.endpoint(game,cart.source);var b=logistics.endpoint(game,cart.destination)
   if a.is_empty() or b.is_empty(): continue
   var path=logistics.path_between(game,Logic.cell(a.position),Logic.cell(b.position))
   for i in range(0,maxi(0,path.size()-1),3):
    if count>=512: break
    var difference=Vector2(path[i+1]-path[i]);var point=Vector2(path[i])+difference*0.4
    arrows.multimesh.set_instance_transform(count,Transform3D(Basis(Vector3.UP,atan2(difference.x,difference.y)),Vector3(point.x,0.09,point.y)));count+=1
  arrows.multimesh.visible_instance_count=count
 arrows.visible=world.planning or world.show_routes
 for area in 3:
  var at=Logic.DEPOTS[area];var node=depots[area];var level=logistics.depot_levels[area]
  node.building.visible=level>0;node.ring.visible=level>0
  node.label.visible=level>0 or world.planning
  node.label.text="%s 集積倉庫\n%d / %d 本 · 予定 %d" % [["雪松","琥珀","銀"][area],logistics.stocks[area].size(),logistics.capacity(area),logistics.reserved(area)] if level>0 else "集積倉庫の予定地"
  var counts=[0,0,0]
  for i in logistics.stocks[area].size():
   var log=logistics.stocks[area][i]
   var p=Vector3(at.x+1.0+(i%8)*0.3,0.25+floori(float(i)/8)*0.2,at.y)
   node.stocks[log.kind].multimesh.set_instance_transform(counts[log.kind],Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.65),p))
   counts[log.kind]+=1
  for kind in 3: node.stocks[kind].multimesh.visible_instance_count=counts[kind]
 for i in carts.size():
  var node=carts[i];node.root.visible=i<logistics.carts.size()
  if not node.root.visible: continue
  var cart=logistics.carts[i];var at=Vector3(cart.position.x,0,cart.position.y)
  var difference=at-node.previous
  if difference.length()>0.001: node.root.rotation.y=atan2(difference.x,difference.z)
  node.previous=at;node.root.position=at
  var gait=sin(world.clock*10+i)*0.5 if difference.length()>0.001 else 0.0
  node.legs[0].rotation.x=gait;node.legs[1].rotation.x=-gait
  node.label.text="%d · %d本" % [cart.id,cart.cargo.size()]
  var counts=[0,0,0]
  for j in cart.cargo.size():
   var log=cart.cargo[j]
   var p=Vector3(0,0.6+floori(float(j)/4)*0.2,-0.8-(j%4)*0.25)
   node.cargo[log.kind].multimesh.set_instance_transform(counts[log.kind],Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.6),p))
   counts[log.kind]+=1
  for kind in 3: node.cargo[kind].multimesh.visible_instance_count=counts[kind]
