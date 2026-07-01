# iCost Icon Direction

This folder contains the app icon source used by the packaging scripts.

## Recommendation

Use `icost-app-icon.svg` as the source for the generated `.icns` file.

The chosen mark combines:

- A restrained cost ring that reads as the product's "Cost" concept.
- A small amount dot for the computed spend shown in the menu bar.
- A plain white rounded app-icon tile for Dock and Finder contexts.
- No dollar sign, token letters, AI sparkle, or dashboard ornament.

This keeps the icon aligned with the product principle: the app is a quiet macOS utility that surfaces one useful number.

## Files

- `icost-app-icon.svg` - white-background source for the packaged app icon.
- `icost-app-icon.png` - exported 1024px PNG preview/use asset.
- `icost-logo.svg` - transparent scalable `currentColor` logo source for docs, web, and UI use.

## Notes

For macOS integration, the menu bar icon is drawn in code as a template image so the system can apply active, inactive, light mode, and dark mode tinting.
