// serial-logger: reads logs from the Pico over USB-CDC serial and prints them to stdout.
// Also watches the UF2 firmware file for changes and auto-reflashes via flashy.
//
// Usage: run from repo root: ./zig-out/bin/serial-logger
//
// Serial port notes:
//   - O_NONBLOCK is required on both the existence check and the open() call.
//     On macOS, opening a serial port without O_NONBLOCK blocks indefinitely
//     waiting for a carrier detect (DCD) signal. USB-CDC devices like the Pico
//     never assert DCD, so the call hangs forever without this flag.
//   - waitForSerial() uses posix.access() (not open()) to check existence,
//     since access() never blocks regardless of DCD state.
//   - VMIN=0 + VTIME=1 in termios makes reads return after 0.1s if no data
//     arrives, allowing the main loop to also poll for UF2 changes.

const std = @import("std");

const SERIAL_PORT = "/dev/tty.usbmodemsomeserial1";
const UF2_PATH = "zig-out/firmware/blinky.uf2";

fn waitForSerial() void {
    while (true) {
        std.posix.access(SERIAL_PORT, std.posix.F_OK) catch {
            std.Thread.sleep(100 * std.time.ns_per_ms);
            continue;
        };
        break;
    }
}

fn openSerial() !std.posix.fd_t {
    const fd = try std.posix.open(SERIAL_PORT, .{ .ACCMODE = .RDWR, .NOCTTY = true, .NONBLOCK = true }, 0);

    var tty = try std.posix.tcgetattr(fd);
    // Raw mode: disable canonical mode, echo, signals
    tty.iflag = .{};
    tty.oflag = .{};
    tty.lflag = .{};
    tty.cflag = .{ .CREAD = true, .CLOCAL = true, .CSIZE = .CS8 };
    // VTIME = 1 means 0.1s timeout, VMIN = 0 means return immediately if no data
    tty.cc[@intFromEnum(std.posix.V.TIME)] = 1;
    tty.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    tty.ispeed = @enumFromInt(115200);
    tty.ospeed = @enumFromInt(115200);
    try std.posix.tcsetattr(fd, .NOW, tty);

    return fd;
}

fn getUF2Mtime() !i128 {
    const file = try std.fs.cwd().openFile(UF2_PATH, .{});
    defer file.close();
    const stat = try file.stat();
    return stat.mtime;
}

fn reflash(allocator: std.mem.Allocator) !void {
    std.debug.print("\n--- Firmware changed, reflashing... ---\n", .{});
    var child = std.process.Child.init(&.{"./zig-out/bin/flashy"}, allocator);
    try child.spawn();
    _ = try child.wait();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Waiting for serial port...\n", .{});
    waitForSerial();

    var last_mtime = getUF2Mtime() catch 0;
    var fd = try openSerial();
    std.debug.print("Watching for changes... (Ctrl+C to quit)\n\n", .{});

    var line_buf: [256]u8 = undefined;
    var line_len: usize = 0;
    var byte_buf: [1]u8 = undefined;

    while (true) {
        // Check if UF2 changed
        const current_mtime = getUF2Mtime() catch last_mtime;
        if (current_mtime != last_mtime) {
            last_mtime = current_mtime;
            std.posix.close(fd);
            try reflash(allocator);
            waitForSerial();
            fd = try openSerial();
            std.debug.print("Reconnected.\n\n", .{});
            line_len = 0;
        }

        // Read one byte at a time, print on newline
        const n = std.posix.read(fd, &byte_buf) catch continue;
        if (n == 0) continue;

        const byte = byte_buf[0];
        if (byte == '\n' or line_len >= line_buf.len - 1) {
            if (line_len > 0) {
                std.debug.print("{s}\n", .{line_buf[0..line_len]});
                line_len = 0;
            }
        } else if (byte != '\r') {
            line_buf[line_len] = byte;
            line_len += 1;
        }
    }
}
