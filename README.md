# Mari0 AE — Legendary Edition Mod

**Legendary Edition** is a community-made expansion and modification for **Mari0 AE**, created by **LukeManiac**.

The project expands Mari0 AE with new gameplay systems, playable characters, enemies, Course Maker content, visual effects, shaders, sounds, languages, loading presentation, controller support, and a wide range of gameplay and quality-of-life changes.

> **Compatibility:** Mari0 AE v13.2 with LÖVE 11.5.

---

## ✨ Highlights

* 🌀 Expanded portal gameplay
* 🍄 Multiple playable characters
* 👾 Expanded enemies and enemy behaviour
* 🧱 Expanded **Course Maker**
* 🧪 Gel gameplay and related mechanics
* 💧 Additional gameplay mechanics and effects
* 🔫 Additional weapons and projectiles
* 💥 New power-ups and gameplay elements
* 🎯 Daily Challenge support
* 🎮 Controller and joystick support
* 🖼️ New and improved graphics
* ✨ New shaders and visual effects
* 🔊 New and improved sounds
* 🌍 Additional languages and translations
* 📢 Expanded loading notifications and presentation
* ⚙️ Gameplay, physics and quality-of-life improvements
* 🚀 Changes throughout the game's Lua source
* 🔧 Additional tweaks across individual gameplay systems

---

# 📖 Contents

