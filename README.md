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

* 🎬 Replaced the intro graphic with the author's name (`authorname` in `variables.lua`), which scales in using a random motion curve
* 🌈 Intro text is now drawn per character with an oscillating colour based on `authorcolour`, offset by character index
* ⏭️ New `skipintro` nitpick, which skips the intro completely
* 🚫 Removed intro skipping and the intro fade-out; the intro now always plays to the end of its sound before transitioning to the menu
* 〰️ Strengthened the `drift_pull`, `arch`, `tidal`, `dip`, `crest` and `hook` motion curves, which were previously almost indistinguishable from linear
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
* Daily challenges use built-in graphics and sounds unless the selected mappack has `overridegraphics` or `overridesounds` active, respectively. The legacy `overrideassets` setting enables both.
* Added the `infinitefireballs` nitpick, which removes the limit on active fireballs, hammers, superballs, iceballs, boomerangs, and custom powerup projectiles.
* Added four keybind slots for each control, so keyboard and controller inputs can be mixed and matched.
* Maximised controller support, including joystick buttons, hats, and axes.
* Press **F6** on a selected keybind to reset that binding. Player 1 restores the default input; players 2–4 copy the same binding from the previous player on the current keybind page. A notice appears if **F6** is pressed in the controls menu while no keybind is selected.
* **Ctrl+F6** still resets, clears, or copies the full keybind page for the current player, matching the previous behaviour.
* The controls tooltip switches when **Ctrl** is held: without **Ctrl** it describes single-keybind **F6** reset (or copy-from-previous-player for players 2–4); with **Ctrl** it describes the full-page **Ctrl+F6** action.
* Each keybind page has its own mouse setting: `mouseowner` for page 1, `mouseowner2` for page 2, `mouseowner3` for page 3, and `mouseowner4` for page 4. The "uses the mouse" checkbox applies to the page you are editing. Aim and portal binds remain hidden on a page when that page's mouse owner is the selected player.
* These controls changes apply in both the options Controls tab and the pause menu controls popup.
* The game doesn't require you to press escape to pause the game, it now uses player-dependent controls.
* Added a new "Generate Nitpicks File" button to the menu's misc tab.
* Added animations for confirmations in editor, and a three-stage warning to confirm resetting all settings.
* Added downscaling for viewports (may look funny when window scale is 3).
* Luigi is no longer a basic recolour of Mario. He now has his own unique sprites.
* Added the poncho and aviator hats from Super Mario Odyssey.
* Pause menu and prompts are now scaled instead of scissored.
* You can now change controls midgame.
* Added custom categories for custom enemies. Set donotcategoriseenemyfolders to true to disable enemies being categorised by folders.
* Saving the game via pause menu no longer quits to menu.
* Added the mappack `disabletransition` setting, which instantly completes transitions between maps during gameplay. It can be managed in the Course Maker with the **Skip trans.** setting. Editor transitions, including transitions while testing a course, remain enabled.
* Tanooki Mario enters statue mode when you press **Run** while holding **Down**. Release **Run** to exit statue mode.
* The editor panels fade in while zooming in when opened, and fade out while zooming out when closed. Each transition lasts half a second and uses a random motion curve.
* New nitpick `displayhiddenenemiesinspawner`, you already know what it does. Use with caution!
* New nitpick `completelycenteredcamera`. This nitpick makes the camera rigidly centered on the furthest player.
* New nitpick `modernmultiplayercamera`. This nitpick makes the camera concentrate on the average distance of all players. If they all go offscreen, the game focuses on the furthest player. Instead of rigidly setting camera position, the game interpolates it. The interpolation is executed when someone dies too.
* New nitpick `splitscreenmultiplayer`. THIS IS THE BEST FEATURE I APPROVE IN GAMING! YOU GET SPLITSCREEN GAMING INSTEAD OF ONE DAMN SCREEN! Want a wider viewrange? Turn on the `horizontalsplitscreenviewports` nitpick.
* Multiplayer warp handling is now akin to from Super Mario Maker 2.
* If a player enters a pipe/door that leads to a different map, all players have to enter that assigned pipe/door. Other warping objects are blocked.
* Added a music priority function. Priority list (starting with top priority): `[Mega Mushroom, Starman, P-Switch]`.
* Splitscreen is now an lua.
* Added transitions for changing scenes (exiting intro, toggling editor mode, selecting mappack, entering different maps, etc.)
* If a player loses its wearable, the wearable will roll backwards.
* The world selection cursor is now animated.
* Added a log dumping system (alesans_entities/logs).
* If you attempt to index a nil value using setframe, it'll print `Failed to get " .. arg .. " from nil quadgroup.`.
* You can now force dump logs using **LCtrl+LShift+L**.
* The controls and cheats menu use the new GUI.
* The volume setting is now an actual slider.
* The misc. menu is now replaced with dropdowns, checkboxes, and buttons, where appropriate.
* Added a shared GUI animation system. Every GUI animation lasts 0.25 seconds and picks a random motion curve each time it starts.
* Checkboxes pop up slightly when hovered and bounce back in when toggled.
* Buttons grow slightly when hovered, their border colour fades toward the highlight colour, and they zoom in and back out when pressed.
* Dropdown lists now animate open and close instead of appearing instantly. The list is clipped to the revealed part and slides along with the animation.
* The scroll factor sliders in the Course Maker now push-zoom when you press them and retract when you let go, like buttons.
* The intro text, pause menu, and prompts now scale in using a random motion curve.
* Checkboxes use a tickmark now.
* One player's death only plays the death sting, unless that's the last player standing.
* Added daily challenge fanfares.
* The editor now supports horizontal object scrolling.
* When you scroll through objects in the editor, the ones adjacent to your selection appear smaller the farther they are from it.
* The game now uses my favourite Super Mario Bros. remaster's audio: Super Mario Bros. Deluxe.
* Added new shaders:
  * Anamorphic: Cinema lens look with 2.39 bars, a teal-and-orange grade, horizontal streaks from bright pixels and fine grain.
  * Bullet Time: Cold, desaturated slow-motion grade with a radial zoom smear and a dark vignette.
  * Cyberpunk: Night City grade: teal shadows, hot pink and yellow highlights, neon bloom, lens colour fringing and a rare glitch where a few bands of the picture tear sideways for a third of a second.
  * Dragan: Crushed portrait grade that sharpens, then overlays a high-pass layer for hard contrast.
  * Dreamy Glow: Soft bloom that blurs bright areas outward and adds them back, with a light pastel lift.
  * Drunk: The screen sways and breathes, with layered double vision and a slow wave rolling up the picture.
  * Dune: Arrakis grade: the picture becomes a single burnt-orange gradient from deep brown shadows to pale sand highlights, with a hazy lifted black, soft bloom, a slow heat ripple and windblown sand streaks.
  * FlipX: Flips the whole picture mirroring it left to right. Up and down stay the same, so the controls still feel normal.
  * FlipY: Flips the whole picture mirroring it top to bottom. Left and right stay the same, so the controls still feel normal.
  * Gameboy: Four-shade green LCD look with Bayer dither, snapped to the pixel grid, plus a faint LCD grid.
  * Glitch: Mild tearing and colour split, plus vivid random squares that jump to a new layout every frame burst.
  * Heat Haze: Rising shimmer that strengthens toward the bottom, with a warm grade and a pulsing ember glow.
  * Hologram: Holoprojector look with a cyan cast, rolling scan bands, horizontal jitter and a little RGB split.
  * Hotline: Hotline Miami trip: the whole screen sways, zooms on a ~130bpm beat, splits its colours on every hit and floods with shifting pink and cyan neon over boosted saturation and contrast.
  * Lightning: Rare full-frame storm flashes, a jagged bolt down the screen, and a small UV kick on each strike.
  * Limbo: Soft grey silhouettes in a cold fog: heavy shadows, light falling from above, ground mist, strong film grain and a dark vignette.
  * Matrix: Digital rain over a green grade, with the head, trail and glyphs scrolling at the display rate.
  * Neon-chase: Wet neon night with teal shadows, magenta highlights, pixel rain and a few anamorphic bokeh specks.
  * Old-film: Sepia silent-movie look with gate weave, lamp flicker, grain, vignette, scratches and dust.
  * Pip-Boy: Fallout terminal: bulging green phosphor tube with rounded black corners, banded tones, heavy scanlines, a slow rolling refresh band, glow and flicker.
  * Pixel Grain: Posterises each channel to a few courses and hides the banding with ordered Bayer dither.
  * Poison: Sickly grade with a slow pulse and pixel bubbles rising through the frame.
  * Posterize: Photoshop-style posterize, splitting each 8-bit channel into equal tone ranges.
  * Sin City: Crushed blacks, blown whites and one colour left alive: red. Everything else is pushed to hard black and white, with a faint halo around the brights, film grain and a heavy vignette.
  * Snowfall: Three layers of pixel-sized flakes drifting down at different speeds over a cold blue grade.
  * Terminator: T-800 vision: everything goes red, with scanlines, a sweeping scan bar, corner brackets and a column of jumping readout bars down the left side.
  * Thermal: Brightness mapped from cold black-blue through purple, red and orange to hot yellow-white, plus sensor noise.
  * Tilt Shift: Toy-world look; the middle band stays sharp while the top and bottom blur, with extra saturation.
  * Tron: Tron: Legacy look. The picture drops to near black, edges light up as glowing neon lines (cyan, or orange on warm colours) and a faint circuit grid pulses across the dark areas.
  * Underwater: Wave distortion, a deep blue-green tint, depth fade and drifting caustic light.
  * Vaporwave: Brightness mapped onto a navy-to-pink gradient, blended back in, with chromatic offset and scanlines.
  * VHS: Worn tape look with colour bleed, line jitter, a rolling tracking band, tape noise and soft scanlines.
* Resizable window scale is now set to 4.
* Fixed canvas size retrieval crashes.
* Added hidden options to the editor settings menu:
  * The camera can now be set to "forward only".
  * The coin limit can now be toggled.
  * You can now use only one-time save files (aka suspend files).
  * **Note:** You will be warned for using the features mentioned as it *could* ruin your mappack gameplay.

### 🐛 Bug Fixes

* Fixed keyboard navigation in the controls menu so the Pause binding is reachable when moving through controls with mouse aiming on or off.
* Fixed music getting stuck on a paused intro after quitting to the menu. The next song now plays without needing to pause the game.
* Fixed the minimap toggle so opening and closing the minimap animates its visibility without incorrectly animating the editor panel.
* Fixed an issue where the rightclick menu was unable to interact with.
* Fixed the rising water graphic glitch.
* Fixed a confusing mechanic where autodelete-able enemies would instantly vanish when a player died in multiplayer splitscreen.
* Fixed an issue where game saving would sometimes be counted as successful, even if it doesn't save successfully.
* Fixed editor scrolling staying blocked after renaming a saved object and closing the editor.
* Course screens now fade to black before loading the next map.
* Selecting a map in the editor now fades the full screen to black before loading.
* Pipe entries without a matching exit marker now use a vignette transition centered on the player's spawn animation.
* Course music now resumes when fast star music ends.
* Objects marked for instant deletion are removed immediately.
* Enemies with `xrelativetocamera` and/or `yrelativetocamera` now stick perfectly to the camera each frame. Both their graphic and hitbox stay at the specified camera-relative position without lag.
* Fixed a bug that let Mario midair-jump after bouncing off an enemy while wearing a Goomba shoe, stiletto, or dry bones shell.
* Fixed an issue where camera boundaries aren't respected in splitscreen viewports.
* Onscreen object detection is now fixed for splitscreen viewports.
* If a character shrinks to super form while ducking, the offsetY and quadcenterY is now fixed to its ducking offsetY and quadcenterY.
* Fixed the game crashing when block was hit while airborne and with speedx if you were specifically playing as Sonic.
* Invincibility timers have been tweaked. If you killed an enemy as Sonic, you won't be stuck on your invincibility animation.
* If you die, all music will be stopped every frame.
* Fixed the issue with screenshake which would only affect the HUD or the screen borders.
* Fixed intro text drawing inconsistency when the window was maximised.
* Fixed crash when downloading DLC.
* Fixed a bug with custom power-ups in mappacks that use Super Mario Maker physics.
* If you pick up two custom power-ups that have custom colours and the `fireenemy` property, then take damage, you now shrink to Big Mario as expected.
* You no longer keep the custom colours or the `fireenemy` property from the power-up you had before.
* Fixed enemies not showing their roll animation when killed in mappacks that use Super Mario Maker physics.
* The roll animation now plays even when `dropshadow` is turned off.
* Fixed Toad's off-palette running arms in his cape graphics.
* **THE GAME FINALLY DOESN'T CRASH WHEN RENDERING A SCISSORED OBJECT WITH SHADERS ENABLED! THIS IS A MOMENT IN HISTORY!**
* Fixed some iceball and ice block sound logic.
* Something was up with Mario's colourables so I fixed it.

### ✨ Improvements

* Yoshi now faces the same direction as the player.
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
* Moved **Pause** into the always-visible controls list. **Aim X**, **Aim Y**, **Portal 1**, and **Portal 2** remain available when the selected player does not use the mouse.
* In splitscreen multiplayer, player coordinate labels appear only in that player's viewport.
* Running into a horizontal autoscroll border resets your animation to idle if you're grounded. It sets your speedx to 0 regardless.
* As soon as you enter the water or fall while underwater, your animation frame and progress resets.
* Underwater checking is executed per frame even when you are climbing on a vine or fence.
* Ditching a wearable now dismounts instead of kills it.
* Changing hat now saves the game.
* When your raccoon/tanooki wag animation finishes, your animation resets to jumping, or falling if you have fallframes active.
* Mounting Yoshi resets the tongue state.
* If you land on the ground while raccoon/tanooki and your speedx is less than 8.9 or your animation state isn't "running", it's disabled.
* The raccoon flying animation only plays when you press jump.
* Holding jump no longer flies you up, you now have to press jump to fly upwards like in Super Mario Bros. 3.
* Mario can now turn around in midair while wearing a Goomba shoe, stiletto, or dry bones shell, without changing ground turning behaviour.
* Map-load animations now execute immediately when the map loads.
* GUI objects cannot be hovered while the editor panels are closed or animating, and editor tooltip timers reset when the panel view is toggled or unavailable.
* The selected tile or enemy preview remains visible behind the editor panels during their animation, with its opacity fading in the opposite direction to the panels.
* With `completelycenteredcamera` enabled, the camera now interpolates when a player dies. With `completelycenteredcamera` or `modernmultiplayercamera` enabled, it also interpolates when a player moves through a portal.
* Off-screen player markbases now show an expanded viewrange and nearby entities.
* With `completelycenteredcamera` or `modernmultiplayercamera` enabled, player teleportation executed by custom enemies or animation `setxsety` actions now use the same camera interpolation as portal travel.
* Overlay rendering is now better as shaders are applied on it.
* Rigid camera centering now tracks uncrouched hitboxes.
* Sped up the pause menu animation.
* Vertical scrolling is no longer dependent on the x-furthest player.
* Sometimes, flying as a bunny could keep your sprite on jumping because of `self.falling and self.speedy >= 0` so it's been changed to `self.falling and self.speedy > 0`.
* If the character has fall frames and was fluttering as Raccoon/Tanooki Mario, it would use the fall frames instead of jump frames.
* Added an icon to the `.exe` using rcedit.
* The enemy death roll animation only plays when the mappack uses Super Mario Maker physics **and** drop shadow.
* Pausing the game resets the selected option state.
* Changing controls, player skins, or any misc settings (scale, letterbox, shader, volume, vsync, or mappack folder) will now save the game immediately.
* Releasing the **Left**, **Right**, **A**, or **D** keys while changing player skin colours or portal hues now saves the game.
* WASD support has been enabled for changing skin colours and portal hues.
* The default mappack folder is now set to `alesans_entities`.
* Entering a pipe or door now unducks your character.
* Entering vertical pipes now keeps your animation on idle.
* You now exit the pipe faster when travelling to a different subzone.
* The pipe sound now plays when you exit the pipe too.
* If the player stomps off an enemy without having jumped beforehand, the animation state is now maintained only if the jump button isn't held or the mappack doesn't use Super Mario Maker physics.

### ❌ Removals

* Removed the annoying `"pipe not found"` spam that could repeatedly appear during character debugging.
* The dropdown arrow and the checkbox are now drawn with LÖVE's native graphics instead of image files.

**Note:** The four-keybind system remains compatible with original Mari0 AE save data and does not negatively affect it. Running Mari0 AE may remove the secondary, tertiary, and quaternary keybinds from your save data so make sure to backup your data. Since v1.4.0, Legendary Edition keeps a backup of its own settings and puts them back after Mari0 AE (see **Settings Backup** under v1.4.0).

**Mod Production Note:** These changes were made with Claude, Grok, and GitHub Copilot.

---

# Nitpicks

Set nitpicks in `alesans_entities/nitpicks.json`. Some of them are also settings in the accessibility menu (see **Accessibility** under v1.4.0): there, the nitpick is only where the setting starts. Most are boolean options: use `true` to enable them. Settings assigned directly from the JSON keep their supplied value; an omitted setting is `nil`. `letterbox` is applied whenever its key exists, including when set to `false`. `dpifix` accepts `true` (use a scale factor of 2) or a number (use that scale factor). `androidversion` is copied into the Android setting when truthy. `persistenteditortools` is enabled by default when the file exists, and only the explicit value `false` disables it. The key `debugGraphs` uses that exact capitalisation.

