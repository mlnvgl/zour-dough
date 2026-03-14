const std = @import("std");

const UF2_PATH = "zig-out/firmware/blinky.uf2";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Rebooting to bootloader...\n", .{});
    var reboot = std.process.Child.init(&.{ "picotool", "reboot", "-f", "-u" }, allocator);
    try reboot.spawn();
    _ = try reboot.wait();

    std.Thread.sleep(3 * std.time.ns_per_s);

    std.debug.print("Flashing {s}...\n", .{UF2_PATH});
    var flash = std.process.Child.init(&.{ "picotool", "load", "-f", "-x", UF2_PATH }, allocator);
    try flash.spawn();
    const term = try flash.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("flash failed with exit code {d}\n", .{code});
            } else {
                std.debug.print("Done!\n", .{});
            }
        },
        .Signal => |sig| std.debug.print("process killed by signal {d}\n", .{sig}),
        else => std.debug.print("process terminated unexpectedly\n", .{}),
    }
}
