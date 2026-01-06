const std = @import("std");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn hello() void {
    // Use std.debug.print for a simple, stable output path
    std.debug.print("Hello from zour_dough\n", .{});
}
