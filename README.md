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
* Added the mappack `disabletransition` setting, which instantly completes transitions between maps during gameplay. It can be managed in the Course Maker with the **Skip trans.** setting. Editor transitions, including transitions while testing a level, remain enabled.
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
  * Pixel Grain: Posterises each channel to a few levels and hides the banding with ordered Bayer dither.
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
* Level screens now fade to black before loading the next map.
* Selecting a map in the editor now fades the full screen to black before loading.
* Pipe entries without a matching exit marker now use a vignette transition centered on the player's spawn animation.
* Level music now resumes when fast star music ends.
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

**Note:** The four-keybind system remains compatible with original Mari0 AE save data and does not negatively affect it. Running Mari0 AE may remove the secondary, tertiary, and quaternary keybinds from your save data so make sure to backup your data.

**Mod Production Note:** These changes were made with Claude, Grok, and GitHub Copilot.

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

---

# Changelog

All notable releases and updates to **Legendary Edition** are documented here.

## v1.1.1

### 🧩 New Features

#### 🥊 Rival Rumble Royale

A four-player battle minigame inspired by the battle mode of Super Mario 4 Jugadores. Grab power-ups from the ? blocks and knock everyone else out. The last one standing wins.

**Players and settings**

* Four players battle in every round. Any players that aren't human are bots.
* **How many players are human?:** 1 (P2 to P4 are bots), 2 (P3 and P4 are bots), 3 (P4 is a bot) or 4 (no bots).
* **Bot difficulty:** Easy, Normal (the default), Expert, Super Expert or Godmode. Harder bots make up their minds faster, shoot more often and from further away, dodge more projectiles, and run from danger sooner. Easy bots sometimes stand around for a moment. Super Expert and Godmode bots aim where you're about to be. Godmode bots also go for ? blocks most of the time and step out of the way when someone drops onto their head.
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

* A player who loses their last life is out. Once their death animation is over, their viewport is removed, and the other viewports slide and resize into the new layout with the same random motion curves as the pause menu. The last viewport is never removed: if its player is out, it follows someone who's still in the battle and shows "watching pN".
* A knockout counts for the player who hit you, if you die within 4 seconds of their hit (falling into a pit, for example). The HUD shows every player's lives and knockouts, and marks the bots with "CPU".
* A human player who is out can type the Konami code with their own controls to come back with 3 lives (1 in sudden death), once per battle: **Up, Up, Down, Down, Left, Right, Left, Right, Run, Jump**. Their viewport comes back with them.
* When only one player is left, everything freezes for 3 seconds, except the players who are still dying. Sounds that are already playing carry on, but nothing new plays and nothing is stopped. Then the game fades to the results screen, which says "pN wins!" and plays the battle clear theme: `levelend.ogg`, or the music pack's own one (see **Custom Music** below), with its `-intro` first if it has one. The results screen stays up until the theme ends, and for at least 4 seconds. A battle clear theme longer than 15 seconds gets cut off.
* With less than 5 seconds left, the timer turns into a big number in the middle of the screen, drawn the same way as the countdown at the start, and `countdownbeepsound` plays every time it changes. The timer stops as soon as the battle is over.
* When the timer runs out with more than one player still in, it's **sudden death**:
  * "time up!" shows, then "sudden death!" 1.5 seconds later. Nobody can move in the meantime.
  * After 3 seconds the game fades to a small 25x15 arena in the same theme. It has no ? blocks, so there are no power-ups.
  * Only the players who were still in take part. Each one starts small with 1 life, and everyone's knockouts carry over.
  * After the 3-2-1-go countdown, `lowtimesound` plays, then the fast music. The HUD shows "sudden death" instead of the timer.
  * The last one standing wins, the same way as above.
