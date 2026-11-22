# DLG: Sprachansagen

Diese Liste ist die einzige Quelle der Ansagen. Texte immer hier ändern und dann neu erzeugen lassen
(Sprach-Sitzung, Werkzeug `~/Documents/20_RC_Modellbau/Ethos Sounds/ethos_sound.py`).
Ablage: `src/dlg/audio/de/<Dateiname>.wav` und `src/dlg/audio/en/<Dateiname>.wav`.
Format WAV A-law, mono, 16 kHz, 8 Bit. Lautstärke nicht anpassen. Folgt im Skript direkt eine Zahl, vorne und
hinten keine Stille. Vor dem Einsetzen anhören lassen.

| Dateiname | Deutsch | Englisch | Aussprache-Hinweis | Wann |
|---|---|---|---|---|
| `hoehe_alarm` | Achtung! Höhe zu hoch | Warning! Altitude too high | Zahl folgt direkt | Höhe über der Alarmschwelle, danach die Zahl |
| `hoehe_hoch` | Höhe hoch | Altitude high | Zahl folgt direkt | Höhe über der Warnschwelle (nur wenn «Warnung auch ansagen» ein) |
| `rxakku_alarm` | Achtung! Empfängerakku tief | Warning! Receiver battery low | Zahl folgt direkt | Empfänger-Akku unter der Alarmschwelle, danach die Zahl |
| `rxakku_tief` | Empfängerakku tief | Receiver battery low | Zahl folgt direkt | Empfänger-Akku unter der Warnschwelle (nur mit «Warnung auch ansagen») |
| `empfang_alarm` | Achtung! Empfang schwach | Warning! Signal weak | Zahl folgt direkt | Empfang unter der Alarmschwelle, danach die Zahl |
| `empfang_schwach` | Empfang schwach | Signal weak | Zahl folgt direkt | Empfang unter der Warnschwelle (nur mit «Warnung auch ansagen») |
| `telemetrie_weg` | Telemetrie verloren | Telemetry lost | – | Telemetrie war da und ist weg (nur mit «Warnung auch ansagen») |
| `wurfhoehe` | Wurfhöhe | Launch height | Zahl folgt direkt (Meter) | Nach jedem Wurf, danach die Höhe |
| `flugzeit` | Flugzeit | Flight time | Zahl folgt direkt (Sekunden) | Nach der Landung, danach die Flugzeit |
| `arbeitszeit_start` | Arbeitszeit läuft | Working time started | – | F3K: Arbeitszeit gestartet |
| `arbeitszeit` | Noch | Remaining | Zahl folgt direkt (Minuten) | F3K: jede volle Minute der Arbeitszeit |
| `arbeitszeit_ende` | Arbeitszeit vorbei | Working time over | – | F3K: Arbeitszeit abgelaufen |
| `zielzeit` | Zielzeit | Target time | Zahl folgt direkt (Sekunden) | F3K Poker: Zielzeit beim Wurf festgelegt |
| `flugphase` | Flugphase | Flight mode | Zahl folgt direkt | Phasenwechsel, wenn der Name zu keiner festen Ansage passt |
| `phase_start` | Start | Launch | – | Phasenwechsel in eine Phase mit «Start» oder «Launch» im Namen |
| `phase_zoom` | Zoom | Zoom | englisch aussprechen | Phasenwechsel, Name enthält «Zoom» |
| `phase_speed` | Speed | Speed | englisch aussprechen | Phasenwechsel, Name enthält «Speed» oder «Schnell» |
| `phase_thermik` | Thermik | Thermal | – | Phasenwechsel, Name enthält «Therm» |
| `phase_strecke` | Strecke | Cruise | – | Phasenwechsel, Name enthält «Strecke», «Cruise» oder «Reise» |
| `phase_landung` | Landung | Landing | – | Phasenwechsel, Name enthält «Land» |
| `phase_normal` | Normal | Normal | – | Phasenwechsel, Name enthält «Normal» |

Die Countdown-Zahlen der letzten 10 s der Arbeitszeit spricht Ethos selbst (Zahlenansage, keine Datei).
Fehlt eine Datei, spielt das Skript einen Ton.
