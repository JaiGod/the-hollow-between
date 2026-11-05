# Mobile Optimization Guide

## What's already done
- **Renderer:** GL Compatibility on every platform — widest device support, smallest overhead.
- **Resolution:** fixed 640×360 canvas with `canvas_items` stretch and `keep` aspect; scales cleanly to any screen with letterboxing. Pixel snapping + nearest filtering keep art crisp.
- **Bullets are plain objects**, drawn in one `_draw()` per frame — no node per projectile. 100+ bullets cost almost nothing.
- **Maps bake to a single texture** on load, so the overworld is one draw call for the ground.
- **Audio is generated once** and cached; total memory for all music is a few MB.
- **No physics engine** — overworld collision is tile lookups.

## Touch controls
`TouchControls.gd` uses `TouchScreenButton`s that press the same input actions as the keyboard. They only appear on touchscreens and change by context:
| Context | Shown |
|---|---|
| Exploring | D-pad, Z (talk), X (run/back), ≡ (menu) |
| Dodging in battle | D-pad, Z (jump in gravity zones) |
| Menus / dialogue | Hidden — tap buttons and the text box directly |

The fight bar accepts a tap anywhere above the menu. Test on desktop with `HOLLOW_TOUCH=1`.

## Tuning for low-end phones
- Lower weather particle `amount` in `Overworld._build_weather()` (40 → 20).
- `AudioManager.RATE` 22050 → 16000 halves audio memory.
- Pattern density scales with `difficulty`; an "Assist mode" setting can clamp it (planned).
- Keep `Project Settings → Application → Run → Low Processor Mode` off for the battle's smooth movement.

## Layout & safe areas
Phones with notches: the 16:9 canvas is letterboxed so UI never sits under a notch. If you switch to `expand` aspect for full-screen, anchor HUD elements using `DisplayServer.get_display_safe_area()`.

## Store checklist
- **Android:** target API 34+, AAB, 512×512 icon, feature graphic 1024×500, content rating questionnaire (mild fantasy violence), data safety form (no data collected).
- **iOS:** App Store icon 1024×1024, screenshots at 6.7" and 5.5", privacy nutrition label (no data collected).
- Screenshots: `docs/screenshots/` — regenerate at any size with `tests/Screenshots.tscn`.
