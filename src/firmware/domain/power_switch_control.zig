const std = @import("std");

pub const PowerState = enum { on, off };

/// Mirrors the Baker's physical on/off toggle switch into the system's
/// power state. Pure and hardware-free so it can be tested without a GPIO
/// or a board.
pub const PowerSwitch = struct {
    state: PowerState = .off,

    pub fn switchOn(self: *PowerSwitch) void {
        self.state = .on;
    }

    pub fn switchOff(self: *PowerSwitch) void {
        self.state = .off;
    }
};

test "switchOn sets the state to on" {
    var sw = PowerSwitch{};
    sw.switchOn();
    try std.testing.expectEqual(PowerState.on, sw.state);
}

test "switchOff sets the state to off" {
    var sw = PowerSwitch{};
    sw.switchOn();
    sw.switchOff();
    try std.testing.expectEqual(PowerState.off, sw.state);
}
