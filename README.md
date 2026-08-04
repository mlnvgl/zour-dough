# Zour-Dough: Zig-powered environment for your sourdough starter

## Hardware

- Raspberry Pi Pico (RP2040)
- IRLZ44N N-channel MOSFET
- DS18B20 Temperature sensor
- Polyimide heater film, 24 V / 30 W, 45 mm x 100 mm
- Resistor for the MOSFET control line
- Jumper wires
- Wooden box
- Cork insulation

Detailed inventories:
- Hardware BOM: [inventory/BOM.md](inventory/BOM.md)
- Software SBOM: [inventory/SBOM.cdx.json](inventory/SBOM.cdx.json)

## Development

Requires Zig 0.15.x and `picotool`:

```sh
brew install picotool
zig build
zig build run-flashy
zig build run-serial-logger
```

## Architecture

- `src/firmware/domain/` contains hardware-free control and state logic.
- `src/firmware/app/` coordinates sensing, control, actuation, and telemetry.
- `src/firmware/platform/rp2040/` contains board wiring and MicroZig-specific
  device and transport adapters.
- `src/firmware/support/` contains small firmware utilities.
- `tools/` contains native host tools. It intentionally remains independent
  from firmware code so it can move to a reusable MicroZig tools repository.
