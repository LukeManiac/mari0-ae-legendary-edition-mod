# Mari0 AE — Legendary Edition Mod

**Legendary Edition** is a community-made expansion and modification for **Mari0 AE**, created by **LukeManiac**.

The project expands Mari0 AE with new gameplay systems, playable characters, enemies, Course Maker content, visual effects, shaders, sounds, languages, loading presentation, controller support, and a wide range of gameplay and quality-of-life changes.

> **Compatibility:** Mari0 AE v13.2 with LÖVE 11.5.

---

# 📖 Contents

* [About](#about)
* [What's New](#whats-new)
* [Initial Release](#initial-release)
* [Nitpicks](#nitpicks)
* [Changelog](#changelog)
* [Requirements](#requirements)
* [Installation](#installation)
  * [Option 1: Using the .exe File](#option-1-using-the-exe-file)
  * [Option 2: Using the .love File](#option-2-using-the-love-file)

* [Features](#features)
  * [Gameplay](#gameplay)
  * [Course Maker](#course-maker)
  * [Loading and Presentation](#loading-and-presentation)

* [Development Environment](#development-environment)
* [Credits](#credits)
* [Contributing](#contributing)
* [AI Policy](#ai-policy)
* [Disclaimer](#disclaimer)

---

# About

Legendary Edition is designed as an expanded version of Mari0 AE, building upon its existing gameplay and systems while introducing additional content and refinements.

The project is primarily written in **Lua** and uses **LÖVE 11.5**.

The project covers a broad range of Mari0 AE systems, including:

* Player movement and physics
* Characters
* Enemies
* Power-ups
* Course Maker
* Menus
* Loading presentation
* Shaders
* Audio
* Languages

---

# What's New?

* 🧭 Toggleable player coordinate display with F9 and `showplayercoords`
* 🐛 In-game hitbox debugging outside the editor
* 📢 Loading overlays for specific game operations
* ⚡ Removed the intentional one-second pre-intro loading delay
* ✨ Change shaders while playing
* 🦖 Improved Yoshi walk animation, thanks to WilliamFrog
* 🎞️ Improved animation number display with `LCtrl+0` and `viewanimationnumbers`
* 🗂️ Optional removal of the mappack's `editor` folder previews with `noeditorpreviews`
* 🧹 Removed obsolete nitpicks including `FamilyFriendly` and `fourbythree`
* ⏸️ Custom pause menu animations
* 🔊 Optimised sound loading with the new `newsound` function
* 🎵 New and improved sound effects
  * `intro.ogg`
  * `key.ogg`
  * `keyopen.ogg`
  * `oneup.ogg`
  * `fireball.ogg`
  * `raccoonswing.ogg`
  * `boomerang.ogg`
  * `freeze.ogg`
  * `iceball.ogg`
  * `iceballhit.ogg`
  * `iceblockbreak.ogg`
  * `melt.ogg`
  * `helmet.ogg`
  * `helmetspike.ogg`
  * `helmetremove.ogg`
  * `magic.ogg`
  * `raccoonplane.ogg`
  * `dialog.ogg`
  * `beep.ogg`
  * `drybonesshell.ogg`
  * `error.ogg`

Vertical camera seeking has also been reduced to help prevent the player from being left off-screen when attempting to camera-seek vertically.

**The rest of the Lua files have also been tweaked and improved**, meaning the changes are not limited to the systems listed above.

---

# Initial Release

The first release of **Legendary Edition**, a community-made expansion and modification for **Mari0 AE** by **LukeManiac**.

### 🧩 New Features

* You can now set a numerical value for the player's walking animation.
* You can open `nofunallowed` mappacks by opening the editor while holding **LCtrl+LShift**.
* Added the `showtime` nitpick, which displays the current time. It can be toggled with **F7**.
* Added the `showbattery` nitpick, which displays the battery status. It can be toggled with **F8**.
* Added the `nocustomenemybg` attribute for custom enemies.
* Custom enemies using `nocustomenemybg` no longer display the red fill rectangle behind them.
* This can be useful for custom enemies that work like, or use, a built-in entity.
* The feature only applies to custom enemies. It does not affect built-in enemies, as the functionality is handled within the `game.lua` condition checking `tablecontains(customenemies, tilenumber)`.

### ✨ Improvements

* Changed the invincibility blinking animation so it is partially akin to the animation in the **New Super Mario Bros.** series.
* Quick testing from the Course Maker plays the last half of the invincibility animation.
* Compressed the logic for handling dropdowns.
* Fixed an issue where the overlay wouldn't render when using your mouse.
* Improved Yoshi's walk cycle animation, thanks to WilliamFrog.
* Added a loading overlay that is displayed while save data is being loaded.
* Added a saving overlay that is displayed while game data is being saved.
* Improved the visual presentation and feedback during save-data operations.
* Added more loading messages to expand the loading presentation.
* Animation number debugging now requires pressing **LCtrl+0**.

### ❌ Removals

* Removed the annoying `"pipe not found"` spam that could repeatedly appear during character debugging.

### Note: These changes were made with Claude and Grok.

---

# Nitpicks

Set nitpicks in `alesans_entities/nitpicks.json`. Most are boolean options: use `true` to enable them. Settings assigned directly from the JSON keep their supplied value; an omitted setting is `nil`. `letterbox` is applied whenever its key exists, including when set to `false`. `dpifix` accepts `true` (use a scale factor of 2) or a number (use that scale factor). `androidversion` is copied into the Android setting when truthy. `persistenteditortools` is enabled by default when the file exists, and only the explicit value `false` disables it. The key `debugGraphs` uses that exact capitalisation.

- `dropshadow`: Forces drop shadows in loaded mappacks, outside the editor. Alias for `forcedropshadow`.
- `forcedropshadow`: Forces drop shadows in loaded mappacks, outside the editor. Alias for `dropshadow`.
- `assistmode`: Set the editor's initial Assist Mode value when Assist Mode has not already been initialised.
- `playmusicineditor`: Allows music to play in the editor.
- `disabletooltips`: Suppresses editor tooltips.
- `disablemouseinmainmenu`: Stops mouse movement from changing the main-menu selection; keyboard and joystick navigation remain available.
- `noportalgun`: Selects the classic player type.
- `mariomakergravity`: Uses the Super Mario Bros. maximum vertical speed.
- `dontpauseonunfocus`: Prevents the game from pausing when another window takes focus from it.
- `firebuttoncannonhelmet`: Fires the cannon helmet with the fire button instead of its automatic firing behaviour.
- `pipesineditor`: Loads pipe entities while editing a level.
- `noonlinemultiplayernames`: Hides online multiplayer names.
- `letterbox`: Set `letterboxfullscreen` to the supplied value, either `true` or `false`, when this key exists.
- `customportalcolors`: Uses the configured portal colours in single-player.
- `usebuttoncappy`: Triggers Cappy with the use button rather than the run button.
- `showplayercoords`: Displays each visible player's coordinates during gameplay.
- `alwaysnocustomenemybg`: Removes the background fill behind custom enemies.
- `showtime`: Displays the device's current local time.
- `showbattery`: Displays battery status and charge, when available.
- `showfps`: Displays the FPS counter.
- `infinitelivesmultiplayer`: Gives infinite lives in local multiplayer when there is more than one player.
- `slowbackgrounds`: Draws custom backgrounds as repeated tiles instead of using the static-background optimisation.
- `nomusic`: Disables music.
- `alwaysinfinitetime`: Starts with infinite time enabled.
- `alwaysinfinitelives`: Starts with infinite lives enabled.
- `centercamera`: Selects the centered camera mode when loading a mappack outside the editor.
- `render3d`: Enables 3D rendering.
- `viewhitboxes`: Draws object hitboxes.
- `viewanimationnumbers`: Displays animation numbers.
- `pcversion`: Disables Android mode and enables Android-safe settings.
- `hideandroidbuttons`: Hides the Android on-screen buttons.
- `androidversion`: When truthy, set the Android mode value to the supplied value, enable Android testing mode, and update the display scale.
- `debugGraphs`: When truthy, set the debug-graph value to the supplied value and display the FPS, memory, performance, and draw graphs.
- `console`: Opens the LÖVE console.
- `noexitconfirmation`: Skips the editor's exit confirmation.
- `persistenteditortools`: Enabled by default when the nitpicks file exists; set to `false` to stop carrying editor tool settings between editor actions.
- `persistenteditortoolslocal`: Saves editor tool settings to the current mappack's `editorsave.json`.
- `dpifix`: Set to `true` to double window dimensions when calculating the window size, or set a number to use it as the scale factor. Applies to resizable windows.
- `noeditorpreviews`: Hides mappack preview images in the editor.
- `displayhiddenenemiesinspawner`: Shows hidden enemy types in the editor's enemy spawner.
- `completelycenteredcamera`: Keeps the camera rigidly centered on the furthest player.
- `modernmultiplayercamera`: Centres the camera on the players' average position, focuses on the furthest player if they all go off-screen, and interpolates camera movement.
- `splitscreenmultiplayer`: Enables splitscreen in local multiplayer.
- `horizontalsplitscreenviewports`: Uses a top-and-bottom layout for two-player splitscreen.
- `hurrymode`: Plays the low-time music cue when the timer reaches its threshold.
- `hurrymodeskipfanfare`: Skips the low-time sound cue and uses fast music at 99 instead of waiting until the timer drops below 99. Requires `hurrymode`.
- `disabletransitions`: Skips fade and vignette transitions.
- `infinitefireballs`: Removes the limit on how many fireballs, hammers, superballs, iceballs, boomerangs, and custom powerup projectiles the player can have active.

---

# Changelog

All notable releases and updates to **Legendary Edition** are documented here.

## v1.2.2

### 🧩 New Features

* Daily challenges use built-in graphics and sounds unless the selected mappack has `overridegraphics` or `overridesounds` active, respectively. The legacy `overrideassets` setting enables both.
* Added the `infinitefireballs` nitpick, which removes the limit on active fireballs, hammers, superballs, iceballs, boomerangs, and custom powerup projectiles.
* Added four keybind slots for each control, so keyboard and controller inputs can be mixed and matched.
* Maximised controller support, including joystick buttons, hats, and axes.
* Added a new "Generate Nitpicks File" button to the menu's misc tab.
* Added animations for confirmations in editor, and a three-stage warning to confirm resetting all settings.
* Added downscaling for viewports (may look funny when window scale is 3).

### 🐛 Bug Fixes

* Fixed keyboard navigation in the controls menu so the Pause binding is reachable when moving through controls with mouse aiming on or off.
* Fixed music getting stuck on a paused intro after quitting to the menu. The next song now plays without needing to pause the game.
* Fixed the minimap toggle so opening and closing the minimap animates its visibility without incorrectly animating the editor panel.
* Fixed an issue where the rightclick menu was unable to interact with.
* Fixed the rising water graphic glitch.
* Fixed a confusing mechanic where autodelete-able enemies would instantly vanish when a player died in multiplayer splitscreen.

### ✨ Improvements

* Moved **Pause** into the always-visible controls list. **Aim X**, **Aim Y**, **Portal 1**, and **Portal 2** remain available when the selected player does not use the mouse.
* In splitscreen multiplayer, player coordinate labels appear only in that player's viewport.
* Running into a horizontal autoscroll border sets your speedx to 0 if you're grounded.
* As soon as you enter the water or fall while underwater, your animation frame and progress resets.
* Underwater checking is executed per frame even when you are climbing on a vine or fence.
* Ditching a wearable now dismounts instead of kills it.

### ❌ Removals

* Removed `freezefade` and `editorzoom` nitpicks as there were too many bugs.

**Note:** The four-keybind system remains compatible with original Mari0 AE save data and does not negatively affect it.

## v1.2.1

### 🧩 New Features

* Added the mappack `disabletransition` setting, which instantly completes transitions between maps during gameplay. It can be managed in the Course Maker with the **Skip trans.** setting. Editor transitions, including transitions while testing a level, remain enabled.
* Tanooki Mario enters statue mode when you press **Run** while holding **Down**. Release **Run** to exit statue mode.
* The editor panels fade in while zooming in when opened, and fade out while zooming out when closed. Each transition lasts half a second and uses a random motion curve.

### 🐛 Bug Fixes

* Level screens now fade to black before loading the next map.
* Selecting a map in the editor now fades the full screen to black before loading.
* Pipe entries without a matching exit marker now use a vignette transition centered on the player's spawn animation.
* Level music now resumes when fast star music ends.
* Objects marked for instant deletion are removed immediately.
* Enemies with `xrelativetocamera` and/or `yrelativetocamera` now stick perfectly to the camera each frame. Both their graphic and hitbox stay at the specified camera-relative position without lag.
* Fixed a bug that let Mario midair-jump after bouncing off an enemy while wearing a Goomba shoe, stiletto, or dry bones shell.

### ✨ Improvements

* The `freezefade` nitpick pauses gameplay updates during fade and vignette transitions. Only the logic objects listed below, and objects linked to them, continue updating.
* Transition logic objects pause while the screen fades to black, but continue updating during the fade back in and vignette zoom-out.
* Mario can now turn around in midair while wearing a Goomba shoe, stiletto, or dry bones shell, without changing ground turning behaviour.
* Map-load animations now execute immediately when the map loads.
* GUI objects cannot be hovered while the editor panels are closed or animating, and editor tooltip timers reset when the panel view is toggled or unavailable.
* The selected tile or enemy preview remains visible behind the editor panels during their animation, with its opacity fading in the opposite direction to the panels.
* With `completelycenteredcamera` enabled, the camera now interpolates when a player dies. With `completelycenteredcamera` or `modernmultiplayercamera` enabled, it also interpolates when a player moves through a portal.
* Off-screen player markbases now show an expanded viewrange and nearby entities.
* With `completelycenteredcamera` or `modernmultiplayercamera` enabled, player teleportation executed by custom enemies or animation `setx`/`sety` actions now use the same camera interpolation as portal travel.

**Note:** The logic objects that continue updating are NOT gates, AND gates, OR gates, RS flip-flops, music changers, wall indicators, region triggers, and collectable locks. Objects linked to these logic objects, and objects they are linked to, also continue updating.
**Disclaimer:** GitHub Copilot also contributed to these changes, using the GPT-6 Luna model.

## v1.2.0

### 🧩 New Features

* New nitpick `displayhiddenenemiesinspawner`, you already know what it does. Use with caution!
* New nitpick `completelycenteredcamera`. This nitpick makes the camera rigidly centered on the furthest player.
* New nitpick `modernmultiplayercamera`. This nitpick makes the camera concentrate on the average distance off all players. If they all go offscreen, the game focuses on the furthest player. Instead of rigidly setting camera position, the game interpolates it. The interpolation is executed when someone dies too.
* New nitpick `splitscreenmultiplayer`. THIS IS THE BEST FEATURE I APPROVE IN GAMING! YOU GET SPLITSCREEN GAMING INSTEAD OF ONE DAMN SCREEN! Want a wider viewrange? Turn on the `horizontalsplitscreenviewports` nitpick.
* Multiplayer warp handling is now akin to from Super Mario Maker 2.
* If a player enters a pipe/door that leads to a different map, all players have to enter that assigned pipe/door. Other warping objects are blocked.
* Added a music priority function. Priority list (starting with top priority): `[Mega Mushroom, Starman, P-Switch]`.
* Splitscreen is now an lua.
* Added transitions for changing scenes (exiting intro, toggling editor mode, selecting mappack, entering different maps, etc.)
* If a player loses its wearable, the wearable will roll backwards.
* The world selection cursor is now animated.

### 🐛 Bug Fixes

* Fixed an issue where camera boundaries aren't respected in splitscreen viewports.
* Onscreen object detection is now fixed for splitscreen viewports.

### ✨ Improvements

* Overlay rendering is now better as shaders are applied on it.
* Rigid camera centering now tracks uncrouched hitboxes.

## v1.1.5

### 🧩 New Features

* Added a log dumping system (alesans_entities/logs).
* If you attempt to index a nil value using setframe, it'll print `Failed to get " .. arg .. " from nil quadgroup.`.
* You can now force dump logs using **LCtrl+LShift+L**.
* Forgot to mention that the controls and cheats menu use the new GUI. Still working on the skins menu.

### 🐛 Bug Fixes

* If a character shrinks to super form while ducking, the offsetY and quadcenterY is now fixed to its ducking offsetY and quadcenterY.

## v1.1.4

### 🧩 New Features

* The volume setting is now an actual slider.
* The misc. menu is now replaced with dropdowns, checkboxes, and buttons, where appropriate.

### ✨ Improvements

* Sped up the pause menu animation.

### 🔜 Upcoming Features

* Controls, skins, and cheats menus might use the new GUI.

## v1.1.3

### 🧩 New Features

* Added a shared GUI animation system. Every GUI animation lasts 0.25 seconds and picks a random motion curve each time it starts.
* Checkboxes pop up slightly when hovered and bounce back in when toggled.
* Buttons grow slightly when hovered, their border colour fades toward the highlight colour, and they zoom in and back out when pressed.
* Dropdown lists now animate open and close instead of appearing instantly. The list is clipped to the revealed part and slides along with the animation.
* The scroll factor sliders in the Course Maker now push-zoom when you press them and retract when you let go, like buttons.
* The intro graphic, pause menu, and prompts now scale in using a random motion curve.
* Checkboxes use a tickmark now.

### ❌ Removals

* The dropdown arrow and the checkbox are now drawn with LÖVE's native graphics instead of image files.

**Note**: These changes were made with Claude and Grok.

## v1.1.2

### 🧩 New Features

* One player's death only plays the death sting, unless that's the last player standing.
* Added daily challenge fanfares.
* The editor now supports horizontal object scrolling.
* When you scroll through objects in the editor, the ones adjacent to your selection appear smaller the farther they are from it.
* The game now uses my favourite Super Mario Bros. remaster's audio: Super Mario Bros. Deluxe.

### ✨ Improvements

* Vertical scrolling is no longer dependent on the x-furthest player.
* Sometimes, flying as a bunny could keep your sprite on jumping because of `self.falling and self.speedy >= 0` so it's been changed to `self.falling and self.speedy > 0`.
* If the character has fall frames and was fluttering as Raccoon/Tanooki Mario, it would use the fall frames instead of jump frames.

### 🐛 Bug Fixes

* Something was up with Mario's colourables so I fixed it.

## v1.1.1 (Sonic update)

### 🐛 Bug Fixes

* Fixed the game crashing when block was hit while airborne and with speedx if you were specifically playing as Sonic.
* Invincibility timers have been tweaked. If you killed an enemy as Sonic, you won't be stuck on your invincibility animation.
* If you die, all music will be stopped every frame.

## v1.1.0

### 🐛 Bug Fixes

* Fixed the issue with screenshake which would only affect the HUD or the screen borders.

## v1.0.9

### 🐛 Bug Fixes

* Fixed intro text drawing inconsistency when the window was maximised.

### ✨ Improvements

* Updated the intro graphic.
* Added an icon to the `.exe` using rcedit.

## v1.0.8

### 🐛 Bug Fixes

* Fixed crash when downloading DLC.

## v1.0.7

### ✨ Improvements

* The enemy death roll animation only plays when the mappack uses Super Mario Maker physics **and** drop shadow.

## v1.0.6

### 🧩 New Features

* Added new shaders:
  * Anamorphic: Cinema lens look with 2.39 bars, a teal-and-orange grade, horizontal streaks from bright pixels and fine grain.
  * Bullet Time: Cold, desaturated slow-motion grade with a radial zoom smear and a dark vignette.
  * Dragan: Crushed portrait grade that sharpens, then overlays a high-pass layer for hard contrast.
  * Dreamy Glow: Soft bloom that blurs bright areas outward and adds them back, with a light pastel lift.
  * Drunk: The screen sways and breathes, with layered double vision and a slow wave rolling up the picture.
  * Gameboy: Four-shade green LCD look with Bayer dither, snapped to the pixel grid, plus a faint LCD grid.
  * Glitch: Mild tearing and colour split, plus vivid random squares that jump to a new layout every frame burst.
  * Heat Haze: Rising shimmer that strengthens toward the bottom, with a warm grade and a pulsing ember glow.
  * Hologram: Holoprojector look with a cyan cast, rolling scan bands, horizontal jitter and a little RGB split.
  * Lightning: Rare full-frame storm flashes, a jagged bolt down the screen, and a small UV kick on each strike.
  * Matrix: Digital rain over a green grade, with the head, trail and glyphs scrolling at the display rate.
  * Neon-chase: Wet neon night with teal shadows, magenta highlights, pixel rain and a few anamorphic bokeh specks.
  * Old-film: Sepia silent-movie look with gate weave, lamp flicker, grain, vignette, scratches and dust.
  * Pixel Grain: Posterises each channel to a few levels and hides the banding with ordered Bayer dither.
  * Poison: Sickly grade with a slow pulse and pixel bubbles rising through the frame.
  * Posterize: Photoshop-style posterize, splitting each 8-bit channel into equal tone ranges.
  * Snowfall: Three layers of pixel-sized flakes drifting down at different speeds over a cold blue grade.
  * Thermal: Brightness mapped from cold black-blue through purple, red and orange to hot yellow-white, plus sensor noise.
  * Tilt Shift: Toy-world look; the middle band stays sharp while the top and bottom blur, with extra saturation.
  * Underwater: Wave distortion, a deep blue-green tint, depth fade and drifting caustic light.
  * Vaporwave: Brightness mapped onto a navy-to-pink gradient, blended back in, with chromatic offset and scanlines.
  * VHS: Worn tape look with colour bleed, line jitter, a rolling tracking band, tape noise and soft scanlines.

### ✨ Improvements

* Pausing the game resets the selected option state.

## v1.0.5

### 🐛 Bug Fixes

* Fixed a bug with custom power-ups in mappacks that use Super Mario Maker physics.
* If you pick up two custom power-ups that have custom colours and the `fireenemy` property, then take damage, you now shrink to Big Mario as expected.
* You no longer keep the custom colours or the `fireenemy` property from the power-up you had before.
* Fixed enemies not showing their roll animation when killed in mappacks that use Super Mario Maker physics.
* The roll animation now plays even when `dropshadow` is turned off.

## v1.0.4

### 🐛 Bug Fixes

* Fixed Toad's off-palette running arms in his cape graphics.
* **THE GAME FINALLY DOESN'T CRASH WHEN RENDERING A SCISSORED OBJECT WITH SHADERS ENABLED! THIS IS A MOMENT IN HISTORY!**

## v1.0.3

### 🧩 New Features

* Resizable window scale is now set to 4.
* Fixed canvas size retrieval crashes.
* Added hidden options to the editor settings menu:
  * The camera can now be set to "forward only".
  * The coin limit can now be toggled.
  * You can now use only one-time save files (aka suspend files).

### **Important Note: You will be warned for using the features mentioned as it *could* ruin your mappack gameplay.**

## v1.0.2

### ✨ Improvements

* Changing controls, player skins, or any misc settings (scale, letterbox, shader, volume, vsync, or mappack folder) will now save the game immediately.
* Releasing the **Left**, **Right**, **A**, or **D** keys while changing player skin colours or portal hues now saves the game.
* WASD support has been enabled for changing skin colours and portal hues.
* The default mappack folder is now set to `alesans_entities`.

## v1.0.1

### ✨ Improvements

* Entering a pipe or door now unducks your character.
* Entering vertical pipes now keeps your animation on idle.
* You now exit the pipe faster when travelling to a different subzone.
* The pipe sound now plays when you exit the pipe too.
* If the player stomps off an enemy without having jumped beforehand, the animation state is now maintained only if the jump button isn't held or the mappack doesn't use Super Mario Maker physics.

### 🐛 Bug Fixes

* Fixed some iceball and ice block sound logic.

---

# Requirements

| Requirement  | Version |
| ------------ | ------- |
| **Mari0 AE** | v13.2   |
| **LÖVE**     | 11.5 or later (only needed for the `.love` file) |

The `.exe` file does not require LÖVE to be installed separately.

A clean Mari0 AE v13.2 installation is recommended as the base for Legendary Edition.

---

# Installation

Legendary Edition can be installed using either the **.exe** file or the **.love** file. Both are available from the project's **Releases** page.

## Option 1: Using the .exe File

Use this option if you are on Windows and want to run the game without installing LÖVE.

1. Open the repository's **Releases** page.
2. Download the Legendary Edition `.exe` file.
3. Place the `.exe` file in the **same directory as your original [Mari0 AE](https://forum.stabyourself.net/viewtopic.php?t=3636) game folder**.
4. Double-click the `.exe` file to launch the game.

> **Important:** Do **not** place the `.exe` file in the AppData folder (`C:/Users/<YOUR_USERNAME>/AppData/Roaming/mari0`). It must sit next to the original Mari0 AE game folder, not inside the AppData folder.

## Option 2: Using the .love File

Use this option if you already have LÖVE installed, or if you are on macOS or Linux.

1. Install **LÖVE 11.5 or later** from [love2d.org](https://love2d.org/) if you do not already have it.
2. Open the repository's **Releases** page.
3. Download the Legendary Edition `.love` file.
4. Launch the game by either:
   * Double-clicking the `.love` file (if `.love` files are associated with LÖVE on your system), or
   * Dragging the `.love` file onto the LÖVE executable, or
   * Running it from a terminal:

     ```
     love LegendaryEdition.love
     ```

     Replace `LegendaryEdition.love` with the actual name of the file you downloaded.

# Features

## Gameplay

Legendary Edition expands the core Mari0 AE gameplay experience with additional mechanics and systems.

Changes cover areas such as:

* Player movement
* Player physics
* Character abilities
* Portal interactions
* Power-ups
* Projectiles
* Weapons
* Gel
* Enemy interactions
* Collision behaviour
* Camera behaviour
* Water and environmental mechanics
* Moving objects
* Pipes and tubes
* Gameplay objects
* Scoring
* Controller input

---

## Course Maker

Legendary Edition expands the **Course Maker** with additional objects, systems and options.

### Course Maker additions include:

* Additional objects
* Additional gameplay elements
* Expanded object behaviour
* Additional configuration options
* Gameplay system integration
* Visual and audio additions
* Additional environment mechanics
* Tweaks to existing Course Maker systems

The Course Maker continues to build upon Mari0 AE's existing course-building framework.

This allows custom courses to make use of additional gameplay systems introduced by Legendary Edition.

---

## Loading and Presentation

Legendary Edition expands the presentation of the game while different parts of Mari0 AE are being loaded.

The loading experience can include:

* Loading messages
* Loading sounds
* Notifications
* Additional presentation elements
* Shader preparation
* Resource-related messages

These changes provide more information during the loading process and give the game's startup and loading stages additional presentation.

---

# Development Environment

Recommended development environment:

* **Mari0 AE v13.2**
* **LÖVE 11.5**
* A Lua-compatible code editor
* A clean working copy of the project

When making changes, preserve the existing directory structure so that assets and Lua systems remain correctly organised.

---

# Credits

Legendary Edition contains work from many contributors to the Mari0 and Mari0 AE communities.

* **LukeManiac** — Legendary Edition
* **Alesan99** — Mari0 AE / Awesome mod
* **Maurice Guégan** — Original Mari0 and substantial original code/content
* **Fakeuser** — Regular turrets
* **Automatik** — Poison Mushroom help
* **Superjustinbros** — SMB sprites
* **Qcode** — Code and advice
* **Trosh** — Raccoon sprites from SE
* **Galas** — Power-up sprites
* **Bobthelawyer** — Mario hammer physics code
* **KGK64** — Dry Beetle sprites
* **Skysometric** — Animated quad cache code from Mari0 SE Community Edition
* **Oxiriar** and **Toonn** — SMB3 item sprites
* **NH1507** — Toad and Toadette character sprites
* **HansAgain** — Portal sprites, Mario sprites, Banzai Bills and pneumatic tubes
* **Subpixel** — Bowser3, Rotodiscs, Ninji and Splunkin sprites
* **Critfish** — Overgrown portal sprites
* **Britdan** — Testing and miscellaneous GitHub contributions
* **MadNyle** — Propeller sound effect and Mega Mushroom
* **fußmatte** — Character/font work and Esperanto translation
* **HugoBDesigner** — Portuguese-Brazilian translation
* **Los** — Russian translation
* **qixils** — Automatic GitHub workflows and LÖVE 11.4 update
* **WilliamFr0g** and **Kant** — GitHub contributions

See the comments in `main.lua` for the in-source credit notice.

---

# Contributing

Contributions are welcome.

When contributing:

1. Keep changes focused and understandable.
2. Test changes using the supported Mari0 AE v13.2 / LÖVE 11.5 environment.
3. Preserve existing credits and attribution.
4. Document new gameplay features or Course Maker objects where appropriate.
5. Preserve the existing project structure.
6. Keep new assets in the appropriate resource directories.
7. Keep Lua systems organised around their relevant gameplay functionality.

---

# AI Policy

Legendary Edition is not against the use of AI. AI tools are allowed for light, supportive tasks, such as:

* Suggestions
* Idea development
* Creativity assistance
* Brainstorming
* Other small, supportive tasks

## Custom Enemies and AI

When it comes to **custom enemies**, majority of AI models are not capable for this category.

Most AI models usually write their own `customtimer` functions for custom enemies instead of using the game's existing `customtimer` code. This leads to compatibility issues and behaviour that does not match the game logic.

Because of this, AI-generated custom enemies are expected to be practically impossible in this project.

AI can potentially produce a correct `customtimer` code for a custom enemy. Despite this, an exceptional result requires excessive time and effort:

* Your prompt requires loads of references.
* Responses may need to be regenerated whenever a flaw is found.
* Every result still needs to be checked carefully so that it goes with the game logic.

In most cases, writing the custom enemy yourself is more reliable.

### General Rule

AI may assist with ideas, suggestions, and other small tasks, but **custom enemy code should be written and maintained by a human**.

Human-made custom enemies may still contain errors. Finding and fixing those errors is part of the development process; this helps ensure that each custom enemy works properly with the game's handling logic.

### Using AI for Custom Enemies

If you still want AI to create a custom enemy, you will need to give a capable AI such as Claude, Grok, or GitHub Copilot access to the game's source. Upload the source `.love` file, or use GitHub Copilot to provide access to the project folder. This gives the AI the code and context it needs to follow the game's existing logic.

Using AI for custom enemies is not recommended. Many custom enemies are created by humans, and human-written code is generally a more reliable approach for this project.

## About AI Detection

Even supposing that the game had a good AI detector, it still would not be completely reliable. Majority of AI detectors return random or inconsistent values, so their results should not be treated as proof of anything.

---

**In short:** AI can be a helpful assistant for small things, but it is not exactly capable of making custom enemies for this project.

# Disclaimer

Mari0 AE and the characters, artwork, audio, trademarks and other third-party material used by the project are not owned by this repository's creator.

Legendary Edition is a fan-made modification of Mari0 AE.

---

## 🎮 Mari0 AE — Legendary Edition

**Created by LukeManiac with contributions from the Mari0 AE community.**

**Mari0 AE v13.2 • LÖVE 11.5 • Lua**

---