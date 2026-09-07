from machine import Pin, I2C, time_pulse_us
import ssd1306
import onewire
import ds18x20
import time


# ========================================
# OLED
# ========================================

i2c = I2C(
    0,
    sda=Pin(0),
    scl=Pin(1),
    freq=400000
)

oled = ssd1306.SSD1306_I2C(128, 64, i2c)


# ========================================
# Startup screen
# ========================================

oled.fill(0)
oled.text("Zour-Dough", 20, 18)
oled.text("v2026.09.12", 16, 34)
oled.show()

time.sleep(2)


# ========================================
# DS18B20
# DATA -> GP16
# ========================================

ow = onewire.OneWire(Pin(16))
ds = ds18x20.DS18X20(ow)

sensors = ds.scan()

if not sensors:
    oled.fill(0)
    oled.text("ERROR", 0, 0)
    oled.text("No temp sensor", 0, 16)
    oled.show()
    raise Exception("No DS18B20 found")


# ========================================
# Rotary encoder
#
# SW  -> GP13
# CLK -> GP14
# DT  -> GP15
# ========================================

sw = Pin(13, Pin.IN, Pin.PULL_UP)
clk = Pin(14, Pin.IN, Pin.PULL_UP)
dt = Pin(15, Pin.IN, Pin.PULL_UP)


# ========================================
# HC-SR04
#
# TRIG -> GP10
# ECHO -> GP11
# ========================================

trig = Pin(10, Pin.OUT)
echo = Pin(11, Pin.IN)


# ========================================
# Pico onboard LED
# ========================================

led = Pin(25, Pin.OUT)


# ========================================
# Settings
# ========================================

target_temp = 22.0

MIN_TEMP = 5.0
MAX_TEMP = 35.0
STEP = 0.5

HYSTERESIS = 0.2


# ========================================
# State
# ========================================

current_temp = 0.0
distance_cm = -1

heating = False

last_clk = clk.value()
last_sw = sw.value()

temp_conversion_running = False
temp_conversion_start = 0
last_temp_read = 0

last_distance_read = 0

last_animation = 0
animation_frame = 0

last_display_update = 0


# Minimal heat animation
heat_frames = [
    "~~~",
    "^^^",
    "~~~",
    "___"
]


# ========================================
# Start first temperature conversion
# ========================================

ds.convert_temp()
temp_conversion_running = True
temp_conversion_start = time.ticks_ms()


# ========================================
# Main loop
# ========================================

while True:

    now = time.ticks_ms()


    # ------------------------------------
    # Rotary encoder
    # ------------------------------------

    current_clk = clk.value()

    if current_clk != last_clk:

        if current_clk == 0:

            if dt.value() != current_clk:
                target_temp += STEP
            else:
                target_temp -= STEP

            target_temp = max(
                MIN_TEMP,
                min(MAX_TEMP, target_temp)
            )

    last_clk = current_clk


    # ------------------------------------
    # Encoder button
    # Reset target to 22 C
    # ------------------------------------

    current_sw = sw.value()

    if last_sw == 1 and current_sw == 0:
        target_temp = 22.0

    last_sw = current_sw


    # ------------------------------------
    # DS18B20 temperature
    # ------------------------------------

    if temp_conversion_running:

        if time.ticks_diff(now, temp_conversion_start) >= 750:

            current_temp = ds.read_temp(sensors[0])

            temp_conversion_running = False
            last_temp_read = now

    else:

        if time.ticks_diff(now, last_temp_read) >= 250:

            ds.convert_temp()

            temp_conversion_running = True
            temp_conversion_start = now


    # ------------------------------------
    # Ultrasonic sensor
    # ------------------------------------

    if time.ticks_diff(now, last_distance_read) >= 250:

        trig.value(0)
        time.sleep_us(2)

        trig.value(1)
        time.sleep_us(10)
        trig.value(0)

        duration = time_pulse_us(
            echo,
            1,
            30000
        )

        if duration > 0:
            distance_cm = duration / 58.0
        else:
            distance_cm = -1

        last_distance_read = now


    # ------------------------------------
    # Heating logic
    # ------------------------------------

    if heating:

        if current_temp >= target_temp + HYSTERESIS:
            heating = False

    else:

        if current_temp <= target_temp - HYSTERESIS:
            heating = True


    # LED follows heating state
    led.value(1 if heating else 0)


    # ------------------------------------
    # Heat animation
    # ------------------------------------

    if time.ticks_diff(now, last_animation) >= 150:

        animation_frame += 1

        if animation_frame >= len(heat_frames):
            animation_frame = 0

        last_animation = now


    # ------------------------------------
    # OLED UI
    # ------------------------------------

    if time.ticks_diff(now, last_display_update) >= 80:

        oled.fill(0)


        # Current temperature
        oled.text("NOW", 0, 2)

        oled.text(
            "{:.1f} C".format(current_temp),
            48,
            2
        )


        # Heat animation
        if heating:
            oled.text(
                heat_frames[animation_frame],
                104,
                2
            )


        # Target temperature
        oled.text("SET", 0, 18)

        oled.text(
            "{:.1f} C".format(target_temp),
            48,
            18
        )


        # Distance
        oled.text("DIST", 0, 34)

        if distance_cm >= 0:

            oled.text(
                "{:.0f} cm".format(distance_cm),
                48,
                34
            )

        else:

            oled.text(
                "---",
                48,
                34
            )


        # Separator
        oled.hline(
            0,
            50,
            128,
            1
        )


        # Status
        if heating:

            oled.text(
                "HEATING",
                64,
                54
            )

        else:

            oled.text(
                "READY",
                80,
                54
            )


        oled.show()

        last_display_update = now


    # Keep loop responsive
    time.sleep_ms(2)
