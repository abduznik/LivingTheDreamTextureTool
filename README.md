# LivingTheDream Texture Tool

A Flutter desktop application for importing, cropping, and processing textures
for the LivingTheDream mod project. Ported from the original C# tool.

## Features

- Image browser for selecting source textures from a local library
- Built-in crop editor with freeform cropping and interactive crop handles
- Smart upscaling: automatically resizes cropped images to 512x512 or 384x384
  depending on source resolution
- High-quality linear interpolation for clean resizing of hard-edged graphics
- Light Gaussian blur pass after resize to reduce compression artifacts on edges
- Texture export in the correct format for the game
- Fully desktop-native: supports Windows, macOS, and Linux

## Platform Support

| Platform | Status      |
|----------|-------------|
| Windows  | Supported   |
| macOS    | Supported   |
| Linux    | Supported   |

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Windows: no additional dependencies
- macOS: Xcode command line tools
- Linux: libgtk-3-dev, libblkid-dev, liblzma-dev

### Build from source

    flutter pub get
    flutter build windows --release
    flutter build macos --release
    flutter build linux --release

## CI / Release

This project uses GitHub Actions for automated builds and releases.
To trigger a release, go to Actions, select "Build and Release",
and run the workflow manually with a version tag (e.g. v1.0.0).

Builds produced:
- Windows: installer (.exe) via inno_bundle
- macOS: disk image (.dmg)
- Linux: tar.gz bundle and AppImage

## Project Structure

    lib/
      src/
        models/       - Data models
        providers/    - Riverpod state providers
        services/     - Texture processing and file services
        ui/
          views/      - Full screen views
          utils/      - Helpers including image editor and crop logic

## License

See LICENSE.txt for details.
