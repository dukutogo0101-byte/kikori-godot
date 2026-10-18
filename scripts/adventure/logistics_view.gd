extends Node3D
const Art=preload("res://scripts/art.gd")
const Defs=preload("res://scripts/adventure/definitions.gd")
const Logic=preload("res://scripts/adventure/logistics.gd")
var game
var world
var art=Art.new()
var road_batch: MultiMeshInstance3D
var preview_batch: MultiMeshInstance3D
var sites: Array = []
var ghost: Node3D
var ghost_shapes=[]
var ghost_ring: MeshInstance3D
var carts: Array = []
var revision=-1
var preview_key=""
var preview_materials=[]
var arrows: MultiMeshInstance3D
var route_key=""

func setup(state, view) -> void:
 game=state;world=view
 art.begin("road");art.box(Vector3.ZERO,Vector3(0.96,0.035,0.96),Color("ba9874"))
 road_batch=world.batch(self,art.finish(),Logic.MAX_ROADS)
 art.begin("road_preview");art.box(Vector3.ZERO,Vector3(0.88,0.045,0.88),Color("6bcbad"))
 preview_batch=world.batch(self,art.finish(),160)
 for color in [Color("64d3a5"),Color("e68b70")]:
  var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;preview_materials.append(material)
 art.begin("route_arrow");art.tri(Vector3(-0.16,0,0),Vector3(0.16,0,0),Vector3(0,0,0.42),Color("f5be58"))
 arrows=world.batch(self,art.finish(),512)
 for i in Logic.MAX_SITES:
  var root=Node3D.new();add_child(root)
  var shapes=[]
  for kind in ["storage","processor","factory"]: shapes.append(world.mesh(root,art.facility(kind)))
  var ring=world.mesh(self,art.ring(1.0,0.15,Color("6a9ac1")))
  var label=world.label(self,"",Vector3.ZERO,Color("32617c"),35)
  var batches=[]
  for stage in 3:
   for kind in 3: batches.append(world.batch(self,art.goods(kind,stage),48))
  var worker=Node3D.new();add_child(worker)
  world.mesh(worker,art.hero_body()).scale=Vector3.ONE*0.9
  var legs=[]
  for x in [-0.14,0.14]: legs.append(world.mesh(worker,art.hero_leg(),Vector3(x,0.6,0)))
  var axe=world.mesh(worker,art.axe(),Vector3(0.3,1.0,0))
  var cargo=[]
  for kind in 3: cargo.append(world.batch(worker,art.log_mesh(kind),5))
  var blade=world.mesh(root,art.saw_blade(),Vector3(0,1.1,0))
  sites.append({"root":root,"shapes":shapes,"ring":ring,"label":label,"stocks":batches,"worker":worker,"legs":legs,"axe":axe,"cargo":cargo,"blade":blade,"previous":Vector3.ZERO})
 ghost=Node3D.new();add_child(ghost)
 for kind in ["storage","processor","factory"]: ghost_shapes.append(world.mesh(ghost,art.facility(kind),Vector3(0,0,-2.7)))
 ghost_ring=world.mesh(ghost,art.ring(1.0,0.15,Color("f1bf61")))
 for i in Logic.MAX_CARTS:
  var root=Node3D.new();add_child(root)
  world.mesh(root,art.hero_body()).scale=Vector3.ONE*0.85
  world.mesh(root,art.cart())
  var legs=[]
  for x in [-0.14,0.14]: legs.append(world.mesh(root,art.hero_leg(),Vector3(x,0.6,0)))
  var batches=[]
  for stage in 3:
   for kind in 3: batches.append(world.batch(root,art.goods(kind,stage),16))
  var label=world.label(root,"",Vector3(0,2.25,0),Color("346f94"),35)
  carts.append({"root":root,"legs":legs,"cargo":batches,"label":label,"previous":Vector3.ZERO})
 update(0)

