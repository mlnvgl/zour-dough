const std = @import("std");
const microzig = @import("microzig");
const rp = microzig.hal;
const DS18B20 = @import("../drivers/DS18B20.zig").DS18B20;

const HEATER_PIN = rp.pins.p15;
const HEATER_ACTIVE_HIGH = false; // Set to true if HIGH turns the heater ON, false if LOW turns it ON

const SENSOR_PIN = rp.pins.p22;

const TEMP_MIN = 20.0;
const TEMP_MAX = 25.0;

var gpa = rp.gpa;
var timer = rp.timer;

pub fn main() !void {
    rp.init();
    timer.init();

    // --- Heater setup ---
    const heater_pin = rp.gpio.init(HEATER_PIN, .{ .mode = .output });
    defer heater_pin.deinit();

    // --- Sensor setup ---
    const sensor_io = rp.gpio.init(SENSOR_PIN, .{ .mode = .input });
    defer sensor_io.deinit();

    var sensor = try DS18B20.init(&sensor_io, &timer);

    // --- Main loop ---
    while (true) {
        // It's good practice to reset the bus before each command
        if (sensor.reset()) |_| {
            // 1. Tell the sensor to start converting the temperature.
            //    We use `skip_rom` because we only have one sensor on the bus.
            try sensor.convert_t(null);

            // 2. Wait for the conversion to complete.
            //    For 12-bit resolution (the default), this can take up to 750ms.
            timer.sleep_ms(800);

            // 3. Reset again before reading the result.
            if (sensor.reset()) |_| {
                // 4. Read the temperature.
                const temp = try sensor.read_temperature(null);
                std.log.info("Current temperature: {d:.2}°C", .{temp});

                // 5. Control the heater based on the temperature.
                if (temp < TEMP_MIN) {
                    set_heater(true);
                    std.log.info("Temperature below {d:.1}°C. Turning heater ON", .{TEMP_MIN});
                } else if (temp > TEMP_MAX) {
                    set_heater(false);
                    std.log.info("Temperature above {d:.1}°C. Turning heater OFF", .{TEMP_MAX});
                }
            } else {
                std.log.err("DS18B20 sensor not found after conversion.", .{});
            }
        } else {
            std.log.err("DS18B20 sensor not found before conversion.", .{});
        }

        timer.sleep_ms(2000);
    }
}

fn set_heater(on: bool) void {
    const heater_pin = rp.gpio.get_pin(HEATER_PIN);
    if (on) {
        heater_pin.put(if (HEATER_ACTIVE_HIGH) .high else .low);
    } else {
        heater_pin.put(if (HEATER_ACTIVE_HIGH) .low else .high);
    }
}
