const std = @import("std");

pub const SPLASH_TOP: [16]u8 = "Zour-Dough      ".*;
pub const SPLASH_VER: [16]u8 = "v2026.09.12     ".*;

test "splash rows are exactly one display row" {
    try std.testing.expectEqual(16, SPLASH_TOP.len);
    try std.testing.expectEqual(16, SPLASH_VER.len);
    try std.testing.expectEqualStrings("Zour-Dough      ", &SPLASH_TOP);
    try std.testing.expectEqualStrings("v2026.09.12     ", &SPLASH_VER);
}

pub fn tempRow(buf: *[16]u8, temp: ?f32) []const u8 {
    if (temp) |t| {
        return std.fmt.bufPrint(buf, "{s:<4}{d:>10.1} C", .{ "NOW", t }) catch unreachable;
    }

    return std.fmt.bufPrint(buf, "{s:<4}{s:>10}  ", .{ "NOW", "---" }) catch unreachable;
}

test "tempRow renders the current temperature right-aligned" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("NOW       24.5 C", tempRow(&buf, 24.5));
}

test "tempRow renders --- before the first successful read" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("NOW        ---  ", tempRow(&buf, null));
}

pub fn distanceRow(buf: *[16]u8, cm: ?f32) []const u8 {
    if (cm) |c| {
        return std.fmt.bufPrint(buf, "{s:<4}{d:>9.0} cm", .{ "DIST", c }) catch unreachable;
    }

    return std.fmt.bufPrint(buf, "{s:<4}{s:>9}   ", .{ "DIST", "---" }) catch unreachable;
}

test "distanceRow renders whole centimeters" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("DIST       12 cm", distanceRow(&buf, 12.4));
}

test "distanceRow renders --- after a timeout" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("DIST      ---   ", distanceRow(&buf, null));
}
