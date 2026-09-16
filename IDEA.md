# HEAVENLY

I have a Polycade Sente with two displays:

* A 1080p primary game display
* A separate secondary marquee display

I live near Heavenly Ski Resort and have access to live ski lift information through an API.

## The idea

When the Polycade isn't being used for games, I want it to become a fictional arcade game called **HEAVENLY**.

The goal is not to build a ski resort dashboard. It should feel like a tiny arcade game where the "gameplay" is watching the mountain.

From the Polycade AGS game selector, you should be able to:

1. Navigate to **HEAVENLY** with the joystick
2. Press A
3. Have HEAVENLY launch exactly like any other arcade game
4. Leave it running in the background as an ambient mountain display

There should be no obvious "app" UI, dashboards, settings screens, browser chrome, etc.

**It should feel like a fake arcade game that happens to have live information from a real mountain.**

## Visual direction

Think classic arcade game meets ski resort:

**HEAVENLY**

A stylized, animated representation of Heavenly Mountain fills the primary display.

The mountain is alive. Lifts animate, snow falls, terrain moves, and the scene changes over time.

Live lift data from the Heavenly API drives the world:

* Open / closed lifts
* Lift status changes
* Potentially lift names and other available data
* Periodic updates from the API

The secondary marquee should have its own animation and information, designed specifically for the narrower marquee display rather than simply mirroring the main screen.

The overall aesthetic should be **fun, nostalgic, arcade-like, and slightly fictional**.

It should look like something that could have existed as an arcade cabinet game, not like a modern web dashboard.

## Architecture

HEAVENLY needs to run as a normal DRM-free Windows game inside Polycade AGS.

Polycade's documented AGS structure is essentially a game folder containing an `.exe` with the same name as the folder.

Reference:

Polycade AGS: https://polycade.com/pages/download-polycade-ags

The Sente PC runs Windows 11 and has HDMI and DisplayPort outputs for the two displays.

The game therefore needs to:

* Run as a Windows executable
* Launch directly from Polycade AGS
* Support joystick / arcade controls where appropriate
* Render independently to the primary and marquee displays
* Run continuously without user interaction
* Fetch and periodically refresh live Heavenly data

## Technology

We should use a lightweight game-oriented framework rather than Electron.

Godot is one option, but I'm open to anything that gives us good performance and easy multi-display rendering.

Another possibility is a web-rendering approach using React + Canvas + Tauri if we can package it into a lightweight Windows executable without the overhead of Electron.

React Native for Windows is also worth considering if it gives us a good fit for the rendering and multi-display requirements.

The important thing is the experience, not the framework.

## Core principle

**Don't build a marquee dashboard that happens to run on a Polycade.**

Build a tiny arcade game called **HEAVENLY**.

The mountain is the game.

The live ski-lift data makes the mountain change.

The two displays are part of the arcade cabinet.

And when someone sees it sitting idle on the Polycade, it should look like an actual game waiting to be played.
