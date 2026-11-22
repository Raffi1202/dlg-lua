# Versionen von DLG

Die Versionsnummer steht in `src/dlg/main.lua` (`local VERSION`). Sie ist dieselbe in der Anleitung, im
Paket für die Suite und hier. Der oberste Abschnitt erscheint in der FrSky Suite als Versionshinweis.

## 0.3.1 (22.11.2026)

- Nach «reload SCRIPTS» ruft Ethos die Widget-Funktionen auch ohne Widget auf: kein Fehler mehr im Log.
- F3K-Runde: wird sofort beim Start, beim Ende und bei der Landung gesichert (nicht mehr alle 30 s); nach Neuladen
  erscheint «Runde fortsetzen?». Skriptdateien und Daten werden über den Ordner des Skripts geladen.
- Sensorsuche: RX-Akku nimmt nicht mehr «Empf.» (zweiter RSSI-Wert), sondern «Empf.-Batt.» (AppID 0xF104); Höhe
  (0x0100) und Vario (0x0110) werden über die AppID zugewiesen.

*EN: After «reload SCRIPTS» no more errors in the log (callbacks without widget). F3K round is saved at start, end and
landing and offers «Resume round?» after reload. Scripts and data load via the script folder. Sensor search: RX battery
no longer picks «Empf.» (second RSSI value) but 0xF104; altitude 0x0100 and vario 0x0110 assigned by AppID.*

## 0.3.0 (22.11.2026)

- Ein Layout für alle Modelle: `Standard.dlg.lua` gilt für jedes Modell ohne eigene Studio-Datei (gesucht an
  denselben Orten). Reihenfolge: Wahl im Menü, Datei des Modells, Standard, eingebaute Seite.
- Menü «Studio-Layout»: Eintrag «Standard (alle Modelle)», «automatisch» zeigt in Klammern, was gerade gilt.
- Änderungen am Sender (`.funke.lua`) bleiben pro Modell, auch mit Standard-Layout. Info-Datei: `studioWahl`
  «standard». Update ohne Verlust (kein neues Speicherformat).

*EN: One layout for all models: `Standard.dlg.lua` applies to every model without its own studio file. Order: menu
choice, model file, default, built-in page. Menu entry «Default (all models)», «automatic» shows what applies. Radio
changes stay per model.*

## 0.2.0 (22.11.2026)

- Flugphasen werden mit Namen angesagt (Start, Zoom, Speed, Thermik, Strecke, Landung, Normal; erkannt am Namen der
  Ethos-Flugphase, deutsch und englisch), je Phase im Menü wählbar: automatisch, festes Wort oder aus.
- F3K Poker (E) mit Zielzeiten (−/+, W = Ende Arbeitszeit) und Wertung nach Reglement.
- Laufende F3K-Runde übersteht das Ausschalten: Rückfrage «Runde fortsetzen?».
- Sprachansagen deutsch und englisch (21 Dateien je Sprache).
- Lua-Studio-Format 2 (ohne Symbole): eigene Ansicht der Seite FLUG, Grenzen, Vorlagen.
- Anleitung (deutsch, englisch), Wiki, README englisch und deutsch, Lizenz GPL-3.0.

## 0.1.0 (22.11.2026)

- Erste Fassung (Etappe 1): Seiten FLUG (Flugphase als farbiges Band, Flugzeit, Wurfhöhe mit Bestwert, Vario nur als
  Anzeige, Höhe, Empfänger-Akku, Empfang), F3K (alle Aufgaben A–N nach FAI SC4 Vol F3 2025, Arbeitszeit mit Ansagen,
  Wertung) und STARTS (letzte 50 Starts, jeder einzeln löschbar, alle löschen).
- Start und Landung automatisch oder per Schalter; Wurf endet automatisch, bei «Schalter aus» (z. B. Snapflap) oder beim
  Verlassen einer Flugphase.
