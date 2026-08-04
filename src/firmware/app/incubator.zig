const rp2xxx = @import("microzig").hal;
const time = rp2xxx.time;
const usb_cdc = @import("../platform/rp2040/transport/usb_cdc.zig");
const board = @import("../platform/rp2040/board/pico_wh.zig");
const status_led = @import("../platform/rp2040/drivers/status_led.zig");
const Ticker = @import("../support/ticker.zig").Ticker;
const heater = @import("../platform/rp2040/drivers/heater.zig");
const heater_control = @import("../domain/heater_control.zig");
const temp_sensor = @import("../platform/rp2040/drivers/temp_sensor.zig");
const ultrasonic = @import("../platform/rp2040/drivers/ultrasonic.zig");
const power_switch = @import("../platform/rp2040/drivers/power_switch.zig");
const PowerSwitch = @import("../domain/power_switch_control.zig").PowerSwitch;

const Self = @This();

ticker: Ticker,
heater_state: heater_control.HeaterState = .off,
power_switch_state: PowerSwitch = .{},

pub fn init(pins: board.Pins, tick_interval_us: u64) !Self {
    try temp_sensor.init(pins.temp);
    temp_sensor.configure() catch |err| {
        usb_cdc.write("ds18b20 init failed: {s}\r\n", .{@errorName(err)});
    };

    ultrasonic.init(pins.ultra_sound_trigger, pins.ultra_sound_echo);

    heater.init(pins.heater);
    power_switch.init(pins.power_switch);

    const self = Self{ .ticker = .{ .interval_us = tick_interval_us } };
    heater.set(self.heater_state) catch |err| {
        usb_cdc.write("heater init failed: {s}\r\n", .{@errorName(err)});
    };

    return self;
}

// Reads the power switch every call (cheap, no cadence needed), then runs a
// full sense/decide/act cycle whenever the ticker says it's time.
pub fn poll(self: *Self) void {
    power_switch.read(&self.power_switch_state);

    const now = time.get_time_since_boot().to_us();
    if (!self.ticker.ready(now)) return;

    self.runCycle();
}

fn runCycle(self: *Self) void {
    status_led.toggle();

    const temp = temp_sensor.read() catch |err| {
        usb_cdc.write("temp read failed: {s}\r\n", .{@errorName(err)});
        return;
    };
    usb_cdc.write("temp: {}\r\n", .{temp});

    self.heater_state = heater_control.decide(temp, self.power_switch_state.state, self.heater_state);
    heater.set(self.heater_state) catch |err| {
        usb_cdc.write("heater write failed: {s}\r\n", .{@errorName(err)});
        return;
    };

    usb_cdc.write("power: {s}\r\n", .{@tagName(self.power_switch_state.state)});
    usb_cdc.write("heater: {s}\r\n", .{@tagName(self.heater_state)});

    time.sleep_ms(100);

    const distance_cm = ultrasonic.measure(usb_cdc.poll) catch |err| {
        usb_cdc.write("ultrasonic read failed: {s}\r\n", .{@errorName(err)});
        return;
    };
    usb_cdc.write("distance_cm: {}\r\n", .{distance_cm});
}
