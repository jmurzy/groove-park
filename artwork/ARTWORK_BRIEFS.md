## AI-generated asset briefs

### Reference rule for every generation

Attach the relevant supplied HEAVENLY reference images from the `artwork/` folder to every generation request.

> Match the attached game-screen reference exactly. The new asset must look native to that game, not like an interpretation of it. Do not add text, logos, watermarks, UI, or a background unless requested. Isolated assets must use true alpha transparency: every non-sprite pixel must be fully transparent (alpha 0). Never simulate transparency with a painted gray-and-white checkerboard, grid, gradient, vignette, floor, or any other fake background pattern. Do not bake scanlines or CRT effects into isolated sprites; the game applies those globally.

> Never draw, render, or bake a fake checkerboard into an isolated asset. A checkerboard is not transparency. Leave all non-sprite pixels empty with true alpha 0; the output must contain no visible background pixels at all.

Generate one approval sample before each complete set. Keep approved rider design, side-view camera, scale, palette, pixel density, lighting, outlines, and equipment anchors consistent across later generations.

### Priority 1 — riders

**Asset: `heavenly_park_skier_pose_set`**

> Use Image 1, `artwork/marquee/skiier_sprite.png`, as the only character reference. Create the same side-view pixel-art freestyle skier for `SkierView`: glossy blue helmet with white stripe, orange-yellow goggles, orange-red puffy jacket with dark-blue sides/backpack, dark-blue pants, green gloves, black poles with green tips, and red skis with yellow stripe. Keep character, skis, scale, body anchor, and ski contact/pivot anchor identical in every frame. Deliver 1024 x 1024 transparent PNGs under `artwork/players/skier/`, named `skier_<state>_f<index>.png`. The full body and skis must be centered and uncropped, with skis on the same horizontal baseline in every frame. Background pixels must be fully transparent (alpha 0); no solid black background, fake transparency pattern, snow, shadow, text, UI, scanlines, or CRT effect.
>
> Create these animation sets: neutral glide (3-4 looping frames with visible pole movement or ski shuffle); tuck (2 looping frames); carve uphill and downhill (2 looping frames each); compression (2-3 crouch frames ending in a hold); takeoff extension (1-2 frames); neutral air (2 looping frames); grab reach (1-2 frames) into grab hold (2 looping frames); grab tweak (1-2 frames); landing preparation (2 frames); deep landing compression (2 frames); sketchy recovery (3-4 looping wobble frames); crash (3-4 non-looping impact-to-settled frames); and celebration (2-4 frames). Keep rider movement restrained except where the state requires it. Equipment must remain legible through all rotation angles. Effects such as snow spray, shadows, and crash plumes are separate assets and must not be baked into the rider frames.

**Asset: `heavenly_park_snowboarder_pose_set`**

> Use Image 1, `artwork/marquee/snowboarder_sprite.png`, as the only character reference. Create the same side-view pixel-art freestyle snowboarder for a future `SnowboarderView`: glossy blue helmet with white stripe, orange-yellow goggles, brown ponytail, pink puffy jacket with dark-blue sides, dark-blue pants, blue gloves, and pink snowboard with a white top stripe. Never add ski poles. Match the skier animation contract and scale: neutral glide, tuck, heel/toe carves, compression, takeoff extension, neutral air, grab reach/hold/tweak, landing preparation, deep landing compression, sketchy recovery, crash, and celebration. Keep board and body anchors consistent across one shared 1024 x 1024 canvas. Use the same frame counts and looping/one-shot intent as the skier set where applicable. Deliver frames under `artwork/players/snowboarder/`, named `snowboarder_<state>_f<index>.png`. The full body and board must be centered and uncropped, with the board on the same horizontal baseline in every frame. Background pixels must be fully transparent (alpha 0); no solid black background, fake transparency pattern, snow, shadow, text, UI, scanlines, or CRT effect.

### Priority 2 — park

**Asset: `heavenly_big_air_course_set`**

> Using the relevant attached HEAVENLY reference images from the `artwork/` folder, create modular side-view pixel-art snow terrain for three big-air features: a forgiving table jump, a long technical jump, and an Olympic-scale final kicker. Include separate approach, lip, knuckle, landing, and runout pieces with quiet snow texture and readable edges. Deliver tile-compatible PNG layers without riders, crowds, logos, text, UI, collision guides, scanlines, or CRT effect.

**Asset: `heavenly_park_dressing_set`**

> Using the relevant attached HEAVENLY reference images from the `artwork/` folder, create side-view park flags, lane markers, pines, distant lift towers, safety fencing, a compact spectator group, and unbranded score structures. Deliver separate transparent pixel-art PNGs. Keep collision-critical terrain unobscured. No text, logos, riders, UI, scanlines, or CRT effect.

### Priority 3 — effects and results

**Asset: `heavenly_park_fx_set`**

> Using the relevant attached HEAVENLY reference images from the `artwork/` folder, create short transparent pixel-art animation sequences for carve spray, hard braking spray, takeoff burst, perfect landing spray, sketchy landing spray, and crash plume. Keep every effect compact enough that rider orientation and equipment contact remain visible. No rider, terrain, text, background, scanlines, or CRT effect.

**Asset: `heavenly_park_results_scene`**

> Using the relevant attached HEAVENLY reference images from the `artwork/` folder, create a 16:9 pixel-art results background showing the final big-air landing area at Lake Tahoe with a skier and snowboarder celebrating together. Leave the center-right visually quiet for runtime scores. No baked-in text, numbers, logos, medals, UI panels, scanlines, or CRT effect.

### Asset acceptance

- Approve one rider rotating over one jump in the actual camera before generating complete pose sets.
- First approve `SkierView` samples for neutral glide (4 frames) and grab
  reach/hold (3 frames total); this validates style, shared anchors, and
  animation readability before generating the full set.
- Confirm skis and snowboard remain readable at every 90-degree orientation.
- Confirm rider anchors do not wobble when animation frames change.
- Confirm every frame is on the agreed shared canvas with the agreed equipment
  contact/pivot anchor; reject frame-size normalization performed only in code.
- Confirm all background pixels are truly transparent (alpha 0). Reject a
  solid background copied from a marquee reference, as well as painted
  checkerboards, grids, gradients, vignettes, or other fake transparency.
- If a generation delivers a fake checkerboard or any opaque background, retain
  the file for review and request a corrected replacement; do not delete it
  unless explicitly instructed.
- Reject art that hides the lip, landing tangent, equipment, or rider orientation.
- Reject art that shares only a general winter theme rather than the supplied HEAVENLY style.
- Check transparency, pixel grid, scale, palette, outlines, and nearest-neighbor scaling in-engine.
- Verify true alpha by sampling border pixels: prompt wording alone does not
  reliably prevent baked checkerboard backgrounds, so every delivered frame
  must pass a border-pixel alpha check before acceptance.
- Build collision geometry, score text, trajectory tools, shadows, and changing UI in-engine.
