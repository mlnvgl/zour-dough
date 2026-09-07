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

pub const HYSTERESIS: f32 = 0.2;

/// Pure bang-bang decision: given the current temperature, the target
/// temperature, the Baker's power switch state, and the heater's current
/// state, decide its next state. `temp` is null before the first successful
/// read. `now_us` only timestamps new heating stints; hardware-free so it can
/// be tested without a GPIO or a board.
pub fn decide(temp: ?f32, target: f32, power_state: PowerState, current: HeaterState, now_us: u64) HeaterState {
    return switch (power_state) {
        .off => .power_off,
        .on => {
            // No reading yet: never heat blind.
            const t = temp orelse return .idle;

            if (t <= target - HYSTERESIS) return switch (current) {
                // Already heating: keep the original start of this stint.
                .heating => current,
                else => .{ .heating = .{ .since_us = now_us } },
            };
            if (t >= target + HYSTERESIS) return .idle;
            return switch (current) {
                // Power is back on but nothing demands heat yet.
                .power_off => .idle,
                else => current,
            };
        },
    };
}

const TARGET: f32 = 22.0;
const HEAT_BELOW: f32 = TARGET - HYSTERESIS;
const STOP_ABOVE: f32 = TARGET + HYSTERESIS;

test "decide starts heating at or below target minus hysteresis" {
    try std.testing.expectEqual(
        HeaterState{ .heating = .{ .since_us = 100 } },
        decide(HEAT_BELOW, TARGET, .on, .idle, 100),
    );
    try std.testing.expectEqual(
        HeaterState{ .heating = .{ .since_us = 200 } },
        decide(HEAT_BELOW - 1, TARGET, .on, .power_off, 200),
    );
}

test "decide goes idle at or above target plus hysteresis" {
    const current = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(HeaterState.idle, decide(STOP_ABOVE, TARGET, .on, current, 100));
    try std.testing.expectEqual(HeaterState.idle, decide(STOP_ABOVE + 1, TARGET, .on, current, 100));
}

test "decide holds the current state inside the hysteresis band" {
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(heating, decide(TARGET, TARGET, .on, heating, 100));
    try std.testing.expectEqual(HeaterState.idle, decide(TARGET, TARGET, .on, .idle, 100));
}

test "decide treats a held power_off as idle once power is back on" {
    try std.testing.expectEqual(HeaterState.idle, decide(TARGET, TARGET, .on, .power_off, 100));
}

test "decide keeps the original stint start when temp stays below the band" {
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(heating, decide(HEAT_BELOW - 1, TARGET, .on, heating, 100));
}

test "decide never heats without a temperature reading" {
    try std.testing.expectEqual(HeaterState.idle, decide(null, TARGET, .on, .idle, 100));

    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(HeaterState.idle, decide(null, TARGET, .on, heating, 100));
}

test "decide forces heater off when the power switch is off regardless of temp" {
    const heating = HeaterState{ .heating = .{ .since_us = 50 } };
    try std.testing.expectEqual(HeaterState.power_off, decide(HEAT_BELOW - 1, TARGET, .off, heating, 100));
}
