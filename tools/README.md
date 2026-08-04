# Host Tools

`flash.zig` and `serial-logger.zig` are native host executables, not firmware
modules. They remain outside `src/firmware/` deliberately: their intended
future home is a standalone repository shared by MicroZig projects.

Until that extraction, `build.zig` builds them as `flashy` and
`serial-logger`. Project-specific defaults, such as the UF2 artifact path and
serial device, are currently local compatibility settings and should become
command-line options in the shared tool.
