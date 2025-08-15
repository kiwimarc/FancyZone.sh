# FancyZone.sh

A lightweight, Bash-based, FancyZones-inspired window snapping helper for X11.  
Hold a custom modifier key + left mouse button, move the pointer over a zone, release — the active window snaps there. No remembering chains of keyboard shortcuts; just a spatial drag-and-release workflow similar to what you were used to on Windows.

> Status: Prototype (4 fixed zones on the primary monitor).  
> Not affiliated with Microsoft or PowerToys. “FancyZone.sh” is an independent reimplementation idea for Linux/X11.

---

## Quick Demo (Placeholder)

Coming soon:
```text
[GIF: Drag with modifier → zone highlight → snap]
```

---

## Motivation

I wanted the comfort of FancyZones on Linux without:
- Switching to a full tiling window manager.
- Memorizing multiple shortcut sequences.
- Writing a heavy daemon in a compiled language (at first).

So FancyZone.sh grew out of a simple Bash + xdotool + xinput loop, aiming for:
1. Zero WM-specific dependencies.
2. Easy first-run setup (pick keyboard, pick mouse, press key).
3. A natural “modifier + drag + release” zone selection model.

---

## Features (Current Prototype)

- Custom modifier key selection (captured from your actual keyboard device).
- Mouse + modifier drag interaction (no grid overlay yet).
- Four predefined zones on primary display:
  - Left 25%
  - Middle 50%
  - Top-right (upper half of rightmost 25%)
  - Bottom-right (lower half of rightmost 25%)
- Automatic unmaximize/fullscreen removal before snapping (multi-strategy).
- Decoration-aware sizing using xwininfo (adjusts for border + title).
- Optional width/height offsets (e.g., panels/docks) with persistence.
- Test mode: spawns four xterms, one in each zone, then exits.
- Pure Bash + standard X11 CLI tools.

---

## Planned / Roadmap

Planned evolution toward a more “FancyZones” feel:

| Phase | Goal |
|-------|------|
| P1 | Config file upgrade: arbitrary zone definitions (percent or absolute). |
| P2 | Multi-monitor support; per-monitor zone sets. |
| P3 | GUI / visual editor (likely Python + GTK or web UI) to drag & resize zones. |
| P4 | Overlay highlight while dragging (semi-transparent zone preview). |
| P5 | Event-driven backend using XInput2 (no 100ms polling). |
| P6 | Hot reload (SIGHUP or socket) of config. |
| P7 | Profiles (work / coding / media). |
| P8 | Packaging + systemd user service + .desktop autostart. |

Have more ideas? Open an issue.

---

## Requirements

Install these packages (names shown for Debian/Ubuntu and openSUSE):

| Tool | Purpose | Debian/Ubuntu | openSUSE |
|------|---------|---------------|------|
| bash | Shell runtime | (core) | (core) |
| xdotool | Window move/resize/query | `xdotool` | `xdotool` |
| wmctrl | Window state management | `wmctrl` | `wmctrl` |
| xinput | Raw device polling | `xinput` | `xorg-xinput` |
| jq | JSON config parsing | `jq` | `jq` |
| xwininfo | Decoration metrics | `x11-utils` | `xorg-xwininfo` |
| xrandr | Monitor geometry | `x11-xserver-utils` | `xorg-xrandr` |
| xterm | Test mode sample windows | `xterm` | `xterm` |
| (optional) zenity/yad | Future simple GUI | `zenity` | `zenity` |

Debian/Ubuntu:
```bash
sudo apt install xdotool wmctrl xinput jq x11-utils x11-xserver-utils xterm
```

openSUSE:
```bash
sudo zypper install xdotool wmctrl xorg-xinput jq xorg-xwininfo xorg-xrandr xterm
```

---

## Installation

```bash
git clone https://github.com/kiwimarc/FancyZone.sh
cd FancyZone.sh
chmod +x fancyzone.sh
```

---

## First Run

Run with debug to see what’s happening:

```bash
./fancyzone.sh --debug
```

You’ll be prompted to:
1. Choose a keyboard device (listed via xinput).
2. Press the modifier key you want to use.
3. Choose a mouse device.
4. Press left mouse button (for detection sanity check).

A config file is created at:
```
~/.config/fancyzone-config.json
```

---

## Usage

Basic run (in background):
```bash
./fancyzone.sh &
```

Flags:
- `--debug` : Verbose logging.
- `--test` : Launch one xterm in each zone, then exit.
- `--width-offset N` : Shrink usable width by N pixels (e.g., left panel).
- `--height-offset N` : Shrink usable height by N pixels (e.g., top bar).
- `--save-config` : Persist current offsets to the JSON config, then exit.

