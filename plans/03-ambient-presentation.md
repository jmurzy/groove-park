# Plan 03: Ambient presentation

## Goal

Turn the functional `GUNBARREL 25` mountain world into an ambient arcade attract mode that remains interesting without user interaction and prepares for a future playable run.

## Visual direction

- Establish a limited arcade-inspired color palette.
- Use authored pixel, vector, or low-resolution shader treatment consistently.
- Add depth through parallax, weather, light, and restrained camera movement.
- Avoid generic modern UI, glass panels, cards, and dashboard typography.
- Make the marquee a complementary cabinet surface rather than a status monitor.

## Ambient systems

1. Add a deterministic time-of-day cycle suitable for accelerated demonstration.
2. Add weather variations that do not imply live weather yet.
3. Add short attract-mode compositions such as mountain-wide, lift-focused, `GUNBARREL 25` title, and lap-countdown moments.
4. Add subtle environmental motion when lifts are closed.
5. Add optional ambient audio and simple arcade cues with independent volume settings stored locally.
6. Prevent burn-in by ensuring bright static elements move or vary over time.

## Marquee direction

Create a small sequence of marquee states:

- `GUNBARREL 25` hero title.
- Mountain activity pulse.
- Featured lift name and state.
- Abstract snowfall or contour animation.

The marquee sequence must tolerate removal at any point. No timing or state progression on the primary display may depend on it.

## Interaction

Keep the experience primarily ambient. If cabinet controls affect the scene, limit them to harmless arcade-like reactions such as changing a camera emphasis or triggering a short snow burst. Do not introduce menus or playable-run rules before a dedicated gameplay plan.

## Verification

1. Observe a complete attract-mode cycle on both displays.
2. Run for several hours and watch for repetition seams, memory growth, and visual burn-in risks.
3. Confirm audio remains optional and never blocks startup.
4. Disconnect the marquee before launch and confirm identical primary timing.

## Done when

The application feels like a fictional arcade game waiting to be played, remains engaging over a long idle period, and does not resemble a ski dashboard.
