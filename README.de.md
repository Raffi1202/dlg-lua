# DLG – Flug-Anzeige für Wurfgleiter (FrSky Ethos)

[English](README.md) · **Deutsch** · Dokumentation: [Wiki (English)](wiki/en/Installation.md) · [Wiki (Deutsch)](wiki/de/Installation.md)

> **Am PC einrichten mit [Lua-Studio](https://github.com/Raffi1202/lua-studio)** – Seite FLUG anordnen, Werte und Grenzen wählen, dann auf den Sender übertragen.

**DLG** ist ein Ethos-Widget (Vollbild) für Wurfgleiter (DLG, F3K) auf FrSky-Sendern mit Farbdisplay. Es zeigt die aktive Flugphase gross und farbig, misst die Wurfhöhe jedes Starts, führt eine Startliste und hilft bei allen F3K-Aufgaben mit Arbeitszeit, Ansagen und Wertung. Anzeige, Menü und Ansagen deutsch und englisch.

| Seite FLUG | F3K | Startliste |
|---|---|---|
| ![FLIGHT](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2004%20Normal.png) | ![F3K](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2010%20Seite%20F3K%20Runde%20laeuft.png) | ![LAUNCHES](docs/bilder-simulator/DLG%20-%20Sim%20800x480%2012%20Seite%20STARTS.png) |

- **Flugphase**: Name aus Ethos, Farbe je Phase, Ansage beim Wechsel mit Namen (Start, Zoom, Speed, Thermik, Strecke, Landung, Normal).
- **Wurfhöhe**: höchster Punkt bis zum Wurf-Ende; Ende wählbar: automatisch, Schalter aus (z. B. Snapflap) oder Flugphase verlassen. Wird angesagt.
- **F3K**: alle Aufgaben A–N nach FAI Sporting Code Vol. F3 (2025), Arbeitszeit mit Ansagen, Wertung, Poker mit Zielzeiten, Runde übersteht das Ausschalten.
- **Startliste**: letzte 50 Starts mit Wurfhöhe und Flugzeit, Bestwert, jeder Eintrag einzeln löschbar.
- **Vario** nur als Anzeige (kein Vario-Ton, kein Thermik-Hinweis), Höhe, Empfänger-Akku und Empfang mit Warnung und Alarm.

## Schnellstart

1. Aus dem neusten Release `DLG-<version>-share.zip` laden und entpacken.
2. In der FrSky Suite das Paket `DLG-<version>.zip` installieren (oder Ordner `dlg` nach `scripts/` kopieren).
3. Modell › Bildschirme › Vollbild › Widget «DLG». Die Sensoren werden automatisch zugewiesen.

Anleitung: [Deutsch (PDF)](docs/DLG%20-%20Anleitung.pdf) · [English (PDF)](docs/DLG%20-%20Manual.pdf)

## Sender und Teststand

| Display | Sender | Status |
|---|---|---|
| 800 × 480, Berührung | X20 Reihe, X18R, X18RS | Simulator; Sendertest an der X18RS folgt |
| 640 × 360, ohne Berührung | Twin X14, X14S | nur Simulator |
| 480 × 320, Berührung | X18, X18S, X18SE, Twin X Lite | nur Simulator |
| 480 × 272, ohne Berührung | X10, X12 (Ethos) | nur Simulator |

Noch nicht getestet: echter Flug, echte Sensoren, Installation über die Suite.

## Entwicklung

Mac-Tests mit Lua 5.4:

```sh
luac -p src/dlg/*.lua
lua test/wertung-test.lua .          # F3K Wertung (Beispiele aus dem Reglement) und Phasennamen
```

Die Abläufe `test/*.json` sind für einen Simulator-Treiber auf Basis des Ethos-WASM-Simulators gedacht; Treiber, Zufallstest und Paket-Skripte gehören zum Werkzeugkasten des Autors und liegen nicht in diesem Repo.

## Lizenz

GPL-3.0-or-later, siehe [LICENSE](LICENSE).

## Verwandte Projekte

| Projekt | |
|---|---|
| [Glider](https://github.com/Raffi1202/glider-lua) | Ethos-Widget für Segler (Vario, Thermik) |
| [Lua-Studio](https://github.com/Raffi1202/lua-studio) | PC-Programm zum Einrichten der Luas |
