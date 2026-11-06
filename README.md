# Don't Look Away

A first-person psychological horror game made in **Godot 4.7**.

> October 2026. Misha inherits his late grandmother's house at 7 Lipovaya Street in the village of Sukhoy Log.
> Her last message was strange: *"Tell Misha not to look away."*
> The house remembers everything. Especially Anya.

There is no monster chasing you. The game uses puzzles, ghosts that are only there when you aren't looking, the sound of breathing behind you, and a few well-timed scares.

**Status:** playable demo in active development (not released yet).

---

## Features

- **A Soviet 1970s–80s house** with period wallpaper, whitewashed ceilings, aged woodwork and furniture made for the game. Every room has its own props.
- **Room puzzles across the house:**
  - TV channels hidden on the backs of old photos.
  - Candles lit in the right order.
  - A mirror shard that shows the "reflected" house.
  - Steam on the bathroom mirror.
  - Hide-and-seek with Anya.
  - Dressing mannequins in the attic.
- **Wrong answers are punished with scares**, not game-overs.
- **Living house events:**
  - Objects move only when you see them in your flashlight.
  - The phone rings, and a hand reaches for the receiver in a first-person cutscene.
  - Whispers come right behind your head.
- **Ghosts with their own rules:** Anya appears at the edge of your vision and vanishes when you look straight at her.
- **Two languages:** English and Russian. Subtitles switch in the settings, and voice-over is English.
- **Graphics settings:** resolution, fullscreen, FSR upscaling, anti-aliasing, shadow and fog quality.

## Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Shift | Run |
| F | Flashlight |
| E | Interact / open and close doors |
| Q / Right mouse | Raise the mirror shard |
| Tab | Inventory |
| Esc | Pause |

Headphones are strongly recommended.

## Running the project

1. Install **Godot 4.7** (standard build, not .NET).
2. In the Project Manager, click **Import** and select `project.godot`.
3. Choose **Import & Edit**. The first import takes a minute (textures, audio, models).
4. Press **F5** to run. The game starts from `scenes/menu.tscn`.

## Project structure

```
scenes/          main level (house), menu, test scenes
scripts/         gameplay code
  level.gd         story flow, puzzles, ghosts, scares
  haunts.gd        house events (moving objects, phone, whispers)
  phone_call.gd    phone cutscene (IK arm, receiver, cord)
  interior.gd      wallpaper, woodwork, ceilings, decals per room
  spirit.gd        Anya (animation, gaze, blink, hair/dress motion)
  attic.gd         attic chapter (mannequins)
  settings.gd      options, languages, voice lookup
shaders/         wallpaper aging, CRT TV, curtains, ghost skin, etc.
models/          Blender-made and licensed 3D models
textures/        PBR textures, wallpapers, decals
audio/           sound effects and ambience
video/           TV shows and memory cutscene (Theora .ogv)
voice/<lang>/    voice-over, one file per text key (e.g. voice/en/NUR_24.ogg)
lang/strings.csv all in-game text (columns: keys, en, ru)
fonts/           OFL fonts
tools/           Blender and Python scripts used to generate assets
```

## Localization and voice-over

- All text lives in `lang/strings.csv`. To add a language, add a column and register it in `scripts/settings.gd` (`LANGS`).
- To voice a line, drop `voice/<lang>/<KEY>.ogg` (or `.wav`/`.mp3`) into the project. The game plays it automatically with that subtitle.
- If a line has no recording in the current language, the English recording plays.

## Tools

The `tools/` folder contains the scripts used to make the game's own assets:

- **Blender:** furniture, picture frames, the TV-show scenes.
- **Python:**
  - wallpaper and blood-writing textures;
  - synthesized TV music;
  - voice processing (`scary_voice.py`);
  - `git_used.py`, which writes `.gitignore` so that only files the game actually uses are committed.

## Credits and licenses

Third-party assets (models, textures, sounds, fonts) are listed with their authors and licenses in **[CREDITS.txt](CREDITS.txt)**. Non-commercial (NC) assets are not used.

> Note: the current Anya voice lines were generated on a free ElevenLabs plan and are **placeholders**. They must be regenerated on a paid plan before any commercial release.

## License

© 2026. All rights reserved. The source is shared for development and review purposes only.
