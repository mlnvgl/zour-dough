const rp2xxx = @import("microzig").hal;

pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO0 = .{ .name = "oled_sda", .direction = .in, .pull = .up },
    .GPIO1 = .{ .name = "oled_scl", .direction = .in, .pull = .up },
    .GPIO16 = .{ .name = "temp", .direction = .in, .pull = .up },
    .GPIO21 = .{ .name = "heater", .direction = .out, .pull = .down },
    .GPIO10 = .{ .name = "ultra_sound_trigger", .direction = .out, .pull = .down },
    .GPIO11 = .{ .name = "ultra_sound_echo", .direction = .in, .pull = .down },
    // Baker's physical on/off toggle switch. Wired to ground, so pull-up
    // reads .low on the pin when the switch is on.
    .GPIO18 = .{ .name = "power_switch", .direction = .in, .pull = .up },
    .GPIO13 = .{ .name = "rotary_sw", .direction = .in, .pull = .up },
    .GPIO14 = .{ .name = "rotary_clk", .direction = .in, .pull = .up },
    .GPIO15 = .{ .name = "rotary_dt", .direction = .in, .pull = .up },
    .GPIO25 = .{ .name = "status_led", .direction = .out, .pull = .down },
};

pub const Pins = @TypeOf(pin_config.apply());

pub fn apply() Pins {
    return pin_config.apply();
}
