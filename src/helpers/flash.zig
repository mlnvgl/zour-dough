const std = @import("std");

const SERIAL_PORT = "/dev/tty.usbmodemsomeserial1";
const UF2_PATH = "./../../zig-out/firmware/blinky.uf2";

pub fn main() !void {
    std.debug.print("Rebooting to bootloader...\n", .{});
    const allocator = std.heap.page_allocator;

    // stty touch to trigger bootloader
    var reboot = std.process.Child.init(&.{ "stty", "-f", SERIAL_PORT, "1200" }, allocator);
    try reboot.spawn();
    _ = try reboot.wait();

    // sleep to wait for volume to mount
    std.Thread.sleep(3 * std.time.ns_per_s);

    // check if UF2 file exists
    std.fs.cwd().access(UF2_PATH, .{}) catch {
        std.debug.print("UF2 file not found {s}\n", .{UF2_PATH});
        return error.UF2NotFound;
    };

    //cp to flash
    var child = std.process.Child.init(&.{ "cp", UF2_PATH, "/Volumes/RPI-RP2/" }, allocator);
    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("flash failed with exit code {d}\n", .{code});
            } else {
                std.debug.print("flashing successful!\n", .{});
            }
        },
        .Signal => |sig| std.debug.print("process killed by signal {d}\n", .{sig}),
        else => std.debug.print("process terminated unexpectedly\n", .{}),
    }
}
