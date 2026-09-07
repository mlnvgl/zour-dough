const std = @import("std");

pub const MIN_TEMP: f32 = 20.0;
pub const MAX_TEMP: f32 = 30.0;
pub const DEFAULT_TEMP: f32 = 22.0;

pub const STEP: f32 = 0.5;

const R_START: u8 = 0x0;
const R_CW_FINAL: u8 = 0x1;
const R_CW_BEGIN: u8 = 0x2;
const R_CW_NEXT: u8 = 0x3;
const R_CCW_BEGIN: u8 = 0x4;
const R_CCW_FINAL: u8 = 0x5;
const R_CCW_NEXT: u8 = 0x6;

const DIR_CW: u8 = 0x10;
const DIR_CCW: u8 = 0x20;
const DIR_MASK: u8 = 0x30;
const STATE_MASK: u8 = 0x0f;

// Ben Buxton's full-step quadrature table, ported from the Arduino Rotary
// library: https://github.com/buxtronix/arduino/blob/master/libraries/Rotary/Rotary.cpp
// Background: http://www.buxtronix.net/2011/10/rotary-encoders-done-properly.html
//
// Rows are the current state, columns the freshly sampled (clk, dt) phase.
// Only a complete, correctly ordered gray-code sequence walks to a FINAL state
// and emits a direction in the high nibble; anything else drops back to
// R_START. That is what rejects contact bounce, without any timing constant:
// a bouncing contact can never do more than shuttle between adjacent states.
// The sequence rests at both pins high, which is where the internal pull-ups
// on rotary_clk and rotary_dt leave them at a detent.
const TRANSITIONS = [7][4]u8{
    .{ R_START, R_CW_BEGIN, R_CCW_BEGIN, R_START },
    .{ R_CW_NEXT, R_START, R_CW_FINAL, R_START | DIR_CW },
    .{ R_CW_NEXT, R_CW_BEGIN, R_START, R_START },
    .{ R_CW_NEXT, R_CW_BEGIN, R_CW_FINAL, R_START },
    .{ R_CCW_NEXT, R_START, R_CCW_BEGIN, R_START },
    .{ R_CCW_NEXT, R_CCW_FINAL, R_START, R_START | DIR_CCW },
    .{ R_CCW_NEXT, R_CCW_FINAL, R_CCW_BEGIN, R_START },
};

pub fn clamp(temp: f32) f32 {
    return @max(MIN_TEMP, @min(MAX_TEMP, temp));
}

pub fn adjust(target: f32, counts: i32) f32 {
    return clamp(target + @as(f32, @floatFromInt(counts)) * STEP);
}

pub const Level = enum { low, high };

fn phase(clk: Level, dt: Level) u2 {
    const hi: u2 = if (clk == .high) 0b10 else 0;
    const lo: u2 = if (dt == .high) 0b01 else 0;
    return hi | lo;
}

pub const Quadrature = struct {
    state: u8 = R_START,

    pub fn update(self: *Quadrature, clk: Level, dt: Level) i8 {
        self.state = TRANSITIONS[self.state & STATE_MASK][phase(clk, dt)];
        return switch (self.state & DIR_MASK) {
            DIR_CW => 1,
            DIR_CCW => -1,
            else => 0,
        };
    }
};

pub const Press = enum { none, pressed };

pub const Button = struct {
    last: Level = .high,

    pub fn update(self: *Button, sw: Level) Press {
        defer self.last = sw;
        return if (self.last == .high and sw == .low) .pressed else .none;
    }
};

pub fn nextTarget(current: f32, counts: i32, press: Press) f32 {
    return switch (press) {
        .pressed => DEFAULT_TEMP,
        .none => adjust(current, counts),
    };
}

test "clamp raises a temperature below the minimum to the minimum" {
    try std.testing.expectEqual(@as(f32, 20.0), clamp(3.0));
}

test "clamp lowers a temperature above the maximum to the maximum" {
    try std.testing.expectEqual(@as(f32, 30.0), clamp(40.0));
}

test "clamp keeps a temperature inside the range unchanged" {
    try std.testing.expectEqual(@as(f32, 25.0), clamp(25.0));
}

test "adjust moves the target by one step per count" {
    try std.testing.expectEqual(@as(f32, 25.0), adjust(24.0, 2));
    try std.testing.expectEqual(@as(f32, 23.0), adjust(24.0, -2));
}

test "adjust leaves the target alone for no counts" {
    try std.testing.expectEqual(@as(f32, 24.0), adjust(24.0, 0));
}

test "adjust clamps a burst of counts to the range" {
    try std.testing.expectEqual(@as(f32, 30.0), adjust(24.0, 100));
    try std.testing.expectEqual(@as(f32, 20.0), adjust(24.0, -100));
}

test "update emits one count at the end of a clockwise sequence" {
    var q = Quadrature{};
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
    try std.testing.expectEqual(@as(i8, 1), q.update(.high, .high));
}

test "update emits the opposite count for a counter-clockwise sequence" {
    var q = Quadrature{};
    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, -1), q.update(.high, .high));
}

test "update stays put while the encoder rests between detents" {
    var q = Quadrature{};
    for (0..10) |_| {
        try std.testing.expectEqual(@as(i8, 0), q.update(.high, .high));
    }
    try std.testing.expectEqual(R_START, q.state);
}

test "update rejects a contact bouncing off the detent" {
    var q = Quadrature{};
    for (0..50) |_| {
        try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
        try std.testing.expectEqual(@as(i8, 0), q.update(.high, .high));
    }
}

test "update rejects bounce partway through a sequence" {
    var q = Quadrature{};
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));

    for (0..50) |_| {
        try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
        try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    }

    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
    try std.testing.expectEqual(@as(i8, 1), q.update(.high, .high));
}

test "update emits nothing for a turn that reverses before completing" {
    var q = Quadrature{};
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .high));
}

test "update keeps emitting across consecutive detents" {
    var q = Quadrature{};
    for (0..5) |_| {
        try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
        try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
        try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
        try std.testing.expectEqual(@as(i8, 1), q.update(.high, .high));
    }
}

test "update tracks a direction reversal without emitting a stale count" {
    var q = Quadrature{};
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .high));

    try std.testing.expectEqual(@as(i8, 0), q.update(.high, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .low));
    try std.testing.expectEqual(@as(i8, 0), q.update(.low, .high));
    try std.testing.expectEqual(@as(i8, -1), q.update(.high, .high));
}

test "button reports a press on a falling edge" {
    var button = Button{};
    try std.testing.expectEqual(Press.pressed, button.update(.low));
}

test "button reports nothing while held or released" {
    var button = Button{};
    try std.testing.expectEqual(Press.pressed, button.update(.low));
    try std.testing.expectEqual(Press.none, button.update(.low));
    try std.testing.expectEqual(Press.none, button.update(.high));
    try std.testing.expectEqual(Press.none, button.update(.high));
}

test "nextTarget moves the target by one step per count" {
    try std.testing.expectEqual(@as(f32, 25.0), nextTarget(24.0, 2, .none));
    try std.testing.expectEqual(@as(f32, 23.0), nextTarget(24.0, -2, .none));
}

test "nextTarget keeps the target when nothing happened" {
    try std.testing.expectEqual(@as(f32, 24.0), nextTarget(24.0, 0, .none));
}

test "nextTarget resets to the default on a press" {
    try std.testing.expectEqual(DEFAULT_TEMP, nextTarget(28.0, 0, .pressed));
}

test "nextTarget lets a press override counts from the same tick" {
    try std.testing.expectEqual(DEFAULT_TEMP, nextTarget(28.0, 4, .pressed));
}
