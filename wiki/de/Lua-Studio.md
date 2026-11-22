# Lua-Studio

Mit [Lua-Studio](https://github.com/Raffi1202/lua-studio) stellst du die Seite FLUG am PC zusammen (Werte, Anordnung, Grenzen) und überträgst sie auf den Sender. Ohne Studio-Datei zeigt DLG seine eigene Seite FLUG. Die Seiten F3K und STARTS ändert das Studio nicht.

## Ein Layout für alle Modelle

In Lua-Studio beim Übertragen «Für alle Modelle (Standard)» wählen. Die Datei heisst dann `Standard.dlg.lua` und gilt für jedes Modell ohne eigene Datei. Reihenfolge: 1. Wahl im Menü «Studio-Layout», 2. Datei des Modells (Modellname.dlg.lua, z. B. `Segler_A.dlg.lua`), 3. `Standard.dlg.lua`, 4. eingebaute Seite. Im Menü erscheint der Eintrag «Standard (alle Modelle)»; «automatisch» zeigt in Klammern, was gerade gilt. Änderungen im Menü am Sender gelten nur für das aktuelle Modell. Heisst ein Modell selbst «Standard», gilt die Datei als seine Modelldatei.
