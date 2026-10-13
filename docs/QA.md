# Snow Trail verification

## Verification scope

The repository's current main is the old idle-management release. The direct-control adventure is on `feature/snow-lumber-adventure`, PR #1. No main update, merge or deployment is part of this change.

The managed local executor can run Godot headlessly but cannot bind a localhost TCP server. WebGL input, visual inspection and screenshots therefore run in the PR's GitHub Actions browser environment. Local Godot is 4.6.3; CI uses the pinned official 4.5.2 editor and export templates. Browser engines are Playwright 1.56 Chromium and WebKitGTK, using software rendering.

## Confirmed locally

- Direct movement → chop → collect → sell: 5 checks passed.
- Adventure suite: 142 checks passed, including a complete physical route with three upgrades, both bridges, workshop and all three resource species.
- Scene suite: 75 checks passed, including UI input exclusion, touch cancel/release, leaving the viewport, PC input reset, menu pause, and one hour of cosmetic updates with fixed pools.
- Web framebuffer guard test passed; Python tooling compiles.
- Save restore validates IDs, counts, harvest cycles, prices, construction contributions and money before committing state. Unsupported schemas and corrupt state are rejected without partial changes.

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

The final PR workflow verifies the full exported adventure; the latest Actions run is authoritative. Its `kikori-test-reports-chromium` / `kikori-test-reports-webkit` artifacts contains actual screenshots and per-engine JSON. Chromium's full route checks touch start/stop/cancel, PC movement, trunk and unbuilt-bridge collision, UI blocking, input resets, sale, all three upgrade types, partial construction/reload, bridge passage, harvesting and selling amber wood, persistent unlocks, rotation, corrupt saves and denied storage. WebKit checks the initial gameplay and save/UI/error paths. Visibility and blur cancellation include injected browser lifecycle events, not physical-device backgrounding.

## Bounded rendering

The scene starts with 170 direct children, including fixed pools of 24 flying logs/labels and 24 chips. One hour of repeated events leaves the child count unchanged; active effects settle to zero and pending pickup IDs retire. Ground/cargo are MultiMesh batches capped at 160 / 30 logical logs. Nearby foreground trees fade and lose their shadow temporarily to keep the protagonist visible.

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