func update(delta: float) -> void:
 var logistics=game.logistics
 if revision!=logistics.revision:
  revision=logistics.revision
  var index=0
  for p in logistics.roads:
   road_batch.multimesh.set_instance_transform(index,Transform3D(Defs.surface(Vector2(p)),Defs.point(Vector2(p),0.045)));index+=1
  road_batch.multimesh.visible_instance_count=index
 var key=str(world.road_preview)+str(world.road_preview_remove)+str(revision)
 if key!=preview_key:
  preview_key=key
  var i=0
  for p in world.road_preview:
   preview_batch.multimesh.set_instance_transform(i,Transform3D(Defs.surface(Vector2(p)),Defs.point(Vector2(p),0.085)));i+=1
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
    arrows.multimesh.set_instance_transform(count,Transform3D(Basis(Vector3.UP,atan2(difference.x,difference.y)),Defs.point(point,0.09)));count+=1
  arrows.multimesh.visible_instance_count=count
 arrows.visible=world.planning or world.show_routes
 ghost.visible=not world.facility_preview.is_empty()
 if ghost.visible:
  var preview=world.facility_preview;ghost.position=Defs.point(preview.position)
  for i in ghost_shapes.size():
   ghost_shapes[i].visible=["storage","processor","factory"][i]==preview.type
   ghost_shapes[i].material_override=preview_materials[0 if preview.valid else 1]
 for i in sites.size():
  var node=sites[i];var visible=i<logistics.sites.size()
  node.root.visible=visible;node.ring.visible=visible;node.label.visible=visible;node.worker.visible=false
  for batch in node.stocks: batch.multimesh.visible_instance_count=0
  if not visible: continue
  var item=logistics.sites[i];var type_index=["storage","processor","factory"].find(item.type)
  var at=item.position;node.root.position=Defs.point(logistics.footprint(item).get_center())
  for index in 3: node.shapes[index].visible=index==type_index
  node.ring.position=Defs.point(at,0.05);node.ring.basis=Defs.surface(at)
  node.label.position=Defs.point(at,0.8)
  node.label.text="%s Lv.%d · %d/%d\n%s" % [Logic.FACILITIES[item.type].name,item.level,item.output.size(),logistics.capacity(item.id),"木こり稼働" if item.type=="storage" and item.worker_enabled else ("木こり休止" if item.type=="storage" else "加工待ち %d 本 · %d%%" % [item.input.size(),int(item.clock/(6.0/item.level)*100)])]
  node.blade.visible=item.type=="processor";node.blade.rotation.y=world.clock*(10 if not item.input.is_empty() and item.output.size()<logistics.capacity(item.id) else 0)
  var counts=[0,0,0,0,0,0,0,0,0]
  for index in mini(48,item.output.size()):
   var log=item.output[index];var material_index=log.kind+3*int(log.get("stage",0))
   var p=Defs.point(at+Vector2(-1.05+(index%8)*0.3,1.3),0.25+floori(float(index)/8)*0.22)
   node.stocks[material_index].multimesh.set_instance_transform(counts[material_index],Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.55),p));counts[material_index]+=1
  for index in 9: node.stocks[index].multimesh.visible_instance_count=counts[index]
  if item.type!="storage": continue
  var worker=item.worker;node.worker.visible=true
  var pos=Defs.point(worker.position);var difference=pos-node.previous
  if difference.length()>0.001: node.worker.rotation.y=atan2(difference.x,difference.z)
  elif worker.target>=0:
   var direction=game.trees[worker.target].position-worker.position;node.worker.rotation.y=atan2(direction.x,direction.y)
  node.previous=pos;node.worker.position=pos
  var gait=sin(world.clock*10+i)*0.5 if difference.length()>0.001 else 0.0
  node.legs[0].rotation.x=gait;node.legs[1].rotation.x=-gait
  node.axe.rotation.x=sin(worker.clock/0.65*PI)*1.7 if worker.phase=="cutting" else -0.25
  var cargo_counts=[0,0,0]
  for index in worker.cargo.size():
   var log=worker.cargo[index]
   node.cargo[log.kind].multimesh.set_instance_transform(cargo_counts[log.kind],Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.5),Vector3(0,1+index*0.15,-0.5)));cargo_counts[log.kind]+=1
  for kind in 3: node.cargo[kind].multimesh.visible_instance_count=cargo_counts[kind]
 for i in carts.size():
  var node=carts[i];node.root.visible=i<logistics.carts.size()
  if not node.root.visible: continue
  var cart=logistics.carts[i];var at=Defs.point(cart.position)
  var difference=at-node.previous
  if difference.length()>0.001: node.root.rotation.y=atan2(difference.x,difference.z)
  node.previous=at;node.root.position=at
  var gait=sin(world.clock*10+i)*0.5 if difference.length()>0.001 else 0.0
  node.legs[0].rotation.x=gait;node.legs[1].rotation.x=-gait
  node.label.text="%d · %d本" % [cart.id,cart.cargo.size()]
  var counts=[0,0,0,0,0,0,0,0,0]
  for j in cart.cargo.size():
   var log=cart.cargo[j]
   var p=Vector3(0,0.6+floori(float(j)/4)*0.2,-0.8-(j%4)*0.25)
   var material_index=log.kind+3*int(log.get("stage",0))
   node.cargo[material_index].multimesh.set_instance_transform(counts[material_index],Transform3D(Basis(Vector3.UP,PI/2).scaled(Vector3.ONE*0.6),p))
   counts[material_index]+=1
  for kind in 9: node.cargo[kind].multimesh.visible_instance_count=counts[kind]