Example (set and save offsets):
```bash
./fancyzone.sh --width-offset 8 --height-offset 32 --save-config
```

Then just run normally (offsets now stored):
```bash
./fancyzone.sh &
```

---

## Interaction Model

1. Make a window active (focus it normally).
2. Hold the chosen modifier key AND hold the left mouse button.
3. Move the pointer around the primary screen:
   - Crossing zone boundaries (internally) updates which zone is “armed.”
4. Release either the key or button:
   - The active window (captured at combo start) snaps into the last zone hovered.

Notes:
- Current prototype only considers the primary monitor.
- The window chosen is the focused one at the moment both inputs first become pressed.

---


## Similar / Related Tools

- PowerToys FancyZones (Windows)
- gTile (GNOME)
- Pop Shell (Pop!_OS)

---

## Future GUI Thoughts

- Minimal start: Python + GTK canvas for zone rectangles; writes JSON and signals daemon to reload.
- Advanced: Live translucent overlay highlighting target zone while dragging.
- Potential extension: Profile switching via tray icon (e.g., python + GtkStatusIcon or libappindicator).

---

## Configuration (Prototype Version)

`~/.config/fancyzone-config.json`:

```json
{
  "keyboard_id": 12,
  "keycode": 64,
  "key_name": "Alt_L",
  "mouse_id": 9,
  "width_offset": 0,
  "height_offset": 0
}
```

Future (planned) richer schema (illustrative DRAFT):

```json
{
  "version": 2,
  "input": {
    "keyboard_id": 12,
    "keycode": 64,
    "key_name": "Alt_L",
    "mouse_id": 9,
    "activation": {
      "mouse_button": 1,
      "mode": "hold"        // future: "toggle"
    }
  },
  "screen": {
    "primary_only": true,
    "width_offset": 0,
    "height_offset": 30
  },
  "zones": [
    { "id": "left", "label": "Left", "x_pct": 0,  "y_pct": 0,  "w_pct": 25, "h_pct": 100 },
    { "id": "middle", "label": "Middle", "x_pct": 25, "y_pct": 0, "w_pct": 50, "h_pct": 100 },
    { "id": "top_right", "label": "Top Right", "x_pct": 75, "y_pct": 0,  "w_pct": 25, "h_pct": 50 },
    { "id": "bottom_right", "label": "Bottom Right", "x_pct": 75, "y_pct": 50, "w_pct": 25, "h_pct": 50 }
  ],
  "ui": {
    "overlay": false,
    "overlay_opacity": 0.25,
    "overlay_color": "#3d7bff"
  }
}
```

---

## Autostart Options

### 1. systemd (User Service)

Install the provided user service file:

```bash
mkdir -p ~/.config/systemd/user
cp contrib/fancyzone.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now fancyzone.service
```

Check status:
```bash
systemctl --user status fancyzone.service
```

### 2. Desktop Autostart (.desktop)

```bash
mkdir -p ~/.config/autostart
cp contrib/fancyzone.desktop ~/.config/autostart/
```

Adjust Exec path inside if you renamed or relocated the script.

---

## Troubleshooting

| Symptom | Possible Cause | Fix |
|---------|----------------|-----|
| Window doesn’t move | WM blocks external moves | Try different WM or disable special constraints |
| Snaps but wrong size | Inaccurate decoration detection | Adjust offsets manually or tweak defaults in script |
| High-ish CPU (still low) | Poll loop every 100ms | Future event-driven backend |
| No zone snap on release | Mouse left primary monitor | Keep pointer inside primary until release |
| Key never detected in setup | Picked wrong keyboard device | Re-run after removing config file |

Remove config to re-run setup:
```bash
rm ~/.config/fancyzone-config.json
```

---

## Contributing

Until a formal CONTRIBUTING.md exists:
1. Open an issue describing feature / bug.
2. Include:
   - WM / desktop environment
   - Output of: `xrandr --listmonitors`
   - Debug log snippet (`--debug` run)
3. For PRs: keep changes modular (one feature per PR).

Planned issue labels:
- enhancement
- bug
- good first issue
- help wanted
- roadmap-phase-X

---

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License.  
You may obtain a copy of the License in the `LICENSE` file or at:

    http://www.apache.org/licenses/LICENSE-2.0


Suggested attribution line:
"Includes FancyZone.sh © 2025 Marc Cummings"

---

## Disclaimer

FancyZone.sh is an independent open-source project inspired by the FancyZones feature of Microsoft PowerToys. It is not endorsed by or affiliated with Microsoft.

---