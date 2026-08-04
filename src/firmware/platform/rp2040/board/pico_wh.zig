const rp2xxx = @import("microzig").hal;

pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO22 = .{ .name = "temp", .direction = .in, .pull = .up },
    .GPIO21 = .{ .name = "heater", .direction = .out, .pull = .down },
    .GPIO20 = .{ .name = "ultra_sound_trigger", .direction = .out, .pull = .down },
    .GPIO19 = .{ .name = "ultra_sound_echo", .direction = .in, .pull = .down },
    // Baker's physical on/off toggle switch. Wired to ground, so pull-up
    // reads .low on the pin when the switch is on.
    .GPIO18 = .{ .name = "power_switch", .direction = .in, .pull = .up },
};

pub const Pins = @TypeOf(pin_config.apply());

pub fn apply() Pins {
    return pin_config.apply();
}
