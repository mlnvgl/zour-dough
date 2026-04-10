# Zour-Dough: Zig-Powered Enviroment for your sour dough starter

## Pre-requisites


## Hardware

- IRLZ44N N-Kanal MOSFET Transistor 55V 47A 3 Polig TO-220AB IRLZ44NPBF Transistoren

## Development

1. Zig build
2. Flash
    - install picotool via ``` brew install picotool ``` which is neccessary for flashing process
    - run ``` zig run tools/flash.zig ```

3. Start serial loggers
    - open new terminal
    - run ``` zig run tools/serial-logger.zig ```
