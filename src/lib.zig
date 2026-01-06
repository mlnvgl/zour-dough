const sdt = @import("std");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn hello() void {
    const stdout = sdt.io.getStdOut().writer();
    _ = stdout.print("Hello from zour_dough\n", .{});
}
