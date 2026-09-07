const std = @import("std");

// Non-blocking interval timer: fires once enough time has elapsed since the
// last fire. Pure logic, no hardware/time dependency — the caller supplies
// "now" (e.g. from time.get_time_since_boot().to_us()) and drives its own
// polling loop.
pub const Tick = enum { waiting, fired };

pub const Ticker = struct {
    interval_us: u64,
    last_fired_us: ?u64 = null,

    pub fn poll(self: *Ticker, now_us: u64) Tick {
        if (self.last_fired_us) |last| {
            if (now_us - last < self.interval_us) return .waiting;
        }
        self.last_fired_us = now_us;
        return .fired;
    }
};

pub const CONVERSION_US: u64 = 750_000;
pub const SAMPLE_INTERVAL_US: u64 = 250_000;

pub const Command = enum { none, start_conversion, read_conversion };

pub const Sampler = struct {
    due_us: u64 = 0,
    converting: bool = false,

    pub fn poll(self: *Sampler, now_us: u64) Command {
        if (now_us < self.due_us) return .none;

        if (self.converting) {
            self.converting = false;
            self.due_us = now_us + SAMPLE_INTERVAL_US;
            return .read_conversion;
        }

        self.converting = true;
        self.due_us = now_us + CONVERSION_US;
        return .start_conversion;
    }
};

test "poll fires once the interval has elapsed and not before" {
    var ticker = Ticker{ .interval_us = 100 };
    try std.testing.expectEqual(Tick.fired, ticker.poll(0));
    try std.testing.expectEqual(Tick.waiting, ticker.poll(99));
    try std.testing.expectEqual(Tick.fired, ticker.poll(100));
    try std.testing.expectEqual(Tick.waiting, ticker.poll(199));
    try std.testing.expectEqual(Tick.fired, ticker.poll(200));
}

const BOOT_US: u64 = 1_200_000;

test "poll starts a conversion on the first call" {
    var sampler: Sampler = .{};
    try std.testing.expectEqual(Command.start_conversion, sampler.poll(BOOT_US));
}

test "poll does nothing while the conversion is in flight" {
    var sampler: Sampler = .{};
    _ = sampler.poll(BOOT_US);
    try std.testing.expectEqual(Command.none, sampler.poll(BOOT_US + 1));
    try std.testing.expectEqual(Command.none, sampler.poll(BOOT_US + CONVERSION_US - 1));
}

test "poll reads the result once the conversion time has elapsed" {
    var sampler: Sampler = .{};
    _ = sampler.poll(BOOT_US);
    try std.testing.expectEqual(Command.read_conversion, sampler.poll(BOOT_US + CONVERSION_US));
}

test "poll waits the sample interval before starting the next conversion" {
    var sampler: Sampler = .{};
    _ = sampler.poll(BOOT_US);
    const read_at = BOOT_US + CONVERSION_US;
    _ = sampler.poll(read_at);
    try std.testing.expectEqual(Command.none, sampler.poll(read_at + SAMPLE_INTERVAL_US - 1));
}

test "poll starts the next conversion after the sample interval" {
    var sampler: Sampler = .{};
    _ = sampler.poll(BOOT_US);
    const read_at = BOOT_US + CONVERSION_US;
    _ = sampler.poll(read_at);
    try std.testing.expectEqual(Command.start_conversion, sampler.poll(read_at + SAMPLE_INTERVAL_US));
}

test "poll issues each command only once for the same instant" {
    var sampler: Sampler = .{};
    try std.testing.expectEqual(Command.start_conversion, sampler.poll(BOOT_US));
    try std.testing.expectEqual(Command.none, sampler.poll(BOOT_US));

    const read_at = BOOT_US + CONVERSION_US;
    try std.testing.expectEqual(Command.read_conversion, sampler.poll(read_at));
    try std.testing.expectEqual(Command.none, sampler.poll(read_at));
}
