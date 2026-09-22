> [!CAUTION]
> **OUTDATED — archived in `plans/` for historical reference only. Do not use as source of truth.**

# Cabinet Tuning Record

Use this record for Milestone 10 on the physical Polycade Sente. Do not mark
the milestone complete from keyboard or macOS testing alone.

## Build Under Test

```text
Date tested:
Git commit / build:
Godot version:
Windows / AGS version:
Physics tick rate: 60 Hz
Course version: park-course-v1
Rules / tuning version: scoring-v1
```

## Device Findings

```text
P1 device name and ID:
P2 device name and ID:
Joystick event type (D-pad, axis, or both):
LT resting / pressed axis values:
RT resting / pressed axis values:
Shared EXIT behavior:
Shared SELECT behavior:
Shared START behavior:
```

Confirm every direction and action button on both stations. Record any
controller mapping difference here before changing the Input Map:

```text
P1 directions: pass / fail
P2 directions: pass / fail
P1 A, B, BLUE X, Y, LB, RB, LT, RT: pass / fail
P2 A, B, BLUE X, Y, LB, RB, LT, RT: pass / fail
Ergonomic findings:
Requested control changes:
```

## Player Tuning

Use the short instruction card in the game without verbal coaching beyond
asking the player to land a basic trick.

```text
New-player attempts to first landing:
New-player basic trick landed within three attempts: yes / no
Experienced-player low-speed line demonstrated: yes / no
Experienced-player target-speed line demonstrated: yes / no
Experienced-player high-speed line demonstrated: yes / no
Experienced-player pop variation demonstrated: yes / no
Experienced-player rotation variation demonstrated: yes / no
Steering findings for digital 8-way stick:
Button ergonomics findings:
Instruction-card comprehension findings:
```

## Render-Rate Checks

Run these on the cabinet build with the marquee active when available. The
commands below are equivalent local-development checks; they deliberately cap
rendering while the simulation continues at its fixed 60 Hz physics rate.

```text
just sente-low       # 30 FPS
just sente-target    # 60 FPS
just sente-high      # 120 FPS
```

```text
30 FPS: pass / fail; visual or input findings:
60 FPS: pass / fail; visual or input findings:
120 FPS: pass / fail; visual or input findings:
Marquee-active performance:
```

## Trace Replay

On macOS and the Windows cabinet build, run `just test`. It replays all
baseline traces at the recorded 60 Hz timestep and rejects a trace whose
course or tuning version does not match the active simulation.

```text
macOS baseline trace result:
Windows baseline trace result:
```

## Decision

```text
Known physics issues:
Ready for two-player foundation: yes / no
Tester:
```
