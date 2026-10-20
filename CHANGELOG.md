# Tire Smoke Control — Changelog

## 0.2.7 — 2026-10-20

- Reworked the collapsed HUD into a small square icon that can be dragged anywhere inside the screen and remembers its position.
- Expands the panel toward the available screen space around the icon.
- Enabled independent width and height resizing in the HUD editor, with a compact minimum size.
- Preserved the HUD editor's own move and resize behavior while the app is collapsed.

## 0.2.6 — 2026-10-20

- Fixed the HUD app failing to mount in BeamNG.drive 0.40.1, which left its controls unusable.
- Made the app controller optional and added a local settings fallback for HUD hosts that do not provide `bngApp`.
- Switched smoke lifetime and rise updates to BeamNG's current Lua datablock API.
- Declared the app as interactive for the current HUD host.

## 0.2.5 — 2026-10-19

- Save and restore the HUD's collapsed state through BeamNG's UI app settings, including after the game menu recreates the app.

## 0.2.4 — 2026-10-19

- Documentation maintenance release: refreshed the installation instructions and added a changelog.
- No gameplay behavior changed from v0.2.3.

## 0.2.3

- Added a smoke-rise control that scales the stock negative `gravityCoefficient` from ×0 to ×2.
- Set the default smoke-rise multiplier to ×0.25.
- Cache original particle lifetime and gravity values so each update is calculated from the stock values instead of cumulatively scaling modified values.
