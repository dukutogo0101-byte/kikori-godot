# Snow Trail verification

## Verification scope

Main contains the direct-control adventure and expanded forests from PRs #1–#2. The roads and logistics expansion is validated below before publication.

This expansion was built locally with the pinned official Godot 4.5.2 and single-thread Web templates. The actual Web export is tested over HTTP using software rendering. Initial local Chromium gameplay/UI results used Playwright 1.56; the current CI pin is 1.64.0. Local WebKit was also made available for repeated-start and redraw diagnostics. Current browser results are recorded in Actions; physical audio devices are unavailable locally. Physical Android/iPhone performance is unmeasured.

## Confirmed locally

- Direct movement → chop → collect → sell: 5 checks passed.
- Adventure suite: 144 checks passed, including a complete physical route with three upgrades, both bridges, workshop and all three resource species.
- Scene suite: 83 checks passed, including UI input exclusion, touch cancel/release, leaving the viewport, PC input reset, menu pause, and one hour of cosmetic updates with fixed pools.
- Web framebuffer guard test passed; Python tooling compiles.
- Save restore validates IDs, counts, harvest cycles, prices, construction contributions and money before committing state. Unsupported schemas and corrupt state are rejected without partial changes.

## Expansion checks

- Automation suite: 69 checks passed, including exact purchase costs, prerequisites, regional production/delivery, storage withdrawal, in-transit cargo save/resume, hostile save rejection, progressed v2 migration and one hour of three automated forests.
- `tests/browser_expansion.py` passed on the actual Web export: fresh-save broad/maximum cameras, four markets / 69 trees, UI exclusion for the zoom button, purchases of all three equipment types through a scrolling modal, real automated sale, reload and portrait/landscape close controls. No console/page errors. The equipment scenario uses a validated earned-revenue fixture from the native tests; it does not claim those purchases were earned by browser play from zero.
- Visual inspection caught missing new Japanese glyphs. Regenerated the existing OFL font subset and verified the menu screenshots.
- Browser rotation regression exposed a queued-keydown race. The Web shell now tracks canceled DOM key codes; the controller rejects stale presses after resize/blur until release or a fresh key press. Browser checks wait for the actual resized viewport and zero velocity, rather than a fixed sleep.
- Export excludes reports and build directories so test images/fixtures are not shipped as game assets.
- Camera orthographic height: portrait 28 / 38, landscape 18 / 24. These are deliberate zoom levels, not world scale changes.

## Tempo measured by deterministic input

This test navigates routes at real game speed, repeatedly chops and collects, sells for upgrades and contributes wood. No time scale, currency grants or unlock commands are used in this route. Deliberation, reading and touch learning time are excluded.

| Milestone | Simulation time |
|---|---:|
| First tree | 4.17 seconds |
| First sale | 15.52 seconds |
| First upgrade (pack) | 19.40 seconds |
| First bridge | 189.82 seconds (3:10) |
| Workshop, second bridge and collecting silver birch | 707 seconds (11:47) |

The first two steps are deliberately quick for practiced input. A new player does not need to wait for funds to accumulate automatically. The first bridge and later landmarks satisfy the 3–5 minute / 10–15 minute progression goals in an efficient route. Actual browser input timing is recorded separately in `chromium-results.json` and `webkit-results.json`; software-renderer waiting time is not a mobile-device performance measurement.

## Browser evidence

