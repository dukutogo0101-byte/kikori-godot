extends RefCounted
# Coordinates are (world X, world Z); clear paths run down the middle of each island.
const SPAWN = Vector2(0, 10)
const AREAS = [Rect2(-9, -7, 18, 20), Rect2(-9, -26, 18, 16), Rect2(-9, -45, 18, 16)]
const BRIDGES = [Rect2(-1.6, -10, 3.2, 3), Rect2(4.4, -29, 3.2, 3)]
const SALE = Vector2(4, 9)
const BUILDINGS = [Rect2(2.5, 5.2, 3.4, 2.2), Rect2(-7, -22.5, 4, 2.5)]
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

static func tree_layout() -> Array:
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
