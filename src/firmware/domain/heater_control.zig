const std = @import("std");
const PowerState = @import("./power_switch_control.zig").PowerState;

pub const HeaterState = enum { on, off };

pub const TEMP_THRESHOLD_MIN: f32 = 25.0;
pub const TEMP_THRESHOLD_MAX: f32 = 28.0;

/// Pure bang-bang decision: given the current temperature, the Baker's
/// power switch state, and the heater's current state, decide its next
/// state. Hardware-free so it can be tested without a GPIO or a board.
pub fn decide(temp: f32, power_state: PowerState, current: HeaterState) HeaterState {
    if (power_state == .off) return .off;
    if (temp <= TEMP_THRESHOLD_MIN) return .on;
    if (temp >= TEMP_THRESHOLD_MAX) return .off;
    return current;
}

test "decide turns heater on at or below the min threshold" {
    try std.testing.expectEqual(HeaterState.on, decide(TEMP_THRESHOLD_MIN, .on, .off));
    try std.testing.expectEqual(HeaterState.on, decide(TEMP_THRESHOLD_MIN - 1, .on, .off));
}

test "decide turns heater off at or above the max threshold" {
    try std.testing.expectEqual(HeaterState.off, decide(TEMP_THRESHOLD_MAX, .on, .on));
    try std.testing.expectEqual(HeaterState.off, decide(TEMP_THRESHOLD_MAX + 1, .on, .on));
}

test "decide holds the current state between thresholds" {
    const mid = (TEMP_THRESHOLD_MIN + TEMP_THRESHOLD_MAX) / 2;
    try std.testing.expectEqual(HeaterState.on, decide(mid, .on, .on));
    try std.testing.expectEqual(HeaterState.off, decide(mid, .on, .off));
}

test "decide forces heater off when the power switch is off regardless of temp" {
    try std.testing.expectEqual(HeaterState.off, decide(TEMP_THRESHOLD_MIN - 1, .off, .on));
}
