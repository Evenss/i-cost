# TokenCostBar Icon Direction

This folder contains a restrained icon direction for TokenCostBar.

## Recommendation

Use `tokencostbar-app-icon.svg` for the transparent glyph direction and `tokencostbar-menubar-template.svg` for the macOS menu bar template icon.

The chosen mark combines:

- A quiet trend line for daily cost movement.
- A small terminal cost dot for the computed amount.
- A transparent background.
- No dollar sign, token letters, AI sparkle, or dashboard ornament.

This keeps the icon aligned with the product principle: the app is a quiet macOS utility that surfaces one useful number.

## Files

- `tokencostbar-app-icon.svg` - recommended transparent glyph concept.
- `tokencostbar-menubar-template.svg` - recommended single-color menu bar template icon.
- `exports/tokencostbar-app-icon-1024.png` - PNG render for review and packaging preparation.
- `variants/*.svg` - six comparison directions.
- `icon-showcase.html` - local preview page.

## Notes

For macOS integration, the menu bar asset should be rendered as a template image so the system can apply active, inactive, light mode, and dark mode tinting.
