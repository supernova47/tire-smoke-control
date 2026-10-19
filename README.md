# Tire Smoke Control

Tire Smoke Control is a BeamNG.drive UI app for adjusting the stock tire-smoke particle effects. It adds a compact HUD with controls for smoke amount, particle lifetime, and upward movement.

## Features

- **Smoke amount:** scale particle count from ×0.1 to ×20.
- **Smoke lifetime:** scale particle lifetime from ×0.1 to ×10. A value of ×1 keeps the stock lifetime.
- **Smoke rise:** scale the negative `gravityCoefficient` from ×0 to ×2. A value of ×0 disables that upward component.
- Collapse the HUD to a smoke icon. The collapsed state is saved and restored when BeamNG recreates the app, including after opening and closing the game menu.
- Smoke settings are saved automatically to `settings/tireSmokeControl.json`.

## Installation

1. Download [Tire Smoke Control v0.2.5](releases/Tire_Smoke_Control_v0.2.5_EN.zip).
2. Put the ZIP in your BeamNG.drive user folder's `current/mods/` directory. Do not extract it.
3. Start the game and add **Tire Smoke Control** from **Esc → UI Apps → Add App**.
4. Remove older Tire Smoke Control ZIPs first to avoid duplicate UI apps.

## Compatibility

The latest game version documented by this project is BeamNG.drive 0.39.4.0. Compatibility with newer versions has not been confirmed.

## How it works

The mod adjusts the stock tire-smoke particle rules. It caches the original `lifetimeMS` and `gravityCoefficient` values for each shared `ParticleData` object and derives new values from those originals, avoiding cumulative scaling. Smoke amount updates the stock rubber-on-asphalt particle rules.

Particle datablocks can be shared by multiple effects, so lifetime and rise changes may affect other effects that use the same datablocks, including AI traffic smoke. Wind, inertia, and emitter velocity may continue to move particles when smoke rise is set to ×0.

Increasing particle count and lifetime can increase performance cost when many smoke particles are visible.

## Repository layout

The `lua/`, `scripts/`, and `ui/` directories contain the mod in BeamNG's expected package layout. See [CHANGELOG.md](CHANGELOG.md) for release history.
