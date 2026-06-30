# TokenCostBar Icon Direction

This folder contains the app icon source used by the packaging scripts.

## Recommendation

Use `tokencostbar-app-icon.svg` as the source for the generated `.icns` file.

The chosen mark combines:

- A quiet trend line for daily cost movement.
- A small terminal cost dot for the computed amount.
- A transparent background.
- No dollar sign, token letters, AI sparkle, or dashboard ornament.

This keeps the icon aligned with the product principle: the app is a quiet macOS utility that surfaces one useful number.

## Files

- `tokencostbar-app-icon.svg` - transparent glyph source for the packaged app icon.

## Notes

For macOS integration, the menu bar icon is drawn in code as a template image so the system can apply active, inactive, light mode, and dark mode tinting.
