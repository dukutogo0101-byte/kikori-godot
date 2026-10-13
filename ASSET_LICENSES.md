# Asset provenance and licenses

| Asset | Source | License | Changes |
|---|---|---|---|
| Snow islands, three tree species, protagonist, axe, backpack, bridges, workshop, props | Original mesh construction in `scripts/art.gd` | MIT (`LICENSE`) | Created for KIKORI; reusable faceted geometry with baked vertex colors |
| Material palette, UI, SVG icon | Original project files | MIT (`LICENSE`) | Created for KIKORI |
| Short sound effects | Original synthesis in `scripts/adventure/feedback.gd` | MIT (`LICENSE`) | Generated sine-wave PCM, no recorded samples |
| `assets/fonts/KikoriSans.otf` | Noto Sans CJK Japanese, from Debian's `fonts-noto-cjk`; upstream https://github.com/notofonts/noto-cjk | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) | Subset with `tools/subset_font.py` to project UI glyphs and renamed Kikori Sans; copyright and license records retained |
| Godot editor and export templates (build tools, not source assets) | https://github.com/godotengine/godot-builds/releases/tag/4.5.2-stable | MIT; Godot third-party notices apply | Official unmodified distributions, SHA-256 verified |

Godot license and third-party credits: https://godotengine.org/license/ and https://github.com/godotengine/godot/blob/4.5.2-stable/COPYRIGHT.txt . Exported runtime includes Godot's notices.

No models, textures, characters, logos, or sounds from Lumber Inc, Whiteout Survival, or Hatchable are included. The reference is a gameplay inspiration only. External model packs were not introduced where the download/license could not be confirmed; the original art uses tapered branching meshes, faceted crowns, detailed architectural geometry and a consistent material palette instead.
