# Godot Facebook Instant Export

Unofficial Godot addon that adds a custom export platform for Facebook
Instant Games.

## Features

-   Adds a new export platform inside Godot
-   Exports your project as a ZIP package
-   Generates `index.html` automatically
-   Includes Web runtime files (`.js`, `.wasm`)
-   Packs project data into `.pck`
-   Designed for Facebook Instant Games workflow

## Requirements

-   Godot 4.x
-   Web export templates installed

## Installation

1.  Download or clone this repository.

2.  Copy the folder:

    addons/facebook_instant_export

    into your Godot project's `addons/` directory.

3.  Open your project in Godot.

4.  Go to:

    Project → Project Settings → Plugins

5.  Enable **Facebook Instant Export**.

## Usage

1.  Open the **Export** menu in Godot.

2.  Add a new export preset:

    Facebook Instant Game

3.  Configure the options:

    -   facebook/app_id (optional)
    -   web/output_basename (default: game)

4.  Click **Export Project**.

5.  A .zip file will be generated, ready for Facebook Instant Games.

## Demo

A working example project is available in the demo/ folder.

To test: 1. Open the demo folder in Godot. 2. Enable the plugin. 3. Try
exporting using the custom platform.

## Current Status

This addon is in early development.

-   Export pipeline is functional
-   ZIP packaging works
-   Basic HTML template system is implemented

### Planned Improvements

-   Facebook Instant SDK integration
-   Better Web bootstrap handling
-   Optimization for production builds
-   UI improvements

## Disclaimer

This project is an independent, unofficial addon.

-   It is NOT affiliated with, endorsed by, or sponsored by the Godot
    Engine project or the Godot Foundation.
-   It is NOT affiliated with, endorsed by, or sponsored by Meta
    Platforms, Inc. (Facebook).
-   "Godot" and "Facebook" are trademarks of their respective owners.

This addon is provided for educational and development purposes only.

Users are responsible for complying with: - Godot Engine license -
Facebook Instant Games policies and terms

## License

This project is licensed under the MIT License.

Provided "as is", without warranty of any kind.
