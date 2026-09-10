const std = @import("std");

pub const SPLASH_TOP: [16]u8 = "Zour-Dough      ".*;
pub const SPLASH_VER: [16]u8 = "v2026.09.12     ".*;

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

pub fn statusRow(buf: *[16]u8, heating: bool) []const u8 {
    return std.fmt.bufPrint(buf, "{s:^16}", .{if (heating) "HEATING" else "READY"}) catch unreachable;
}

test "statusRow centers HEATING while heating" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("    HEATING     ", statusRow(&buf, true));
}

test "statusRow centers READY while idle" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("     READY      ", statusRow(&buf, false));
}

pub fn targetRow(buf: *[16]u8, target: f32) []const u8 {
    return std.fmt.bufPrint(buf, "{s:<4}{d:>10.1} C", .{ "SET", target }) catch unreachable;
}

test "targetRow renders the target temperature" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("SET       22.0 C", targetRow(&buf, 22.0));
}
