pub const BOOT_BLINK_COUNT: u32 = 5;
pub const BOOT_BLINK_INTERVAL_MS: u32 = 100;

pub const LedState = enum {
    off,
    on,

    pub fn toggled(self: LedState) LedState {
        return switch (self) {
            .off => .on,
            .on => .off,
        };
    }
};

// Fixed-count blink sequence used as a visual "flash succeeded" confirmation
// right after boot, before the main loop's heartbeat takes over. Pure state
// machine: the caller drives timing (e.g. time.sleep_ms) between calls to
// next().
pub const BootBlink = struct {
    remaining_toggles: u32,
    state: LedState = .off,

    pub fn init(blink_count: u32) BootBlink {
        return .{ .remaining_toggles = blink_count * 2 };
    }

    pub fn done(self: BootBlink) bool {
        return self.remaining_toggles == 0;
    }

    pub fn next(self: *BootBlink) LedState {
        self.state = self.state.toggled();
        self.remaining_toggles -= 1;
        return self.state;
    }
};
