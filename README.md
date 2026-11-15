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

Countries, regions, and provinces are independently selectable territories. World country borders appear at startup; zooming reveals global ADM1 regions, ADM2 subdivisions, and the deepest available national layer (ADM3–ADM5) when one is bundled. The map can pan and zoom, highlights selected territories, and includes toggles for political colors, international borders, administrative limits, and labels. Regional ownership inherits from its parent unless a campaign action assigns an explicit owner. Stable GeoBoundaries shape IDs are used for campaign selections and saves. The economy and political values are abstract game values rather than census estimates.

## Windows build

Push to `main`/`master`, or manually start **Build Windows game** under GitHub Actions. The workflow installs Godot and its export templates, imports the project, exports `build/WorldDominion.exe`, and uploads it as the `WorldDominion-Windows` artifact.

To export locally, install the Godot 4.3 Windows export templates and run:

```powershell
godot --headless --editor --path . --import
godot --headless --path . --export-release "Windows Desktop" build/WorldDominion.exe
```

## Map data

`data/maps/admin_layers.zip` contains simplified, shared-topology GeoBoundaries gbOpen ADM0, ADM1, and ADM2 layers. The bundled country-specific ADM3–ADM5 archives contain the deepest available level for countries with deeper open coverage. The game loads these local archives, so map play does not require a network connection. Geometry simplification preserves shared borders and feature shapes to keep rendering responsive; source coverage and reference dates vary by country.

The full source records from the GeoBoundaries current API are preserved in [`data/maps/geoboundaries_manifest.json`](data/maps/geoboundaries_manifest.json), including country, administrative level, source, license, source update date, and build date. GeoBoundaries gbOpen is published under CC BY 4.0, while source-level terms can vary; attribution details are included in that manifest. See the [GeoBoundaries API and license documentation](https://www.geoboundaries.org/api.html). The former `data/world.geojson` Natural Earth file is retained for reference and is not used by the game map.
