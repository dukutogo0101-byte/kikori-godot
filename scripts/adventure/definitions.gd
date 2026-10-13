extends RefCounted
# Coordinates are (world X, world Z); clear paths run down the middle of each island.
const SPAWN = Vector2(0, 10)
const AREAS = [Rect2(-18, -7, 36, 24), Rect2(-18, -26, 36, 16), Rect2(-18, -45, 36, 16)]
const BRIDGES = [Rect2(-1.6, -10, 3.2, 3), Rect2(4.4, -29, 3.2, 3)]
const SALE = Vector2(4, 9)
const BUILDINGS = [Rect2(2.5, 5.2, 3.4, 2.2), Rect2(-7, -22.5, 4, 2.5)]
const MARKETS = [
 {"name": "拠点売り場", "position": SALE, "area": 0},
 {"name": "東の売り場", "position": Vector2(12, 9), "area": 0},
 {"name": "琥珀の売り場", "position": Vector2(12, -11), "area": 1},
 {"name": "銀の売り場", "position": Vector2(12, -30), "area": 2}
]
const CAMPS = [Vector2(-12, 9), Vector2(-12, -11), Vector2(-12, -30)]
const AREA_NAMES = ["雪松", "琥珀", "銀"]
const AUTOMATION = {
 "camp": {"name": "自動伐採所", "price": 180, "description": "木こりが伐採し、倉庫へ運ぶ"},
 "porter": {"name": "運搬係", "price": 140, "description": "倉庫から売り場へ運び、自動売却"},
 "mill": {"name": "製材設備", "price": 320, "description": "この森の木材の売値を25%ずつ増加"}
}
const AUTO_MAX_LEVEL = 3
const KINDS = [
 {"name": "雪松", "hp": 3, "yield": 3, "value": 10, "regrow": 32.0},
 {"name": "琥珀カラマツ", "hp": 7, "yield": 4, "value": 24, "regrow": 40.0},
 {"name": "銀の白樺", "hp": 12, "yield": 5, "value": 50, "regrow": 48.0}
]
const PROJECTS = [
 {"id": "bridge", "name": "森への橋", "position": Vector2(0, -5.1), "need": 60, "area": 0},
 {"id": "workshop", "name": "木工工房", "position": Vector2(-5, -19), "need": 84, "area": 1},
 {"id": "high_bridge", "name": "白樺への橋", "position": Vector2(6, -24.5), "need": 120, "area": 1}
]
const UPGRADE_NAMES = {"axe": "斧", "pack": "リュック", "boots": "靴"}
const BASE_PRICES = {"axe": 90, "pack": 60, "boots": 80}
const MAX_LEVEL = 6
const MAX_GROUND = 160
const PLAYER_RADIUS = 0.34

static func legacy_tree_layout() -> Array:
 var result = []
 for area in 3:
  for row in 3:
   for column in 4:
    var x = [-6.3, -3.4, 3.4, 6.3][column]
    var z = [3.1, -0.2, -3.6][row] if area == 0 else ([-12.8, -16.1, -23.1][row] if area == 1 else [-31.8, -36.1, -41.1][row])
    if area == 1 and ((column == 0 and row < 2) or (column == 3 and row == 2)):
     continue
    result.append({"position": Vector2(x, z), "kind": area})
 return result

static func tree_layout() -> Array:
 # Keep the legacy prefix and tree IDs stable for version-2 saves.
 var result = legacy_tree_layout()
 for area in 3:
  var rows = [3.1, -0.2, -3.6] if area == 0 else ([-16.1, -19.6, -23.1] if area == 1 else [-35.0, -38.5, -42.0])
  for z in rows:
   for x in [-13.5, -10.0, 10.0, 13.5]:
    result.append({"position": Vector2(x,z), "kind": area})
 return result

static func building_rects() -> Array:
 var result = BUILDINGS.duplicate()
 for i in range(1,MARKETS.size()):
  var p = MARKETS[i].position + Vector2(0,-2.7)
  result.append(Rect2(p-Vector2(1.7,1.1),Vector2(3.4,2.2)))
 for p in CAMPS:
  result.append(Rect2(p+Vector2(-1.6,-3.8),Vector2(3.2,2.2)))
 return result
