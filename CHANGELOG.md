# Tire Smoke Control — Changelog

## 0.2.5 — 2026-10-19

- Save and restore the HUD's collapsed state through BeamNG's UI app settings, including after the game menu recreates the app.

## 0.2.4 — 2026-10-19

- Documentation maintenance release: refreshed the installation instructions and added a changelog.
- No gameplay behavior changed from v0.2.3.

## 0.2.3

- Added a smoke-rise control that scales the stock negative `gravityCoefficient` from ×0 to ×2.
- Set the default smoke-rise multiplier to ×0.25.
- Cache original particle lifetime and gravity values so each update is calculated from the stock values instead of cumulatively scaling modified values.
