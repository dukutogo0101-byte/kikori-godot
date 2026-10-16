extends SceneTree
const Art=preload("res://scripts/art.gd")
func _initialize() -> void:
 call_deferred("bake")
func bake() -> void:
 DirAccess.make_dir_recursive_absolute("res://assets/baked")
 Art.baking=true
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var total=0
 for key in Art.baked_files:
  var mesh=load(Art.baked_files[key]) as ArrayMesh
  assert(mesh!=null and mesh.get_surface_count()>0,"Valid baked mesh: "+key)
  assert(mesh.surface_get_array_len(0)>0,"Nonempty baked mesh: "+key)
  total+=1
 for key in ["hit","fell","pickup","sell","deposit","complete","upgrade"]:
  var sound=load("res://assets/baked/sound_%s.res" % key) as AudioStreamWAV
  assert(sound!=null and sound.data.size()>0,"Valid baked sound: "+key)
 print("KIKORI_BAKED_ASSETS meshes=%d sounds=7" % total)
 quit()
