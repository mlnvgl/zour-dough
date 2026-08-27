const std = @import("std");
const PowerState = @import("./power_switch_control.zig").PowerState;

pub const HeaterState = union(enum) {
    /// Forced off by the Baker's power switch, not by a control decision.
    power_off,
    /// Off by control decision: at/above the max threshold, or holding
    /// between thresholds.
    idle,
    /// Heating; records when this heating stint started.
    heating: struct { since_us: u64 },
};

pub const TEMP_THRESHOLD_MIN: f32 = 25.0;
pub const TEMP_THRESHOLD_MAX: f32 = 28.0;

/// Pure bang-bang decision: given the current temperature, the Baker's
/// power switch state, and the heater's current state, decide its next
/// state. `now_us` only timestamps new heating stints; hardware-free so it
/// can be tested without a GPIO or a board.
pub fn decide(temp: f32, power_state: PowerState, current: HeaterState, now_us: u64) HeaterState {
    return switch (power_state) {
        .off => .power_off,
        .on => {
            if (temp <= TEMP_THRESHOLD_MIN) return switch (current) {
                // Already heating: keep the original start of this stint.
                .heating => current,
                else => .{ .heating = .{ .since_us = now_us } },
            };
            if (temp >= TEMP_THRESHOLD_MAX) return .idle;
            return switch (current) {
                // Power is back on but nothing demands heat yet.
                .power_off => .idle,
                else => current,
            };
        },
    };
}

test "decide starts heating at or below the min threshold" {
    try std.testing.expectEqual(
        HeaterState{ .heating = .{ .since_us = 100 } },
        decide(TEMP_THRESHOLD_MIN, .on, .idle, 100),
    );
    try std.testing.expectEqual(
        HeaterState{ .heating = .{ .since_us = 200 } },
        decide(TEMP_THRESHOLD_MIN - 1, .on, .power_off, 200),
    );
}

test "decide goes idle at or above the max threshold" {
    const current = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(HeaterState.idle, decide(TEMP_THRESHOLD_MAX, .on, current, 100));
    try std.testing.expectEqual(HeaterState.idle, decide(TEMP_THRESHOLD_MAX + 1, .on, current, 100));
}

test "decide holds the current state between thresholds" {
    const mid = (TEMP_THRESHOLD_MIN + TEMP_THRESHOLD_MAX) / 2;
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(heating, decide(mid, .on, heating, 100));
    try std.testing.expectEqual(HeaterState.idle, decide(mid, .on, .idle, 100));
}

test "decide treats a held power_off as idle once power is back on" {
    const mid = (TEMP_THRESHOLD_MIN + TEMP_THRESHOLD_MAX) / 2;
    try std.testing.expectEqual(HeaterState.idle, decide(mid, .on, .power_off, 100));
}

test "decide keeps the original stint start when temp stays below min" {
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(heating, decide(TEMP_THRESHOLD_MIN - 1, .on, heating, 100));
}

test "decide forces heater off when the power switch is off regardless of temp" {
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(HeaterState.power_off, decide(TEMP_THRESHOLD_MIN - 1, .off, heating, 100));
}
