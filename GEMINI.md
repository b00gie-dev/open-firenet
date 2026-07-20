# Project Rules: Open Firenet Firmware

## 1. Project Context
This project provides firmware for ESP32-S3 boards to replace the proprietary RIKA Firenet 2.0 cloud dongle, enabling local control of RIKA pellet stoves via REST API and a web interface.

## 2. Standards
- **Language**: C++ (Arduino/PlatformIO)
- **Framework**: ESP32 Arduino core 3.x
- **Development**: Use `arduino-cli` or PlatformIO.

## 3. Project-Specific Notes
- **Hardware**: ESP32-S3 with native USB OTG is required.
- **Protocol**: Reverse-engineered USB CDC protocol.