A mappack can also have its own `nitpicks.json`, next to its `settings.txt`. Its nitpicks replace the global ones while that mappack is played or edited, and every nitpick it doesn't list keeps its global value (see **Local Nitpick Loading** under v1.4.0).

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
- `pipesineditor`: Loads pipe entities while editing a course.
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
- `alwaysinfinitetime`: Starts with infinite time enabled. In Boo Baffler Bash, the timer never goes down.
- `alwaysinfinitelives`: Starts with infinite lives enabled. In Jumping Juggle Jamboree, touching the ground doesn't end the game, and in Block Beat Bonanza, reviving is always available and free.
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
- `smwwaterphysics`: Uses Super Mario World-style swimming. Holding Down while swimming halves the strength of each swim stroke, and holding Up increases it by 50%. Frog Mario is unaffected.
- `nologdumping`: You can guess what this does.
- `skipintro`: Skips the intro completely and loads the main menu straight away.
- `consistentvinespeed`: Moving down vines are now in the same speed as moving up vines.
- `orderedmovementtypes`: Boo Baffler Bash goes through its movement types in order, starting with Shy and looping, without Super Random.
- `invinciblesnake`: The snake in Snake Slither Scramble can't crash, without looking invincible.
- `multiplejumping`: In Jumping Juggle Jamboree, every jump press gives a full-height jump, even in mid-air, and landing on the ground adds a point and jumps you back up.
- `probabilitypasser`: In Snake Slither Scramble, the ? block and the Starman appear straight away whenever there isn't one on the screen.
- `immortalcombometer`: The bonus meter in Boo Baffler Bash always stays full.
- `removecooldowns`: The ? blocks in Rival Rumble Royale have no cooldown, so every hit gives an item.
- `classicspeedupfastmusic`: In Rival Rumble Royale, a song without a fast version is just played faster, which also makes it higher.
- `modernsizechangeanimation`: Powering up and down uses a Super Mario Maker 2 style animation instead of the classic one.
- `noairspeedcap`: Holding run in the air speeds you up to full running speed, even if you jumped from below walking speed.
- `inertiaphysics`: Jumping or falling off a moving platform keeps its speed, so you fly off in the direction it was going.
- `mariomakerblockphysics`: Blocks grow as they bounce up and shrink back as they come down, like in Super Mario Maker. Items come out of blocks in 0.4 seconds instead of 0.7.
- `dontfreezeonsizechange`: Powering up and down only freezes the player it happens to, like in SMBX2. Everything else keeps moving, and that player can't be touched until the animation is done.
- `camerasmoothing`: The camera eases after where it's going instead of moving rigidly, so it trails slightly behind.
- `backwardsmoothing`: The camera leads ahead by as much as `camerasmoothing` would make it trail. Requires `camerasmoothing`.
- `automaticenemyreload`: The Course Maker loads every custom enemy again whenever a map is loaded or tested, like before v1.4.0, so you don't have to press **refresh data**.
- `automaticbackgroundreload`: The Course Maker decodes custom backgrounds and foregrounds again whenever a map is loaded or tested, like before v1.4.0, so you don't have to press **refresh data** in the backgrounds tab.
- `automaticanimationreload`: The Course Maker reads every animation again whenever a map is loaded or tested, like before v1.4.0, so you don't have to press the **Animations** tab's arrow button.
- `automaticmapreload`: The Course Maker reads every map and preview again whenever a map is loaded or tested, or the editor panel is opened, so you don't have to press **refresh data** in the **Maps** tab.

---

# Changelog

All notable releases and updates to **Legendary Edition** are documented here.

## v1.4.0

### 🧩 New Features

#### 🎵 Music

The star theme, the princess theme, the P-Switch theme and the Mega Mushroom theme can now have their own intros and fast versions, the same way course music can.

* `starmusic`, `pbutton` and `megamushroom` take all three extra versions:
  * `-intro` plays once before the song.
  * `-fast` plays instead of the song when the time is low.
  * `-fastintro` (or `-introfast`) plays once before the fast version.
* `princessmusic` takes `-intro`.
* Put them next to the song they belong to: in `sounds` in the game, or in a mappack's `sounds` folder. For example, `pbutton-intro.ogg` goes next to `pbutton.ogg`.
* A song's versions only come from its own folder. A mappack's `pbutton.ogg` doesn't pick up the game's `pbutton-intro.ogg`, and switching to a mappack without an intro doesn't keep the last mappack's one.
* When the time runs low, the P-Switch and Mega Mushroom themes switch to their `-fast` versions, the same way the star theme does. Without a `-fast` file, the normal version keeps playing. Unlike the star theme, they don't get a made-up sped-up version.
* A mappack's star theme without `starmusic-fast.ogg` is still sped up for low time. If the mappack has `starmusic-fastintro.ogg`, that plays first instead of a sped-up copy of `starmusic-intro.ogg`.
* In Rival Rumble Royale, a music pack's star theme can have its own fast intro too (`star-fastintro.ogg` or `star-introfast.ogg` next to `star.ogg`). The mappack's star theme, with all its versions, comes back when the battle ends.
* `pbuttonsound` and `megamushroomsound` still work in the Course Maker's custom sounds and in animations. They play the main song, without its intro.

#### 🧱 Music Functions

For anyone working with the music code:

* `music.special` lists the songs that load their versions from their own folder, and which versions each one takes.
* `music:loadspecial(name, file)` loads one of those songs and the versions next to it, and takes away any versions that folder doesn't have.
* `music:stoptrack(name)` stops a song, its fast version and both their intros.
* `music:trackplaying(name)` checks whether any of those four is playing. `music:isplayingwithintro(name)` only checks one version and its intro.
* `playprioritytrack(name)` plays the star, P-Switch or Mega Mushroom theme: the fast version when the time is low, with its intro first. It does nothing if the right version is already playing.

#### 👾 Refresh Data

A new **refresh data** button in the Course Maker's custom enemies tab (**Custom → Enemies**), bottom left, where the other tabs have **update image** and **update sounds**.

* It loads every custom enemy again, so changes to their `.json` and image files show up without leaving the editor.
* The entity list and the enemy dropdown update with it. The selected enemy stays selected if it's still there.
* A notice says "Refreshed enemy data" when it's done.
* The button is translated into every language the game has.

#### ⚙️ Automatic Enemy Reload

A new nitpick, `automaticenemyreload`. With it on, the Course Maker loads every custom enemy again each time a map is loaded or tested, the way it did before v1.4.0. Changes to enemy files then show up on the next map load, without pressing **refresh data**. Maps load slower with it on, the more custom enemies a mappack has. **Generate Nitpicks File** adds it to an existing file.

#### 🖼️ Background Refresh Data

The custom backgrounds tab (**Custom → Backgrounds**) has a **refresh data** button too, under the animated backgrounds text.

* In the Course Maker, and while testing a map from it, background and foreground pictures are now only decoded once. Loading another map that uses the same picture reuses it instead of decoding it again.
* **refresh data** decodes them all again, so changes to a picture show up without leaving the editor. It also picks up pictures added to the `backgrounds` folder since, and shows a "Refreshed background data" notice.
* New picture files are still found on every map load. Only changes to a picture that's already been loaded need **refresh data**.
* Outside the Course Maker, nothing is kept: backgrounds load the same way as before. The kept pictures are let go when you leave the editor or open another mappack.

#### ⚙️ Automatic Background Reload

A new nitpick, `automaticbackgroundreload`. With it on, the Course Maker decodes backgrounds and foregrounds again on every map load, the way it did before v1.4.0, so you never need **refresh data** for them. **Generate Nitpicks File** adds it to an existing file.

#### 🗺️ Map Refresh Data

The Course Maker now reads the mappack's maps once, when you open it from the menu, instead of every time a map loads or the editor panel opens.

