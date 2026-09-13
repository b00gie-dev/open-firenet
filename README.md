# Open Firenet

Local WiFi bridge for RIKA pellet stoves — replaces the proprietary Firenet 2.0 cloud dongle with an ESP32-S3 that exposes a local REST API and web interface.

No cloud account. No internet dependency. Works on your LAN.

> **Disclaimer** — This project is not affiliated with or endorsed by RIKA Innovative Ofentechnik GmbH. The protocol was reverse-engineered for interoperability purposes only. Use at your own risk. No warranty of any kind is provided.

---

## What it does

RIKA stoves use a USB CDC dongle (the "Firenet 2.0" stick) to connect to RIKA's cloud. This project replaces that dongle with an ESP32-S3 that:

- Speaks the same USB CDC protocol as the original dongle
- Connects to your home WiFi
- Exposes a local web interface at `http://open-firenet.local`
- Exposes a REST API for home automation (Home Assistant, etc.)
- Stores all state locally — no external dependency

---

## Hardware

> **Tested hardware only** — This firmware has only been tested on an ESP32-S3. Other ESP32-S3 boards will likely work. The ESP32-S2 also has native USB OTG and may work but is untested. ESP32, ESP32-C3, and other variants without native USB OTG will not work.

### Required

| Part | Notes |
|---|---|
| ESP32-S3 dev board with native USB | The board must expose the S3's USB OTG pins (GPIO19/20 = D+/D−) on its USB connector. Any connector type works (USB-A, USB-C, Micro-B) as long as it is wired to the S3's native USB, not to a UART bridge chip. |
| Cable to stove | The stove has a USB-A socket. Use whatever cable or adapter connects your board's USB port to USB-A Male (e.g. USB-C to USB-A, or USB-A to USB-A). |

### How it connects

The stove acts as USB host; the ESP32-S3 acts as USB device (CDC class). The firmware registers VID `0x303A` / PID `0x819A` to match the original dongle and be recognized by the stove's firmware.

### What to look for when buying

- The board **must** have the ESP32-S3 chip (not ESP32, S2, or C3)
- The board **must** expose native USB OTG — **not** a UART bridge (CH340, CP2102, etc.)
- Check the schematic or product page: the native USB port is labeled "USB OTG", "USB", or connects to GPIO19/20; the UART port is labeled "UART", "COM", or connects to a bridge chip

---

## Flashing

### Linux (recommended)

**Requirements:** `arduino-cli`, `esptool`, ESP32 Arduino core 3.x

```bash
chmod +x flash.sh
./flash.sh                       # serial flash via /dev/ttyACM0
./flash.sh /dev/ttyACM1          # specify serial port
./flash.sh --ota 192.168.1.x     # OTA flash via WiFi (once already running)
```

The script compiles then flashes bootloader + partition table + app. The NVS partition (WiFi credentials) is **preserved** across flashes.

---

### macOS

