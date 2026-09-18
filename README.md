# Mari0 AE — Legendary Edition Mod

**Legendary Edition** is a community mod for **Mari0 AE**, created by **LukeManiac**.

This mod contains tons of fixes, improvements, and notifications before part of the game loads. It expands and improves Mari0 AE with new gameplay features, characters, enemies, sounds, shaders, languages, course maker content, and many other changes.

> **Compatibility:** Mari0 AE v13.2 with LÖVE 11.5.

## Features

- 🌀 Improved portal gameplay
- 🍄 Multiple playable characters
- 👾 Improved enemies and enemy behaviour
- 🧱 Expanded **Course Maker** functionality
- 🧪 Gel gameplay and related mechanics
- 💧 Additional gameplay mechanics and effects
- 🔫 Additional weapons and projectiles
- 💥 New power-ups and gameplay elements
- 🎯 Daily Challenge support
- 🎮 Controller and joystick support
- 🖼️ New and improved graphics
- ✨ New shaders and visual effects
- 🔊 New and improved sounds
- 🌍 Additional languages and translations
- ⚙️ Numerous gameplay, physics and quality-of-life improvements
- 📢 New loading notifications and messages
- 🚀 Improvements throughout the game
- 🐛 Tons of bug fixes
- 🔧 Tweaks across the rest of the Lua source files

## What's New?

Legendary Edition contains many changes throughout Mari0 AE, including improvements that affect both gameplay and the way the game loads.

Some of the changes include:

- New loading messages
- New loading sounds
- New shaders
- New languages
- Improved enemies
- Numerous gameplay improvements
- Bug fixes
- Quality-of-life improvements
- Tweaks to existing mechanics
- Improvements to the Course Maker
- Improvements to character behaviour
- Improvements to various visual and audio effects
- Improved notifications before parts of the game load

Vertical camera seeking has also been reduced to help prevent the player from being left off-screen when attempting to camera-seek vertically.

**The rest of the Lua files have also been tweaked and improved**, so changes are not limited to the features listed above.

## Requirements

- **Mari0 AE v13.2**
- **LÖVE 11.5**

## Installation

1. Install **Mari0 AE v13.2**.
2. Download or clone this repository.
3. Back up your original Mari0 AE installation.
4. Copy the mod files into your Mari0 AE installation while preserving the directory structure.
5. Run the game using **LÖVE 11.5**.

For the best results, use a clean Mari0 AE v13.2 installation when installing the mod.

## Development

Legendary Edition is primarily written in **Lua** and uses **LÖVE** as its framework.

The repository contains the game's Lua source code and assets directly rather than using a conventional compiled build system.

### Main Lua Files

| File | Description |
| --- | --- |
| `main.lua` | Main LÖVE entry point, loading and initial setup |
| `game.lua` | Core gameplay and game-state logic |
| `mario.lua` | Player behaviour and physics |
| `enemy.lua` | Enemy systems and behaviour |
| `editor.lua` | Course Maker functionality |
| `menu.lua` | Menus and interface |
| `variables.lua` | Configurable gameplay and physics variables |
| `dailychallenge.lua` | Daily Challenge functionality |

### Other Lua Code

There are many other Lua files throughout the repository that handle individual gameplay systems, objects, characters, enemies, effects, menus, utilities and other parts of the game.

**The rest of the Lua files have been tweaked as part of Legendary Edition as well.**

Changes may include bug fixes, balancing changes, performance improvements, gameplay adjustments, compatibility fixes, visual changes and general quality-of-life improvements.

## Course Maker

Legendary Edition expands the **Course Maker** with additional functionality and content.

Course Maker-related changes include:

- Additional objects
- Additional gameplay elements
- Improved object behaviour
- Improvements to existing Course Maker functionality
- Additional options and tweaks
- Bug fixes

The Course Maker continues to use Mari0 AE's existing course-building systems while adding and improving functionality.

## Gameplay Improvements

Legendary Edition includes many improvements to the core game.

These include changes to:

- Player movement
- Player physics
- Enemy behaviour
- Power-ups
- Projectiles
- Portal interactions
- Collision behaviour
- Camera behaviour
- Loading behaviour
- Game menus
- Input handling
- Course Maker functionality
- Visual effects
- Audio
- Languages
- General game stability

Not every change is listed here. **Many of the Lua files have been modified with smaller fixes and improvements throughout the project.**

## Configuration

Many gameplay and physics values can be configured through the project's Lua source.

`variables.lua` contains a large number of configurable values relating to things such as:

- Player movement
- Friction
- Air control
- Ice physics
- Portal timing
- Gel behaviour
- Projectile lifetimes
- Controller settings
- Character settings
- Scoring
- Power-ups
- Other gameplay behaviour

Some systems use values from multiple Lua files, so changing a variable may require checking related code as well.

## Credits

Legendary Edition contains work from many contributors to the Mari0 and Mari0 AE communities.

- **LukeManiac** — Legendary Edition
- **Alesan99** — Mari0 AE / Awesome mod
- **Maurice Guégan** — Original Mari0 and substantial original code/content
- **Fakeuser** — Regular turrets
- **Automatik** — Poison Mushroom help
- **Superjustinbros** — SMB sprites
- **Qcode** — Code and advice
- **Trosh** — Raccoon sprites from SE
- **Galas** — Power-up sprites
- **Bobthelawyer** — Mario hammer physics code
- **KGK64** — Dry Beetle sprites
- **Skysometric** — Animated quad cache code from Mari0 SE Community Edition
- **Oxiriar** and **Toonn** — SMB3 item sprites
- **NH1507** — Toad and Toadette character sprites
- **HansAgain** — Portal sprites, Mario sprites, Banzai Bills and pneumatic tubes
- **Subpixel** — Bowser3, Rotodiscs, Ninji and Splunkin sprites
- **Critfish** — Overgrown portal sprites
- **Britdan** — Bug testing and miscellaneous GitHub contributions
- **MadNyle** — Propeller sound effect and Mega Mushroom
- **fußmatte** — Character/font work and Esperanto translation
- **HugoBDesigner** — Portuguese-Brazilian translation
- **Los** — Russian translation
- **qixils** — Automatic GitHub workflows and LÖVE 11.4 update
- **WilliamFr0g** and **Kant** — GitHub contributions

See the comments in `main.lua` for the in-source credit notice.

## Licensing

This repository includes a custom **MARI0 AE MOD LICENSE** in [`LICENSE`](LICENSE).

Please read the included license for the complete terms regarding redistribution, modified versions, attribution and included material.

Third-party artwork, audio, characters, trademarks and other material remain the property of their respective rights holders.

## Contributing

Contributions are welcome.

When contributing:

1. Keep changes focused and understandable.
2. Test changes using the supported Mari0 AE v13.2 / LÖVE 11.5 environment.
3. Preserve existing credits and attribution.
4. Document new gameplay features or Course Maker objects where appropriate.
5. Avoid removing existing functionality without a clear reason.

## Disclaimer

Mari0 AE and the characters, artwork, audio, trademarks and other third-party material used by the project are not owned by this repository's creator.

Legendary Edition is a fan-made modification of Mari0 AE.

---

**Mari0 AE — Legendary Edition Mod**

Created by **LukeManiac** with contributions from the Mari0 AE community.
