# Versionen von DLG

Die Versionsnummer steht in `src/dlg/main.lua` (`local VERSION`). Sie ist dieselbe in der Anleitung, im
Paket für die Suite und hier. Der oberste Abschnitt erscheint in der FrSky Suite als Versionshinweis.

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
