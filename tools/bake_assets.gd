extends SceneTree
const Art=preload("res://scripts/art.gd")
func _initialize() -> void:
 call_deferred("bake")
func bake() -> void:
 DirAccess.make_dir_recursive_absolute("res://assets/baked")
 Art.baking=true
 # The full-bleed background is safe for Android's maskable app icons.
 var icon_source=FileAccess.get_file_as_string("res://assets/icon.svg").replace('rx="28"','rx="0"')
 for size in [192,512]:
  var icon=Image.new()
  var error=icon.load_svg_from_string(icon_source,float(size)/128)
  assert(error==OK)
  error=icon.save_png("res://build/web/app-icon-%d.png" % size)
  assert(error==OK)
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
