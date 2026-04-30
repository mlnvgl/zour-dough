# Zour-Dough: Zig-Powered Enviroment for your sour dough starter

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

1. Zig build
2. Flash
    - install picotool via ``` brew install picotool ``` which is neccessary for flashing process
    - run ``` zig run tools/flash.zig ```

3. Start serial loggers
    - open new terminal
    - run ``` zig run tools/serial-logger.zig ```
