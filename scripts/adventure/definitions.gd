extends RefCounted
# World X/Z. Three watersheds, joined only by the two buildable crossings.
const SPAWN = Vector2(0,10)
const SALE = Vector2(4,9)
const WORLD_BOUNDS = Rect2(-98,-224,196,294)
const AREAS = [Rect2(-62,-38,124,104),Rect2(-76,-113,164,68),Rect2(-94,-220,184,100)]
const OUTLINES = [
 [Vector2(-62,18),Vector2(-54,-12),Vector2(-30,-30),Vector2(-8,-38),Vector2(12,-38),Vector2(35,-28),Vector2(54,-8),Vector2(62,25),Vector2(48,53),Vector2(18,66),Vector2(-22,60),Vector2(-48,44)],
 [Vector2(-76,-76),Vector2(-63,-100),Vector2(-34,-113),Vector2(18,-113),Vector2(48,-104),Vector2(76,-85),Vector2(88,-61),Vector2(68,-48),Vector2(34,-49),Vector2(12,-45),Vector2(-8,-45),Vector2(-36,-52),Vector2(-62,-58)],
 [Vector2(-94,-172),Vector2(-76,-204),Vector2(-36,-220),Vector2(5,-213),Vector2(36,-218),Vector2(72,-191),Vector2(90,-161),Vector2(70,-137),Vector2(38,-126),Vector2(12,-120),Vector2(0,-120),Vector2(-24,-130),Vector2(-58,-137),Vector2(-82,-149)]
]
const BRIDGES = [Rect2(-1.6,-45,3.2,7),Rect2(4.4,-120,3.2,7)]
const BUILDINGS = [Rect2(2.5,5.2,3.4,2.2),Rect2(-7,-76.5,4,2.5)]
const MARKETS = [{"name":"中央基地・出荷場","position":SALE,"area":0}]
const CAMPS = [Vector2(-12,9),Vector2(-28,-64),Vector2(-34,-157)]
const AISLES = [-8.3,-24.3,-30.3]
const AUTO_TREE_X = [-10.0,-26.0,-32.0]
const AREA_NAMES = ["雪松の盆地","琥珀の丘陵","白樺の高原"]
const SHORT_NAMES = ["雪松","琥珀","白樺"]
const LAKES = [Rect2(24,22,17,12),Rect2(-57,-94,22,15),Rect2(33,-185,25,18)]
const ROCKS = [Vector3(-40,0,28),Vector3(40,0,-8),Vector3(52,0,-85),Vector3(-57,0,-66),Vector3(-56,0,-183),Vector3(58,0,-151)]
const AUTOMATION = {
 "camp":{"name":"自動伐採所","price":180,"description":"木こりが伐採し、現地の倉庫へ運ぶ"},
 "porter":{"name":"基地への運搬係","price":140,"description":"川の橋を渡り中央基地まで往復。届いてから入金"},
 "mill":{"name":"製材設備","price":320,"description":"この森の木材の売値を25%ずつ増加"}
}
const AUTO_MAX_LEVEL = 3
const KINDS = [
 {"name":"雪松","hp":3,"yield":3,"value":10,"regrow":32.0},
 {"name":"琥珀カラマツ","hp":7,"yield":4,"value":24,"regrow":40.0},
 {"name":"銀の白樺","hp":12,"yield":5,"value":50,"regrow":48.0}
]
const PROJECTS = [
 {"id":"bridge","name":"丘陵への橋","position":Vector2(0,-35.5),"need":60,"area":0},
 {"id":"workshop","name":"木工工房","position":Vector2(-5,-73),"need":84,"area":1},
 {"id":"high_bridge","name":"高原への橋","position":Vector2(6,-110.5),"need":120,"area":1}
]
const UPGRADE_NAMES = {"axe":"伐採威力","cut_range":"伐採範囲","collect_range":"収集範囲"}
const BASE_PRICES = {"axe":90,"cut_range":60,"collect_range":80}
const CUT_RADII = [1.62,2.6,3.6,4.6,5.6,6.6,7.6]
const COLLECT_RADII = [1.65,2.6,3.6,4.8,6.0,7.2,8.5]
const TOOL_NAMES = ["手斧","長柄斧","大なた","丸のこ","大型丸のこ","双刃ハーベスター","広域ハーベスター"]
const CARRY_CAPACITY = 128
const WALK_SPEED = 6.5
const MAX_LEVEL = 6
const MAX_GROUND = 160
const PLAYER_RADIUS = 0.34

static func in_area(p: Vector2, area: int, margin: float = 0.0) -> bool:
 if not AREAS[area].has_point(p) or not Geometry2D.is_point_in_polygon(p,PackedVector2Array(OUTLINES[area])): return false
 if margin>0:
  for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   if not Geometry2D.is_point_in_polygon(p+d*margin,PackedVector2Array(OUTLINES[area])): return false
 for lake in LAKES:
  var radius=lake.size*0.5+Vector2.ONE*margin
  var offset=(p-lake.get_center())/radius
  if offset.length_squared()<1.0: return false
 for rock in ROCKS:
  if p.distance_to(Vector2(rock.x,rock.z))<2.2+margin: return false
 return true