* If the timer runs out with fewer than two players still in, the player with the most lives left wins (being alive at that moment beats waiting to respawn), then the one with the most knockouts. If it's still a tie, the battle is a draw. Either way, the music stops and the battle clear theme plays in the arena. Once it ends, the game fades to the results screen, which says "pN wins!" or "draw!" and stays up for 4 seconds without a sound.
* When the timer drops below 100, the music stops, `lowtimesound` plays, and the fast version of the battle music takes over as soon as the sound ends (with its `-fastintro` if it has one). The star theme speeds up too. The fast version is `song-fast.ogg` next to a custom song, or one of the built-in `-fast` versions. A song without one gets one made up: the song itself played 1.25 times faster, which also raises it by just under 4 semitones (LÖVE can't change the speed and the pitch separately).
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
      "Battle Clear": "level clear",
      "songs": [
          ["boss", "Boss"],
          ["skybattle", "Battle Across The Sky"]
      ]
  }
  ```

  Packs with an `order` come first (lowest first), and the rest come after them. Packs with the same `order`, or no `order`, are sorted alphabetically by their name in the list. A broken `pack.json` is ignored.
* `"Starman Theme"` names a song of the pack that replaces the star theme while a song from that pack is playing. Its `-intro` works too (`kirby star-intro.ogg`).
* `"Battle Clear"` names a song of the pack that plays when the battle ends, instead of `levelend.ogg`. Its `-intro` works too.
* Song names in both keys can be written with or without `.ogg`, and the key names don't care about capitals. Neither song shows up in the list.
* If a key is missing, names a file that isn't in the pack, or the pack has no `pack.json`, the pack's `starmusic.ogg` (with `starmusic-intro.ogg`) or `battleclear.ogg` is used instead. If that isn't in the pack either, the built-in star theme or `levelend.ogg` is used.
* Without `pack.json`, names come from the folder and file names ("my_song.ogg" becomes "My Song").
* `overworld.ogg`, `underground.ogg` or `castle.ogg` placed directly in a music folder replaces the built-in song. Inside a pack folder, they're songs of that pack instead ("My Pack- Overworld"), and the built-in songs stay.
* If a song or pack in the save folder has the same name in the list as one in the game, the save folder's one is used.
* `pack.json` files are included for **Kirby VRC6 Music**, **Castlevania VRC6 Music** and **Super Mario Bros. 2 Remade**. The songs themselves aren't included. `RIVALRUMBLEROYALE_README.md` explains all of this.

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

**Other**

* The minigame's graphic shows Mario, Luigi, Toad and Toadette, with Mario and Luigi wearing the standard hat.
* Jumping on the first frame after **go!** now shows the jump pose instead of the falling pose.

#### ⚙️ Minigame Nitpicks

* `removecooldowns`: The ? blocks in Rival Rumble Royale have no cooldown. Every hit gives an item, and the block shows its roulette again straight away. **Generate Nitpicks File** adds it to an existing file.

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
* In normal levels, the fast music now starts as soon as the low time sound ends, instead of after a fixed wait of about 3 seconds that only matched the default sound. It also starts while the timer is stopped, in a pipe for example.
* Custom music's fast version can now have its own intro, including a mappack's `music` folder and `music.ogg`/`music1.ogg` files, in `.ogg` or `.mp3`. `song-fastintro.ogg` (or `song-introfast.ogg`) plays once before `song-fast.ogg` when the time runs low, the same way `song-intro.ogg` plays before `song.ogg`. Fast intros don't show up as separate songs in the editor's music list. Stopping the music while an intro is playing now stops the intro too.

### 🐛 Bug Fixes

* In splitscreen, player fireballs, superballs, iceballs, hammers and boomerangs no longer disappear as soon as they leave the shared camera. They now last as long as they're inside the level.
* A player's boomerang now only disappears when it gets back to the player who threw it. Before, it disappeared on contact with any other player, so other players could catch it.
* If the Super Star wears off while the player is a Tanooki statue, they now go back to the statue colours instead of their normal ones.
* When the blinking invincibility ends while the player is a Tanooki statue, they now stay invincible. Before, enemies could hurt a statue once the blinking was over.
* Stomping enemies in a row without landing gives 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000 and 8000 points again, then a 1up for each stomp after that. Before, the nth stomp only gave n points ("+1", "+2"...). Minigames still count stomps that way.
* Changing form now ends any animation the new form doesn't have, and sets the new form's sprite straight away. For example, getting hit during a tail whip ends the whip, and its hitbox stops hitting things. A raccoon flight or a float ends the same way.
* Changing form while ducking in mid-air (a duck jump into a power-up, for example) now keeps you ducking once the grow or shrink animation ends. Before, you only ducked again if you were on the ground.
* Dropdowns in a minigame's settings no longer disappear when the description above them is long. They used to stay where they were before the panel was scrolled.

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