* Opening the Course Maker from the menu reads which maps exist and decodes their previews (the pictures in the mappack's `editor` folder). Loading a map, testing one and opening the editor panel all use what was read then.
* Saving a map in the Course Maker only changes that map's entry, and its preview if it gets a new one. Pasting or deleting a map from the maps tab's right-click menu does the same. Nothing else is read again.
* The **Maps** tab has a **refresh data** button, right under **save level**. It reads again every map and preview that was changed outside the game since: edited, added or deleted. Only those are read again, and only changed previews are decoded again.
* A map added outside the game shows up after **refresh data**, with new worlds, levels and sublevels added for it if it needs them. Worlds and levels are never taken away.
* Pressing it fades the screen to black and shows a "refreshing map data..." overlay ("refreshing course data..." in Better English) while it reads, then fades back in. The fade plays even with the mappack's **Skip trans.** setting on, the same as selecting a map in the Course Maker. Only the `disabletransitions` nitpick skips it.
* A notice says "Refreshed map data" when it's done.
* **refresh data** doesn't reload the map you have open. Load it again from the **Maps** tab to see changes made to it outside the game.
* With `noeditorpreviews` on, the previews aren't decoded at all, since they aren't shown.

#### ⚙️ Automatic Map Reload

A new nitpick, `automaticmapreload`. With it on, the Course Maker reads every map and decodes every preview again each time a map is loaded or tested, or the editor panel is opened, whether anything changed or not. Changes made outside the game then show up without pressing **refresh data**. Maps load slower with it on, the more maps and previews a mappack has. **Generate Nitpicks File** adds it to an existing file.

#### 🎞️ Animation Cache

Mappack animations are now read and decoded once, instead of on every map load. This also speeds up going into subzones in normal play.

* The first map load lists the mappack's `animations` folder (and its subfolders) and decodes every animation file. Every load after that builds the animations from what was kept, without touching the disk. Character animations (`alesans_entities/characters/<name>/animations`) are kept the same way.
* Every load still makes its own animations from what was kept, so nothing that happens to an animation during a course carries over to the next load.
* Creating, saving, renaming or deleting an animation in the Course Maker updates the cache for that file only. Saving an animation without renaming it doesn't even list the folder again.
* What's kept belongs to one mappack. Loading another mappack, or opening the Course Maker from the menu, starts it over.

The **Animations** tab has a new button between **save** and **x**, showing the counterclockwise arrow from `graphics/GUI/directions.png` (the same icon as the boo circle's right-click menu).

* Pressing it lets go of every kept animation and reads them all again, so changes made to animation files outside the game show up. The animation you had open stays open if it's still there.
* Changes to the open animation that weren't saved are dropped, so its file's own contents show.
* Hovering over it for a second shows a tooltip under it: "Press this button to reset animations cache". The tooltip is a liquid glass box that pops in with a jelly, like a dropdown list, and pops back out with one when the mouse leaves the button.
* The tooltip is translated into every language the game has. Its lines are split so it fits under the button.
* A notice says "Reset animations cache" when it's done.

#### ⚙️ Automatic Animation Reload

A new nitpick, `automaticanimationreload`. With it on, the animation cache is reset every time a map is loaded or tested in the Course Maker, so every animation is read and decoded again, the way it was before v1.4.0. Changes made to animation files outside the game then show up on the next map load, without pressing the arrow button. Normal play still uses the cache. Maps load slower with it on, the more animations a mappack has. **Generate Nitpicks File** adds it to an existing file.

#### 🧩 Map Parse Cache

Loading a map now splits up its tiles and turns them into numbers once, then keeps the result.

* Loading the same map again builds it from what was kept, without reading or parsing the file again.
* Every load still checks the file's size and modtime, and the tile counts the map was parsed with. A map that was saved, changed outside the game, or parsed before the tiles changed is parsed again.
* The check for custom enemies that don't exist still runs on every load, against the enemies loaded at the time. It now looks names up in a set instead of going through the whole enemy list for every tile.
* **update image** in the Course Maker's tiles tab (**Custom → Tiles**) lets go of every parsed map, since the checks for tiles that don't exist depend on the tileset. Loading another mappack, or opening the Course Maker from the menu, does too.
* This works in normal play as well as in the Course Maker.

#### 📢 Update Overlays

Every button in the Course Maker's **Custom** tab that loads something again now fades the screen to black and shows an overlay first, the same way **refresh data** in the **Maps** tab does:

* **update image** in the graphics tab: "updating graphics..."
* **update image** in the tiles tab: "updating tiles..."
* **update image** in the backgrounds tab: "updating backgrounds..."
* **update sounds** in the sounds tab: "updating sounds..."
* **refresh data** in the enemies tab: "refreshing enemy data..."
* **refresh data** in the backgrounds tab: "refreshing background data..."
* The **Animations** tab's reset button: "resetting animations cache..."

Dropping a new tileset onto the window shows "updating tiles..." too, since it runs **update image**. Each overlay is translated into every language the game has, and so is "refreshing map data..." now. Only the `disabletransitions` nitpick skips the fade.

#### 🧱 Animation and Map Parse Functions

* `animationcache_get(path)` returns an animation file's decoded contents, reading it only the first time. `animation:init` uses it, and `animation:decode` now also takes an already decoded table.
* `animationcache_changed(path, samefiles)` forgets one file, and the lists of files too unless `samefiles` is `true` (only its contents changed). The editor runs it whenever it writes or removes an animation.
* `clearanimationcache()` lets go of every kept animation. `resetanimationcache()` is what the **Animations** tab's arrow button runs.
* `clearmapparsecache()` lets go of every parsed map. `savemap` forgets the map it saves.
* `drawanimationcachetooltip()` draws the arrow button's tooltip.

#### ⏳ Background Loading

Everything that shows a loading overlay (loading a level, the Course Maker, a mappack or save data, testing a level, returning to the menu or editor, saving, and every **update** and **refresh data** button) now does its work in the background instead of stopping the whole program until it's done. The new `overlaytask.lua` handles it.

* The game is frozen while the work runs: nothing updates, keys are kept for later (see **Keys Pressed While Loading** below) and any other input is ignored. The window isn't: it keeps drawing frames and handling its own events, so it can be moved or closed and never stops responding.
* The work runs a piece at a time, about 33 milliseconds a frame (`OVERLAYTASK_BUDGET`), so the window still gets about 30 frames a second. Vsync is turned off while it runs and turned back on when it's done: with vsync on, every frame waited for the monitor, and a frame whose work ran past a refresh waited for a whole extra one, which made loading take about twice as long. The fade before it keeps vsync on, so it stays smooth.
* The work gives the frame back inside the long loops: map tiles, custom enemies, animations, custom tiles and sprites, animated tiles, sounds, music, the editor's map list and previews, and **refresh data**.
* The fade to black before an overlay plays frame by frame too, instead of in a loop of its own.
* Meanwhile, the screen shows a picture of the frame taken when the overlay appeared, dimmed, with the overlay's text on top. The half-loaded game is never drawn.
* The overlays drawn over the game aren't frozen with it: notices, the FPS, battery and time overlays and the debug graphs keep updating and are drawn live on top, and they're left out of the frozen picture so they never show twice. F7, F8, F9 and F11 still switch them on and off while loading, with their usual slide.
* `drawhudstats()` draws the FPS, battery and time overlays and `hudoverlays_update(dt)` keeps notices, those overlays and the debug graphs going. `hudoverlays_keypressed(key)` handles their keys.
* Overlays ending in "..." now animate their dots: "", ".", "..", "...", then back to "", one step every 0.5 seconds (`OVERLAYTASK_DOTTIME`). The animation always starts from "". Only the dots that are showing are part of the text, so it's centred as it is at every step. This also covers the mappack menu's download overlay.
* The overlay's text is now in the middle of the screen. It used to be centred in a box worked out from the game's size and scale, which is off-centre whenever the window is bigger than that (fullscreen without the resizable scale). `centerprintscreen` now measures what it's drawn on (`getproperwindowsize`), and the overlay dims all of it.
* This uses coroutines on the main thread rather than `love.thread`. A LÖVE thread has its own Lua state, so it can't see or change the game's tables, and it can't make images or canvases, which is what all of this work does.
* Overlays shown before the game has finished starting up still work the old way: one frame, then the work runs straight through.

#### 🧱 Background Loading Functions

* `overlayyield(force)` gives the frame back when background work has used up its share of it (always, with `force`). Outside of background work it does nothing, so any long loop can call it.
* `overlaytask_canyield()` says whether the code running now is background work that can give the frame back.
* `overlay_animatedtext(text, start)` returns a text with its "..." animated from `start`.
* `overlaytask_install()` wraps LÖVE's callbacks so they can run in the background. `love.load` runs it last.
* `quit`, `resize` and `visible` are never run in the background, so quitting always finishes before the window closes.

#### ⌨️ Keys Pressed While Loading

Keys pressed while a loading overlay is up are no longer lost.

* Every key pressed while the work runs is added to the end of a queue. The overlay keys (F7, F8, F9 and F11) still work straight away and aren't queued.
* Once the work is done, the nth key of the queue is pressed on the nth frame after the end: the first key on the first frame, the second on the second, and so on. A key pressed 5 times is pressed 5 times.
* A key held down only counts once. Its repeats aren't added.
* Each pressed key is let go of on the frame after, unless you're still holding it down. Then it's let go of when you really let go. Until it's let go of, `love.keyboard.isDown` says it's down.
* If a pressed key starts another load (Enter on a menu, for example), the rest of the queue waits for it. Its frames count again from 1 once that load ends, and keys pressed during it are added to the end.

#### 🚪 Alt+F4

* **Alt+F4** now closes the game straight away, even in the middle of a load. It's never added to the queue, and it doesn't wait for the work to finish. Left or right Alt both work.
* The game still shuts down the normal way, so online play is left and the log is still dumped.

#### 🧱 Key Queue Functions

* `overlaykeyqueue` holds every key pressed while the work ran and not pressed yet, as `{key, scancode}`, oldest first.
* `overlaykeys_play()` lets go of the key pressed on the last frame, then presses the next one in the queue. `overlaytask.lua` runs it once a frame, before the game updates, whenever the game isn't frozen.

#### 🗂️ Options Tab Picker

The options menu's row of tab names (**controls**, **skins**, **misc.** and **cheat**) is now a dropdown.

* It's 205 pixels wide and sits 4 pixels in from the top left corner of the options box, where the controls tab's highlight used to start.
* Picking a tab from it switches to that tab with the usual slide.
* With the keyboard on the tab row, the dropdown looks hovered. Left and Right (or A and D) still switch tabs, and the new tab's name slides into the header like any dropdown changed without the mouse. Enter (or Space) opens it, Up and Down move through it, Enter picks and Escape closes it.
* While it's open, the other keys don't change anything under it.
* Its list opens over the tab below it, and it can still be used while the tabs are sliding.

#### 🎯 Centred Dropdowns

Every dropdown's options are now drawn in the middle of their row instead of at its left edge.

* This includes the option shown in the header, which is centred in the part left of the divider, and the copy of the header at the top of a list too long for the screen.
* An option too long for its row still starts at the left edge, the same as before.
* Custom enemy options keep their icon right before their name.
* Graphical dropdowns (like the skins tab's characters, hats and colours) draw their own options and aren't changed. Neither are right-click menus.

#### 🧱 Enemy Functions

* `enemies_loadkey()` returns everything `enemies_load` depends on besides the enemy files: the mappack, whether it uses custom enemies, `donotcategoriseenemyfolders` and the players' characters. `enemies_load` keeps the last one in `enemiesloadedkey`.
* `refreshcustomenemies()` is what **refresh data** runs.
* `refreshcustombackgrounds()` is what the backgrounds tab's **refresh data** runs. `clearbackgroundcache()` lets go of the kept background and foreground pictures, so the next load decodes them again.

#### 🧱 Map Functions

* `loadeditormapcache()` reads which maps exist and loads their previews. Opening the Course Maker from the menu runs it, in place of `loadeditormetadata()`, which it now runs itself.
* `editormapcache_updatemap(filename)` reads one map's entry again (`filename` without `.txt`, like `"1-2_3"`). `savemap` runs it after writing the map.
* `editormapcache_updatepreview(levelstring)` does the same for one preview (`levelstring` like `"1~2~3"`).
* `refresheditormaps()` is what the maps tab's **refresh data** runs.
* `getmaps()` builds the map buttons from the cache instead of checking every map file. With `automaticmapreload` on, it runs `loadeditormapcache()` first every time.

#### ⏸️ Pausing While Testing

Testing a course from the Course Maker now pauses like normal play.

* The pause key (Escape, or whatever pause is bound to, on a keyboard or a controller) opens the pause menu instead of going straight back to the Course Maker. Pressing it again closes the menu.
* The game also pauses when its window loses focus while testing, unless `dontpauseonunfocus` is on.
* **Quit to menu** in the pause menu goes back to the Course Maker while testing, instead of the main menu.
* While testing, the pause menu shows **stop testing level** where **save game** (or **suspend**) usually is. Picking it goes straight back to the Course Maker, without a prompt. A label too long for the menu's left column is split over two lines at a space, so it doesn't run into **controls**. Testing a course never saves the game.
* The pause menu stays on screen through the fade back to the Course Maker, whichever way testing is stopped. After **yes** in the **quit to menu?** prompt, the prompt stays up through the fade, so the pause menu under it doesn't look usable again before the Course Maker loads.

#### ⏹️ Stop Testing Course

The "TESTING COURSE - PRESS ESC TO RETURN" text at the bottom of the screen is now a **stop testing level** button ("stop testing course" in Better English). Its text comes from the `"stop testing level"` key in the language files.

* It sits in the middle of the bottom of the screen, with its bottom edge 4 pixels above the bottom of the game.
* Clicking it goes back to the Course Maker, the same way Escape used to.
* It stays on screen after it's clicked, squashed, and fades to black with the rest of the screen. It only goes once the Course Maker has loaded. If the game was paused, the pause menu stays up through the fade too.
* It works while playing and while the pause menu is open. It fades out while a pause menu prompt or the controls popup is showing, and fades back in once they close.
* Clicking it doesn't shoot a portal, and the click doesn't reach anything in the Course Maker once it opens.
* Its label is translated into every language the game has.

#### ⚙️ Pause Menu Settings

The right side of the pause menu now has more of the misc. tab's settings. From top to bottom:

* **controls:** with **edit** under it, as before.
* **joy deadzone:** with the same slider as in options, under its label. Left and Right change it by 5%, and a red notice warns when it goes below 10%.
* **scale:** with a dropdown at the end of its line: *1 to *4, or resizable. Left and Right step through them the same way as in options.
* **letterbox:** with a checkbox at the end of its line. Left, Right and Enter toggle it.
* **shader1:** and **shader2:**, which were already there, now come after letterbox.

Every change saves the game straight away, like in options. The row selected with the keyboard looks hovered. The left side of the pause menu hasn't changed.

#### 💾 Settings Backup

Mari0 AE and Legendary Edition share `alesans_entities/options.txt`. When Mari0 AE saves it, everything it doesn't know is lost: the second, third and fourth keybind pages, the accessibility settings and the other Legendary Edition settings. Legendary Edition now keeps a backup that Mari0 AE never touches.

* Every time Legendary Edition saves `options.txt`, it starts the file with `savedby:mari0_le;`, and writes the same file to `alesans_entities/options_le_backup.txt`. Mari0 AE ignores the marker when it reads the file, and leaves it out when it saves.
* When the game starts, the backup is only used if both of these are true:
  * `options.txt` doesn't start with the marker, so Mari0 AE saved it last.
  * The backup does start with it, so Legendary Edition saved it.
* Then the settings are read from the backup instead, a notice says "mari0 ae changed your settings. restored them from the legendary edition backup!", and `options.txt` is saved again straight away, with the marker.
* If Legendary Edition saved `options.txt` last, the backup isn't used, even if it's different.
* Coming from Mari0 AE for the first time, there's no backup yet, so `options.txt` is read as it is. Legendary Edition then marks it and makes the backup.
* Settings changed in Mari0 AE after that aren't carried over: the backup's settings are used instead.

For anyone working with the settings code: `readoptionsfile()` is what `loadconfig` reads, `OPTIONS_LE_MARKER` is the marker and `OPTIONS_LE_BACKUP` is the backup's path.

#### 🗂️ Local Nitpick Loading

Mappacks can now have their own nitpicks. Put a `nitpicks.json` in the mappack's folder (`<mappack folder>/<mappack>/nitpicks.json`, next to `settings.txt`), written the same way as the global `alesans_entities/nitpicks.json`.

* Whenever the mappack's settings load (starting or continuing a game, opening the Course Maker, online play), the game runs `loadnitpicks()` again with the mappack's file on top of the global one.
* Only the nitpicks the mappack's file lists are changed. Every other nitpick keeps its value from the global `nitpicks.json`. For example, a mappack file with just `{"nomusic": false}` turns the music back on for that mappack and leaves everything else as the player set it.
* If the mappack has no `nitpicks.json`, every nitpick goes back to its value from the global file. Nothing is read again while neither the mappack nor the last one had a file, so nitpicks switched with F7, F8 or F9 stay how they are.
* Going back to the menu, the daily challenge and the minigames always use the global nitpicks.
* Nitpicks that are also accessibility settings (smooth camera, infinite lives, the physics and camera ones) follow the mappack's file when it lists them, and the player's setting otherwise. The settings themselves aren't changed or saved, so they come back once you leave the mappack.
* Taking `noportalgun` or `mariomakergravity` out goes back to the portal gun and the normal fall speed.
* A few nitpicks only work at startup, so they're only read from the global file: `console`, `androidversion`, `pcversion`, `hideandroidbuttons`, `dpifix`, `letterbox` and `debugGraphs`.
* A broken mappack `nitpicks.json` counts as missing, instead of crashing.

For anyone working with the nitpicks code:

* `loadnitpicks(localpath)` reads the global file, puts `localpath` over it if it's there, and sets the nitpicks. Without `localpath`, only the global file is used.
* `readnitpicksfile(path)` returns a nitpicks file's table with its keys in lowercase, or `nil` if it isn't there or isn't valid JSON.
* `loadlocalnitpicks()` loads the open mappack's file. `loadmappacksettings` runs it first.
* `restoreglobalnitpicks()` puts the global nitpicks back after a mappack's were used. `menu_load` runs it, and so does `game_load` for the daily challenge and minigames.
* `accessibility_afterlocalnitpicks(loc)` lets the nitpicks in `loc` replace their accessibility settings, and puts the settings back for the rest.

#### ♿ Accessibility

A new **accessibility** tab in the options menu, after **cheat** in the tab picker, and the same settings on a new page of the pause menu. Both list them in categories, with each setting's label indented under its category and its widget at the end of the line:

```
motion:
    reduce motion          [ ]
    screen shake           [====100%]
    shake direction
    [both            v]
    smooth camera          [ ]
display:
    ...
```

There are eight categories: **motion**, **display**, **gameplay**, **physics**, **assists**, **camera**, **controls** and **notices**.

A setting that does nothing because of another one (skip course after ... deaths while never skip automatically is ticked, rapid hold execution while hold to fire is off, backward smoothing while smooth camera is off, horizontal splitscreen viewports while splitscreen multiplayer is off) is greyed out: its label and widget are dimmed, and it doesn't take clicks or keys until the other setting allows it. A label too long for its line wraps beside a checkbox. A slider or dropdown that doesn't fit next to its label goes on the line under it. Both pages are taller than the space they have, so they scroll, with a GUI scrollbar at their right edge that can be dragged like any other. The mouse wheel scrolls them too, and the setting the keyboard is on always scrolls into view, with the scrollbar following. Settings scrolled out of view can't be clicked.

Every change saves straight away. They're saved in `options.txt` as `a11y_<name>:<value>`, and **Reset All Settings** puts them all back to their defaults.

**Motion**

* **Reduce motion:** Animations that scale things fade them instead. Popups, the pause menu, prompts, dropdown lists, right-click menus, tooltips, the editor panels, the checkbox tick and the intro's author name all appear at their full size and fade in and out. Buttons and other GUI elements no longer lean towards the mouse, squash when pressed or wobble back with a jelly.
* **Screen shake:** How strong screen shake is, from 25% to 100% in steps of 5%. 100% by default.
* **Shake direction:** Which way the screen shakes: vertical, horizontal or both. Both by default.
* **Smooth camera:** The `camerasmoothing` nitpick as a setting. The first time the game starts, it's set to whatever the nitpick says. From then on, the setting decides, and **Reset All Settings** takes it from the nitpick again.
* **Backward smoothing:** The `backwardsmoothing` nitpick as a setting, started from the nitpick the same way. It's greyed out while smooth camera is off. If it's on without smooth camera when the game starts, a red notice says "backward smoothing needs smooth camera: turn on smooth camera to use it!".

**Display**

* **Reduce transparency:** Glass panels no longer blur what's behind them. They're drawn as solid panes in their own colour, so menus look plainer and are easier to read over a busy course. Highlights and dividers keep their own look.
* **Increase contrast:** Like iOS's Increase Contrast: glass panels are darker and more solid, their rims are brighter and stronger, highlights are easier to see, and grey text (unselected options, hints) is drawn much brighter.
* **Colour filter:** None, protanopia, deuteranopia or tritanopia. The whole frame goes through a daltonisation filter that moves the colours someone with that colour vision deficiency would lose into ones they can tell apart. Everything is filtered, including menus, the HUD, notices and shaders.
* **HUD outline:** Outlines the HUD in every mappack, the same as a mappack with `hudoutline` on. Score notes (the points and 1-ups that float up) get a black outline too, whenever the HUD is outlined. The mappack's own `hudoutline` setting isn't changed.
* **Text cursor:** How wide a text input's cursor is: normal (2 pixels), large (3) or extra large (4). This also covers a slider's cursor while you type a value into it.
* **Reduce flashing:** A Starman no longer flashes the player through colours. They keep their own colours, with a rainbow glow over them like in the Super Mario Maker series. The glow is a copy of the player's whole picture, hat included, coloured entirely with `rainbow()` and drawn on top with additive (glow) blending, pulsing gently. It only moves while the player updates, so it stops while the game is paused, and it slows down with **Game speed**. Only the Starman changes.
* **Player indicator:** "P1" (or P2, P3, P4) with "↓" under it above every player, in that player's colour with a black outline. Each line is centred on the player.
* **Aim line:** The portal gun's dots are replaced by a solid line with a black outline, from the portal gun to where the portal would open, in the colour of the player's first portal. Where a portal can't open, the line is red and ends in a red cross. The crosshair on the surface still shows.
* **Low time warning:** Once the timer drops below 100, it turns red and pulses, so the warning doesn't depend on hearing the "hurry" sound. It doesn't show with infinite time, in courses without a timer, or in the Course Maker.

**Gameplay**

* **Game speed:** How fast gameplay runs, from 25% to 100% in steps of 5%. 100% by default. Everything in a course slows down together, including the timer. The pause menu, its prompts and the menus run at normal speed, and so does the Course Maker while editing. Testing a course uses the setting. Online play always runs at 100%.
* **Half-opaque blink:** A player blinking after a hit is drawn at half opacity the whole time instead of blinking. The player is drawn as one picture first, so their colours, hat and other layers fade together instead of showing through each other.

**Physics**

Nitpicks as settings. Like smooth camera, each one starts as its nitpick the first time the game starts. From then on, the setting decides, and **Reset All Settings** takes it from the nitpick again.

* **SMW water physics:** `smwwaterphysics`.
* **Consistent vine speed:** `consistentvinespeed`.
* **Modern size change animation:** `modernsizechangeanimation`.
* **SMBX2-styled size change animation:** `dontfreezeonsizechange`.
* **No air speed cap:** `noairspeedcap`.
* **Inertia physics:** `inertiaphysics`.

**Assists**

* **Jump buffer:** Pressing jump up to 0.15 seconds before landing jumps as soon as you land. If jump was let go of by then, it's a short hop, the same as tapping jump. A press in the air that does something (a double jump, a raccoon flap, a swim stroke) isn't remembered.
* **Coyote time:** For 0.1 seconds after walking off a ledge, you can still jump as if you were on the ground. It doesn't apply after a jump, underwater, or on vines and fences.
* **Pit rescue:** Falling out of the bottom of the level puts you back on the last solid ground you stood on, blinking as if you'd been hit. A powered-up player drops one size (or loses their shoe, helmet or Yoshi, like any hit). A small player stays small instead of dying, and a player who can't be hurt (blinking or with a Starman) is just put back. It doesn't apply in the Course Maker, in minigames, in autoscrolling courses or once the course is finished.
* **Respawn where you died:** After everyone dies, the next try starts on the last solid ground you stood on in that course and area, instead of the start or a checkpoint. A new course, or a game over, starts as usual. It doesn't apply in minigames or the daily challenge.
* **Generous stomps:** Running into an enemy's side while you're coming down with your feet above its middle counts as landing on it, so clipping its edge stomps it instead of hurting you. Enemies that hurt you from above still do.
* **Infinite lives** and **Infinite time:** The `alwaysinfinitelives` and `alwaysinfinitetime` nitpicks as settings, including what they do in the minigames. The first time the game starts, they're set to whatever the nitpicks say. From then on, the settings decide, and **Reset All Settings** takes them from the nitpicks again. The cheat tab's switches still work for the session.
* **Never skip automatically:** Ticked by default. While it's ticked, the pause menu always offers a **skip course** button next to **accessibility**, which goes straight to the next course, the same way finishing it would. The number below is greyed out, since only the automatic skip uses it.
* **Skip course after ... deaths:** Only while never skip automatically is unticked. The course is skipped by itself on the death that reaches this number, with a notice saying so, instead of starting the course again. It's from 5 to 100, 10 by default. It isn't skipped by itself on the last life: that's a game over, as usual, and the pause menu offers **skip course** once that many deaths have been reached. The number is a text input like the Course Maker's colour inputs: click it and type a number (Enter sets it), or drag it left and right. A number outside 5 to 100 is moved into it, and anything that isn't a number puts the old one back with a red notice. With the keyboard, Left and Right change it by 1, and Enter selects it to type over. In English it reads "skip level after ... deaths", since English says "level" where Better English says "course".
* Skipping never happens, and the button never shows, while testing a course from the Course Maker, in minigames, in the daily challenge or online.

**Camera**

Nitpicks as settings, started from them the same way as the physics ones.

* **Completely centered camera:** `completelycenteredcamera`.
* **Modern multiplayer camera:** `modernmultiplayercamera`.
* **Splitscreen multiplayer:** `splitscreenmultiplayer`. Rival Rumble Royale still keeps split screen on for the whole battle. Changing this setting during a battle takes effect once the battle ends.
* **Horizontal splitscreen viewports:** `horizontalsplitscreenviewports`. It's greyed out while splitscreen multiplayer is off.

**Controls**

* **Toggle run:** Pressing run starts running, and pressing it again stops. Anything that needs run held (the Tanooki statue, carrying things) acts as if it's held while it's on.
* **Hold to swim:** Holding jump underwater keeps swimming upwards, a stroke every 0.3 seconds, instead of needing a press for each stroke. Frog Mario is unaffected.
* **Hold to fire:** Holding run keeps throwing fireballs, iceballs, superballs, hammers, boomerangs and custom power-up projectiles, one every 0.3 seconds, within the usual limit on how many can be out at once. It only repeats throws: tail whips, picking things up, Cappy and Yoshi still need a press each time. It works in a Goomba shoe, stiletto, dry bones shell or cloud too, even with Up held: the repeated throws never take the shoe off, only pressing Up and Run yourself does. With toggle run on, it's the run button itself that has to be held.
* **Rapid hold execution:** With hold to fire on, a throw is tried every frame instead of every 0.3 seconds, so a new projectile goes out as soon as there's room for one under the usual limit. It's greyed out while hold to fire is off.

**Notices**

* **Click to dismiss:** Notices slide in and stay until you click them, with no time limit. Clicking one slides it away.

**Options menu**

* Pick **accessibility** from the tab picker, or press Right on the tab row from **cheat**. It slides in like the other tabs.
* Up and Down move through the settings. Left and Right move a slider by 5%, step through a dropdown's options, or tick and untick a checkbox. Enter ticks a checkbox or opens a dropdown.

**Pause menu**

* An **accessibility** button sits at the bottom of the pause menu. Pressing it, or pressing Down after the last option on the right (shader2) and then Down again from the button, slides the pause menu up and the accessibility page up from below.
* When **skip course** is on offer (see **Never skip automatically** above), its button sits next to **accessibility**. On the button row, Left and Right move between the two, and Enter presses the selected one.
* The accessibility page has two columns: motion, gameplay, physics and assists on the left, display, camera, controls and notices on the right. It scrolls, with its scrollbar on the right. Its keys work the same as in the options menu. The button at the bottom says **back** there.
* Pressing Up from the first setting, Escape (or the pause key), or **back** slides back to the pause menu, with the **accessibility** button selected. The pause menu always opens on its own page.
* Nothing on either page can be used while they slide.

All labels, categories and options are translated into every language the game has.

#### 🧱 Mario Maker Block Physics

A new nitpick, `mariomakerblockphysics`. **Generate Nitpicks File** adds it to an existing file.

* A block that's hit doesn't only move up and back down: it grows from its middle as it goes up, to 1.25 times its size at the top of the bounce (`mmblockbouncescale` in `variables.lua`), and shrinks back as it comes down. Every flip block type does too: flip blocks, action blocks, switch blocks, propeller boxes and cannon boxes. Note blocks only move, like before.
* An item inside the block comes out once the block is back to its normal size, the same moment the bounce ends. The block always grows first: the bounce's first step stops at the top, so a long frame can't skip straight to the end and let the item out without the block ever looking bigger.
* The sprout sound (or the vine sound) waits for the item too, and plays when it comes out instead of when the block is hit. Note blocks, and every block with the nitpick off, still play it straight away.
* Items take `mmmushroomtime` seconds (0.4 by default, in `variables.lua`) to come out of the block, instead of `mushroomtime` (0.7).
* Coins (and collectables) still come out straight away, as soon as the block is hit.
* `drawbouncetile(img, quad, x, y, bouncescale)` draws a tile scaled from its middle. `blockbouncescales(bounce)` says whether a bouncing block scales (the nitpick is on and it isn't a note block), and `sproutsound(bounce, sound)` plays an item's sound straight away or keeps it for when the item comes out. `classicmushroomtime` keeps the normal `mushroomtime`, so it goes back to it with the nitpick off.

#### 🚪 Locked Doors

* Opening a key door with a key now stops you in front of it. Your controls are turned off, your speed goes to 0 and you can't be hurt. After `lockeddoorentrywait` seconds (0.5 by default, in `variables.lua`), you go in.
* The wait only counts while you're updating, so pausing doesn't use it up, and it holds still while your size is changing. If you die, or something else takes you over first, the wait is called off.
* If the door can't be entered when the wait is over (in multiplayer, when everyone has to take another one), your controls come back.
* P-doors and key doors now work like normal doors when you hold Up while walking into them: an open one lets you in, and a locked key door opens with your key. Before, Up had to be pressed while standing in front of them.
* `mario:trylockeddoor(x, y)` goes through or opens the P-door or key door at `x`, `y`, and returns `true` if it did either.

#### 🪓 Axe Cutscene

Grabbing the axe at the end of a castle now plays a new cutscene. Every new timing is in `variables.lua`.

* The axe disappears and `grabsound` plays. The music keeps going.
* Every enemy that isn't on screen is deleted straight away, including ones with `resistseverything` or `resistsenemykill`.
* Everything in the course freezes for `beforebridgebreaktime` seconds (0.5 by default). Nothing moves or animates except the cutscene.
* Then the bridge breaks one block at a time, at the same speed as before. It always breaks now, even when there's no boss or the boss was already beaten with fireballs. Before, the cutscene skipped straight to the walk in that case.
* Every enemy stops where it is as soon as the axe is grabbed, not just Bowser. This covers built-in and custom enemies. Enemies with `resistseverything` or `resistsenemykill` aren't affected: once the freeze is over, they carry on like normal.
* The stopped enemies don't walk, shoot or jump any more. From the moment the bridge starts breaking, they play their normal animation `enemycastlefallanimspeed` times faster (2 by default), instead of only Bowser tapping his feet. Anything their animation would spawn or play is taken straight back out.
* Once the last block is gone, the stopped enemies turn to face the player who grabbed the axe, and fall if there's nothing under them.
* If any of them falls through the gap, the music stops and `bowserfallsound` plays. An enemy counts once it's half a block below where the bridge was.
* If there are no stopped enemies, or none of them falls within `axefallchecktime` seconds (0.2), the cutscene carries on as if one had fallen: the music stops and everything below happens the same way, just without `bowserfallsound`.
* At that moment, the player who grabbed the axe can move again, but their controls stay off. Their speed goes to 0 and any jump stops, so they drop straight down if they were in the air. Other players aren't affected.
* `turnafteraxeland` seconds (0.25) after that player lands, they turn to face left.
* `beforeaxeplaytime` seconds (1) after that, the player walks to the end of the course and the course end sound plays, like before. Toad's lines show at the same times as before, counted from the start of the walk.
* `aftercastleendtime` seconds (2) after the course end sound finishes, `scoreringsound` plays and the time left is added to the score, the same way as at the flagpole. The next course loads as soon as it's done, or straight away if there's no time left.
* Falling into water during the cutscene, or walking through an underwater castle, now uses underwater physics: water gravity, slowed speed and the underwater walking speed. Before, the player fell as if there were no water.
* The final castle's ending (the princess's lines and pressing a button to finish) is the same as before.

#### 🧱 Axe Cutscene Functions

* `axefreezetimer` is how long the freeze has left. While it's set, `game_update` only updates the player who grabbed the axe.
* `mario:axedeleteoffscreenenemies()` deletes every enemy that isn't on screen when the axe is grabbed, the same way the game deletes objects.
* `mario:axeholdenemies()` stops every enemy for the cutscene and marks it `axeheld`. `game_update` doesn't run the update of an enemy marked `axeheld`, so it only has physics left.
* `mario:axereleaseenemies()` turns the stopped enemies to face the player and gives them their physics back. `axefacingreversed` lists the built-in enemies whose sprites face right by default, so they're turned the other way.
* `mario:axeanimateenemies(dt)` runs every stopped enemy's own update at `enemycastlefallanimspeed` times the speed, then puts back everything except the fields in `axeanimfields` (`quad`, `frame`, `animationtimer` and so on). Sounds are muted while it runs, and anything spawned is removed. An enemy whose animation uses another field needs that field added to `axeanimfields`.
* `mario:axeanyenemyfalling()` says whether one of the stopped enemies is falling through the gap.
* `mario:axeenemiesfell(fallsound)` stops the music, plays `bowserfallsound` if `fallsound` is `true`, and starts the wait before the walk.
* `mario:axeenableplayer()` gives the axe player their physics back without controls, and `mario:axeplayerlanding(dt)` turns them left once they've landed.
* `mario:axestartcastle()` starts the walk and the course end sound.
* `mario:axewaterphysics()` switches the axe player to underwater physics and back.
* `castleanimationchaindisappear`, `castleanimationbowserframedelay` and `castleanimationnextlevel` are no longer used.

#### ⌨️ Text Input Keys

Every GUI text input now takes the usual editing keys:

* **Ctrl+←** and **Ctrl+→** jump a word at a time. A word is a run of letters, numbers and underscores, or a run of symbols, and spaces are skipped.
* **Ctrl+Backspace** deletes back to the start of the word before the cursor, and **Ctrl+Delete** deletes up to the start of the next one.
* **Delete** deletes the character after the cursor.
* **Home** and **End** go to the start and end of the text. In a text input with more than one row, they go to the start and end of the row the cursor is on.
* **Ctrl+Home** and **Ctrl+End** always go to the start and end of the whole text.
* With text selected, **Delete**, **Ctrl+Backspace** and **Ctrl+Delete** delete the selection.
* Holding **Shift** with any of the movement keys selects text, the same as **Shift+←** and **Shift+→**.

#### 🧱 GUI Functions

* `pausemenu_wraplabel(text, maxchars)` splits a pause menu label into lines of at most `maxchars` characters, at spaces.
* `accessibility.lua` holds the accessibility settings (`accessibility.<name>`), what they do, and the categorised layout both menus use. `accessibility_set(name, value)` changes a setting and saves it.
* `motion_scale(sx, sy)` is `love.graphics.scale` for an animation: with reduce motion on, it fades everything drawn until the matching `love.graphics.pop` instead of scaling it. `motion_zoom(zoom)` is 1 with reduce motion. Use them for any new pop-in or zoom animation.
* `graphicsalphamult` fades everything drawn while it's below 1: `love.graphics.setColor` multiplies the alpha by it and `getColor` divides it back out, and it goes back to what it was at the matching `pop`.
* `hudoutlined()` says whether the HUD is outlined (the mappack's `hudoutline` or the setting). `drawoutlined(fn)` draws something with a black outline a pixel wide.
* `accessibility_playerupdate(p, dt)` runs every frame for every player (jump buffer, coyote time, hold to swim, hold to fire). `accessibility_safeground(p)` remembers where a player last stood on solid ground, and `accessibility_pitrescue(p)` puts them back there.
* `accessibility_canskip()` says whether a course can be skipped (enough deaths on it), `accessibility_skipcourse()` skips it from the pause menu, and `accessibility_autoskip()` skips it by itself after a death when never skip automatically is unticked.
* `pausemenu_setpage(page)` slides the pause menu to page 1 (itself) or 2 (accessibility). `pausemenu_a11yrow()` is the keyboard's row for the **accessibility** button.
* `notice.mousepressed(x, y)` dismisses the notice under the mouse when notices stay until clicked.
* `PAUSERIGHT` holds the layout of the pause menu's right side, and `pausemenu_rightrow(name)` gives the `pausemenuselected` value of one of its rows (`"controls"`, `"deadzone"`, `"scale"`, `"letterbox"`, `"shader1"` or `"shader2"`).
* `pausemenu_setscale(i)`, `pausemenu_setletterbox(v)` and `pausemenu_setshader(slot, i)` change those settings from the pause menu and save them.

* `guielement:resetanimation()` starts a right-click menu's opening animation over.
* A slider's `drawtrack(self, x, y, w, h, radius, alpha)` now paints its colours inside the slider's glass track instead of drawing the whole track. It gets the box a game pixel in from the track's edge, fills all of it with colours at `alpha` (`SLIDER_TRACKPAINTALPHA`, 225), and the slider cuts the paint to the glass's rounded shape and lays the glass's rim back over it.
* `guielement:closeanimated()` closes a right-click menu with its closing animation, and `guielement:isclosing()` is true until it's finished, so the menu can be drawn while `active` is `false`.
* A right-click menu with `centerentries` set to `true` draws its title and options in the middle of their rows.
* `stoptestingbutton_draw()`, `stoptestingbutton_update(dt)`, `stoptestingbutton_mousepressed(x, y, button)` and `stoptestingbutton_mousereleased(x, y, button)` run the **stop testing course** button. `stoptestingbutton_click()` is what it runs when clicked.

### 🐛 Bug Fixes

* In Rival Rumble Royale, sudden death can no longer leave split screen on after the battle. Starting sudden death saved the split screen setting again, which could happen while the battle was still forcing it on. Now the setting saved when the battle started is kept.
* Music now plays again after the volume is turned up from 0%. Before, setting the volume to 0% and later changing it to any other volume left the music silent.
* `starmusic-intro.ogg` and `princessmusic-intro.ogg` now actually play. Before, built-in music only ever loaded its `-fast` version, and a mappack's star and princess themes were loaded without looking for an intro, so both themes always started without one.
* A mappack star theme with `starmusic-intro.ogg` but no `starmusic-fast.ogg` no longer plays an intro before the fast star theme only. Now the intro plays before the normal one as well.
* With **Continue subzone music** on, going into a subzone while the fast star theme was playing kept it playing as the course music. Now any version of the star theme counts, so the course's own music starts.
* Deleting a map from the **Maps** tab's right-click menu now takes its preview off the button straight away. Before, the deleted map's preview stayed on its button until the Course Maker was opened from the menu again.
* The **Maps** tab's right-click menu now pops out with its jelly every time it opens. Before, the animation only played the first time, and every menu after that appeared straight away.
* The **Maps** tab's right-click menu now animates closing too, instead of vanishing. Like a dropdown's options, it swells a little, then shrinks back into the corner it opened from over 0.2 seconds (`RIGHTCLICK_CLOSETIME`), with its width following its height. It stops taking clicks as soon as it starts closing, and right-clicking another map while it closes opens the new one straight away.
* While a right-click menu on an entity opens and closes in the Course Maker, the selected tile or entity is no longer drawn at the cursor, fading out and back in with the menu. It shows again once the menu has finished closing.

### ✨ Improvements

* The music priority only restarts a theme when the right version isn't already playing. If it's checked again partway through an intro (when the low time sound ends, or another player's star runs out), the intro keeps playing and the song still follows it.
* Removed the interval when adding points from the remaining timer at the end of a course. Points from the timer are now added without the previous delay between each one.
* The superball sounds are now fixed because I just had to remove the silence at the start.

#### 🛠️ Course Maker

* Loading a map in the Course Maker, or testing one, is faster. It no longer loads every custom enemy again each time. Enemies are only loaded again when the mappack or the players' characters change, and otherwise they just switch to the map's spriteset, the same as in normal play.
* Changes to enemy files made while the editor is open are now picked up with **refresh data** instead of by loading a map. Turn on `automaticenemyreload` to load them on every map load like before.
* Loading a map in the Course Maker no longer decodes its background and foreground pictures again when an earlier map already used them. Turn on `automaticbackgroundreload` to decode them on every map load like before.
* Loading a map, testing one and opening the editor panel no longer check every map file in the mappack. The map list is read when the Course Maker opens from the menu, and changes made outside the game are picked up with the **Maps** tab's **refresh data**. Turn on `automaticmapreload` to read them all again every time like before.
* **save level** in the **Maps** tab is now one line tall, so **refresh data** fits under it.
* The **Maps** tab's right-click menu draws its title and options (**copy**, **paste** and **delete**) in the middle of their rows.

#### 🎚️ Slider Tracks

* The skins tab's **coop portal 1 colour** and **coop portal 2 colour** sliders now have the same liquid glass track as every other slider, with the hue bar inside it. Before, the hue bar sat in a plain black box.
* The skins tab's red, green and blue sliders and the Font Renderer's colour sliders are glass the same way, with their gradients inside.
* None of these tracks has a black frame behind its colours any more. The glass's rim runs around the colours instead, and a little of the glass shows through them.
* Loading a map no longer reads and decodes every mappack animation again. Press the **Animations** tab's arrow button to pick up changes made to them outside the game, or turn on `automaticanimationreload` to read them on every map load like before.
* Loading a map that was already loaded no longer reads and parses its file again, unless the file or the tileset changed.

## v1.3.0

### 🧩 New Features

#### 🫧 Liquid Glass

The GUI is now made of liquid glass, in the style of iOS 26. The glass itself is in the new `guiglass.lua`.

* Every glass panel blurs whatever is already drawn behind it, but only inside its own rounded shape, so the blur is cut to exactly the part of the element you can see.
* The edges bend what's behind them like a lens, with a little colour split. A light rim runs along the edge, brightest at the top left with a softer glow on the bottom right, and a soft shadow sits underneath.
* An element's fill colour tints its glass and its border colour becomes the rim, so custom colours (the red save button, for example) still show.
* Corners are rounder: buttons, text inputs, checkboxes and dropdown headers use 0.3 of their shorter side. Slider and scrollbar handles are pill-shaped, or 0.3 for sliders with `buttonround`.
* This covers buttons, checkboxes, dropdowns, text inputs, sliders, scrollbars and right-click menus.

Glass also replaces the black boxes and outlines of things that aren't GUI elements:

* The world selection popup, the new game warning, the reset warning and the language menu.
* The pause menu and all of its prompts: quit to menu, quit to desktop, save game and save highscore.
* The pause menu's controls popup and both key prompts.
* Notices.
* The two tip boxes right of the mappack menu's lists (the mappack folder tip and the DLC tip).
* The controls tab's **F6** note.
* The minigames' description, settings and highscores boxes.
* The Course Maker's background. It's one big pane of glass over the course, lighter on the **Maps** tab like before. The elements on it read the course behind it, so they stand out from it.

Glass drawn on a canvas of its own reads what's on the canvas underneath. This keeps the mappack menu's pages glassy while they slide, and the Course Maker's panels while they zoom in and out. Before the fix, glass there came out as a solid tint.

#### 🧲 Motion

Every element now moves the same way.

* **Hover:** The element leans towards the mouse. It moves by 15% of the distance from its centre to the mouse, never more than an eighth of its diagonal (a quarter of the distance from its centre to a corner). The lean is lerped every frame, so it follows the mouse smoothly. Buttons still grow a little (1.03) and checkboxes pop up (1.12) while hovered.
* **Press:** Clicking an element squashes it wide (1.12 times as wide and 1/1.12 times as tall, so its area stays the same) on an ease-out curve over 0.2 seconds. It holds that shape until the mouse button comes up, wherever the mouse is by then, so moving the mouse away while holding doesn't let go early.
* **Jelly:** Once you let go, a spring wobbles the element back into shape.
* This works on buttons, checkboxes, dropdown headers, text inputs, and slider and scrollbar handles. Clicking a slider's track also squashes the handle it grabs. Handles don't lean while they're being dragged.
* A checkbox's tick still pops in when it's toggled.

#### 🔽 Dropdowns

* The header is one glass capsule with a thin divider before the arrow. The arrow turns over as the list opens and back as it closes.
* The list pops out of the header with a jelly, and each option pops in after it, one after another, starting with the one nearest the header. The gap between them is at most 0.022 seconds, and the whole cascade never takes more than 0.16 seconds, however long the list is.
* Closing runs the other way: the options furthest from the header shrink first, each swelling a little before it goes, then the panel follows 0.06 seconds later. Each shrink takes 0.2 seconds.
* The hovered option has a glass highlight that glides from option to option and fades in and out. Options keep their own colours instead of turning black on white.
* Lists taller than the screen still scroll, with a copy of the header at the top.
* Right-click menus pop out of the corner they opened at with a jelly. The picked option has a green highlight and the hovered one has a highlight that glides.

#### 🛠️ Course Properties

The Course Maker's **Course Properties** panel now opens and closes like a dropdown.

* Its button looks like a dropdown header, with the same divider and turning arrow. The button draws the arrow itself, so the `↓` at the end of its translated text is left out.
* The panel pops out of the button with the same jelly as a dropdown list, and its checkboxes pop in one after another. Closing shrinks them from the bottom up.
* Clicking anywhere outside the panel and its button closes it, like a dropdown.

#### 🖼️ Mappack and Minigame Icons

* Mappack icons (local and DLC), the "no icon" picture, the loading icon and the minigames' graphics now have rounded corners. Their radius is the frame's radius minus the 4 pixel gap around the icon, so the corners run alongside the frame's. A minigame's title and tagline are drawn on top and aren't cut.

#### ⚙️ Liquid Glass Settings

At the top of `guiglass.lua`:

* `guiglass.quality`:
  * `"full"`: the blur behind the glass is redone up to 60 times a second.
  * `"lite"`: redone 4 times a second. It looks the same, since the blur is always taken before any glass is drawn.
  * `"flat"`: no blur, just tinted glass.
  * `"auto"` (the default): see below.
* `guiglass.minfps` (200 by default): the frame rate `auto` aims for with vsync off. With vsync on, it aims for the monitor's refresh rate instead.
* `guiglass.enabled`: `false` is the same as `"flat"`.
* `guiglass.blur` (3), `guiglass.refraction` (1.6) and `guiglass.tintstrength` (0.42) set how blurry the glass is, how much its edges bend (both in game pixels) and how much of the fill colour is laid over it.

**Auto quality** watches the frame rate one second at a time:

* If the game stays below its target for 2 seconds while glass is on screen, it steps down from full to lite, or from lite to flat.
* A step is only kept if it makes the game at least 10% faster. If it doesn't, the slowdown is coming from something else: auto steps back and stops trying.
* Once a screen has less than half the glass panels it had when it stepped down (leaving the Course Maker, for example), it goes back to full.

#### 🧱 GUI

For anyone building menus:

* `guiglass.panel(x, y, w, h, r, options)` draws a glass panel where `love.graphics.rectangle("fill", x, y, w, h, r)` would go. Its options include `tint`, `tintstrength`, `rim`, `rimstrength`, `alpha`, `shadow`, `nobackdrop` (a tinted pane without the blur, for things inside another panel) and `base` (the glass on top of it reads what's behind it instead).
* `guiglass.box(x, y, w, h, r, alpha)` is a popup box: glass with a bright rim, in place of a black box with a white outline.
* `guiglass.pill(x, y, w, h, r, color)` is a cheap tinted pane, like a dropdown's highlight.
* `guiglass.push(element, cx, cy, w, h, hovering, options)` and `guiglass.pop()` give anything drawn between them an element's lean, squash and jelly.
* `guiglass.beginround(x, y, w, h, r)` and `guiglass.endround()` cut everything drawn between them to a box with rounded corners. `guiglass.insetradius(button, inset)` gives the radius that runs alongside a button's corners.
* `guielement.drawdroppanel(owner, open, x, y, w, h, rows, options)` draws a panel that opens and closes like a dropdown list, with each row popping in after the last.
* A button with `droparrow` (a function that returns how far it's open, from 0 to 1) ends with a dropdown's divider and turning arrow.
* `element:mousepos()` gives the mouse in the element's own coordinates.

#### 🕹️ Konami Code

* Typing the Konami code in the menus now also unlocks every world in the open mappack, on top of unlocking cheats. Every world can then be picked straight away in the world selection popup.
* Only worlds that actually exist (with a `N-1.txt` course) are unlocked, so the popup never offers a world that can't load.
* The unlocked worlds are saved straight away, like the cheats. A second notice, "All worlds unlocked!", shows under "Cheats unlocked!" whenever at least one new world was unlocked.

### ✨ Improvements

* The pause menu's controls popup now shows the **F6** note to the right of the popup, in a glass box centred halfway down the screen, like the note in the options menu. Before, it was squeezed in under the popup's title. Its lines wrap to fit the box.
* Each canvas is blurred once a frame and every glass panel on it reads that blur. It's only blurred again when a panel would sit on top of glass drawn since, like an open dropdown over the buttons below it. Slider tracks don't count, so their handles don't make it blur again.
* The blur is done at the game's own resolution (400x224), so it costs the same however big the window is.
* The middle of a glass panel only reads and tints the blur. The bending, colour split and rim are only worked out in a band along the edge, at most 6 game pixels wide.
* When the window isn't resizable, the frame is drawn to a canvas first so the glass can read it back. This only happens while glass with a blur has been on screen in the last 30 frames, and never in flat mode, so plain gameplay draws straight to the window. A menu's first frame on screen shows its glass without the blur.

### ❌ Removals

* The mappack icon border (`graphics/GUI/mappackoverlay.png`) is no longer drawn or loaded. The file is no longer there.
* Buttons no longer zoom in and out when pressed, and the Course Maker's scroll factor sliders no longer push-zoom. The press squash and jelly replace both.
* Dropdown lists no longer slide out of a clipped box, and no longer have a grey drop shadow behind them. They pop out with the jelly and cast the glass's soft shadow instead.

## v1.2.2

### 🧩 New Features

#### 🎨 Skins Menu

The skins tab has been rebuilt with graphical dropdowns and real sliders, in place of the old left-and-right arrows and fake sliders.

* **Edit player** is now a dropdown, in the same place and with the same layout as the one in the controls tab.
* **Character** is a dropdown next to the portal preview. Each option shows the character's skin with its name underneath, in one option.
  * The character you're playing as is drawn in your colours and hat. Every other character is drawn in the colours and hat that picking it would give you (its `defaultcolors` and `defaulthat` for that player).
  * Every skin stands on the same line just above its name, centred on the character's middle, which is where the game centres it in a course (`6 - smalloffsetX + smallquadcenterX` across its standing frame). Custom characters line up too, however their frames are padded. The big preview on the left is placed the same way.
  * A name that's too long for the box slides along to its end and back, so all of it can be read.
  * If the list is taller than the screen, it scrolls like any other long dropdown.
* **Hat** is a dropdown of only the hat graphics, laid out in a grid 6 wide, so every hat fits on screen at once. The first one, a crossed-out circle, takes your hat off.
  * The standard hat is drawn in your first colourable's colour, like it is on the player.
  * A character that can't wear hats shows "disabled", and the dropdown doesn't open.
* **Colour** is a dropdown of the character's colourables, each one shown with its colour next to its name.
* **Red**, **green** and **blue** are sliders now.
  * Each track shows what the colour would be along it, with the other two channels as they are.
  * The value is shown in the middle of the handle.
  * The full colour is shown to the right of the three sliders.
* **Coop portal 1 color** and **coop portal 2 color** are sliders too. Their tracks are the hue bar, the handle is filled with the portal's colour, and the full colour is shown next to each one.
* The sliders work like the volume slider: drag the handle, or right-click anywhere on one to type a number. Clicking anywhere on a track also jumps the handle there and grabs it. The mouse wheel doesn't move them, so a colour can't change without being saved. Letting go saves the game.
* A character without any colourables doesn't show the colour dropdown or the red, green and blue sliders, and its portal colours are the next rows down for the keyboard, as before.
* Every character's skin is loaded when the menu loads, so the skins tab never stops to load one. A character added later (a downloaded one, for example) loads the first time it's drawn.

**Keyboard**

* The rows are the same as before: tabs, edit player, character, hat, colour, red, green, blue, then the two portal colours.
* Enter opens the selected row's dropdown. Up and Down move through an open list, Enter picks, and Escape closes it.
* In the hat grid, Left and Right move along a row and Up and Down move along a column. Both wrap around.
* Left and Right still change the player, character, hat and colourable without opening anything. A character is now picked straight away. Before, it was only applied once you left the row.
* Holding Left or Right (or A and D) on a colour or portal row still changes it smoothly, and the slider follows it.
* While a skins dropdown is open, the other keys don't change what's under it.

#### 🎚️ Slider Animations

* Every slider's handle border now fades between dim and bright, easing in and out like a dropdown's border, when it's hovered, dragged, typed into or selected with the keyboard. Before, it switched instantly. This covers all sliders: the volume slider, the Course Maker's sliders, the skins sliders and the scrollbars of long dropdowns.
* Scrollbars now light up when they're selected with the keyboard too, the same as horizontal sliders.
* In the skins tab, the red, green and blue sliders glide over to their new values when you switch to another player, character or colourable. The portal sliders glide when you switch to another player, since their colours belong to the player. Each glide takes 0.25 seconds and eases out (`ease_out_quad`), and the handle shows the value it's heading to.
* Holding a key on a colour row and dragging a handle stay instant. Grabbing a handle while it's gliding stops the glide.
* Everything showing those colours glides with the handles: the red, green and blue tracks, the full colour to the right of them, the colour square in the colour dropdown, and each portal slider's handle and colour. Before, the handles glided but the colours jumped straight to the new ones.

#### 📑 Tab Animations

* Switching tabs in the options menu and the Mappack Creator now slides the old tab out and the new one in, instead of swapping them instantly. Moving to a tab further right slides the pages left, and moving back slides them right. Each slide takes 0.25 seconds and eases in and out (`ease_in_out_quad`).
* The pages are cut to the menu's dark box while they slide, so they never spill over the course behind it.
* The tab names, the line under the Mappack Creator's tabs and its **Back** button stay where they are.
* Nothing on either tab can be clicked, typed into or hovered until the slide ends. Pressing Left or Right again, or clicking another Mappack Creator tab, starts a new slide straight away.
* The controls tab's keybind pages are cut to the options box the same way, and follow the tab while it slides.
* The mappack menu's pages (**Local**, **DLC**, **Daily Challenge** and **Minigames**) slide the same way. Before, they crept towards the new page, the panel right of each list popped in and out, and they overlapped each other on the way. Now the old page slides out while the new one slides in, and each of the page's two areas slides inside its own box: the list (or the daily challenge) in the list's box, and the panel right of it in the panel's box. Nothing from one area shows up in the other, and nothing is left behind or disappears when the slide ends. The slide starts on its first frame on screen, so opening **DLC** still slides even when the game stops for a moment to download its list. Left and Right keep going the same way when they wrap around from one end to the other, and clicking a tab slides towards it.

#### 🎮 Joysticks

**Any input on any control**

* A controller's buttons, hats and sticks can now be bound to any control. Before, run, jump, reload, use, the portals and pause only took buttons, and the aim controls only took sticks. The "you can only set buttons/axes for this" messages are gone, apart from one case: a keyboard key still can't be bound to aim, since a key has no direction to aim with.
* A stick or hat bound to a button control acts like a button: it presses the control once when it goes past the deadzone (or the hat turns that way), and releases it when it comes back. This works everywhere a controller button does: in courses, the pause menu, the menus and the level screens.
* A button bound to aim aims right or down while it's held, as if that stick were pushed all the way. A hat aims the way it was pushed when it was bound.

**Joystick deadzone**

* A new **Joy deadzone** slider in the misc. tab, right above **Scale**, sets how far a stick has to move before it counts. **Scale** and **Letterbox** moved up to make room, and everything from **Shader1** down stays where it was.
  * At **0%**, any movement off the centre counts.
  * At **100%**, only a stick pushed all the way counts.
  * Anything in between counts once the stick is further from the centre than that.
* It works like the volume slider: drag it, click the track, right-click to type a value, or use Left and Right on its row to change it in steps of 5%. Letting go saves the game.
* Setting it below 10% shows a red notice warning that sticks may drift and press things by themselves. The notice is in English whatever the language, like the game's other notices. Changing it again while the notice is up keeps that notice on screen instead of adding another.
* It's saved as `joydeadzone` in `options.txt`, straight after `scale`. It starts at 25%, the same as before, and **Reset All Settings** puts it back there.
* It covers every stick input: moving, button controls on a stick, and aiming. For aiming, the deadzone is measured by how far the stick is from its centre in any direction, instead of on each axis separately.
* Binding a stick in the controls tab still needs a quarter of a push (`joystickbinddeadzone` in `variables.lua`), so a stick that drifts a little can't bind itself when the deadzone is low.

#### 🎞️ Animation Curves

Animations no longer pick a random motion curve each time they start. Every animation now eases in and out quadratically (`ease_in_out_quad` in `main.lua`), so the same animation always moves the same way.

* This covers the GUI (buttons, checkboxes, dropdowns, slider borders and text cursors), the pause menu and its prompts, the language menu, the editor panels, the world selection cursor, transitions, splitscreen viewports and their death fades, the camera interpolation, the minigames' revive prompt, and the options menu and Mappack Creator tab slides.
* A slider that moves to a new value by itself, without the mouse, eases out (`ease_out_quad`) whichever way it goes: Left and Right on the volume and joystick deadzone sliders, and the skins sliders gliding to another player's colours. Before, going left eased in and going right eased out.
* Only the intro's scaling still uses a random motion curve (`random_motion_curve`).

#### 🔽 Dropdown Animations

* When a dropdown's option changes without the mouse (Left and Right on its row, a controller, picking from the open list with the keyboard, or something else changing it), the new option slides into the header sideways and pushes the old one out, easing out (`ease_out_quad`). It comes in from the right when it's further down the list, and from the left when it's further up. Going past either end of the list keeps going the same way.
* Picking an option with the mouse still changes it straight away.
* An open dropdown (or one still animating closed) is always drawn above the rest of the game, so it stays on top of menus, the editor and course content. The FPS, battery, time and other overlay elements still draw above it.

#### 🧱 GUI

For anyone building menus with the GUI:

* Dropdowns can be graphical. `dropdown:setentrydrawing(drawfunc, rowheight, columns)` makes a dropdown draw its own entries with `drawfunc(self, i, x, y, w, h, highlighted, header)`, gives it taller rows (`rowheight`, 10 by default), and lays the list out in a grid (`columns`, 1 by default). The header is a row tall plus a pixel. Opening, closing, scrolling, hovering, clicking and the keyboard all work with them.
* `dropdown:setentries(entries, var)` changes a dropdown's entries and works its layout out again.
* Horizontal sliders have a few new options:
  * `drawtrack(self, x, y, w, h, radius)` paints the track instead of the plain background colour.
  * `centerdisplay` puts the shown value in the middle of the handle.
  * `trackclick` makes a click on the track jump the handle there and grab it.
* `loadcustomplayergraphics(name)` loads a character's images and quads without picking it. `setcustomplayer` uses it too.

### 🐛 Bug Fixes

* A character's quads are now only built once. `setcustomplayer` checked a `quads` flag that was never set, so it rebuilt every quad of the character each time it ran.
* In a dropdown list too long for the screen, the entry under the mouse is now the one drawn there. Before, the mouse was a pixel off at the line between two entries.
* Switching to a player whose character has fewer colourables than the one you were editing no longer leaves the colour row pointing at a colourable that doesn't exist.
* A character whose `colorables` list is empty is no longer treated as having colourables.

### 🚨 Major Bug Fixes

* Pause bound to a controller button now pauses and unpauses the game. Pressing it acted like pressing Escape, but the game only paused if Escape itself was a pause bind. Once pause was bound to a controller button instead, Escape wasn't, so the press did nothing. The controller's pause button is now always treated as a pause press, and it still backs out of the quit prompts like Escape does.

### ✨ Improvements

* Pressing Right on **Controls** in the pause menu no longer opens the controls. Enter (or clicking it) still does.
* `getproperwindowsize` now measures what the game is drawn on, instead of working it out from `width`, `height` and `scale`: the game's own canvas when the window is resizable (it's stretched to the window afterwards), otherwise the window itself. Prompts, the controls popup and the fades that use it line up with the real window when it isn't the size those variables say, like in fullscreen without the resizable scale.
* `getCanvasSize` (how much the game's canvas is scaled to fit the window) now measures the canvas and the window too. Before, it always used `400*scale` by `224*scale` and the `winwidth` and `winheight` variables, since the canvas's real size was read into variables that were thrown away straight after. Without a resizable window it returns 1, since nothing is scaled.
* Escape now closes an open dropdown first in every options tab, instead of leaving the options menu with the dropdown still open.
* Sliders that show their value in the middle of the handle (like the skins tab's red, green and blue) now keep it in the middle while you type a value after right-clicking. Before, the text jumped to the left edge of the handle. The text glides along with the typing cursor as it grows or shrinks.
* The controls tab's **F6** note now sits in a box on the right of the options menu, centred halfway down the screen, where the DLC tips are in the mappack menu. Before, it was squeezed in at the top of the screen. Its lines wrap to fit the box, and it fades in and out when you switch to or from the controls tab.

#### 🔤 Font Renderer

* The red, green and blue sliders now show what the text colour would be along each track, with the other two channels as they are, the same as the skins tab's sliders. Before, each track was a flat dark red, green or blue. The tracks update live as you move any of the three sliders or press **HUD Colour**.

### ❌ Removals

* The skins tab's `{` and `}` arrows and the hue bar markers are gone, replaced by the dropdowns and sliders. `huebarmarkerimg` is still loaded, but the menu no longer draws it.

## v1.2.1

### 🧩 New Features

#### 👾 Size Change Handling

A new custom enemy property, `donotpassupdatewhensizechange`. Set it to `true` in the enemy's JSON file, and the enemy keeps `updatewhensizechange` to itself instead of passing it on.

```json
"donotpassupdatewhensizechange": true
```

* Normally, an enemy with `updatewhensizechange` set to `true` passes it on to the enemies it spawns (`spawnsenemy` or `spawnchildren`) and the enemies it transforms into.
* With `donotpassupdatewhensizechange`, those enemies don't get it. They only keep updating during a size change if their own JSON has `updatewhensizechange`.

#### 🛹 Inertia Physics

A new nitpick, `inertiaphysics`. When you jump or fall off something that's moving, you keep its speed, the same way you would in real life. **Generate Nitpicks File** adds it to an existing file.

* It works on everything that carries the player: moving platforms, objects on tracks, custom enemies with `platform`, Big Moles, Shy Guys, seesaws and snake blocks.
* Seesaws and snake blocks only carry you up and down, so they only pass on their vertical speed.
* **Getting on:** If you land on a moving object while you still have speed from another one, your speed becomes relative to the new object, so you don't slide off it. Landing on it from the ground or a tile keeps your speed like normal.
* **Riding:** The game keeps track of the object's speed every frame while you're on it.
* **Getting off:** The object's horizontal speed is added to yours. If it was going up, its upward speed is added too: jumping adds it to your jump, and falling off gives you whichever of the two is faster upwards, so objects that already push you up don't push you twice.
* Landing on solid ground (or anything that isn't moving) makes it count as your new starting point, so your speed goes back to normal.
* Pipes, cutscenes, dying and sideways gravity drop the object without flinging you anywhere.
* Only players are affected. Enemies and items ride objects the same as before.

### 🐛 Bug Fixes

* Fixed a crash whenever a custom background was drawn. The check for a background that doesn't scroll sideways compared the scroll factor against `scrollfactormax`, which doesn't exist.
* Custom backgrounds now stop scrolling sideways at the highest scroll factor, the same way they already did up and down.
* Players can't die while the screen fades out for the next course, or for an animation's `loadlevel` or `loadlevelinstant` action. Before, falling into a pit or touching an enemy during the fade could kill you after you'd already finished.
* Moving up through a top-only object from below no longer sticks you onto its top when you aren't holding jump. Letting go of jump ends the jump while you're still going up, and moving objects only skipped players who were still jumping, so your feet got pulled onto the top as soon as they reached it. Now you carry on up and only land on it when you come back down. This covers moving platforms, objects on tracks, custom enemies with `platform`, seesaws and donut blocks.
* Standing on a rising custom enemy with `platform` no longer shows the running frames when you should be skidding. The game used to think you were falling, since the enemy was moving up from under you.
* Going from big to bunny (with a Carrot) or from bunny to big now flashes between the two looks, like every other big-to-big change. Bunny Mario uses the big sprite with the ears drawn on top, and the ears only checked your real power-up, not the look the animation was showing. Both looks were the same big sprite, so nothing flashed and the ears just popped in or out. Now the ears follow the look that's on screen, with `modernsizechangeanimation` and with `dontfreezeonsizechange`. A custom power-up with bunny ears only shows them on the frames that show its own look.

### ✨ Improvements

#### 🍩 Donut Blocks

* A donut block now falls after `donutfalltime` seconds (1 by default, in `variables.lua`) instead of half a second.
* The shake is now a smooth sine wave instead of a zigzag. Each shake lasts 1/`donutoffsetspeed` seconds (`donutoffsetspeed` is 8 by default, in `variables.lua`).

#### 🧊 Icicles

* When a player below is within `icicleshakedist` tiles of an icicle sideways (5 by default), it shakes by tilting back and forth. The tilt follows a sine wave that's 1/`donutoffsetspeed` seconds long and goes up to `icicleshakeangle` degrees each way (18 by default). It doesn't move sideways.
* It stops shaking if every player moves out of range.
* When a player below gets within `iciclefalldist` tiles (2 by default), it stops shaking and holds still for half a second (`goombadeathtime`), then falls. Before, small icicles fell straight away once a player was within 3 tiles, and big ones shook sideways for 0.8 seconds once a player was within 2.
* This works for small and big icicles. Big icicles that are set not to fall don't shake either.
* Hitting a big icicle from below starts the same half-second wait.

#### 🗿 Thwomps

* After a Thwomp pounds and goes back, it waits `thwomprestwait` seconds (0.25 by default, in `variables.lua`) before it can attack again. Before, it was half a second. The wait starts once it's stopped: when it gets back to its spawn, or when it hits a ceiling (or a wall for sideways Thwomps) with **return to spawn** off.
* It keeps the same sprite while it waits, and doesn't look at players until the wait is over.
* A left-facing Thwomp only notices a player whose x minus their width is less than its own x minus its width. Downward and right-facing Thwomps still only notice players below them or to their right.

#### 🐹 Monty Moles

* A mole that jumps out of the ground now keeps its jump sprite until it lands. It only starts its walking animation and chasing the player once it's back on the ground. Before, it switched to walking and started chasing while still in the air.

#### ⛓️ Chain Chomps

Chain Chomps now attack like in Super Mario Maker 2.

* Once it spots a player, it stops and waits 1 second before lunging, instead of under half a second. The wait is set by `chainchompattackwait` in `variables.lua`.
* While it waits, it keeps chomping like normal instead of freezing on one frame.
* As soon as the wait starts, it points straight at the player and locks on. It doesn't turn while it waits, and it lunges the way it locked on, even if the player has moved.
* It stays pointed that way until it starts heading back, then turns back upright.
* It never lunges downward. If the player is even a little below it, it lunges straight sideways instead.
* Chain Chomps no longer pass through walls or ceilings. A lunge that hits one stops there (this doesn't count as a try at breaking free). Walking or bouncing into a wall turns them around, and a free Chain Chomp bumps its head on ceilings instead of going through.
* While it's attacking, it chomps twice as fast.
* A try at breaking free now counts when the chain actually stops a lunge, not when the lunge starts. As soon as that count reaches `chainchompfreecount`, the stake gives way: the Chain Chomp keeps going the way it lunged, with its broken chain trailing behind it.
* The links follow it like a Wiggler's body: each one traces the exact path the Chain Chomp took, a set distance behind the one in front. The spacing is `chainchompfreelinkdist` (6/16 of a tile by default). A Chain Chomp that comes out free (from a pipe, for example) trails a chain too.
* A free Chain Chomp keeps bouncing along the ground instead of dropping through it after a few bounces, and always faces the way it's going.

#### 🎬 Animations

Mappack animations now stop completely while the game is paused or frozen for a size change.

* Nothing in an animation runs, waits or counts time while the pause menu is open or the game is frozen.
* Pressing a button while paused or frozen doesn't trigger anything, and neither does letting go of it afterwards.
* A button release only triggers if its press did. Holding a button from before the course started and letting go no longer sets off a release on its own.
* Letting go of a button while paused or frozen triggers once the game carries on, as long as the button is still up by then.
* Landing and getting hurt don't trigger animations while the game is frozen.

## v1.2.0

### 🧩 New Features

#### 🧰 Utils

A new **Utils** option on the title screen, under **Options**. It opens a hub with three tools: the **Character Formatter**, the **Font Renderer** and the **Mappack Creator**, plus **Back**.

* The title screen items are now 12 pixels apart instead of 16, so **Utils** ends where **Options** used to and nothing moves off the screen. **1 Player Game** stays where it was.
* Move through the hub with Up and Down (or W and S) and pick a tool with Enter or Space, or use the mouse. The bottom of the hub explains the selected tool.
* Escape goes back a page, and from the hub it goes back to the title screen, with **Utils** still selected. Escape closes an open dropdown first.
* Every tool page has a **Back** button in the bottom right corner. While a tool is still working, Back and Escape wait, and a notice says "wait until it's finished!".
* The tools do their work in the background, a little every frame, so the game never freezes while they run. Progress bars show how far along they are.
* While Utils is open, it gets every click and key press first, so nothing else in the game can take them. F keys and Alt+Enter (fullscreen) still go to the game.
* If something in Utils breaks, the game doesn't crash. The panel shows the error instead, and it's saved to `alesans_entities/crashes/utils_error.txt`. Escape or Enter goes back to the title screen.
* Every bit of text in Utils is translated into every language the game has.

#### 🎨 Character Formatter

Splits a character's animation sheets into the colour layers the game uses for colourable characters.

* Pick a character from the dropdown. It lists every folder in `alesans_entities/characters` that has a `config.json`.
* The page shows the character's colours from the `colors` list in `config.json` as swatches, and every sheet it will split. A sheet is any `.png` whose name ends in `animations`, like `animations.png` or `biganimations.png`.
* **Format** copies the character to a new folder, `<name>_formatted`, and splits every sheet there:
  * Every fully opaque pixel that matches colour N of the list goes into layer N (`animations1.png`, `animations2.png` and so on), drawn in white.
  * Every other pixel goes into layer 0 (`animations0.png`) with its own colour.
* Layers the character already has, made by hand, are kept as they are and aren't written over.
* When it's done, the page says how many layers it wrote. Restart the game to play as the formatted character.
* **Open Folder** opens `alesans_entities/characters`.
* **Format** can't be pressed while the character has no colours or no sheets. A `config.json` without a `colors` list, or with a colour that isn't three numbers, shows what's wrong in red.

#### 🔤 Font Renderer

Renders text with the current mappack's font to a `.png`, for thumbnails, title cards and the like. The font in use is shown in the top right corner.

* Type in the text box. It shows 6 lines, holds up to 2,000 characters and scrolls both ways. Enter makes a new line.
* The text box works like a normal one: the arrow keys, Home and End move the cursor, Backspace and Delete remove characters, the mouse wheel scrolls, and clicking moves the cursor there.
* **Ctrl+V** pastes, **Ctrl+C** copies all the text, and **Ctrl+X** cuts all of it.
* Characters the font doesn't have show up as a red `?` in the text box, so you know they won't be in the render.
* **All caps** draws the text the same way the game does with its capitals font. It's on by default.
* **Outline** adds the font's black outline.
* **Align** lines up lines of different lengths to the left, centre or right.
* Three red, green and blue sliders set the text colour, with a swatch next to them. They start on the mappack's HUD colour and outline. **HUD Colour** goes back to them.
* The render updates as you type and shows up under the sliders on the game's sky colour, so the outline can be seen, with its size in pixels.
* **Save PNG** saves the render to `renders/text <date> <time>.png` in the save folder.
* **Copy Image** puts the render on the clipboard, with its transparency where the system allows it. It uses PowerShell on Windows, `osascript` on macOS and `xclip` on Linux. If that doesn't work, the image is saved to `renders/clipboard.png` instead and a notice says so.

#### 🗺️ Mappack Creator

Makes a new mappack filled with blank courses and subzones. Its options and project files match the Python Mappack Creator, so projects work in both.

The creator has six tabs: **General**, **Worlds**, **HUD**, **Text**, **Course** and **Create**. Click a tab, or use Left and Right (or A and D) when you aren't typing.

**General**

* **Name** (the folder name), **Display name** (up to 17 characters), **Author** (up to 13) and **Description** (up to 51, over three lines).
* **Lives**, from 0 to 9999. 0 shows "infinite lives!".
* **Physics:** Mari0, SMB, Mari0-SMB2J, SMB2J, Mari0-Maker, Mario Maker or Portal.
* **Camera:** Default, Centered or Forward Only.
* **Icon:** Drop an image onto the window to use it as the icon. It's kept as it is. Right-click the icon frame or press **Clear** to remove it.
* Lives and the course time limit use steppers like the editor's time limit: hold an arrow to keep counting, or click the number to type one.

**Worlds**

* **Drop shadow** (with a warning that it reduces performance), **Real time**, **Continue subzone music**, **No hurry music** and **No coin limit**.
* **World count** (1 to 999), **Courses per world** (1 to 99) and **Subzones per course** (1 to 13) are sliders. **Do not create subzones** hides the last one.
* The number of files to create is shown at the bottom. Its colour fades from grey through orange to dark red as it gets bigger.

**HUD**

* **Player name**, or **Use character name for player name**.
* **HUD colour**, from 14 colours, each one shown in its own colour.
* **Use letters for worlds above 9**, **Visible HUD**, **Outlined HUD**, **Simple HUD** and **Allow cheats**. Simple HUD always uses the character's name.
* **Hide HUD collectables**, with a checkbox for each of the 10 collectables.

**Text**

* The two ending lines and their colour, Toad's three lines and Peach's five lines.

**Course**

* The defaults for every new course: **Time limit** (0 to 9999, in steps of 10; 0 shows "infinite time!"), **Portal gun** (Normal, None, 1 Only, 2 Only or Gel), and the background and foreground scroll factors (0 to 9, in steps of 0.1).

**Create**

* Before anything is made, the creator checks the values and lists anything wrong in red. The **Create** tab's name turns red while something is wrong. A mappack can't be made if:
  * The name is empty, has `/ \ : * ? " < > |` in it, or is already a folder in the mappack folder.
  * The display name, author or description is too long, or the display name is empty and the name is longer than 17 characters.
* Large mappacks only get a warning. From 1,000, 10,000, 100,000 and 1,000,000 files, it says the mappack will take some time, a lot of time, a very long time or a ridiculously long time to make. These limits are `MAPPACKCREATOR_FILEWARNING` and the others at the top of `utilsmenu.lua`.
* **Create Mappack** writes the mappack to the mappack folder with a progress bar:
  * `settings.txt`, `text.txt` and `icon.png`.
  * The `animated`, `animations`, `backgrounds`, `custom`, `enemies`, `music` and `sounds` folders.
  * A blank 25x15 course for every course and subzone (`1-1.txt`, `1-1_1.txt` and so on), with sky and two rows of ground.
* If making the mappack fails, the half-made folder is removed.
* **Delete Mappack** deletes the mappack with the current name. Click it twice within 3 seconds to confirm. It only deletes mappacks the creator made, and only in the save folder.
* **Prevent deletion from the mappack creator** (on by default) stops **Delete Mappack** from deleting the mappack later. Mappacks made since the game started can always be deleted.
* **Save Project** saves every setting, including the icon, to `alesans_entities/mappackprojects` as `.mpckproj`, `.json` or `.cfg`.
* **Load Project** loads a project picked from the dropdown. Dropping a project file onto the window loads it too.
* **Reset Properties** puts everything back to default. Click it twice within 3 seconds to confirm.
* Text is lowercased when a project is loaded, since the game's text boxes don't show capitals properly.

### ✨ Improvements

#### 🎚️ Sliders

* Right-click anywhere on a slider, not just its handle, to type a number. Enter sets it, and Escape or clicking somewhere else cancels.
* Typing works on every slider now, not only the ones with a fixed range. The box starts with the slider's current value, and a typed number goes to the closest place on the slider that shows it, even when the slider's scale isn't straight.
* A typed value counts the same as letting go of the slider, so anything that happens on release happens then too.
* The typing cursor fades in and out with a random motion curve and glides between characters, the same as in text boxes.
* Slider tracks are now rounded to match their handles.
* While you're typing a value, the keys you press go to the slider and nothing else.

#### 🛠️ Course Maker

* Typing a value into the autoscroll speed slider uses the real speed, and typing into the scroll factor sliders uses the scroll factor shown on them, instead of the slider's position.
* Changing the autoscroll speed or a scroll factor now counts as an unsaved change to the course.

#### 🌐 Languages

* Spanish, Esperanto, Portuguese, Russian and Turkish now have translations for the Course Maker's **Cont. music**, **No low time** and **No coin cap** settings.

## v1.1.1

### 🧩 New Features

#### 🥊 Rival Rumble Royale

A four-player battle minigame inspired by the battle mode of Super Mario 4 Jugadores. Grab power-ups from the ? blocks and knock everyone else out. The last one standing wins.

**Players and settings**

* Four players battle in every round. Any players that aren't human are bots.
* **How many players are human?:** 1 (P2 to P4 are bots), 2 (P3 and P4 are bots), 3 (P4 is a bot) or 4 (no bots).
* **Bot difficulty:** 25 levels, from Complete Noob to THE UNDEFEATABLE, with Skilled as the default (see **Bot Difficulty** below). The dropdown colours them from green for the weakest to dark red for the strongest.
* **Battle theme:** Overworld, Underground, Castle, Portal or Night Overworld (the Overworld with a grey palette and a black sky).
* **Battle music:** Overworld, Underground, Castle, or any custom song (see **Custom Music** below). Long names are shortened in the closed dropdown, and the list opens wide enough to show them in full.
* **Bot Splitscreen:** On by default. Gives the bots their own viewports as well, so you can watch them. When it's off, only the human players get a viewport.
* **Starting lives:** A slider from 5 to 100, 10 by default.
* **Timer:** A checkbox with a slider from 100 to 1000 seconds, in steps of 10. The slider only works while the box is ticked.
* Split screen is always on, whatever the `splitscreenmultiplayer` nitpick is set to. With one viewport, it fills the whole screen.
* The battle uses the game's own physics instead of the Super Mario Maker physics the other minigames use.

**Starting a battle**

* P1 spawns at the top left of the arena, P2 at the top right, P3 at the bottom left and P4 at the bottom right.
* A countdown in real time shows **3**, **2** and **1** (one second each, with the new `countdownbeep.ogg`), then **go!** (with the new `countdowngo.ogg`). Nobody can move before **go!**, and the music only starts then.

**Arenas**

* Every battle gets a new arena in its theme's style, 40 tiles wide and 30 tiles high, with the camera scrolling up and down. Both halves of the arena mirror each other, so it's fair.
* The Overworld has pipes, hills, bushes, trees and clouds. The Underground has a brick ceiling and pipes. The Castle has lava pits. The Portal test chamber has a pillar in the middle.
* Platforms are stacked up to near the top of the arena, each one 3 or 4 tiles above the last. The rare block sits over the highest platform in the middle.
* Every arena is checked before the battle starts: every spawn has ground under it, every ? block can be hit from below, there is a route to every spawn and block (the same routes the bots use), and every ? block has at least 3 empty tiles above it. With a platform any closer, a bot jumping from on top of the block could get pushed into the tiles and through the wall. If 40 arenas in a row fail the check, the theme's fixed arena is used instead.

**? Blocks**

* When a ? block is ready, a roulette of its items is drawn on the block, changing every 0.2 seconds. It's drawn behind everything else.
* When a block is on cooldown, it shows the seconds left. It can still be bumped, but nothing comes out.
* When the cooldown ends, the roulette starts over from the block's first item, on the block's own clock, so blocks that become ready at different times don't cycle in step. With `removecooldowns`, it starts over straight after every hit.
* **Spawn blocks:** One sits 3 tiles above each spawn. 10-second cooldown. Fire Flower, Hammer Suit or Boomerang Flower.
* **? blocks:** 15-second cooldown. Super Leaf, Tanooki Suit or Superball Flower.
* **Rare block:** 30-second cooldown. Blue Shell, Super Star or Cape Feather.

**Power-ups and getting hurt**

* Power-ups apply instantly, without the grow or shrink animation. Getting a power-up while small gives you that power-up straight away, not just Super form.
* Getting a power-up, respawning or taking damage gives you 1 second of invincibility. The blinking animation starts at 2.2.
* Hits always damage instead of killing outright, under any physics. A powered-up player drops to Super form, a Super player drops to small, and a small player dies.
* Fireballs, superballs, hammers, boomerangs and tails hurt every player except the one who threw them.
* A player with a Super Star, or in a Blue Shell at full speed, hurts anyone who touches them and can be hurt. Two Blue Shells that meet bounce off each other.
* A Tanooki Suit player in statue mode can't be hurt, and hurts anyone who touches them.
* Any player can stomp on another player's head and bounce off it, like bouncing off an enemy. The player underneath only takes damage when they can be hurt. The player on top never gets hurt by the stomp, even when landing on a Super Star or a fast Blue Shell. After a stomp, those two players can't hurt each other by touching for 0.25 seconds.
* Bots also follow the `infinitefireballs` nitpick. Without it, they only press fire when a shot can actually come out. With it, they shoot faster, but never more than about as fast as someone can mash the button.

**Lives, knockouts and winning**

* A player who loses their last life is out. Once their death animation is over, their viewport is removed, and the other viewports slide and resize into the new layout with the same random motion curves as the pause menu. The last viewport is never removed: if its player is out, it stays on that player and fades out, without switching to spectate anyone else.
* A knockout counts for the player who hit you, if you die within 4 seconds of their hit (falling into a pit, for example). The HUD shows every player's lives and knockouts, and marks the bots with "CPU".
* A human player who is out can type the Konami code with their own controls to come back with 3 lives (1 in sudden death), once per battle: **Up, Up, Down, Down, Left, Right, Left, Right, Run, Jump**. Their viewport comes back with them.
* When only one player is left, everything freezes for 3 seconds, except the players who are still dying. Sounds that are already playing carry on, but nothing new plays and nothing is stopped. Then the game fades to the results screen, which says "pN wins!" and plays the battle clear theme: `bowserend.ogg`, or the music pack's own one (see **Custom Music** below), with its `-intro` first if it has one. The results screen stays up until the theme ends, and for at least 4 seconds. A battle clear theme longer than 15 seconds gets cut off.
* With less than 5 seconds left, the timer turns into a big number in the middle of the screen, drawn the same way as the countdown at the start, and `countdownbeepsound` plays every time it changes. The timer stops as soon as the battle is over.
* When the timer runs out with more than one player still in, it's **sudden death**:
  * "time up!" shows, then "sudden death!" 1.5 seconds later. Nobody can move in the meantime.
  * After 3 seconds the game fades to a small 25x15 arena in the same theme. It has no ? blocks, so there are no power-ups.
  * Only the players who were still in take part. Each one starts small with 1 life, and everyone's knockouts carry over.
  * After the 3-2-1-go countdown, `lowtimesound` plays, then the fast music. The HUD shows "sudden death" instead of the timer.
  * The last one standing wins, the same way as above.
* If the timer runs out with fewer than two players still in, the player with the most lives left wins (being alive at that moment beats waiting to respawn), then the one with the most knockouts. If it's still a tie, the battle is a draw. Either way, the music stops and the battle clear theme plays in the arena. Once it ends, the game fades to the results screen, which says "pN wins!" or "draw!" and stays up for 4 seconds without a sound.
* When the timer drops below 100, the music stops, `lowtimesound` plays, and the fast version of the battle music takes over as soon as the sound ends (with its `-fastintro` if it has one). The star theme speeds up too. The fast version is `song-fast.ogg` next to a custom song, or one of the built-in `-fast` versions. A song without one gets one made up: the song is time-stretched to 1.25 times its speed at the same pitch. LÖVE can only change a song's playback rate, which moves its pitch with it, so the stretching is done once in the background when the battle starts and is kept for sudden death. With the `classicspeedupfastmusic` nitpick, the song is just played 1.25 times faster instead, which also raises it by just under 4 semitones.
* The score is every human player's knockouts added up. Bots' knockouts don't count (if only bots played, it's the winner's knockouts). It's kept up to date during the battle, so quitting from the pause menu can save it. The victory screen labels it "knockouts".

**Custom Music**

* Custom music goes in `sounds/rivalrumbleroyalemusic` in the game, or in `alesans_entities/rivalrumbleroyalemusic` in the save folder (`%appdata%/mari0` on Windows). The game makes the save folder one the first time the minigames menu lists the music. The minigame's description also explains this, with an example.
* Every `.ogg` file becomes an option in the **Battle music** dropdown. A folder is a music pack, and its songs are listed as "Pack name- Song name", for example "Kirby VRC6 Music- Nightmare".
* `song-intro.ogg` plays once before `song.ogg`.
* `pack.json` is optional and sets the pack's name, its place in the list, the names of its songs, and the pack's own star theme and battle clear theme:

  ```json
  {
      "name": "Kirby VRC6 Music",
      "order": 1,
      "Starman Theme": "kirby star",
      "Battle Clear": "course clear",
      "songs": [
          ["boss", "Boss"],
          ["skybattle", "Battle Across The Sky"]
      ]
  }
  ```

  Packs with an `order` come first (lowest first), and the rest come after them. Packs with the same `order`, or no `order`, are sorted alphabetically by their name in the list. A broken `pack.json` is ignored.
* `"Starman Theme"` names a song of the pack that replaces the star theme while a song from that pack is playing. Its `-intro` works too (`kirby star-intro.ogg`).
* `"Battle Clear"` names a song of the pack that plays when the battle ends, instead of `bowserend.ogg`. Its `-intro` works too.
* Song names in both keys can be written with or without `.ogg`, and the key names don't care about capitals. Neither song shows up in the list.
* If a key is missing, names a file that isn't in the pack, or the pack has no `pack.json`, the pack's `starmusic.ogg` (with `starmusic-intro.ogg`) or `battleclear.ogg` is used instead. If that isn't in the pack either, the built-in star theme or `bowserend.ogg` is used.
* Without `pack.json`, names come from the folder and file names ("my_song.ogg" becomes "My Song").
* `overworld.ogg`, `underground.ogg` or `castle.ogg` placed directly in a music folder replaces the built-in song. Inside a pack folder, they're songs of that pack instead ("My Pack- Overworld"), and the built-in songs stay.
* If a song or pack in the save folder has the same name in the list as one in the game, the save folder's one is used.
* `RIVALRUMBLEROYALE_README.md` explains all of this.

Example of what a music folder can hold:

```
rivalrumbleroyalemusic/
├── my_song.ogg
└── my pack/
    ├── pack.json        "Starman Theme": "star", "Battle Clear": "win"
    ├── boss.ogg
    ├── boss-intro.ogg
    ├── star.ogg
    └── win.ogg
```

**Bots**

* Bots find their way around the arena with routes between platforms. They jump gaps (backing up for a run-up when a gap is wide), drop down from platforms, and won't walk off an edge into a pit.
* They go for items and ? blocks, especially when small, and fight whoever is closest. They leave an item or block they can't reach in 6 seconds alone for 10 seconds.
* They jump over projectiles coming at them, run from Super Stars and fast Blue Shells, and jump over Tanooki statues in their way.

**Bot Difficulty**

There are 25 levels. Each one is a little better than the last, and the stats of the levels between the anchors (1, 5, 10, 15, 20, 23 and 25) are blended between them, so there are no big jumps. Up to Skilled, bots get faster and sharper. From Expert up, they start learning tricks, and by the top they're crazy good.

| # | Level | What it's like |
|---|-------|----------------|
| 1 | Complete Noob | Slow to decide, often stands around, barely shoots, never dodges. |
| 2 | Clueless | |
| 3 | Rookie | |
| 4 | Beginner | |
| 5 | Amateur | The old **Easy**. Still stands around sometimes and dodges about one projectile in seven. |
| 6 | Trainee | |
| 7 | Apprentice | |
| 8 | Novice | |
| 9 | Learner | |
| 10 | Skilled | The default, and the old **Normal**. Dodges half the projectiles it sees. |
| 11 | Competent | |
| 12 | Experienced | |
| 13 | Veteran | |
| 14 | Elite | |
| 15 | Expert | The old **Expert**, plus the first tricks: it starts aiming ahead, spotting stomps from above and fighting in the air. |
| 16 | Master | |
| 17 | Grandmaster | |
| 18 | Champion | |
| 19 | Conqueror | |
| 20 | Legend | Stronger than the old **Super Expert**. Almost always dodges stomps, hunts the weakest player, fights instead of looting once powered up. |
| 21 | Mythical | |
| 22 | Immortal | |
| 23 | Godlike | Stronger than the old **Godmode**. Every trick, every time. |
| 24 | Omnipotent | |
| 25 | THE UNDEFEATABLE | Reacts in a few hundredths of a second, sees projectiles from 9 tiles away and shoots from anywhere in the arena. |

What changes as the level goes up:

* **Thinking:** How long a bot takes to make up its mind, from 1.6 seconds down to 0.04.
* **Shooting:** The wait between shots, from 2.5 seconds down to 0.03, and how far away it starts shooting, from 4 tiles to the whole arena.
* **Dodging:** The chance it jumps over a projectile coming at it, from never to always, and how far away it spots one, from 2 tiles to 9.
* **Running away:** How close a Super Star or fast Blue Shell gets before it runs, from 2 tiles to 14.
* **Standing around:** Low levels sometimes stand still for a moment when they make up their minds. It gets rarer after Skilled and stops at Expert.
* **Aiming ahead:** From Expert up, it aims where you're about to be, up to just over half a second ahead.
* **Stomp dodging:** From Expert up, it can step out from under someone coming down on its head. A Legend almost always does, and from Godlike up it always does, spotting the stomp from further up.
* **Focus:** From Expert up, it can pick the weakest target it can hurt (small, nearly out of lives, not blinking) instead of the closest one. It also leaves items that someone else will clearly reach first, and once it's powered up, it only bothers with the rare block.
* **Aggression:** From Expert up, once it's powered up and someone is close by, it can fight them instead of going off for items and ? blocks. At the top, it always does.
* **Fighting in the air:** From Expert up, it can hop up to shoot someone standing a little above it, shoot down at someone below, shoot while jumping, and jump at someone who's in the air too.
* **Boldness:** From Expert up, it can stay put instead of running from a Super Star or fast Blue Shell while it's still blinking after a hit, since nothing can hurt it then. From Legend up, it always does.
* **Greed:** Godlike, Omnipotent and THE UNDEFEATABLE go for ? blocks most of the time (80%, 85% and 90%) when they aren't busy fighting. The rest pick how greedy they are at random.

All bots stick with the item, ? block or player they're going for unless another one is clearly closer, so they don't flip between two.

**Other**

* The minigame's graphic shows Mario, Luigi, Toad and Toadette, with Mario and Luigi wearing the standard hat.
* Jumping on the first frame after **go!** now shows the jump pose instead of the falling pose.

#### ⚙️ Minigame Nitpicks

* `removecooldowns`: The ? blocks in Rival Rumble Royale have no cooldown. Every hit gives an item, and the block shows its roulette again straight away. **Generate Nitpicks File** adds it to an existing file.
* `classicspeedupfastmusic`: In Rival Rumble Royale, a song without a fast version gets its made-up fast version the old way: it's played 1.25 times faster, which also raises it by just under 4 semitones, instead of being time-stretched to keep its pitch. **Generate Nitpicks File** adds it to an existing file.

#### 🎮 Minigames

* Minigame settings can now be sliders, or a checkbox with a slider next to it that only works while the box is ticked. Right-click a slider to type a number.
* Dropdown entries can now come from a function, so a list can depend on files. Entries are shown in lowercase because the old font draws some capitals as symbols.
* Wide dropdowns shorten long entries while closed (the pack name is shortened first), then open to the left, wide enough to show the full names.
* A minigame can now have up to four players, keep the game's own physics instead of Super Mario Maker physics, and set its own victory sound, headline and score label.
* A minigame can keep some things moving while the game is frozen at the end (like players who are still dying), and can undo its changes when it returns to the menu.
* A minigame can now draw right after the tiles, behind every object.
* A minigame can play its own jingle in the game and then show a silent results screen for a set number of seconds (`resultsilent`).
* A minigame can end with a silent freeze: the game stands still, sounds that are already playing carry on, and no new sounds play until the results screen.
* A minigame can play its own music on the results screen (`resultmusic`), and the screen stays up for as long as the minigame says.
* Quitting a minigame from the pause menu, to the menu or to the desktop, now asks "save highscore?" once you confirm. **Yes** saves your score and then quits, **No** quits without saving it, and **Cancel** closes both prompts and takes you back to the pause menu. Escape takes you back to the quit prompt. With a score of 0 there's nothing to save, so the game quits straight away without asking.
* Scores of 0 are never saved. They're also removed from `alesans_entities/minigame_data.json` whenever it's read, and the file is rewritten without them.
* Words in a minigame's description that are longer than a line (like a long folder name) are now split over several lines, so they don't run under the scrollbar.

#### 🖥️ Splitscreen

* Minigames can choose which players get a viewport, which player each viewport follows, and extra HUD for each viewport. A single viewport is allowed, and fills the whole screen.

#### 🎵 Music

* `-intro` and `-fast` versions now also work for built-in music names, for example `starmusic-intro`.
* In normal courses, the fast music now starts as soon as the low time sound ends, instead of after a fixed wait of about 3 seconds that only matched the default sound. It also starts while the timer is stopped, in a pipe for example.
* Custom music's fast version can now have its own intro, including a mappack's `music` folder and `music.ogg`/`music1.ogg` files, in `.ogg` or `.mp3`. `song-fastintro.ogg` (or `song-introfast.ogg`) plays once before `song-fast.ogg` when the time runs low, the same way `song-intro.ogg` plays before `song.ogg`. Fast intros don't show up as separate songs in the editor's music list. Stopping the music while an intro is playing now stops the intro too.

#### 🍄 Modern Size Change Animation

A new nitpick, `modernsizechangeanimation`, swaps the classic power-up and power-down animations for Super Mario Maker 2 style ones. The game freezes while it plays, the same as before. **Generate Nitpicks File** adds it to an existing file.

* The animation plays in parts of 1/8 of a second each (`modernsizechangeparttime` in `variables.lua`). Your pose doesn't reset: every part shows the pose you were in, on that part's sprite sheet. Hats scale along with you from the same point, so they stay on your head.
* **Small type to big type** (small to big, tiny to small, small to hammer and so on): the new sprite is squashed and stretched from the bottom of your hitbox, at 0.75, 0.625, 0.875, 0.75 and 1 times its height, and the animation ends after the last one (`modernsizegrowscales`).
* **Big type to small type** (big to small, small to tiny, hammer to small and so on): the old sprite goes through 0.75, 0.875, 0.625, 0.75 and 0.5 times its height from the bottom of your hitbox, then the animation ends on the small sprite (`modernsizeshrinkscales`). Getting hit then gives you the usual blinking.
* **Big type to big type** (big to fire, fire to hammer, hammer to boomerang, fire to big and so on): the new and old sprite sheets and colours take turns: new, old, new, old, and the animation ends as soon as it reaches the last new one (`modernsizesuitparts`). Getting hit as a power-up in Mari0-Maker physics, which drops you to big, plays this too.
* A custom power-up that gives you a fire enemy plays the big-to-big animation into its own colours. If you're already fire and it has no colours of its own, you get the power straight away, without an animation or a freeze.
* Mega Mario, classic huge Mario and characters with health keep their own effects, and minigames keep their instant power-ups.
* The classic after-size-change jump works during the modern animation too. If you press jump in mid-air while a power-up is changing your size, you get a silent jump as soon as the animation ends, the same as with the classic animation. Like the classic shrink animation, getting hit doesn't allow it.
* Jumping while your size is changing no longer changes your sprite. The animation keeps showing the pose you were in, and the jumping pose only shows once the game unfreezes. This works the same with or without `modernsizechangeanimation`.

#### ❄️ Don't Freeze On Size Change

A new nitpick, `dontfreezeonsizechange`, stops power-ups and getting hit from freezing the whole game. Like in SMBX2, only the player whose size is changing stops, in place, while enemies, other players and everything else keep going. **Generate Nitpicks File** adds it to an existing file.

* You become the new size straight away and hang still where you are until the animation ends, then carry on with the speed you had.
* The after-size-change jump still works: press jump in mid-air while a power-up is changing your size, and you jump silently as soon as you're free. Nothing else you press does anything until then.
* It works with both the classic animations and `modernsizechangeanimation`, and each one lasts as long as it does with the freeze.
* Until the animation is over, you're intangible: enemies, items and other players pass through you, and nothing can hurt you. The course itself (tiles, platforms, springs, doors and so on) still counts as solid.
* Getting hit gives you the usual blinking once the animation is over. Blinking you already had carries on through a power-up.
* Ducking carries on straight away, since nothing has to stand up for the animation.
* Leaving Mega Mario after a hit takes you straight to big, with the blinking.

#### 🎥 Camera Smoothing

Two new nitpicks for the camera. Both are just `true` or `false`. **Generate Nitpicks File** adds them to an existing file.

* `camerasmoothing`: The camera still works out where it would normally go, but what you see eases towards that instead of jumping straight there, so it trails slightly behind when it moves. How fast it catches up is `camerasmoothingspeed` in `variables.lua` (8 by default, higher is faster).
* `backwardsmoothing`: Takes how far the smoothed camera trails behind and puts the camera that far ahead instead (the normal position minus the smoothed position's difference from it), so the camera leads in the direction you're moving.
* `backwardsmoothing` only works with `camerasmoothing` on. If it's on without it, a notice tells you to enable `camerasmoothing` when the game starts.
* The smoothed camera never goes past the edges of the course, and splitscreen viewports are smoothed too. The camera is never smoothed in the editor, and anything that moves the camera on its own (loading a map, a camera snap) starts the smoothing over from there.
* Rival Rumble Royale keeps every camera snapped to its player for the whole 3-2-1 countdown, so the battle always opens with the cameras already in place, even when it's restarted from the pause menu. Smoothing takes over at **go!**.

#### 👾 Update When Size Change

A new custom enemy property, `updatewhensizechange`. Set it to `true` in the enemy's JSON file, and the enemy keeps updating and moving while the game is frozen for a power-up or a hit.

```json
"updatewhensizechange": true
```

* Enemies it spawns (`spawnenemy` and `spawnchildren`) and enemies it transforms into keep updating too, even if their own JSON doesn't have it. They pass it on in the same way.
* Everything else stays frozen, but these enemies still collide with it, including the players.
* With `dontfreezeonsizechange`, nothing else freezes, so every enemy keeps updating anyway.

#### 🏃 No Air Speed Cap

A new nitpick, `noairspeedcap`, lifts the classic air speed cap. Normally, if you're moving slower than walking speed in the air, holding run only gets you up to walking speed, and only a run you already had when you jumped carries on at full speed. With `noairspeedcap`, holding run in the air always speeds you up to full running speed, like in Super Mario Maker 2. **Generate Nitpicks File** adds it to an existing file.

#### 🏁 Multiplayer Flagpole

The flagpole now waits for everyone in multiplayer, instead of ending the course for whoever got there first.

* The first player to grab the flagpole hangs on where they grabbed it, and the flag stays at the top. The timer stops, but the music keeps playing.
* The flag animation starts as soon as every player is either on the flagpole or dead. If everyone who hasn't grabbed it dies, it starts straight away.
* If that hasn't happened `flagpolewaittime` seconds after the first grab (5 by default, in `variables.lua`), the flag animation starts anyway. Players who aren't on the flagpole keep playing until the course ends.
* A player who dies respawns at the furthest player, the same as before, and they still respawn after the flag animation has started. If the furthest player has already grabbed the flagpole, they respawn at the checkpoint they reached in that area, or at the start if there isn't one.
* The music stops when the flag animation starts, not when someone grabs the flagpole. The course end sound plays then too.
* Everyone on the flagpole slides down from where they grabbed it and walks to the castle. Every grab gives its own flag points, but the flag shows the first player's score.
* The first player to grab the flagpole runs the course end: the flag coming down, the time bonus, the castle flag and the fireworks. Everyone else just walks off and stops, so the time bonus doesn't count down any faster.
* In single player, the flag animation starts the moment you grab the flagpole, the same as before.

### 🐛 Bug Fixes

* In splitscreen, the player who uses the mouse now aims exactly at the cursor. Before, the aim was worked out as if there were one full screen, so it was off everywhere but the top-left viewport, and more so in viewports that show more of the course.
* In splitscreen, player fireballs, superballs, iceballs, hammers and boomerangs no longer disappear as soon as they leave the shared camera. They now last as long as they're inside the course.
* A player's boomerang now only disappears when it gets back to the player who threw it. Before, it disappeared on contact with any other player, so other players could catch it.
* If the Super Star wears off while the player is a Tanooki statue, they now go back to the statue colours instead of their normal ones.
* When the blinking invincibility ends while the player is a Tanooki statue, they now stay invincible. Before, enemies could hurt a statue once the blinking was over.
* Stomping enemies in a row without landing gives 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000 and 8000 points again, then a 1up for each stomp after that. Before, the nth stomp only gave n points ("+1", "+2"...). Minigames still count stomps that way.
* Changing form now ends any animation the new form doesn't have, and sets the new form's sprite straight away. For example, getting hit during a tail whip ends the whip, and its hitbox stops hitting things. A raccoon flight or a float ends the same way.
* Changing form while ducking now keeps you ducking, like picking up a power-up in Rival Rumble Royale. This works on the ground and in mid-air (a duck jump into a power-up, for example). Power-ups that only flash your colours (a Fire Flower when you're already big, for example) keep the duck the whole time. The classic small-to-big and big-to-small animations still show you standing, then you duck again as soon as they end. Your feet stay in the same place throughout. Before, you only ducked again afterwards if you were on the ground.
* Changing form while you're blinking after a hit now keeps your invincibility timer: once the grow animation ends, the blinking carries on from where it was.
* Finishing a course (at the flagpole, the axe or a levelball) now takes every player off their Lakitu cloud, quietly, so the cloud doesn't follow you through the ending.
* Dropdowns in a minigame's settings no longer disappear when the description above them is long. They used to stay where they were before the panel was scrolled.
* Corner clipping now works next to semisolid tiles. When you hit the corner of a block, the game checks whether the tile beside it is a better fit to bonk. It used to count any tile with collision, so a semisolid next to the block (a treetop, for example) bonked you instead of pushing you past the corner. Now only tiles that are solid from below count: semisolids are skipped unless they're solid on their bottom side (`platformdown`).

### ✨ Improvements

#### ⏸️ Pause Menu

* The options in the pause menu's prompts (quit to menu, quit to desktop and save game) are now listed one under the other instead of side by side, and you move between them with Up and Down (or W and S). The prompt box grows taller to fit them.

#### 🟨 Block Beat Bonanza

* The revive prompt now looks and animates like the pause menu's prompts. It scales in and out with a random motion curve over a dimmed screen, and its options are listed one under the other. Like the pause menu's prompts, it only takes input once it's fully open. You move between the options with Up and Down, and clicking one still works.

#### 🦝 Raccoon and Tanooki

* Landing while at P-speed and still running at full speed keeps P-speed on, with a full P-meter. Before, every landing switched it off. Any flight still ends when you land.
* Running on the ground at full speed keeps P-speed on for as long as you keep running. In the air, the P-meter drains as before.
* Stomping an enemy at P-speed keeps P-speed and refills it: the P-meter goes back to full, and a flight gets its whole flying time back. This works for every enemy, not just custom ones.
* The P-meter now has a maximum: 1.1 seconds of running at full speed fills it, which is where P-speed starts. It's set with `raccoonplanefull` in `variables.lua`.
* Each flap while flying now plays the whole flying animation, all 3 frames, over `raccoonflaptime` (0.3 seconds, in `variables.lua`). It keeps playing even when you start falling. Before, it went back to the first frame as soon as you started falling.
* Pressing jump again while flapping keeps the animation going from the frame it's on, instead of starting it over. It only goes back to the first frame once you stop flapping.
* Raccoon and Tanooki Mario can now fly while riding Yoshi. Run to build up P-speed, jump to take off, then keep pressing jump to flap, the same as without Yoshi. Stomping an enemy at P-speed while on Yoshi keeps P-speed too.

## v1.1.0

### 🧩 New Features

#### 🎮 Minigames

* Added a new **Minigames** tab to the mappack menu, next to the Local, DLC and Daily Challenge tabs.
* Each minigame option is 200x58 and shows a 192x50 graphic from `graphics/minigames/<id>.png`, with the minigame's title and tagline drawn in lowercase over the centre of the graphic.
* The search bar is hidden on the Minigames tab. The minigame's description sits where the search bar was, with its game mode settings (checkboxes and dropdowns) 2 pixels below the text.
* The description and the settings share one box that never takes up more than half of the game height. If they don't fit, the box gets a GUI scrollbar and can also be scrolled with the mouse wheel, one line per notch. Settings that are scrolled out of view can't be clicked, and an open dropdown is always drawn on top.
* Descriptions support line breaks (`\n`).
* The highscores list shows every score, best first, under the description box. It scrolls with the mouse wheel and has its own GUI scrollbar.
* Minigames run inside the normal game, with one player, the daily challenge music, and the built-in graphics and sounds. Mappacks can never override a minigame's assets.
* Every score is saved in `alesans_entities/minigame_data.json`, as `{"Minigame Name": [all scores, oldest first]}`.
* Winning plays `dcwin2sound` with falling confetti. Losing plays `dclosesound`. Once the sound finishes, the game returns to the Minigames tab.
* Endless minigames have no real win, so losing with more than `victoryscore` points (100 by default, set in `minigames.lua`) shows the victory screen instead.
* Getting a new highscore plays `dcwin2sound` instead of `dclosesound`, even when you lose.
* The pause menu in a minigame has **Restart** and **Menu** options, both with fades.
* Each minigame has its own HUD with the score centred at the top of the screen.
* Big scores use short units: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, then the -illions from Dc to Nog, up to Ce (centillion) and UCe, the largest number Lua can hold. For example, 1,234 shows as 1.23K and a googol shows as 10DTg. The full score is still saved.

#### 👻 Boo Baffler Bash

Find the Boo shown at the top of the screen and click it before the timer runs out.

* You start with 10 seconds. Finding the Boo quickly wins time back: if you find it within the first 3 seconds you get 5 extra seconds, then 4 within 6 seconds, and so on down to 1. The bonus is added in 0.0625-second steps while `scoreringsound` plays.
* A bonus meter under the HUD shows how much time you will win back. It drains as the round goes on and changes colour from green to yellow to red. The same colour is used for the "+N" display beside it and the popup over the found Boo.
* The HUD is one half-transparent box in the middle of the screen, with the score and round on the left, the Boo to find in the middle, and the clock and time left on the right.
* Clicking the wrong Boo shows a red cross on it.
* When you find the right Boo, every other Boo disappears in a poof. The found Boo then leaves with one of 10 random found animations, each starting with its own sound. When time runs out, every Boo on the screen plays one:
  * **Fade:** Grows and fades out (`mushroomappearsound`).
  * **Fall:** Flips over and falls off the screen (`bowserfallsound`).
  * **Poof:** Vanishes in a puff of smoke (`stompbigsound`).
  * **Spin:** Twirls three times, faster and faster, puffs up a little and shrinks to nothing (`raccoonswingsound`).
  * **Rocket:** Crouches down, then blasts off the top of the screen with a smoke trail (`cannonfastsound`).
  * **Squash:** Gets flattened like a pancake, springs back slightly, then fades (`stompsound`).
  * **Melt:** Wobbles and melts down into a puddle of its own colour, which then dries up (`meltsound`).
  * **Shatter:** Turns icy blue and shakes harder and harder, then breaks into four pieces that tumble away (`freezesound`, then `iceblockbreaksound` when it breaks).
  * **Burst:** Puffs up and flashes white, then pops into a ring of spinning sparkles (`magicsound`).
  * **Dash:** Leans back, then zooms off the side of the screen it's facing, leaving afterimages behind (`capeflysound`).
* Found animations are kept in the `BOO_FOUND_ANIMS` table in `minigames.lua`. Each one has a `start` function that plays its sound and an `update` function that runs every frame until the animation is done, and can draw extra effects behind or in front of the Boo. Adding a new entry adds it to the random pick.
* More Boos appear every round, and they move a little faster each round, up to 50% faster.
* Every round uses a random movement type, never the same one twice in a row:
  * **Shy:** Boos near your cursor stop and turn see-through, while the rest sneak towards it.
  * **Circle:** Boos fly around in rings, some spinning each way.
  * **Chain:** Boos follow each other in long lines, like a train.
  * **Wave:** Boos float sideways and bob up and down, wrapping around the sides.
  * **Lanes:** Boos slide along in rows, each row going the opposite way to the one next to it.
  * **Spiral:** Boos spin around the middle of the screen, moving out to the edges and back in.
  * **Flock:** Boos fly together in groups, like a school of fish.
  * **Shuffle:** Boos stay still for a moment, then all zoom and swap places.
  * **Teleport:** Boos vanish in a puff of smoke and pop up somewhere else.
  * **Flee:** Boos run away from your cursor, so you have to trap them against a wall.
  * **Phase:** Boos fade until they are almost invisible, then come back.
  * **Swing:** Boos hang on faint strings and swing like a pendulum wave.
  * **Super Random:** Every Boo does its own random move (drift, wander, zigzag, orbit, bob, dash, teleport, flee, chase, freeze, fade or jitter) and switches to a new one every 3 to 5 seconds.

#### 🐍 Snake Slither Scramble

Steer the snake block around the screen, eat mushrooms to grow longer, and try to fill every empty tile.

* The snake uses the snake block graphics. It only turns when it crosses a tile, and remembers up to two turns in a row, ignoring presses in the same or the opposite direction.
* Mushrooms add 1 point. A ? block appears every 5 to 10 seconds and is worth 2, 3, 5 or 10 points.
* A Starman appears every 15 to 25 seconds. It makes the snake invincible for `mariostarduration` seconds, lets it pass through itself and walls, and plays the star music. A crash only counts again once the head is back on an empty tile. The HUD shows the invincibility time left.
* Crashing plays `blockhitsound` and bumps the head into what it hit, like a bumped block, before the game ends.
* Filling every empty tile wins the game. Losing with more than `victoryscore` points still counts as a victory.
* Scores of 100 or more earn a title, scaled up to the highest possible score.
* **Wall Mode:** The edges of the screen become walls.
* **Slow Mode:** The snake moves at the snake block's speed and uses the green snake block graphic.

#### 🦘 Jumping Juggle Jamboree

You only get one jump. Keep bouncing on the enemies that walk in from the sides, and don't touch the ground.

* You play as player 1 with your own skin, without the portal gun, standing on three hard blocks.
* Every control except jump is locked until you jump. The blocks disappear as soon as you leave them.
* After the jump, jump and run are held for you. Run doesn't trigger custom character animations, and you can always reach `maxrunspeed` in the air.
* Touching the ground ends the game and only plays the death sting.
* 3 to 10 enemies are already on screen when the game starts, and more walk in from the sides every 3 to 5 seconds. Once an enemy is fully on screen, the edges of the map turn it around.
* Each run gets a randomly decorated background with hills, bushes, fences, trees and clouds.
* The physics are always Super Mario Maker.
* **Can Spike Spawn Spikeballs?:** Lets Spikes throw spikeballs.
* **Fast Falling:** Switches the physics to Mari0-Maker for a faster fall.
* **Wind Mode:** None, Occasional (gusts that come and go) or Continuous. Wind blows at speed 4 and eases in and out.

#### 🟨 Block Beat Bonanza

Watch the coloured ? blocks light up in a pattern, then hit them in the same order with the mouse or your movement keys. Every round adds one more beat.

* You start with 5 lives. A wrong hit costs a life and plays the pattern again.
* If you wait 10 seconds without hitting a block, the pattern plays again.
* Every point also goes into a separate revive-check score, and every 10 points there pays for a revive. When you run out of lives with 10 or more, you get a prompt to revive with 3 extra lives. Accepting restarts the music from the beginning, plays `oneupsound`, and uses up 10 points of the revive-check score. Your real score doesn't change.
* The HUD shows your score and lives.

#### ⚙️ Minigame Nitpicks

New nitpicks for the minigames, set in `alesans_entities/nitpicks.json` like the others. **Generate Nitpicks File** adds them to an existing file.

* `orderedmovementtypes`: Boo Baffler Bash uses its movement types in order instead of at random. It starts with Shy, then Circle, Chain, Wave, Lanes, Spiral, Flock, Shuffle, Teleport, Flee, Phase and Swing, then loops back to Shy. Super Random is never used.
* `invinciblesnake`: The snake in Snake Slither Scramble acts as if it always has a Starman, so walls and its own body can't stop it. It doesn't flash or show the invincibility timer. Starmen still work as normal.
* `multiplejumping`: In Jumping Juggle Jamboree, you can jump as many times as you like in mid-air. Every jump, including the first one off the blocks, is a full-height jump, the same height as a jump with a full-speed run-up, and plays the jump sound and animation from the start. Landing on the ground adds 1 point and throws you straight back up with a full-height jump.
* `probabilitypasser`: In Snake Slither Scramble, the ? block and the Starman appear as soon as there isn't one on the screen, without a random wait. There is still only one of each on the screen at a time, and no Starman appears while the snake is invincible.
* `immortalcombometer`: The bonus meter in Boo Baffler Bash always stays full, so every Boo you find wins back the full 5 seconds.

The existing infinite time and infinite lives nitpicks now also work in the minigames:

* `alwaysinfinitetime`: In Boo Baffler Bash, the timer never goes down, so you can take as long as you like to find the Boo. Finding it still adds bonus time.
* `alwaysinfinitelives`: In Jumping Juggle Jamboree, touching the ground no longer ends the game; you just land as if nothing happened. If `multiplejumping` is also on, landing bounces you back up instead. In Block Beat Bonanza, you can always revive when you run out of lives, and reviving doesn't use up any of the revive-check score.

**Disclaimer:** This entire minigames feature was created only with Claude Opus 5.5.

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