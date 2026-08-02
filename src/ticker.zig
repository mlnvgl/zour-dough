// Non-blocking interval timer: fires once enough time has elapsed since the
// last fire. Pure logic, no hardware/time dependency — the caller supplies
// "now" (e.g. from time.get_time_since_boot().to_us()) and drives its own
// polling loop.
pub const Ticker = struct {
    interval_us: u64,
    last_fired_us: u64 = 0,

    pub fn ready(self: *Ticker, now_us: u64) bool {
        if (now_us - self.last_fired_us < self.interval_us) return false;
        self.last_fired_us = now_us;
        return true;
    }
};
