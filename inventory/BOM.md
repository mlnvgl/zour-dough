# Zour-Dough BOM

Generated: 2026-04-10

This BOM reflects only parts that are explicitly documented in the repository or directly implied by the checked-in firmware and build configuration. Unknown values are left unknown on purpose.

## Hardware

| Item | Qty | Status | Source | Notes |
| --- | ---: | --- | --- | --- |
| Raspberry Pi Pico (RP2040 board) | 1 | Confirmed | `build.zig`, `README.md` | Build target is `raspberrypi.pico`. |
| IRLZ44N N-channel MOSFET | 1 | Confirmed | `README.md` | Listed as the switching transistor. |
| DS18B20 temperature sensor | 1 | Confirmed | `README.md`, `src/firmware/platform/rp2040/board/pico_wh.zig` | Firmware initializes a DS18B20 driver on GPIO22. |
| Polyimide heater film, 24 V / 30 W, 45 mm x 100 mm | 1+ | Confirmed | `README.md` | README mentions a 4-pack purchase, but installed quantity is not stated. |
| Resistor for MOSFET control line to negative rail | 1 | Partially identified | User note, `README.md` | This is a pull-down, not a pull-up, based on the described placement. Value is currently unknown. |
| Binary on/off toggle switch | 1 | Confirmed | `src/firmware/platform/rp2040/board/pico_wh.zig` | Wired to GND on GPIO18 with internal pull-up (active-low); toggling it forces the heater off without stopping sensing/logging. |
| Jumper wires | as needed | Confirmed | `README.md` | Breadboard wiring. |
| Breadboard | 1 | Inferred | User note | Not listed in README, but implied by the described build. |
| Wooden box | 1 | Confirmed | `README.md` | Enclosure. |
| Cork insulation | as needed | Confirmed | `README.md` | Thermal insulation. |

## Open Items

- The resistor value on the MOSFET control line is not documented in the repo.
- The exact Pico variant is not documented beyond the `raspberrypi.pico` build target.
- The installed heater-film count is not documented.

## Practical Note

If the resistor is between the MOSFET control pin and the minus rail, it is serving as a gate pull-down resistor. Common values for that job are 10 kOhm or 100 kOhm, but the repository does not prove which one was used here.