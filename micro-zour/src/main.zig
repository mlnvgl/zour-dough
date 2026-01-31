const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const dht22 = @import("dht22.zig");
const DHT22 = dht22.DHT22;

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
    .GPIO22 = .{
        .name = "dht22",
        .direction = .in,
    },
    .GPIO12 = .{
        .name = "heater",
        .direction = .out,
    },
};

const pins = pin_config.pins();

// Temperature control constants
const MAX_TEMP: f32 = 25.0; // Celsius - turn heater off
const MIN_TEMP: f32 = 23.9; // Celsius - turn heater on
const CHECK_INTERVAL_MS: u32 = 2000; // Milliseconds between checks

// Most MOSFET modules are active-low (GPIO low = ON). Set to true if yours is active-high.
const HEATER_ACTIVE_HIGH: bool = false;

fn set_heater(on: bool) void {
    const pin_level: u1 = if (on == HEATER_ACTIVE_HIGH) @as(u1, 1) else @as(u1, 0);
    pins.heater.put(pin_level);
}

pub fn main() !void {
    pin_config.apply();

    // Default safe state: heater OFF
    set_heater(false);

    const DHT22Sensor = DHT22(@TypeOf(pins.dht22));
    var sensor = DHT22Sensor.init(pins.dht22);
    var heater_is_on: bool = false; // Track if heater is on

    while (true) {
        if (sensor.read()) |reading| {
            // Successfully read sensor

            // Temperature control logic with hysteresis
            if (reading.temperature >= MAX_TEMP) {
                heater_is_on = false; // Turn OFF
            } else if (reading.temperature <= MIN_TEMP) {
                heater_is_on = true; // Turn ON
            }
            // If between MIN_TEMP and MAX_TEMP, keep previous state

            // Apply heater state
            set_heater(heater_is_on);

            // Success: 3 rapid blinks (easy to count)
            for (0..3) |_| {
                pins.led.put(1);
                time.sleep_ms(150);
                pins.led.put(0);
                time.sleep_ms(150);
            }

            // Pause before next read
            time.sleep_ms(CHECK_INTERVAL_MS);
        } else |_| {
            // Error: 1 long slow blink (1s on, 1s off)
            heater_is_on = false; // Turn off heater on error
            set_heater(false);
            pins.led.put(1);
            time.sleep_ms(1000);
            pins.led.put(0);
            time.sleep_ms(1000);
        }
    }
}
