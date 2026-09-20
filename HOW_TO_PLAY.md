# How to Play Heavenly

**Heavenly** is a side-view skiing game built around a terrain-park jump. Your
goal is to control your speed and route down the slope, launch from the ramp,
perform a trick, and land safely for a high score.

Although the game looks side-on, you can also move across the width of the
slope, giving it a 2.5D feel.

## 1. Approach the Ramp

Your route determines how fast you reach the jump:

- Hold **Right** to point straight downhill and gain the most speed.
- Press **Up** or **Down** to carve across the slope and slow down.
- Point partly or fully left to travel uphill and lose even more speed.
- Hold **A** to tuck, reducing air resistance and increasing speed. Tucking
  makes steering harder.
- Hold **Y** to carve more sharply, at the cost of speed.
- Hold **B** to perform a strong speed check or brake.

Movement is momentum-based. The joystick tells the skier which direction to
turn toward, but it does not instantly move or stop them.

## 2. Prepare the Jump

The blue **X** button controls compression and pop:

1. Hold **X** while approaching the ramp to compress.
2. Release **X** close to the lip to pop.
3. Good timing produces a stronger upward launch.
4. Releasing too early gives a weaker pop.
5. Holding too long provides little benefit and makes the takeoff less balanced.

You still leave the ramp if you miss the pop. Your actual speed, direction,
ramp angle, and pop timing determine the jump rather than a scripted launch.

## 3. Perform a Trick

Once airborne, the skier follows a fixed path determined at takeoff. You cannot
steer through the air or change where you are going to land.

You can control the skier's rotation and pose:

- **Left/Right:** Apply backward or forward rotation.
- **Down:** Compact the body and rotate faster.
- **Up:** Extend the body and rotate more slowly.
- **A:** Perform the signature grab.
- **X:** Tweak an active grab.
- **B:** Release the grab, slow the rotation, and prepare to land.

Rotation has momentum. Releasing the joystick does not immediately stop a flip,
and pushing the opposite direction must first overcome the existing spin.

A grab only begins from a fresh press after takeoff. Holding **A** to tuck before
the jump will not accidentally start a grab in the air.

## 4. Land the Jump

The game judges the skier at the first moment they touch the landing. It
considers:

- How closely the skis match the landing slope.
- How hard the skier hits the ground.
- Whether their movement matches the slope direction.
- How quickly they are still rotating.
- Whether they released the grab.
- Whether they prepared for landing.
- Whether they landed inside the valid landing area.

The possible results are:

- **Perfect:** Almost exactly aligned, with a gentle and controlled impact.
- **Clean:** Slightly misaligned, but safely controlled.
- **Sketchy:** A rough but recoverable landing.
- **Crash:** Bad angle, excessive impact, body-first contact, or landing outside
  the valid area.

Holding **B** for landing prep applies a small angle correction. It is enough
to help a controlled attempt, but it will not rescue a badly mistimed trick.

## 5. Score the Jump

The score combines:

- Approach speed.
- Alignment at takeoff.
- Pop timing.
- Airtime.
- Completed rotations.
- Grab duration.
- Tweak duration.
- Grab release timing.
- Landing quality.

Only complete physical rotations count. The game measures how far the skier
actually rotated instead of awarding a trick based on how long a button was
held.

Landing quality acts as a multiplier:

- Better landings preserve more of the trick's value.
- Difficult, clean tricks should beat simple straight jumps.
- Crashes always score zero.

After landing, the game displays a breakdown so you can understand why the
attempt succeeded, failed, or earned its score.

## Gameplay Loop

1. Choose a line down the slope.
2. Use carving, tucking, and braking to reach the right speed.
3. Compress and time the pop at the ramp.
4. Control a flip and optionally perform a grab.
5. Release the trick and align with the landing.
6. Receive a landing result and score.
7. Immediately restart and try again.

## First-Playable Scope

The initial version is intentionally small:

- One skier.
- One player.
- One approach, ramp, and landing.
- One fully implemented grab.
- Immediate retries.
- No rails, halfpipes, upgrades, progression, or online features.
- No complete three-jump event yet.
- Two-player play comes later, after the one-player physics are reliable.

The focus is to make one jump deep, predictable, and skill-based rather than
building a large course with simplified physics.
