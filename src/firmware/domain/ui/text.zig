const std = @import("std");

pub const SPLASH_TOP: [16]u8 = "Zour-Dough      ".*;
pub const SPLASH_VER: [16]u8 = "v2026.09.12     ".*;

pub fn temp_row(buf: *[16]u8, temp: ?f32) []const u8 {
    if (temp) |t| {
        return std.fmt.bufPrint(buf, "{s:<4}{d:>10.1} C", .{ "NOW", t }) catch unreachable;
    }

    return std.fmt.bufPrint(buf, "{s:<4}{s:>10}  ", .{ "NOW", "---" }) catch unreachable;
}

test "tempRow renders the current temperature right-aligned" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("NOW       24.5 C", temp_row(&buf, 24.5));
}

test "tempRow renders --- before the first successful read" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("NOW        ---  ", temp_row(&buf, null));
}

pub fn distance_row(buf: *[16]u8, cm: ?f32) []const u8 {
    if (cm) |c| {
        return std.fmt.bufPrint(buf, "{s:<4}{d:>9.0} cm", .{ "DIST", c }) catch unreachable;
    }

    return std.fmt.bufPrint(buf, "{s:<4}{s:>9}   ", .{ "DIST", "---" }) catch unreachable;
}

test "distanceRow renders whole centimeters" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("DIST       12 cm", distance_row(&buf, 12.4));
}

test "distanceRow renders --- after a timeout" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("DIST      ---   ", distance_row(&buf, null));
}

pub fn status_row(buf: *[16]u8, heating: bool) []const u8 {
    return std.fmt.bufPrint(buf, "{s:^16}", .{if (heating) "HEATING" else "READY"}) catch unreachable;
}

test "statusRow centers HEATING while heating" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("    HEATING     ", status_row(&buf, true));
}

test "statusRow centers READY while idle" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("     READY      ", status_row(&buf, false));
}

pub fn target_row(buf: *[16]u8, target: f32) []const u8 {
    return std.fmt.bufPrint(buf, "{s:<4}{d:>10.1} C", .{ "SET", target }) catch unreachable;
}

test "targetRow renders the target temperature" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("SET       22.0 C", target_row(&buf, 22.0));
}
