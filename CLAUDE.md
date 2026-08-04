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

**Current implementation vs. `doc/requirements/`:**
`doc/requirements/software-spec.md` describes a much more ambitious future
Python/Raspberry-Pi-SBC system with PID control, fermentation-phase estimation,
persistent state, Grafana/InfluxDB logging, energy accounting, and a phone UI.
None of that is implemented — the actual firmware in `src/` is the current,
much simpler two-point controller. Don't assume the spec's modules
(`SPEC-CTRL`, `SPEC-EST`, etc.) exist in code; treat that document as design
aspiration/talk notes, not a description of `src/firmware/`.

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

- `src/firmware/main.zig` — firmware composition root. It initializes the board-specific
  peripherals, polls USB, and invokes the application service.
- `src/firmware/app/incubator.zig` — coordinates the periodic sensing, two-point heater control,
  actuation, and serial logging. The Baker's physical on/off toggle switch (GPIO18, pull-up,
  active-low) is read every loop iteration and fed into `PowerSwitch`; when off, the heater is
  forced low but temperature/ultrasound sensing and logging continue unchanged.
- `src/firmware/domain/` — pure, hardware-free control and state logic. `heater_control.zig` and
  `power_switch_control.zig` are covered by `zig build test` precisely because they have no
  MicroZig/GPIO dependency.
- `src/firmware/platform/rp2040/` — board wiring and MicroZig adapters. In particular,
  `transport/usb_cdc.zig` provides firmware logging and bounds `write` to a 10ms deadline so a
  disconnected/non-reading host cannot hang the main loop; dropped debug lines are acceptable.
  `drivers/ultrasonic.zig` accepts a keep-alive callback rather than importing USB directly.
- `src/firmware/support/` — small firmware utilities such as the non-blocking ticker.
- `build.zig` — defines the `blinky` firmware target for `raspberrypi.pico` via
  `MicroBuild(.{ .rp2xxx = true })`, plus the two host-side executables (`flashy`,
  `serial-logger`) built for the host target, each wired to a `run-*` build step.
- `tools/flash.zig` / `tools/serial-logger.zig` — host-side CLI tools (compiled by `zig build`, not
  scripts) deliberately kept outside `src/firmware/` so they can move to a shared MicroZig-tools
  repository. `serial-logger.zig` watches the `.uf2` mtime and shells out to the built `flashy`
  binary to reflash automatically; both hardcode the serial port name
  (`/dev/tty.usbmodemsomeserial1`, derived from the `.serial` string set in `usb_cdc.zig`) and the
  firmware path (`zig-out/firmware/blinky.uf2`), so if either changes, update both.
- `inventory/BOM.md` / `inventory/SBOM.cdx.json` — hardware and software bill of materials; keep in
  sync with real hardware/dependency changes rather than treating them as historical records.

## Working on this firmware

- macOS-specific serial/flashing quirks (permission-denied on `cp` to `/Volumes/RPI-RP2`,
  `stty`/bootloader detection, blocking `open()` without `O_NONBLOCK`) are documented with root
  causes in `doc/development/DEVLOG.md` — check there before re-deriving a fix for a
  flashing/serial issue.
- Any new blocking work added to the main loop or to `usb_cdc.write` must not starve
  `usb_device.poll()`; follow the existing deadline pattern rather than adding bare `sleep`s.
