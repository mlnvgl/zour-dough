const std = @import("std");

pub const Readings = struct {
    current_temp: ?f32 = null,

    distance_cm: ?f32 = null,
    heat: Heat = .idle,

    pub fn recordTemp(self: *Readings, temp: f32) void {
        self.current_temp = temp;
    }

    pub fn recordDistance(self: *Readings, cm: f32) void {
        self.distance_cm = cm;
    }

    pub fn recordDistanceTimeout(self: *Readings) void {
        self.distance_cm = null;
    }

    pub fn recordHeat(self: *Readings, heat: Heat) void {
        self.heat = heat;
    }
};

pub const Heat = enum { idle, heating };

test "recordHeat stores the heat state" {
    var readings: Readings = .{};
    readings.recordHeat(.heating);
    try std.testing.expectEqual(Heat.heating, readings.heat);
    readings.recordHeat(.idle);
    try std.testing.expectEqual(Heat.idle, readings.heat);
}

test "recordDistanceTimeout clears the distance" {
    var readings: Readings = .{};
    readings.recordDistance(12.4);
    readings.recordDistanceTimeout();
    try std.testing.expectEqual(@as(?f32, null), readings.distance_cm);
}

test "recordDistance stores the distance" {
    var readings: Readings = .{};
    readings.recordDistance(12.4);
    try std.testing.expectEqual(@as(?f32, 12.4), readings.distance_cm);
}

test "recordTemp stores the temperature" {
    var readings: Readings = .{};
    readings.recordTemp(24.5);
    try std.testing.expectEqual(@as(?f32, 24.5), readings.current_temp);
}
