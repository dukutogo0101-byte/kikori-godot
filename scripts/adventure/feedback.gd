extends Node
var sound = false
var vibration = false
var voices = {}
func _ready() -> void:
 for key in ["hit","fell","pickup","sell","deposit","complete","upgrade"]:
  var player = AudioStreamPlayer.new()
  player.max_polyphony = 4
  player.volume_db = -17 if key in ["pickup","deposit"] else -12
  if OS.has_feature("web"):
   player.stream=load("res://assets/baked/sound_%s.res" % key)
   add_child(player);voices[key]=player
   continue
  var wave = AudioStreamWAV.new()
  wave.format = AudioStreamWAV.FORMAT_16_BITS
  wave.mix_rate = 22050
  var length = 0.22 if key in ["complete","upgrade"] else 0.07
  var samples = PackedByteArray()
  samples.resize(int(22050*length)*2)
  var frequency = {"hit":150,"fell":85,"pickup":600,"sell":880,"deposit":380,"complete":1100,"upgrade":950}[key]
  for i in samples.size()/2:
   var t = float(i)/22050
   var envelope = pow(1-t/length,2)
   var tone = sin(TAU*(frequency+350*t)*t)*0.48+sin(TAU*frequency*1.5*t)*0.16
   samples.encode_s16(i*2,int(clampf(tone*envelope,-1,1)*18000))
  wave.data = samples
  if preload("res://scripts/art.gd").baking:
   var error=ResourceSaver.save(wave,"res://assets/baked/sound_%s.res" % key,ResourceSaver.FLAG_COMPRESS)
   assert(error==OK)
  player.stream = wave
  add_child(player)
  voices[key] = player
func event(data: Dictionary) -> void:
 if sound and voices.has(data.type): voices[data.type].play()
 if vibration and OS.has_feature("web") and data.type in ["fell","complete","upgrade"]:
  JavaScriptBridge.eval("if(navigator.vibrate) navigator.vibrate(%d);" % (40 if data.type=="complete" else 15),true)