The first minimal direct-control loop passed in both Chromium and WebKit, [run 38334797825](https://github.com/dukutogo0101-byte/kikori-godot/actions/runs/38334797825): 30 money earned, empty cargo, no console/page errors. This was an early prototype, before final presentation and progression.

The final PR workflow verifies the full exported adventure; the latest Actions run is authoritative. Its `kikori-test-reports-chromium` / `kikori-test-reports-webkit` artifacts contains actual screenshots and per-engine JSON. Chromium's full route checks touch start/stop/cancel, PC movement, trunk and unbuilt-bridge collision, UI blocking, input resets, sale, all three upgrade types, partial construction/reload, bridge passage, harvesting and selling amber wood, persistent unlocks, rotation, corrupt saves and denied storage. WebKit checks the initial gameplay and save/UI/error paths. Tab activation uses real browser pages where visibility changes are available; headless targets may remain visible, so blur and orientation cancellation also use browser events. No `document.hidden` override is used because it can desynchronize WebKit rendering. Canvas frame hashes must change after movement and carrying, preventing script-only false positives. Physical-device backgrounding remains unverified.

## WebKit presentation

The original shader-only final copy allowed scripts and the offscreen scene to update while the default WebKit drawing image retained the initial frame. A fresh-page movement probe caught this despite zero GL errors. Resolving via one reusable intermediate RGBA framebuffer made source and displayed pixel signatures match and the movement/carry frame hashes change. The production guard contains no debug pixel readbacks or extra shader programs. Safari-family contexts retain their drawing buffer. WebKitGTK evidence uses actual GPU framebuffer pixels because its compositor snapshot and canvas export may return a cached image. Chrome evidence uses normal page screenshots. Neither is physical iOS device certification.

## Bounded rendering

The expanded scene starts with 276 direct children, including fixed pools of 24 flying logs/labels and 24 chips. One hour of repeated events leaves the child count unchanged; active effects settle to zero and pending pickup IDs retire. Ground/cargo are MultiMesh batches capped at 160 / 30 logical logs. Nearby foreground trees fade and lose their shadow temporarily to keep the protagonist visible.

## Real-device acceptance still pending

| Check | Android Chrome | iPhone Safari |
|---|---|---|
| Cold load over mobile connection | Pending | Pending |
| One-handed touch, no stuck input after browser interruptions | Pending | Pending |
| Notch/toolbars, keyboard, portrait/landscape | Pending | Pending |
| Ten to fifteen minutes of real play and comfortable camera | Pending | Pending |
| Background / foreground / close-reopen preservation | Pending | Pending |
| Audio unlock and opt-in vibration | Pending | Pending |
| 30fps+ and stable memory on recent mid-range phone | Pending | Pending |

The game is optimized toward 30fps, but no physical-device frame rate, memory or thermal claim has been made. WebKitGTK tests the Safari-family engine; it is not iOS Safari certification. Storage may be cleared by private browsing, device cleanup or user action; unavailable storage leaves a playable in-tab session with a visible indicator.


## Roads and logistics

- Native logistics suite: 176 checks, including atomic road purchases, disconnected/locked terrain, occupied-road removal, two-stage delivery, cross-bridge transport preserving resource species, cargo reservation across competing carts and player deposits, exact transit save/resume, pause and route changes, old v3 migration, corrupt saves and one simulated hour with six carts.
- Scene tests exercise real screen touch/drag, preview without spending, cancel and editor exclusion of hero movement. A short landscape/square viewport exposed a toolbar overlap; editing controls now share the camera-button row.
- Browser coverage uses a native-validated earned-revenue fixture, purchases and configures two carts through the actual menu, waits for their sale, pauses after delivery, constructs roads with protocol touch input and explicit confirmation, cancels touch, rotates, and reloads. The fixture does not claim those setup funds were earned in-browser.
- Endpoint lists are rebuilt only when available facilities change; continuous refresh must not reset a keyboard or touch selection in an open picker.
- v4 validation accounts for all depot/cargo resource IDs, road and cart purchase costs, route geometry, depot capacity reservations and precise cart positions before committing a restored state. Existing storage key is preserved.
- Carts can share roads and pass each other; traffic simulation and signals are outside this version. The existing porter remains a direct-sale option.

## Startup hardening

Repeated WebKit startup diagnostics reproduced an intermittent engine crash during procedural mesh generation (`quad` → `box` → world setup), plus memory-access failures and corrupt compressed script/font loading. A successful single run was insufficient to establish reliable startup.

The Web build now loads 39 precomputed meshes and seven WAV resources. The pinned native Godot editor creates them before export from the same original geometry and synthesis code; native play retains procedural creation. The bake validates nonempty geometry/audio and asserts identical vertex arrays for every reused mesh key. Keys identify explicit model/scene parts rather than depending on construction order. Generated resources stay outside git and are rebuilt by `tools/build_web.sh`.

`tests/browser_boot.py` checks 40 fresh WebKit contexts in CI before the existing redraw probe and gameplay tests. Each run requires the current save schema, intact resource accounting and UI; any console/page error or failed start fails the job without a retry. Public deployment still requires both browser jobs.

The export uses text GDScript (`script_export_mode=0`), an uncompressed font import and uncompressed baked resources. Repeated diagnostic failures included invalid compressed tokenizer lengths, inconsistent vector indices and invalid FreeType data; this format avoids the affected runtime decompression paths. This is an observed compatibility workaround, not a claim about an upstream root cause. The pinned Godot version remains 4.5.2; comparison with 4.5.1 also reproduced an error.

The legacy Playwright 1.56 bundle (WebKit 26.0) also produced memory traps after this export-format change on CI, despite 60 successful local starts. Verification uses Playwright 1.64 and its current browser builds; the 40-start, redraw, gameplay and error assertions remain required. No compatibility claim is made for the older WebKitGTK build.