**Requirements:** [arduino-cli](https://arduino.github.io/arduino-cli/installation/), [esptool](https://docs.espressif.com/projects/esptool/en/latest/esp32/installation.html), ESP32 Arduino core 3.x

Install dependencies via Homebrew:

```bash
brew install arduino-cli esptool
arduino-cli core install esp32:esp32
```

The serial port is named differently on macOS — find it with:

```bash
ls /dev/cu.usbmodem*
```

Then flash:

```bash
chmod +x flash.sh
./flash.sh /dev/cu.usbmodem14101   # adjust to your port
./flash.sh --ota 192.168.1.x       # or OTA if already running
```

---

### Windows

The `flash.sh` script requires a bash shell. Two options:

**Option A — WSL (Windows Subsystem for Linux)**

Install WSL2 then follow the Linux instructions above. To forward the USB serial port to WSL, use [usbipd](https://github.com/dorssel/usbipd-win):

```powershell
# In PowerShell (admin)
usbipd list                     # find the ESP32 busid
usbipd attach --wsl --busid <busid>
```

Then inside WSL:
```bash
./flash.sh /dev/ttyACM0
```

**Option B — Flash a pre-built binary with esptool**

1. Install [Python](https://python.org) and esptool:
   ```powershell
   pip install esptool
   ```
2. Download the latest `.bin` from [Releases](../../releases) (or build it on Linux/macOS).
3. Find your COM port in Device Manager (e.g. `COM4`).
4. Flash:
   ```powershell
   esptool --chip esp32s3 --port COM4 --baud 460800 `
     --before default-reset --after hard-reset `
     write-flash --flash-mode dio --flash-freq 80m --flash-size 4MB `
     0x0000 open-firenet.ino.bootloader.bin `
     0x8000 open-firenet.ino.partitions.bin `
     0x10000 open-firenet.ino.bin
   ```

> **OTA is the easiest path on Windows** — flash once via serial (Option A or B), then all subsequent updates work via `./flash.sh --ota <ip>` from any platform, or directly through the `/update` page in the browser.

---

## First boot — WiFi provisioning

On first boot (or if credentials were reset), the bridge enters **provisioning mode** with its own Wi-Fi Access Point: **`Open-Firenet-Setup`** (open network, no password).

Three ways to provision:

### Option A — Captive Portal (smartphone or PC, recommended)
1. Connect your phone or laptop to the Wi-Fi network **`Open-Firenet-Setup`**.
2. The captive portal opens automatically (or browse to `http://open-firenet.local` or `http://192.168.4.1`).
3. Select your 2.4 GHz home Wi-Fi from the scanned networks list, enter your Wi-Fi password, and click **Enregistrer / Connect**.
4. The dongle reboots, connects to your LAN, and becomes available at **`http://open-firenet.local`**.

### Option B — Stove screen (no smartphone needed)
1. On the stove panel, navigate to **Settings → WiFi** and select your network.
2. The stove transmits credentials over the USB CDC link to the bridge.
3. The bridge connects and displays the connected icon on the stove screen.

### Option C — Serial command (for lab / debugging)
Connect to the ESP32-S3 serial port (`115200 baud`):
```
SETWIFI:YourSSID:YourPassword
```

---

## Web interface

Once connected, open **`http://open-firenet.local`** in any web browser (or use the device IP assigned by your router).

- **Language selector with flags**: 🇫🇷 Français / 🇬🇧 English dropdown in the header.
- **Glassmorphism dark UI**: responsive for mobile and desktop screens.
- **Live stove status**: operational state (Standby, Ignition, Start, Regulation, Cleaning, Burnoff, Splitlog), room temperature, flame temperature, Wi-Fi signal strength.
- **Interactive controls**:
  - Power **ON / OFF** toggle
  - **Operating Mode**: Manuel, Auto (Thermostat), Confort, Réduit (Setback)
  - **Target Room Temperature**: slider 14.0°C – 28.0°C (in Confort mode)
  - **Heating Power**: slider 30% – 100% (in Manuel / Auto modes)
- **Live CDC Link Log**: collapsible console streaming USB CDC communication with the stove.
- **Restart button**: reboot the ESP32 bridge directly from the UI without unplugging.

---

## REST API V2

Open-Firenet V2 provides a clean, unified REST JSON API with natural units (temperatures in °C as floats, power as percentage integers, clean mode strings):

| Endpoint | Method | Description |
|---|---|---|
| `/api/state` | GET | **V2 Unified state**: device info, stove state, sensors, controls |
| `/api/controls` | POST | **V2 Set controls**: accepts clean JSON payload (partial updates supported) |
| `/api/restart` | POST | Software restart of the ESP32 bridge |
| `/api/status` | GET | *Legacy* status endpoint (retained for backward compatibility) |
| `/api/sensors` | GET | *Legacy* sensors endpoint (retained for backward compatibility) |
| `/api/controls` | GET | Current controls in JSON format |
| `/reset-wifi` | GET / POST | Erase Wi-Fi credentials from NVS and reboot into provisioning AP |
| `/log` | GET | Plain-text live USB CDC debug log |

### `GET /api/state` example

```json
{
  "device": {
    "status": "connected",
    "rssi": -62,
    "ip": "192.168.1.93",
    "mac": "84:FC:E6:XX:XX:XX",
    "uptime_ms": 348210
  },
  "stove": {
    "online": true,
    "state": "regulation",
    "state_code": 3,
    "igniter_on": false,
    "error_mask": 0,
    "warning_mask": 0
  },
  "sensors": {
    "room_temperature": 20.4,
    "flame_temperature": 412.0
  },
  "controls": {
    "on": true,
    "mode": "comfort",
    "power_percent": 70,
    "target_temperature": 21.0
  }
}
```

### `POST /api/controls` example

Send a JSON object with `Content-Type: application/json`. Partial updates are fully supported:

```bash
# Set target temperature to 21.0 °C in Comfort mode
curl -X POST http://open-firenet.local/api/controls \
  -H "Content-Type: application/json" \
  -d '{"target_temperature": 21.0, "mode": "comfort"}'

# Turn the stove ON at 80% power
curl -X POST http://open-firenet.local/api/controls \
  -H "Content-Type: application/json" \
  -d '{"on": true, "power_percent": 80}'
```

Supported fields:
- `on`: boolean (`true` or `false`)
- `mode`: string (`"manual"`, `"auto"`, `"comfort"`, `"setback"`)
- `power_percent`: integer (`30` – `100`)
- `target_temperature`: float in °C (`14.0` – `28.0`)

---

## Home Assistant Integration

For Home Assistant, use the official custom integration repository:  
**[openfirenet/open-firenet-ha](https://github.com/openfirenet/open-firenet-ha)**

Features:
- Single-step setup via UI Config Flow (enter `http://open-firenet.local` or IP)
- Native **Climate** entity (`climate.stove`) with target temperature, presets (`manual`, `auto`, `comfort`, `setback`), and fan power
- **11 native sensor entities**: room temperature, flame temperature, operational state, sub-state, Wi-Fi RSSI, runtime, pellet consumption, error masks
- **Binary sensors**: Stove connection, combustion active, error status
- Real-time updates via asynchronous polling of the V2 API without cloud lag

---

## License

GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later) — see [LICENSE](LICENSE)

Any derivative work, including commercial forks, must be distributed under the same license with the full source code made available.
