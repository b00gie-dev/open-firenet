#!/usr/bin/env python3
"""Poll the bridge's /api/state and log every observed value change.

Flattens the whole state (raw_sensors, status, sensors_pos, controls_pos included)
and diffs it against the previous poll. Known-volatile fields (radio noise, uptime,
frame counters, free heap) are ignored by default since they change constantly and
carry no diagnostic signal.

Usage:
    python3 watch_sensors.py [--host 192.168.1.93] [--interval 3] [--log changes.log]
                              [--ignore key1,key2,...] [--no-default-ignore]
"""
import argparse
import json
import sys
import time
import urllib.request
from datetime import datetime, timezone

DEFAULT_IGNORE = {
    "device.wifi_rssi", "device.uptime_seconds", "device.free_heap",
    "uptime_seconds", "frames_in", "frames_out",
    "raw_sensors.rssi", "status.rssi",
    "sensors.room_temperature",  # duplicate of raw_sensors.roomTemp, noisy at the decimal
}


def flatten(d, prefix=""):
    out = {}
    for k, v in d.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            out.update(flatten(v, key + "."))
        elif isinstance(v, list):
            for i, item in enumerate(v):
                out[f"{key}[{i}]"] = item
        else:
            out[key] = v
    return out


def fetch(host, timeout=5):
    with urllib.request.urlopen(f"http://{host}/api/state", timeout=timeout) as r:
        return json.loads(r.read())


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="192.168.1.93")
    ap.add_argument("--interval", type=float, default=3.0, help="seconds between polls")
    ap.add_argument("--log", default="sensor_changes.log")
    ap.add_argument("--ignore", default="", help="comma-separated extra keys to ignore")
    ap.add_argument("--no-default-ignore", action="store_true",
                     help="don't apply the built-in noisy-field ignore list")
    args = ap.parse_args()

    ignore = set() if args.no_default_ignore else set(DEFAULT_IGNORE)
    if args.ignore:
        ignore |= {k.strip() for k in args.ignore.split(",") if k.strip()}

    print(f"Watching {args.host} every {args.interval}s, logging to {args.log}")
    print(f"Ignoring: {sorted(ignore)}")

    last = None
    logf = open(args.log, "a", buffering=1)

    while True:
        try:
            state = fetch(args.host)
            flat = flatten(state)
        except Exception as e:
            ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
            print(f"{ts}  [error] {e}", file=sys.stderr)
            time.sleep(args.interval)
            continue

        if last is not None:
            for key in sorted(set(flat) | set(last)):
                if key in ignore:
                    continue
                # sensors_pos/controls_pos are transient positional arrays whose
                # LENGTH varies cycle to cycle (the stove only echoes "dirty"
                # fields) — diffing them index-by-index is pure noise; the same
                # values are already tracked, stably, via the named raw_sensors map.
                if key.startswith("sensors_pos[") or key.startswith("controls_pos["):
                    continue
                old = last.get(key)
                new = flat.get(key)
                if old != new:
                    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
                    line = f"{ts}  {key}: {old!r} -> {new!r}"
                    print(line)
                    logf.write(line + "\n")

        last = flat
        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
