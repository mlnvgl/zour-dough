# zour-dough

This is a project about sour dough.

The purpose of this project is to build a system that keeps sour dough at a temperature of 28 degree celsius to build the perfect environment for the grow of the lactic acid bacteria.

# The Software

This is a mono repository containing currently two solutions

- micro-python for the implementation in python
- micro-zig for the implementation with zig

They both shall fulfill the exact same use case.
The main reason to have two different solutions are:

- difficulties to implement everything in Zig, because of low-level code challenges
- experience in python and availability of reference projects and support for many drivers for different sensors.

# The Hardware

Following sensors and hardware is used

- Temperature Sensor DS18B20
- Temperature Sensor DHT22
- Raspberry Pico RP2040
- Raspberry Pico RP2035
