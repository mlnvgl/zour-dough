const std = @import("std");
const rotary_control = @import("./rotary_control.zig");

pub const MAX_TEMP_AGE_US: u64 = 3_000_000;

pub const Readings = struct {
    current_temp: ?f32 = null,
    temp_read_at_us: u64 = 0,

    distance_cm: ?f32 = null,
    heat: Heat = .idle,
    target_temp: f32 = rotary_control.DEFAULT_TEMP,

    pub fn recordTemp(self: *Readings, temp: f32, now_us: u64) void {
        self.current_temp = temp;
        self.temp_read_at_us = now_us;
    }

    pub fn freshTemp(self: Readings, now_us: u64) ?f32 {
        const temp = self.current_temp orelse return null;
        if (now_us - self.temp_read_at_us > MAX_TEMP_AGE_US) return null;
        return temp;
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

    pub fn recordTarget(self: *Readings, temp: f32) void {
        self.target_temp = temp;
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

test "recordTarget stores the target temperature" {
    var readings: Readings = .{};
    readings.recordTarget(24.0);
    try std.testing.expectEqual(@as(f32, 24.0), readings.target_temp);
}

test "recordTemp stores the temperature" {
    var readings: Readings = .{};
    readings.recordTemp(24.5, 0);
    try std.testing.expectEqual(@as(?f32, 24.5), readings.current_temp);
}

test "freshTemp returns null before the first reading" {
    const readings: Readings = .{};
    try std.testing.expectEqual(@as(?f32, null), readings.freshTemp(1_000_000));
}

test "freshTemp returns the reading up to the maximum age" {
    var readings: Readings = .{};
    readings.recordTemp(24.5, 1_000_000);
    try std.testing.expectEqual(@as(?f32, 24.5), readings.freshTemp(1_000_000));
    try std.testing.expectEqual(@as(?f32, 24.5), readings.freshTemp(1_000_000 + MAX_TEMP_AGE_US));
}

test "freshTemp returns null once the reading is too old" {
    var readings: Readings = .{};
    readings.recordTemp(24.5, 1_000_000);
    try std.testing.expectEqual(@as(?f32, null), readings.freshTemp(1_000_000 + MAX_TEMP_AGE_US + 1));
}

test "freshTemp goes stale and comes back with a new reading" {
    var readings: Readings = .{};
    readings.recordTemp(24.5, 1_000_000);

    const stale_at = 1_000_000 + MAX_TEMP_AGE_US + 1;
    try std.testing.expectEqual(@as(?f32, null), readings.freshTemp(stale_at));

    readings.recordTemp(25.0, stale_at);
    try std.testing.expectEqual(@as(?f32, 25.0), readings.freshTemp(stale_at));
}
