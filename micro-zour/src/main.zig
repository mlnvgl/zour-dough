const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

// DHT22 Driver
const DHT22Error = error{
    Timeout,
    Checksum,
    NoResponse,
};

const DHT22Reading = struct {
    temperature: f32,
    humidity: f32,
};

fn DHT22(comptime PinType: type) type {
    return struct {
        pin: PinType,

        fn wait_for_level(pin: PinType, level: u1, timeout_us: u32) DHT22Error!void {
            var elapsed: u32 = 0;
            while (pin.read() != level) {
                if (elapsed >= timeout_us) return DHT22Error.Timeout;
                time.sleep_us(1);
                elapsed += 1;
            }
        }

        fn measure_high_us(pin: PinType, timeout_us: u32) DHT22Error!u32 {
            var elapsed: u32 = 0;
            while (pin.read() == 1) {
                if (elapsed >= timeout_us) return DHT22Error.Timeout;
                time.sleep_us(1);
                elapsed += 1;
            }
            return elapsed;
        }

        pub fn init(pin: PinType) @This() {
            return .{ .pin = pin };
        }

        pub fn read(self: @This()) !DHT22Reading {
            var data: [5]u8 = .{ 0, 0, 0, 0, 0 };

            // Send start signal (DHT22: >1ms low, then release)
            self.pin.set_direction(.out);
            self.pin.put(0);
            time.sleep_us(1000); // 1ms low
            self.pin.put(1);

            // Briefly keep line high before switching to input
            time.sleep_us(30);

            // Switch to input
            self.pin.set_direction(.in);

            // Wait for sensor response: 80us low, then 80us high
            wait_for_level(self.pin, 0, 200) catch return DHT22Error.NoResponse;
            wait_for_level(self.pin, 1, 200) catch return DHT22Error.Timeout;
            wait_for_level(self.pin, 0, 200) catch return DHT22Error.Timeout;

            // Read 40 bits
            for (0..40) |bit_idx| {
                // Each bit: 50us low, then high pulse (26-28us for 0, ~70us for 1)
                wait_for_level(self.pin, 1, 100) catch return DHT22Error.Timeout;
                const pulse_duration = measure_high_us(self.pin, 100) catch return DHT22Error.Timeout;

                // If pulse is longer than ~40us, it's a 1 bit, otherwise 0
                const byte_idx = bit_idx / 8;
                const bit_pos = 7 - (bit_idx % 8);

                if (pulse_duration > 40) {
                    data[byte_idx] |= (@as(u8, 1) << @intCast(bit_pos));
                } else {
                    data[byte_idx] &= ~(@as(u8, 1) << @intCast(bit_pos));
                }
            }

            // Verify checksum
            const checksum = data[0] +% data[1] +% data[2] +% data[3];
            if (checksum != data[4]) {
                return DHT22Error.Checksum;
            }

            // Parse temperature and humidity
            const humidity_int = data[0];
            const humidity_dec = data[1];
            const temp_int = data[2];
            const temp_dec = data[3];

            const humidity = @as(f32, @floatFromInt(humidity_int)) +
                @as(f32, @floatFromInt(humidity_dec)) / 100.0;

            const temp_raw = @as(f32, @floatFromInt(temp_int)) +
                @as(f32, @floatFromInt(temp_dec)) / 100.0;
            const temperature = if ((data[2] & 0x80) != 0) -temp_raw else temp_raw;

            return .{
                .temperature = temperature,
                .humidity = humidity,
            };
        }
    };
}

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
