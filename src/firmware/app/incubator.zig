const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const usb_cdc = @import("../platform/rp2040/transport/usb_cdc.zig");
const board = @import("../platform/rp2040/board/pico.zig");
const status_led = @import("../platform/rp2040/drivers/status_led.zig");
const timing = @import("../support/timing.zig");
const Ticker = timing.Ticker;
const Tick = timing.Tick;
const heater = @import("../platform/rp2040/drivers/heater.zig");
const heater_control = @import("../domain/heater_control.zig");
const temp_sensor = @import("../platform/rp2040/drivers/temp_sensor.zig");
const ultrasonic = @import("../platform/rp2040/drivers/ultrasonic.zig");
const power_switch = @import("../platform/rp2040/drivers/power_switch.zig");
const power_switch_control = @import("../domain/power_switch_control.zig");
const PowerSwitch = power_switch_control.PowerSwitch;
const PowerState = power_switch_control.PowerState;
const rotary = @import("../platform/rp2040/drivers/rotary.zig");
const rotary_control = @import("../domain/rotary_control.zig");
const Blink = @import("../domain/blink.zig");
const Readings = @import("../domain/readings.zig").Readings;

const Self = @This();

const DISTANCE_INTERVAL_US: u64 = 250_000;
const TELEMETRY_INTERVAL_US: u64 = 1_000_000;
const HEARTBEAT_INTERVAL_US: u64 = 500_000;

pub const Snapshot = struct {
    temp: ?f32,
    distance: ?f32,
    power: PowerState,
    counts: i32,
    press: rotary_control.Press,
};

const Ticks = struct {
    heartbeat: Tick,
    telemetry: Tick,
};

readings: *Readings,
temp_sampler: timing.Sampler = .{},
distance_ticker: Ticker = .{ .interval_us = DISTANCE_INTERVAL_US },
telemetry_ticker: Ticker = .{ .interval_us = TELEMETRY_INTERVAL_US },
heartbeat_ticker: Ticker = .{ .interval_us = HEARTBEAT_INTERVAL_US },
led_state: Blink.LedState = .off,
heater_state: heater_control.HeaterState = .power_off,
power_switch_state: PowerSwitch = .{},
button_state: rotary_control.Button = .{},

pub fn init(pins: board.Pins, readings: *Readings) !Self {
    try temp_sensor.init(pins.temp);
    temp_sensor.configure() catch |err| {
        usb_cdc.write("ds18b20 init failed: {s}\r\n", .{@errorName(err)});
    };

    ultrasonic.init(pins.ultra_sound_trigger, pins.ultra_sound_echo);
    heater.init(pins.heater);
    power_switch.init(pins.power_switch);
    rotary.init(pins.rotary_sw, pins.rotary_clk, pins.rotary_dt);

    const self = Self{ .readings = readings };
    heater.set(self.heater_state) catch |err| {
        usb_cdc.write("heater init failed: {s}\r\n", .{@errorName(err)});
    };

    return self;
}

pub fn poll(self: *Self) void {
    const now = time.get_time_since_boot().to_us();
    const ticks = Ticks{
        .heartbeat = self.heartbeat_ticker.poll(now),
        .telemetry = self.telemetry_ticker.poll(now),
    };

    const snapshot = self.sense(now);
    self.control(snapshot, now);
    self.actuate(snapshot, ticks);
}

fn sense(self: *Self, now_us: u64) Snapshot {
    self.sensePowerSwitch();
    self.senseTemp(now_us);
    self.senseDistance(now_us);

    return .{
        .temp = self.readings.freshTemp(now_us),
        .distance = self.readings.distance_cm,
        .power = self.power_switch_state.state,
        .counts = rotary.takeCounts(),
        .press = self.button_state.update(rotary.readSw()),
    };
}

fn sensePowerSwitch(self: *Self) void {
    power_switch.read(&self.power_switch_state);
}

fn senseTemp(self: *Self, now_us: u64) void {
    switch (self.temp_sampler.poll(now_us)) {
        .none => {},
        .start_conversion => temp_sensor.startConversion() catch |err| {
            usb_cdc.write("temp conversion failed: {s}\r\n", .{@errorName(err)});
        },
        .read_conversion => {
            const temp = temp_sensor.readTemperature() catch |err| {
                usb_cdc.write("temp read failed: {s}\r\n", .{@errorName(err)});
                return;
            };
            self.readings.recordTemp(temp, now_us);
        },
    }
}

fn senseDistance(self: *Self, now_us: u64) void {
    if (self.distance_ticker.poll(now_us) == .waiting) return;

    const distance_cm = ultrasonic.measure(usb_cdc.poll) catch |err| {
        usb_cdc.write("ultrasonic read failed: {s}\r\n", .{@errorName(err)});
        self.readings.recordDistanceTimeout();
        return;
    };
    self.readings.recordDistance(distance_cm);
}

fn control(self: *Self, snapshot: Snapshot, now_us: u64) void {
    self.readings.recordTarget(rotary_control.nextTarget(
        self.readings.target_temp,
        snapshot.counts,
        snapshot.press,
    ));

    self.heater_state = heater_control.decide(
        snapshot.temp,
        self.readings.target_temp,
        snapshot.power,
        self.heater_state,
        now_us,
    );
}

fn actuate(self: *Self, snapshot: Snapshot, ticks: Ticks) void {
    self.actuateHeater();
    self.actuateLed(ticks.heartbeat);
    self.report(snapshot, ticks.telemetry);
}

fn actuateHeater(self: *Self) void {
    self.readings.recordHeat(switch (self.heater_state) {
        .heating => .heating,
        else => .idle,
    });

    heater.set(self.heater_state) catch |err| {
        usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
    };
}

fn actuateLed(self: *Self, heartbeat: Tick) void {
    const mode: Blink.Mode = if (self.heater_state == .heating) .solid else .heartbeat;
    const beat: Blink.Beat = if (heartbeat == .fired) .toggle else .hold;
    const desired = Blink.desired(self.led_state, mode, beat);

    if (desired == self.led_state) return;

    self.led_state = desired;
    status_led.set(desired);
}

fn report(self: *Self, snapshot: Snapshot, telemetry: Tick) void {
    if (telemetry == .waiting) return;

    usb_cdc.write("temp: {?} dist: {?} target: {} power: {s} heater: {s}\r\n", .{
        snapshot.temp,
        snapshot.distance,
        self.readings.target_temp,
        @tagName(snapshot.power),
        @tagName(self.heater_state),
    });
}
