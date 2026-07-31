# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Zour-Dough: RP2040 (Raspberry Pi Pico) firmware, written in Zig on top of MicroZig, that keeps a
sourdough starter at temperature. A DS18B20 probe reads temperature, an HC-SR04-style ultrasonic
sensor measures dough height/rise, and a MOSFET-driven heater film is switched by simple two-point
(bang-bang) control between `TEMP_THRESHOLD_MIN`/`TEMP_THRESHOLD_MAX`. All logging goes out over
USB CDC serial rather than a debugger.

Two host-side Zig CLI tools round out the dev loop: `flashy` (reboot-to-bootloader + flash via
picotool) and `serial-logger` (tails the USB serial log and auto-reflashes when the built `.uf2`
changes).

**Current implementation vs. `doc/`:** `doc/` (gitignored, so it exists locally but is never
committed) contains a much more ambitious software spec
(`sourdough-incubator-software-spec.md`) describing a future Python/Raspberry-Pi-SBC system with
PID control, fermentation-phase estimation, persistent state, Grafana/InfluxDB logging, energy
accounting, and a phone UI. None of that is implemented — the actual firmware in `src/` is the
current, much simpler two-point controller. Don't assume the spec's modules (`SPEC-CTRL`,
`SPEC-EST`, etc.) exist in code; treat that doc as design aspiration/talk notes, not a description
of `src/main.zig`.

## Commands

Requires Zig `0.15.x` (`minimum_zig_version` in `build.zig.zon` is `0.15.1`) and, for flashing,
`picotool` (`brew install picotool`).

**Zig 0.16 does not currently build this repo** — MicroZig's own build tooling (`regz`, `aro`,
`translate_c`, vendored) hasn't been updated for 0.16's `Build` API changes yet, even on
MicroZig's `main` branch. Use Zig 0.15.x until upstream MicroZig catches up. On this machine
that means the keg-only `zig@0.15` Homebrew formula (`brew install zig@0.15`), invoked via its
full path since the global `zig` on `PATH` is 0.16 (substitute plain `zig` below if your `PATH`
already resolves to 0.15.x):

```bash
alias zig=/opt/homebrew/opt/zig@0.15/bin/zig  # this machine only; skip if `zig` is already 0.15.x

zig build                    # build firmware (zig-out/firmware/blinky.uf2 + .elf) and host tools
zig build test                # run host-side unit tests (currently: src/power_switch.zig)
zig build run-flashy         # flash zig-out/firmware/blinky.uf2 to the Pico via picotool
zig build run-serial-logger  # tail USB serial output; auto-reflashes when the .uf2 changes
```

Typical dev loop, in two terminals:

```bash
zig build && zig build run-flashy   # first flash
zig build run-serial-logger         # leave running; rebuilding + reflashing auto-reconnects it
```

## Architecture

- `src/main.zig` — firmware entry point. Owns pin config (`pin_config`), the main polling loop,
  the two-point heater control, and the ultrasonic distance measurement
  (`measure_ultra_sound`/`waitForEchoStart`/`waitForEchoEnd`). The loop is non-blocking by design:
  everything is driven off `time.get_time_since_boot()` deltas and `usb_cdc.poll()` calls, never
  `time.sleep_ms` in a spot that would starve USB — see the "LED Freezing" lesson in
  `doc/DEVLOG.md` for why blocking here is a real regression, not just a style nit. The Baker's
  physical on/off toggle switch (GPIO18, pull-up, active-low) is read every loop iteration and fed
  into `PowerSwitch`; when off, the heater is forced low but temperature/ultrasound sensing and
  logging continue unchanged.
- `src/power_switch.zig` — pure, hardware-free `PowerSwitch` (`switchOn`/`switchOff` methods over
  a `PowerState` enum, no bare `bool` for the mode). Covered by `zig build test`; this is the only
  module in the repo with unit tests, precisely because it has no MicroZig/GPIO dependency.
- `src/helpers/usb_cdc.zig` — the USB CDC serial wrapper (`init`/`poll`/`write`/`read`) used for all
  firmware logging. `write` bounds itself with a 10ms deadline so a disconnected/non-reading host
  can't hang the main loop; a dropped log line is an accepted tradeoff, not a bug.
- `build.zig` — defines the `blinky` firmware target for `raspberrypi.pico` via
  `MicroBuild(.{ .rp2xxx = true })`, plus the two host-side executables (`flashy`,
  `serial-logger`) built for the host target, each wired to a `run-*` build step.
- `tools/flash.zig` / `tools/serial-logger.zig` — host-side CLI tools (compiled by `zig build`, not
  scripts). `serial-logger.zig` watches the `.uf2` mtime and shells out to the built `flashy`
  binary to reflash automatically; both hardcode the serial port name
  (`/dev/tty.usbmodemsomeserial1`, derived from the `.serial` string set in `usb_cdc.zig`) and the
  firmware path (`zig-out/firmware/blinky.uf2`), so if either changes, update both.
- `inventory/BOM.md` / `inventory/SBOM.cdx.json` — hardware and software bill of materials; keep in
  sync with real hardware/dependency changes rather than treating them as historical records.

## Working on this firmware

- macOS-specific serial/flashing quirks (permission-denied on `cp` to `/Volumes/RPI-RP2`,
  `stty`/bootloader detection, blocking `open()` without `O_NONBLOCK`) are documented with root
  causes in `doc/DEVLOG.md` — check there before re-deriving a fix for a flashing/serial issue.
- Any new blocking work added to the main loop or to `usb_cdc.write` must not starve
  `usb_device.poll()`; follow the existing deadline pattern rather than adding bare `sleep`s.
