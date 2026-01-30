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

        pub fn init(pin: PinType) @This() {
            return .{ .pin = pin };
        }

        pub fn read(self: @This()) !DHT22Reading {
            var data: [5]u8 = undefined;

            // Send start signal
            self.pin.set_direction(.out);
            self.pin.put(0);
            time.sleep_us(1000); // 1ms low
            self.pin.put(1);

            // Switch to input
            self.pin.set_direction(.in);

            // Wait for sensor response (pull low)
            var timeout: u32 = 0;
            while (self.pin.read() == 1 and timeout < 100000) {
                time.sleep_us(1);
                timeout += 1;
            }

            if (timeout >= 100000) {
                return DHT22Error.NoResponse;
            }

            // Wait for sensor to release (pull high)
            timeout = 0;
            while (self.pin.read() == 0 and timeout < 100000) {
                time.sleep_us(1);
                timeout += 1;
            }

            if (timeout >= 100000) {
                return DHT22Error.Timeout;
            }

            // Read 40 bits
            for (0..40) |bit_idx| {
                // Wait for data bit (sensor pulls low)
                timeout = 0;
                while (self.pin.read() == 1 and timeout < 100000) {
                    time.sleep_us(1);
                    timeout += 1;
                }

                if (timeout >= 100000) {
                    return DHT22Error.Timeout;
                }

                // Measure duration of high pulse
                timeout = 0;
                while (self.pin.read() == 0 and timeout < 100000) {
                    time.sleep_us(1);
                    timeout += 1;
                }

                if (timeout >= 100000) {
                    return DHT22Error.Timeout;
                }

                // Measure high pulse duration
                var pulse_duration: u32 = 0;
                while (self.pin.read() == 1 and pulse_duration < 100000) {
                    time.sleep_us(1);
                    pulse_duration += 1;
                }

                // If pulse is longer than ~30us, it's a 1 bit, otherwise 0
                const byte_idx = bit_idx / 8;
                const bit_pos = 7 - (bit_idx % 8);

                if (pulse_duration > 30) {
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
};

const pins = pin_config.pins();

pub fn main() !void {
    pin_config.apply();

    const DHT22Sensor = DHT22(@TypeOf(pins.dht22));
    var sensor = DHT22Sensor.init(pins.dht22);

    while (true) {
        pins.led.toggle();

        if (sensor.read()) |reading| {
            // Successfully read sensor
            // reading.temperature and reading.humidity contain the values
            _ = reading;

            // Blink LED rapidly on success
            time.sleep_ms(100);
            pins.led.toggle();
            time.sleep_ms(100);
        } else |_| {
            // Handle error - slow blink on error
            time.sleep_ms(500);
        }

        time.sleep_ms(1500); // DHT22 needs ~2 seconds between reads
    }
}
