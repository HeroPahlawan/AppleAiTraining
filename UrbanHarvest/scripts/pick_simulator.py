#!/usr/bin/env python3
"""Print the UDID of an available iPhone simulator on the newest iOS runtime.

Usage:  xcrun simctl list devices available -j | python3 scripts/pick_simulator.py
"""

import json
import re
import sys

devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
            if best is None or version > best[0]:
                best = (version, device["udid"])

if best is None:
    sys.exit("No available iPhone simulator found")
print(best[1])