static func corridor(p: Vector2) -> bool:
 # Broad valley floor and working aisles are deliberately clear for transport.
 if absf(p.x)<2.1 or (absf(p.x-6)<2.1 and p.y<-103): return true
 for area in 3:
  if absf(p.x-AISLES[area])<1.1 and absf(p.y-CAMPS[area].y)<24: return true
  if absf(p.y-CAMPS[area].y)<1.8 and p.x>=CAMPS[area].x-2 and p.x<8: return true
  for row in [-8.0,-14.0,-20.0]:
   if absf(p.y-CAMPS[area].y-row)<1.0 and absf(p.x-AISLES[area])<5: return true
 return false

static func height_at(p: Vector2) -> float:
 # The trade valley stays level; the forest floor climbs into broad hills.
 var valley=smoothstep(7.0,28.0,absf(p.x))
 var hills=1.0+1.4*sin(p.x*0.055+p.y*0.022)+0.9*cos(p.y*0.06-p.x*0.018)
 var height=valley*maxf(0.25,hills)+(smoothstep(125.0,205.0,-p.y)*valley*2.0)
 for camp in CAMPS:
  height*=smoothstep(5.0,10.0,p.distance_to(camp))
 for lake in LAKES:
  var r=((p-lake.get_center())/(lake.size*0.5)).length()
  height=lerpf(-1.6,-0.66,smoothstep(0.6,1.0,r)) if r<1.0 else lerpf(-0.66,height,smoothstep(1.0,1.35,r))
 return height

static func point(p: Vector2, up: float = 0.0) -> Vector3:
 return Vector3(p.x,height_at(p)+up,p.y)

static func surface(p: Vector2) -> Basis:
 var dx=Vector3(1,(height_at(p+Vector2(0.2,0))-height_at(p-Vector2(0.2,0)))/0.4,0).normalized()
 var dz=Vector3(0,(height_at(p+Vector2(0,0.2))-height_at(p-Vector2(0,0.2)))/0.4,1).normalized()
 var normal=dz.cross(dx).normalized()
 return Basis(dx,normal,dx.cross(normal)).orthonormalized()

static func quality(p: Vector2) -> int:
 var distance=p.distance_to(SALE)
 return 2 if distance>=135 else (1 if distance>=58 else 0)

static func building_rects() -> Array:
 var result=BUILDINGS.duplicate()
 for p in CAMPS: result.append(Rect2(p+Vector2(-1.6,-3.8),Vector2(3.2,2.2)))
 # Depot structures sit beside the loading circle.
 for p in [Vector2(0,13),Vector2(0,-66),Vector2(6,-157)]: result.append(Rect2(p+Vector2(-4.2,2.9),Vector2(2.8,2.6)))
 return result

static func tree_layout() -> Array:
 var result=[]
 # Accessible first grove and three reliable groves for the autonomous cutters.
 for z in [3.1,-0.2,-3.6]:
  for x in [-6.3,-3.4,3.4,6.3]: result.append({"position":Vector2(x,z),"kind":0})
 for area in [1,2]:
  for z in ([-53.0,-58.0,-84.0] if area==1 else [-131.0,-145.0,-176.0]):
   for x in [-3.4,3.4]: result.append({"position":Vector2(x,z),"kind":area})
 for area in 3:
  for row in [-8.0,-14.0,-20.0]:
   result.append({"position":Vector2(AUTO_TREE_X[area],CAMPS[area].y+row),"kind":area})
 # Deterministic irregular groves, with clear river banks and a traversable valley.
 var centers=[[Vector2(-30,23),Vector2(27,-13),Vector2(12,43),Vector2(-22,-20)],
 [Vector2(-39,-80),Vector2(33,-68),Vector2(25,-94),Vector2(-10,-98)],
 [Vector2(-40,-161),Vector2(18,-145),Vector2(-24,-193),Vector2(47,-196)]]
 for area in 3:
  for cluster in centers[area]:
   for row in range(-3,4):
    for col in range(-3,4):
     var seed_value=area*307+row*73+col*43+roundi(cluster.x)*13
     if posmod(seed_value,4)==0: continue
     var p=cluster+Vector2(col*4.1+sin(seed_value*1.7)*0.9,row*4.3+cos(seed_value*0.9)*0.9)
     if not in_area(p,area,2.0) or corridor(p): continue
     var clear=true
     for rect in building_rects():
      if rect.grow(2.0).has_point(p): clear=false
     for project in PROJECTS:
      if p.distance_to(project.position)<3: clear=false
     for existing in result:
      if p.distance_to(existing.position)<3.1: clear=false;break
     if clear: result.append({"position":p,"kind":area})
 return result

static func porter_route(area: int) -> Array:
 var camp=CAMPS[area]
 if area==0: return [camp,Vector2(0,camp.y),SALE]
 if area==1: return [camp,Vector2(0,camp.y),Vector2(0,9),SALE]
 return [camp,Vector2(6,camp.y),Vector2(6,-106),Vector2(0,-106),Vector2(0,9),SALE]
