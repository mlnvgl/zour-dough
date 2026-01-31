const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub const DHT22Error = error{
    Timeout,
    Checksum,
    NoResponse,
};

pub const DHT22Reading = struct {
    temperature: f32,
    humidity: f32,
};

pub fn DHT22(comptime PinType: type) type {
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
