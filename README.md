# DLG – flight display for discus launch gliders (FrSky Ethos)

**English** · [Deutsch](README.de.md) · Documentation: [Wiki (English)](wiki/en/Installation.md) · [Wiki (Deutsch)](wiki/de/Installation.md)

> **Configure on your PC with [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – arrange the FLIGHT page, choose values and limits, then transfer to the radio.

**DLG** is an Ethos widget (full screen) for discus launch gliders (DLG, F3K) on FrSky radios with a colour display. It shows the active flight mode large and in colour, measures the launch height of every launch, keeps a launch list and helps with all F3K tasks with working time, announcements and score. Display, menu and voice in German and English.

| FLIGHT page | F3K | Launch list |
|---|---|---|
| ![FLIGHT](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2019%20Englisch%20Alarm.png) | ![F3K](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2020%20Englisch%20F3K.png) | ![LAUNCHES](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2012%20Seite%20STARTS.png) |

- **Flight mode**: name from Ethos, colour per mode, announced by name on change (Launch, Zoom, Speed, Thermal, Cruise, Landing, Normal).
- **Launch height**: highest point until the end of the launch; end selectable: automatic, switch off (e.g. snapflap) or leaving a flight mode. Announced.
- **F3K**: all tasks A–N according to FAI Sporting Code Vol. F3 (2025), working time with announcements, score, poker with target times, round survives power off.
- **Launch list**: last 50 launches with launch height and flight time, best value, every entry deletable.
- **Vario** as display only (no vario tone, no thermal hint), altitude, receiver battery and link with warning and alarm.

## Quick start

1. Download `DLG-<version>-share.zip` from the latest release and unzip it.
2. In FrSky Suite install the package `DLG-<version>.zip` (or copy the folder `dlg` to `scripts/` on the SD card).
3. Model › Displays › full screen › widget «DLG». The sensors are assigned automatically.

Manual: [Deutsch (PDF)](docs/DLG%20-%20Anleitung.pdf) · [English (PDF)](docs/DLG%20-%20Manual.pdf)

## Radios and test status

| Display | Radios | Status |
|---|---|---|
| 800 × 480, touch | X20 series, X18R, X18RS | simulator; test on a real X18RS follows |
| 640 × 360, no touch | Twin X14, X14S | simulator only |
| 480 × 320, touch | X18, X18S, X18SE, Twin X Lite | simulator only |
| 480 × 272, no touch | X10, X12 (Ethos) | simulator only |

Not yet tested: a real flight, real sensors, installation through Suite.

## Development

Mac tests with Lua 5.4:

```sh
luac -p src/dlg/*.lua
lua test/wertung-test.lua .          # F3K score (examples from the rules) and flight mode names
```

The flows `test/*.json` are meant for a simulator driver based on the Ethos WASM simulator; that driver, the random test and the package scripts belong to the author's build kit and are not part of this repo.

## Support

This project is free. If you would like to support the work, you can do so via PayPal: https://paypal.me/Raffi1202. Thank you!

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).

## Related projects

| Project | |
|---|---|
| [Glider](https://github.com/Raffi1202/glider-lua) | Ethos widget for gliders (vario, thermals) |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC program to configure the Luas |