* [About](#about)
* [What's New](#whats-new)
* [Changelog](#changelog)
* [Requirements](#requirements)
* [Installation](#installation)

  * [Using the Installer](#using-the-installer)
  * [Installing from Source](#installing-from-source)
  * [Installation Locations](#installation-locations)
* [Project Layout](#project-layout)
* [Features](#features)

  * [Gameplay](#gameplay)
  * [Characters](#characters)
  * [Enemies](#enemies)
  * [Portals and Physics](#portals-and-physics)
  * [Course Maker](#course-maker)
  * [Daily Challenge](#daily-challenge)
  * [Visuals and Shaders](#visuals-and-shaders)
  * [Audio](#audio)
  * [Languages](#languages)
  * [Loading and Presentation](#loading-and-presentation)
* [Gameplay Improvements](#gameplay-improvements)
* [Configuration](#configuration)
* [Development](#development)
* [Main Lua Files](#main-lua-files)
* [Repository Structure](#repository-structure)
* [Credits](#credits)
* [Licensing](#licensing)
* [Contributing](#contributing)
* [Disclaimer](#disclaimer)

---

# About

Legendary Edition is designed as an expanded version of Mari0 AE, building upon its existing gameplay and systems while introducing additional content and refinements.

The project is primarily written in **Lua** and uses **LÖVE 11.5**.

Rather than relying on a conventional compiled build system, the repository contains the Lua source code and game assets directly.

The project covers a broad range of Mari0 AE systems, including:

* Player movement and physics
* Characters
* Enemies
* Portals
* Weapons and projectiles
* Power-ups
* Gel mechanics
* Course Maker
* Daily Challenges
* Camera behaviour
* Menus
* Loading presentation
* Shaders
* Audio
* Languages
* Controller input
* Individual gameplay objects and systems

---

# What's New?

Legendary Edition introduces changes throughout the game rather than concentrating everything into a single feature.

### Gameplay

* Expanded player and character behaviour
* Additional gameplay mechanics
* Expanded enemy behaviour
* Additional power-ups
* Additional weapons and projectiles
* Portal gameplay improvements
* Gel-related gameplay
* Camera behaviour adjustments
* Physics and movement refinements
* Additional Course Maker functionality

### Presentation

* New loading messages
* New loading sounds
* Additional loading notifications
* New shaders
* Additional visual effects
* Improved graphical presentation
* Additional audio content
* Additional languages and translations

### Systems

* Controller and joystick support
* Daily Challenge functionality
* Expanded configuration options
* Additional gameplay objects
* Changes throughout the Lua source
* Improvements to individual game systems

Vertical camera seeking has also been reduced to help prevent the player from being left off-screen when attempting to camera-seek vertically.

**The rest of the Lua files have also been tweaked and improved**, meaning the changes are not limited to the systems listed above.

---

# Changelog

All notable releases and updates to **Legendary Edition** are documented here.

## v1.0.2

### ✨ Improvements

* Added more loading messages to expand the loading presentation.
* Animation number debugging now requires pressing **LCtrl+0**.

### ❌ Removals

* Removed the annoying ass `"pipe not found"` spam that could repeatedly appear during character debugging.

## v1.0.1

### 🐛 Bug Fixes

* Fixed a crash that could occur when a **Koopa Troopa** side-hit a block.
* Improved the handling of Koopa Troopa interactions with blocks to prevent the game from crashing during side-hit collisions.

---

# Requirements

| Requirement  | Version |
| ------------ | ------- |
| **Mari0 AE** | v13.2   |
| **LÖVE**     | 11.5    |

A clean Mari0 AE v13.2 installation is recommended as the base for Legendary Edition.

---

# Installation

There are two primary ways to install Legendary Edition.

## Using the Installer

The easiest method is to download the **Legendary Edition installer** from the project's **Releases** page.

1. Open the repository's **Releases** page.
2. Download the installer for your platform.
3. Run the installer.
4. Follow the installation instructions.
5. Launch the game.

The installer is intended to provide a straightforward installation without requiring you to manually place the individual source files.

## Installing from Source

You can also install Legendary Edition directly from the source repository.

1. Download the repository source code.
2. Extract the downloaded files.
3. Locate your Mari0 data directory for your operating system.
4. Place the Legendary Edition files inside the `mari0` directory.
5. Preserve the repository's directory structure.
6. Launch Mari0 AE through **LÖVE 11.5**.

### Installation Locations

#### Windows

```
C:/Users/<YOUR_USERNAME>/AppData/Roaming/mari0
```

#### macOS

```
Users/<YOUR_USERNAME>/Library/Application Support/mari0
```

#### Linux

```
home/<YOUR_USERNAME>/.local/share/mari0
```

Replace `<YOUR_USERNAME>` with your operating-system username.

### Source Installation Layout

The installed files should retain their directory structure.

For example:

```
mari0/
├── enemies/
├── graphics/
├── languages/
├── shaders/
├── sounds/
├── main.lua
├── game.lua
├── mario.lua
├── enemy.lua
├── editor.lua
├── menu.lua
├── portal.lua
├── variables.lua
└── ...
```

---

# Project Layout

Legendary Edition is organised around the Lua systems used by Mari0 AE, together with separate directories for major asset groups.

```
Legendary Edition
│
├── enemies/          Enemy-specific assets and resources
├── graphics/         Graphics and sprite resources
├── languages/        Language and translation files
├── shaders/          Shader programs and visual effects
├── sounds/           Sound effects and audio resources
│
├── main.lua          Main LÖVE entry point
├── game.lua          Core game and game-state systems
├── mario.lua         Player and character behaviour
├── enemy.lua         Enemy systems
├── editor.lua        Course Maker
├── menu.lua          Menus and interface
├── portal.lua        Portal systems
├── variables.lua     Gameplay and physics configuration
├── dailychallenge.lua Daily Challenge systems
└── ...
```

The repository also contains many specialised Lua files for individual objects, mechanics and gameplay systems.

---

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

## Characters

Legendary Edition supports multiple playable characters and includes additional character-related content.

Character systems can affect:

* Movement
* Physics
* Animation
* Abilities
* Power-ups
* Sprites
* Character-specific behaviour
* Character configuration

Character and font-related resources are also included within the project.

---

## Enemies

Enemy systems have been expanded with additional behaviour and content.

The project contains a variety of enemy-related systems and assets, including:

* Standard enemies
* Turrets
* Banzai Bills
* Dry Beetles
* Ninji
* Splunkin
* Bowser-related content
* Additional enemy behaviours

Enemy systems are handled through both the main enemy code and specialised Lua files.

---

## Portals and Physics

Portals remain one of the central mechanics of Mari0 AE, and Legendary Edition expands the systems surrounding them.

Changes include:

* Portal interactions
* Portal timing
* Portal movement
* Character movement through portals
* Physics interactions
* Gel interactions
* Collision behaviour
* Camera behaviour
* Portal-related visual effects

Additional portal assets and visual variations are included in the project.

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

## Daily Challenge

Legendary Edition includes support for **Daily Challenges**.

Daily Challenge functionality is handled through dedicated Lua systems, including:

```
dailychallenge.lua
dailychallengenew.lua
```

These systems integrate Daily Challenge functionality into the wider game structure.

---

## Visuals and Shaders

Legendary Edition includes additional graphical content and visual effects.

The project contains a dedicated:

```
graphics/
```

directory for graphical resources and:

```
shaders/
```

for shader-based effects.

Visual changes can include:

* New sprites
* Character graphics
* Portal graphics
* Environmental graphics
* Animated effects
* Shader effects
* Additional visual variations
* Improved presentation of gameplay elements

---

## Audio

The project contains a dedicated:

```
sounds/
```

directory for audio resources.

Audio additions include:

* New sound effects
* Loading sounds
* Gameplay sounds
* Character-related sounds
* Power-up sounds
* Environmental sounds
* Additional effects

Loading sounds are also used alongside the expanded loading presentation.

---

## Languages

Legendary Edition includes additional language support and translations.

Language resources are stored in:

```
languages/
```

The project includes contributions for languages such as:

* Esperanto
* Portuguese-Brazilian
* Russian

Additional translations may be added as the project develops.

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

# Gameplay Improvements

Legendary Edition contains changes across many different parts of Mari0 AE.

These include:

### Player

* Movement
* Physics
* Air control
* Friction
* Ice physics
* Character behaviour
* Power-up interactions

### Enemies

* Enemy behaviour
* Enemy movement
* Enemy interactions
* Enemy-specific mechanics
* Additional enemy content

### Portals

* Portal interactions
* Portal timing
* Portal physics
* Portal movement
* Portal visual effects

### World

* Moving tiles
* Water systems
* Pipes
* Tubes
* Environmental objects
* Collision systems

### Camera

* Horizontal camera behaviour
* Vertical camera seeking
* Camera boundaries
* Player visibility during camera movement

### Interface

* Menus
* Loading presentation
* Notifications
* Controller input
* Language support

### Course Maker

* Additional objects
* Additional gameplay systems
* Object behaviour
* Configuration options
* Custom-course functionality

Not every individual change is listed in this README. **Many of the Lua files throughout the project contain smaller gameplay, presentation, physics and quality-of-life changes.**

---

# Configuration

Many gameplay and physics values can be configured through the Lua source.

The main configuration file is:

```
variables.lua
```

It contains values relating to systems such as:

* Player movement
* Friction
* Air control
* Ice physics
* Portal timing
* Gel behaviour
* Projectile lifetimes
* Controller settings
* Character settings
* Scoring
* Power-ups
* Physics
* Gameplay behaviour

Some systems use values from multiple Lua files, so advanced customisation may require examining the related gameplay systems as well.

---

# Development

Legendary Edition is primarily written in **Lua** and uses **LÖVE 11.5** as its framework.

The repository contains the game's Lua source code and assets directly.

There is no conventional compiled build system required for the source itself. The project is structured around the source files and resources used by the LÖVE game.

## Development Environment

Recommended development environment:

* **Mari0 AE v13.2**
* **LÖVE 11.5**
* A Lua-compatible code editor
* A clean working copy of the project

When making changes, preserve the existing directory structure so that assets and Lua systems remain correctly organised.

---

# Main Lua Files

| File                    | Description                                      |
| ----------------------- | ------------------------------------------------ |
| `main.lua`              | Main LÖVE entry point, loading and initial setup |
| `game.lua`              | Core gameplay and game-state logic               |
| `mario.lua`             | Player behaviour and physics                     |
| `enemy.lua`             | Enemy systems and behaviour                      |
| `editor.lua`            | Course Maker functionality                       |
| `menu.lua`              | Menus and interface                              |
| `portal.lua`            | Portal systems                                   |
| `variables.lua`         | Configurable gameplay and physics variables      |
| `dailychallenge.lua`    | Daily Challenge functionality                    |
| `dailychallengenew.lua` | Additional Daily Challenge functionality         |
| `camerastop.lua`        | Camera-related systems                           |
| `clearpipe.lua`         | Clear pipe systems                               |
| `energylauncher.lua`    | Energy launcher systems                          |
| `geldispenser.lua`      | Gel dispenser systems                            |
| `risingwater.lua`       | Rising water systems                             |
| `tilemoving.lua`        | Moving tile systems                              |
| `box.lua`               | Box-related gameplay systems                     |
| `intro.lua`             | Introductory presentation and loading systems    |

The project also contains many additional Lua files for specialised objects and mechanics.

---

# Repository Structure

The repository is divided into several major areas.

| Directory / File     | Purpose                |
| -------------------- | ---------------------- |
| `enemies/`           | Enemy resources        |
| `graphics/`          | Graphics and sprites   |
| `languages/`         | Translation resources  |
| `shaders/`           | Shader programs        |
| `sounds/`            | Audio resources        |
| `main.lua`           | Main game entry point  |
| `game.lua`           | Core game systems      |
| `mario.lua`          | Player systems         |
| `enemy.lua`          | Enemy systems          |
| `editor.lua`         | Course Maker           |
| `menu.lua`           | Menus                  |
| `portal.lua`         | Portal mechanics       |
| `variables.lua`      | Gameplay configuration |
| `dailychallenge.lua` | Daily Challenge        |
| `LICENSE`            | Project licence        |

Additional Lua files provide specialised functionality for individual objects, mechanics, effects and systems.

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

# Licensing

This repository includes a custom **MARI0 AE MOD LICENSE** in [`LICENSE`](LICENSE).

Please read the included licence for the complete terms regarding:

* Redistribution
* Modified versions
* Attribution
* Included material
* Other applicable conditions

Third-party artwork, audio, characters, trademarks and other material remain the property of their respective rights holders.

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

# Disclaimer

Mari0 AE and the characters, artwork, audio, trademarks and other third-party material used by the project are not owned by this repository's creator.

Legendary Edition is a fan-made modification of Mari0 AE.

---

## 🎮 Mari0 AE — Legendary Edition

**Created by LukeManiac with contributions from the Mari0 AE community.**

**Mari0 AE v13.2 • LÖVE 11.5 • Lua**

---
