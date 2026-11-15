# World Dominion

World Dominion is an offline, turn-based geopolitical strategy game built with Godot 4.3 and GDScript. This repository contains the first playable campaign slice: a real world map, selectable countries, territory administration, state creation, campaign turns, and local save files.

## Run in Godot

Open `project.godot` in Godot 4.3 or later and press **F6/F5**. Choose a country on the title screen and begin the campaign.

## Controls and campaign actions

- Click a country to inspect it. Hold **Shift** while clicking to add or remove territories from a multi-selection.
- Drag the map to pan; use the mouse wheel to zoom.
- Annex or occupy selected territories for the player nation, or restore their original owners.
- Choose **Found New State** to give selected territories a new owner and country record. Set its name, government, diplomatic relationship, and map color.
- **End Turn** advances the date and updates country treasuries and stability.
- Save and load named campaign files from the title screen. Saves are stored under `user://saves`.

In this campaign slice each Natural Earth country polygon is an independently selectable territory. Detailed subnational provinces, capitals and cities, military operations, autonomous administration, diplomacy, AI policies, events, and map overlays are planned follow-up systems. The economy and political values are abstract game values rather than census estimates.

## Windows build

Push to `main`/`master`, or manually start **Build Windows game** under GitHub Actions. The workflow installs Godot and its export templates, imports the project, exports `build/WorldDominion.exe`, and uploads it as the `WorldDominion-Windows` artifact.

To export locally, install the Godot 4.3 Windows export templates and run:

```powershell
godot --headless --editor --path . --import
godot --headless --path . --export-release "Windows Desktop" build/WorldDominion.exe
```

## Map data

`data/world.geojson` contains Natural Earth 1:110m Admin 0 country boundaries, downloaded from the [Natural Earth Vector](https://github.com/nvkelso/natural-earth-vector) project. Natural Earth datasets are public domain. The game is an original project and does not use artwork or data from the referenced commercial games.
