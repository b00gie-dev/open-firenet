# Project Rules: Open Firenet Firmware

## 1. Project Context
This project provides firmware for ESP32-S3 boards to replace the proprietary RIKA Firenet 2.0 cloud dongle, enabling local control of RIKA pellet stoves via REST API and a web interface.

## 2. Standards
@../.gemini/rules/shared_cpp.md

## 3. Project-Specific Notes
- **Framework**: ESP32 Arduino core 3.x
- **Hardware**: ESP32-S3 with native USB OTG is required (for USB CDC to the stove).
- **Protocol**: Reverse-engineered USB CDC protocol — see `PROTOCOL.md` for the wire format, confirmed against the DOMO vendor app.
- **Structure**: single-file firmware (`open-firenet/open-firenet.ino`); build/flash via `flash.sh` (serial or `--ota <ip>`).
- **No CI**: this project has no automated build/test workflow today (see `shared_cpp.md` §7) — verify changes by flashing and observing device behavior.
