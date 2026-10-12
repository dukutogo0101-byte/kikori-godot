# Phase 1 verification

## Confirmed locally

- The Godot 4 project imports and starts headlessly using the local 4.6.3 editor. CI builds and tests the pinned 4.5.2 release.
- Deterministic economy suite: **815 assertions, 0 failures**.
- Simulation covers production, regeneration, purchases, maximum levels, cooldown, conserved log counts, bounded stock, save validation/round-trip, capped offline progress and one hour of maximum upgrades.
- Python tooling compiles. Original assets and font provenance documented.

## Automated CI checks

The release Web export, all 815 simulation assertions, scene event checks, and Chromium/WebKit end-to-end tests passed in [Actions run 38229554117](https://github.com/dukutogo0101-byte/kikori-godot/actions/runs/38229554117). Both browser engines reported zero console/page errors and `gl.getError() == 0`; touch purchases, revenue, reload persistence, rotation and corrupt-save recovery passed. The exported payload is approximately 38.5 MB before compression (9.6 MB zipped).

After deployment, the workflow repeats the browser checks against the actual public HTTPS URL. See the latest Actions run and its `kikori-live-reports` artifact for publication verification. These tests use software-rendered browser engines, so their frame rates do not measure mobile-device performance.

## Real device acceptance checklist (pending physical devices)

| Check | Android Chrome | iPhone Safari |
|---|---|---|
| Open the deployed HTTPS URL and dismiss loading | Pending | Pending |
| Forest, shadows, trees, worker and truck visible | Pending | Pending |
| Observe a tree fall, truck delivery, saw processing, rising funds | Pending | Pending |
| Tap all three upgrade types and verify funds decrease | Pending | Pending |
| Boost works for 15 seconds and cooldown prevents repeat | Pending | Pending |
| Rotate, pinch, reset view | Pending | Pending |
| Reload restores upgrades and ongoing production | Pending | Pending |
| Background/return and close/reopen retain saved progress | Pending | Pending |
| Portrait/landscape, notch and browser toolbar do not hide controls | Pending | Pending |
| Sound toggles after a tap | Pending | Pending |
| Ten-minute play session without crash or sustained stutter | Pending | Pending |
| Storage blocked/private browsing produces a usable fallback | Pending | Pending |

Target performance: 30fps or better on a recent mid-range mobile device. This is a target, not a measured real-device result. The renderer avoids physics-heavy simulation, expensive post-processing, large texture assets and unbounded decorative objects. If a device is memory constrained, reload or close other tabs; if WebGL 2 is unavailable, the loading shell explains the limitation.
