# Custom Music for the Minigames

This is the music for the **Battle music** dropdown in Rival Rumble Royale.

## Where it goes

Music can go in either of these folders, and both work the same way:

* `sounds/minigames` in the game
* `alesans_entities/battleroyalemusic` in the save folder (`%appdata%/mari0` on Windows). The game makes this folder the first time the minigames menu lists the music.

If a song or pack in the save folder has the same name as one in `sounds/minigames`, the one in the save folder is used.

## Songs and packs

Every `.ogg` file becomes an option in the dropdown. A folder is a music pack, and each of its songs is named "Pack name- Song name", for example "Kirby VRC6 Music- Nightmare".

| File | What it does |
|---|---|
| `song.ogg` | A song (loops) |
| `song-intro.ogg` | Optional. Plays once before `song.ogg` |
| `starmusic.ogg` | Optional. Replaces the star theme while a song from this pack is picked (`starmusic-intro.ogg` works too) |
| `battleclear.ogg` | Optional. The win fanfare on the victory screen for this pack, instead of the default one |
| `pack.json` | Optional. The pack's name, its place in the list and the songs' names (see below) |

## pack.json

```json
{
    "name": "Kirby VRC6 Music",
    "order": 1,
    "songs": [
        ["boss", "Boss"],
        ["skybattle", "Battle Across The Sky"]
    ]
}
```

* `songs` are `["file name without .ogg", "name in the list"]`, in list order.
* Packs with an `order` come first (lowest first), and the rest come after them.
* Packs with the same `order`, or no `order`, are sorted alphabetically by their name in the list.

## Names

Without `pack.json` (or for a song it doesn't list), the name comes from the folder or file: `my_song.ogg` becomes "My Song".

## Replacing the built-in songs

`overworld.ogg`, `underground.ogg` or `castle.ogg` placed directly in this folder replace the built-in ones.

Inside a pack folder, they're just songs of that pack ("My Pack- Overworld"), and the built-in ones stay.