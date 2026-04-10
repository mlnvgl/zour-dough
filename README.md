# Zour-Dough: Zig-Powered Enviroment for your sour dough starter

- 2punkt regler
-
## Pre-requisites


## Hardware

- IRLZ44N N-Kanal MOSFET Transistor 55V 47A 3 Polig TO-220AB IRLZ44NPBF Transistoren
- RP 2040
- DS18B20 Temperature sensor
- Heizfolien: 24V 30W Flexibler Polyimid PI Heizfolie Heizplatten Klebstoff 45mmx100mm Beheizte Panel Für Industriegerät Frostschutzisolierung (4er). rbeitsspannung: DC 24 V, Leistung: 30 W, Filmgröße: 100 x 45 mm / 3,94 x 1,77 Zoll (L * W), maximale Temperatur: ca. 170 ° C.
- Resistoren:
- Jumper Wire
- Holzkiste
- Kork für Isolierung

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
