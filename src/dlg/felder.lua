-- DLG: Liste aller Einstellungen (für Menü, Werkwerte und Speicher). Wird nur bei Bedarf geladen und wieder
-- freigegeben. Eine Einstellung steht nur hier: Menü, Prüfung und Speichern richten sich nach dieser Liste.
-- Art: q = Quelle (Sensor, Kanal, Schalter), z = Zahl, b = Ja/Nein, w = Auswahl.
-- Jeder Text steht in zwei Sprachen: { "deutsch", "english" }. Ein einfacher Text gilt für beide.
-- q: { name, "q", Text }
-- z: { name, "z", Text, Werkwert, min, max, Kommastellen, Einheit, Schritt }. Zahlen mit Kommastellen sind als ganze
--    Zahl gespeichert (Kommastellen 1: 110 bedeutet 11,0).
-- b: { name, "b", Text, Werkwert }
-- w: { name, "w", Text, Werkwert, { { "Text", 1 }, { "Text", 2 } } }
-- Grenzwerte stehen ab Werk auf 0 = aus (keine erfundenen Zahlen); der User stellt sie im Widget-Menü ein.
local M = {}
M.DIR = ""   -- Ordner des Skripts, setzt kern.lua beim Laden (Daten liegen in <Ordner>/daten/)

local FARBEN = { { { "Grau", "Grey" }, 1 }, { { "Grün", "Green" }, 2 }, { { "Blau", "Blue" }, 3 }, { { "Gelb", "Yellow" }, 4 },
  { { "Lila", "Purple" }, 5 }, { { "Türkis", "Teal" }, 6 }, { { "Rosa", "Pink" }, 7 }, { { "Weiss", "White" }, 8 } }

-- Ansage je Flugphase: automatisch (Name der Phase), eine feste Ansage oder aus. Reihenfolge wie PHASEN in kern.lua.
local PANS = { { { "automatisch", "automatic" }, 0 }, { { "Start", "Launch" }, 1 }, { "Zoom", 2 }, { "Speed", 3 },
  { { "Thermik", "Thermal" }, 4 }, { { "Strecke", "Cruise" }, 5 }, { { "Landung", "Landing" }, 6 }, { "Normal", 7 },
  { { "aus", "off" }, 8 } }

-- F3K-Aufgaben nach FAI Sporting Code Volume F3, Ausgabe 2025 (F3K.11); Nummern wie in kern.lua (AUFGABEN)
local AUFG = {}
for i, t in ipairs({ "A 7 min", "A 10 min", "B 10 min", "B 7 min", "C", "D", "E 10 min", "E 15 min", "F", "G", "H", "I",
  "J", "K", "L", "M", "N" }) do AUFG[i] = { t, i } end

M.gruppen = {
  { { "Sensoren", "Sensors" }, {
    { "hoehe", "q", { "Höhe", "Altitude" } },
    { "vario", "q", { "Vario", "Vario" } },
    { "rx", "q", { "Empfänger-Akku", "Receiver battery" } },
    { "lq", "q", { "Empfang (RSSI/LQ)", "Link (RSSI/LQ)" } },
  } },
  { { "Start und Landung", "Launch and landing" }, {
    { "startArt", "w", { "Start erkennen", "Detect launch" }, 1,
      { { { "automatisch", "automatic" }, 1 }, { { "Schalter", "switch" }, 2 } } },
    { "swStart", "q", { "Schalter Start", "Launch switch" } },
    { "wurfV", "z", { "Wurf ab Steigen", "Launch from climb" }, 40, 10, 200, 1, " m/s" },
    { "landArt", "w", { "Landung erkennen", "Detect landing" }, 1,
      { { { "automatisch", "automatic" }, 1 }, { { "Schalter", "switch" }, 2 } } },
    { "swLand", "q", { "Schalter Landung", "Landing switch" } },
    { "endH", "z", { "Landung unter Höhe", "Landing below alt." }, 2, 1, 20, 0, " m" },
  } },
  { { "Wurfhöhe", "Launch height" }, {
    { "wurfEnde", "w", { "Wurf endet bei", "Launch ends at" }, 1,
      { { { "automatisch", "automatic" }, 1 }, { { "Schalter aus", "switch off" }, 2 },
        { { "Flugphase verlassen", "leaving flight mode" }, 3 } } },
    { "swWurf", "q", { "Schalter (z. B. Snapflap)", "Switch (e.g. snapflap)" } },
    { "wurfPhase", "z", { "Flugphase Nr.", "Flight mode no." }, 2, 1, 8, 0 },
  } },
  { { "F3K", "F3K" }, {
    { "aufgabe", "w", { "Aufgabe", "Task" }, 1, AUFG },
    { "swAz", "q", { "Schalter Arbeitszeit", "Working time switch" } },
    { "pokerZiel", "z", { "Poker Zielzeit", "Poker target time" }, 60, 5, 900, 0, " s", 5 },
    { "cStarts", "z", { "C Anzahl Starts", "C number of launches" }, 5, 3, 5, 0 },
    { "ansAz", "b", { "Arbeitszeit ansagen", "Announce working time" }, true },
  } },
  { { "Grenzwerte (0 = aus)", "Limits (0 = off)" }, {
    { "hWarn", "z", { "Höhe Warnung über", "Altitude warning above" }, 0, 0, 2000, 0, " m", 5 },
    { "hAlarm", "z", { "Höhe Alarm über", "Altitude alarm above" }, 0, 0, 2000, 0, " m", 5 },
    { "rxWarn", "z", { "RX-Akku Warnung unter", "RX batt. warning below" }, 0, 0, 200, 1, " V" },
    { "rxAlarm", "z", { "RX-Akku Alarm unter", "RX batt. alarm below" }, 0, 0, 200, 1, " V" },
    { "lqWarn", "z", { "Empfang Warnung unter", "Link warning below" }, 0, 0, 100, 0, " %" },
    { "lqAlarm", "z", { "Empfang Alarm unter", "Link alarm below" }, 0, 0, 100, 0, " %" },
  } },
  { { "Ansagen", "Announcements" }, {
    { "ansWurf", "b", { "Wurfhöhe ansagen", "Announce launch height" }, true },
    { "ansPhase", "b", { "Phasenwechsel ansagen", "Announce flight mode" }, true },
    { "ansFlug", "b", { "Flugzeit nach Landung", "Flight time on landing" }, true },
  } },
  { { "Warnungen", "Warnings" }, {
    { "ansage", "b", { "Ton und Ansage bei Alarm", "Sound and voice on alarm" }, true },
    { "warnAnsage", "b", { "Warnung auch ansagen", "Announce warnings too" }, false },
    { "zahl", "b", { "Wert mit ansagen", "Announce value" }, true },
    { "vibration", "b", { "Vibration bei Alarm", "Vibration on alarm" }, true },
    { "pause", "z", { "Wiederholung alle", "Repeat every" }, 30, 5, 600, 0, " s", 5 },
  } },
  { { "Flugphasen", "Flight modes" }, {
    { "fp1", "w", { "Phase 1", "Mode 1" }, 2, FARBEN },
    { "fp2", "w", { "Phase 2", "Mode 2" }, 4, FARBEN },
    { "fp3", "w", { "Phase 3", "Mode 3" }, 3, FARBEN },
    { "fp4", "w", { "Phase 4", "Mode 4" }, 5, FARBEN },
    { "fp5", "w", { "Phase 5", "Mode 5" }, 6, FARBEN },
    { "fp6", "w", { "Phase 6", "Mode 6" }, 7, FARBEN },
    { "fp7", "w", { "Phase 7", "Mode 7" }, 8, FARBEN },
    { "fp8", "w", { "Phase 8", "Mode 8" }, 1, FARBEN },
    { "pa1", "w", { "Ansage Phase 1", "Voice mode 1" }, 0, PANS },
    { "pa2", "w", { "Ansage Phase 2", "Voice mode 2" }, 0, PANS },
    { "pa3", "w", { "Ansage Phase 3", "Voice mode 3" }, 0, PANS },
    { "pa4", "w", { "Ansage Phase 4", "Voice mode 4" }, 0, PANS },
    { "pa5", "w", { "Ansage Phase 5", "Voice mode 5" }, 0, PANS },
    { "pa6", "w", { "Ansage Phase 6", "Voice mode 6" }, 0, PANS },
    { "pa7", "w", { "Ansage Phase 7", "Voice mode 7" }, 0, PANS },
    { "pa8", "w", { "Ansage Phase 8", "Voice mode 8" }, 0, PANS },
  } },
  { { "Anzeige", "Display" }, {
    { "sprache", "w", "Sprache / Language", 0,
      { { { "wie der Sender", "as the radio" }, 0 }, { "Deutsch", 1 }, { "English", 2 } } },
  } },
}

-- Text in der Sprache sp (1 = Deutsch, 2 = English).
function M.text(t, sp)
  if type(t) == "table" then return t[sp] or t[1] end
  return t
end

-- Reihenfolge im Speicher. Ethos speichert Quellen nach Reihenfolge, nicht nach Namen:
-- neue Einstellungen kommen immer ANS ENDE dieser Liste, nie dazwischen. Jede Einstellung aus M.gruppen steht hier.
M.folge = {
  "hoehe", "vario", "rx", "lq", "swStart", "swLand", "swWurf", "swAz",
  "startArt", "wurfV", "landArt", "endH", "wurfEnde", "wurfPhase", "aufgabe", "ansAz",
  "hWarn", "hAlarm", "rxWarn", "rxAlarm", "lqWarn", "lqAlarm", "ansWurf", "ansPhase", "ansFlug",
  "ansage", "warnAnsage", "zahl", "vibration", "pause",
  "fp1", "fp2", "fp3", "fp4", "fp5", "fp6", "fp7", "fp8", "sprache",
  "pa1", "pa2", "pa3", "pa4", "pa5", "pa6", "pa7", "pa8", "pokerZiel", "cStarts",
}

-- Kennung des Speicherformats: erhöhen, wenn sich die Reihenfolge der Quellen in M.folge doch einmal ändert.
M.FORMAT = 1

-- Feld zu einem Namen (Verzeichnis einmal aufbauen: Ethos begrenzt die Befehle je Aufruf).
local INDEX = nil
function M.feld(name)
  if INDEX == nil then
    INDEX = {}
    for _, g in ipairs(M.gruppen) do
      for _, f in ipairs(g[2]) do INDEX[f[1]] = f end
    end
  end
  return INDEX[name]
end

-- Darf das Studio diese Einstellung setzen? (Lua-Studio-Format v1, studio/beschreibung.json): keine Quellen und
-- keine Grenzwerte (die kommen über «grenzen»).
local STUDIO_GRUPPE = nil
function M.studioEinstellung(name)
  if STUDIO_GRUPPE == nil then
    STUDIO_GRUPPE = {}
    for _, g in ipairs(M.gruppen) do
      local gname = type(g[1]) == "table" and g[1][1] or g[1]
      if gname ~= "Sensoren" and gname:sub(1, 10) ~= "Grenzwerte" then
        for _, f in ipairs(g[2]) do
          if f[2] ~= "q" then STUDIO_GRUPPE[f[1]] = true end
        end
      end
    end
  end
  return STUDIO_GRUPPE[name] == true
end

function M.standard()
  local c = {}
  for _, g in ipairs(M.gruppen) do
    for _, f in ipairs(g[2]) do
      if f[2] ~= "q" then c[f[1]] = f[4] end
    end
  end
  return c
end

local function istQuelle(v)
  local t = type(v)
  if not (t == "userdata" or (t == "table" and type(v.value) == "function")) then return false end
  if CATEGORY_NONE then
    local ok, k = pcall(v.category, v)
    if ok and k == CATEGORY_NONE then return false end
  end
  return true
end
M.istQuelle = istQuelle

-- Gespeicherten Wert prüfen; passt er nicht, gilt der Wert ab Werk.
local function pruefe(f, v)
  local art = f[2]
  if art == "q" then
    if istQuelle(v) then return v end
    return nil
  elseif art == "b" then
    if type(v) == "boolean" then return v end
  elseif art == "z" then
    if type(v) == "number" and v == v and v >= f[5] and v <= f[6] then return math.floor(v) end
  elseif art == "w" then
    if type(v) == "number" then
      for _, a in ipairs(f[5]) do
        if a[2] == v then return v end
      end
    end
  end
  return f[4]
end

-- Speicher, gemessen im Simulator 26.1.2: der Widget-Speicher von Ethos fasst nur rund 256 Byte
-- (51 Zahlen oder 51 Quellen, danach «Max size reached») und arbeitet nach Reihenfolge, nicht nach Namen. Darum:
-- * Widget-Speicher: nur die Quellen (Sensoren, Kanäle, Schalter), in der Reihenfolge von M.folge, mit Rahmen
--   (fmt vorn, ende hinten). Höchstens 49 Quellen.
-- * Datei daten/<Modell>.txt im Skriptordner: alle Zahlen, Ja/Nein, Auswahlen als «name=wert» und die dauerhaften
--   Werte als «d_name=wert», also nach Namen und nicht nach Reihenfolge.
local function quellen()
  local r = {}
  for _, name in ipairs(M.folge) do
    local f = M.feld(name)
    if f and f[2] == "q" then r[#r + 1] = name end
  end
  return r
end

-- Dateiname zum aktuellen Modell (Ordner und Name, nur Buchstaben, Ziffern, _ und -).
function M.datei()
  local ok, p = pcall(model.path)
  if not ok or type(p) ~= "string" or p == "" then
    local ok2, n = pcall(model.name)
    p = (ok2 and type(n) == "string" and n ~= "") and n or "modell"
  end
  p = p:gsub("%.bin$", ""):gsub("[^%w%-]", "_")
  return (M.DIR or "") .. "daten/" .. p .. ".txt"
end

M.MAX_STARTS = 50

-- Zahl aus Text im Bereich, sonst nil.
function M.zahlOder(t, lo, hi)
  local x = tonumber(t)
  if x and x == x and x >= lo and x <= hi then return x end
  return nil
end

-- Datei ganz lesen (Ethos liest nur in Stücken), höchstens 8 KB.
local function liesDatei(pfad)
  local ok, f = pcall(io.open, pfad, "r")
  if not ok or not f then return nil end
  local teile, n = {}, 0
  while n < 8192 do
    local ok2, s = pcall(f.read, f, 512)
    if not ok2 or type(s) ~= "string" or s == "" then break end
    teile[#teile + 1] = s
    n = n + #s
  end
  pcall(f.close, f)
  return table.concat(teile)
end

-- Einstellungen lesen. Gibt true zurück, wenn schon etwas gespeichert war (sonst läuft die automatische Suche).
function M.lies(w)
  local c = M.standard()
  w.cfg = c
  w.studioWahl = ""
  local gefunden = false
  -- Quellen aus dem Widget-Speicher
  if storage and storage.read then
    local function hol(name)
      local ok, v = pcall(storage.read, name)
      if ok then return v end
      return nil
    end
    local q = quellen()
    if hol("fmt") == M.FORMAT then
      local werte = {}
      for i = 1, #q do werte[i] = hol("q" .. i) end
      if hol("ende") == M.FORMAT then
        gefunden = true
        for i, name in ipairs(q) do c[name] = istQuelle(werte[i]) and werte[i] or nil end
      else
        print(tostring(w.name) .. ": gespeicherte Sensoren unlesbar, bitte neu zuweisen")
      end
    end
  end
  -- Zahlen und dauerhafte Werte aus der Datei
  local text = liesDatei(M.datei())
  if text == nil and M.DIR ~= "" then text = liesDatei(M.datei():sub(#M.DIR + 1)) end   -- Daten bis 0.3.0 (relativ)
  if text then
    gefunden = true
    w.dauer, w.liste, w.offen, w.f3kGesp = {}, {}, nil, nil        -- ein zweites Lesen darf nichts doppelt führen
    for zeile in text:gmatch("[^\r\n]+") do
      local k, v = zeile:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if k == "k" and v then                           -- F3K-Runde: Aufgabe, läuft, Rest, Lauf, Starts, Treffer, Ziel fest, Ziel, W fertig
        local t = {}
        local i = 0                                    -- leere Felder zählen mit (sonst verrutscht die Uhrzeit)
        for x in (v .. ","):gmatch("([^,]*),") do i = i + 1 t[i] = tonumber(x) end
        if t[1] and t[1] >= 1 and t[1] <= 17 then
          w.f3kGesp = { nr = math.floor(t[1]), warAn = t[2] == 1, rest = (t[3] and t[3] >= 0 and t[3] <= 900) and t[3] or nil,
            lauf = M.zahlOder(t[4], 0, 36000), starts = M.zahlOder(t[5], 0, 99) or 0, treffer = M.zahlOder(t[6], 0, 3) or 0,
            zielFest = t[7] == 1, zielAkt = M.zahlOder(t[8], -1, 900), wFertig = t[9] == 1, fl = {}, zl = {},
            uhrHi = M.zahlOder(t[10], 0, 99999), uhrLo = t[11] and M.zahlOder(t[11], 0, 99999) or nil }   -- bis 0.3.2: eine Zahl (ungültig)
        end
      elseif k == "kf" and v and w.f3kGesp then          -- Flüge der Runde: Zeit:Ziel;…
        for a, b in v:gmatch("([%d%.]+):([%d%.%-]*)") do
          local t = M.zahlOder(a, 0, 3600)
          if t and #w.f3kGesp.fl < 60 then
            w.f3kGesp.fl[#w.f3kGesp.fl + 1] = t
            w.f3kGesp.zl[#w.f3kGesp.fl] = M.zahlOder(b, 0, 900) or false
          end
        end
      elseif (k == "s" or k == "o") and v then             -- Start: Wurfhöhe, Flugzeit, Höchste Höhe
        local a, b, h = v:match("^([%d%.%-]*),([%d%.]+),([%d%.%-]*)$")
        local t = tonumber(b)
        if t and t >= 0 and t < 36000 then
          local e = { wurf = M.zahlOder(a, -100, 3000), t = t, hmax = M.zahlOder(h, -100, 3000) }
          if k == "o" then w.offen = e elseif #w.liste < M.MAX_STARTS then w.liste[#w.liste + 1] = e end
        end
      elseif k == "studio" and v then                     -- im Menü gewählte Studio-Datei (leer = automatisch)
        w.studioWahl = #v <= 120 and v or ""
      elseif k and k:sub(1, 2) == "d_" then
        local x = tonumber(v)
        if x and x == x and x > -1e7 and x < 1e7 then w.dauer[k:sub(3)] = x end
      elseif k then
        local f = M.feld(k)
        if f and f[2] == "b" then
          c[k] = pruefe(f, v == "1")
        elseif f and (f[2] == "z" or f[2] == "w") then
          c[k] = pruefe(f, tonumber(v))
        end
      end
    end
  end
  return gefunden
end

-- Quellen in den Widget-Speicher (Ethos ruft das beim Speichern des Modells auf).
function M.schreibe(w)
  if not (storage and storage.write) then return end
  local c = w.cfg
  local q = quellen()
  pcall(storage.write, "fmt", M.FORMAT)
  for i, name in ipairs(q) do
    local v = c[name]
    pcall(storage.write, "q" .. i, istQuelle(v) and v or 0)
  end
  pcall(storage.write, "ende", M.FORMAT)
end

-- Datei in zwei Teilen bauen (Ethos begrenzt die Befehle je Aufruf): Teil 1 Einstellungen und dauerhafte Werte,
-- Teil 2 Startliste und offener Flug. M.schreibeText schreibt das Ganze.
function M.textEinst(w)
  local c = w.cfg
  local z = { "# " .. tostring(w.name) .. ": Einstellungen, Startliste und dauerhafte Werte dieses Modells" }
  for _, name in ipairs(M.folge) do
    local f = M.feld(name)
    local v = c[name]
    if f and f[2] == "b" then
      z[#z + 1] = name .. "=" .. (v and "1" or "0")
    elseif f and f[2] ~= "q" and type(v) == "number" then
      z[#z + 1] = name .. "=" .. string.format("%d", math.floor(v))
    end
  end
  if type(w.studioWahl) == "string" and w.studioWahl ~= "" then z[#z + 1] = "studio=" .. w.studioWahl end
  local namen = {}
  for k, x in pairs(w.dauer or {}) do
    if type(k) == "string" and type(x) == "number" and x == x then namen[#namen + 1] = k end
  end
  table.sort(namen)
  for _, k in ipairs(namen) do z[#z + 1] = "d_" .. k .. "=" .. string.format("%.2f", w.dauer[k]) end
  return table.concat(z, "\n") .. "\n"
end

function M.textListe(w)
  local z = {}
  local function zz(x) return x and string.format("%.1f", x) or "" end
  for _, e in ipairs(w.liste or {}) do z[#z + 1] = "s=" .. zz(e.wurf) .. "," .. string.format("%.1f", e.t or 0) .. "," .. zz(e.hmax) end
  local f0 = w.flug
  if f0 then z[#z + 1] = "o=" .. zz(f0.wurf) .. "," .. string.format("%.1f", f0.t or 0) .. "," .. zz(f0.hmax) end
  local k = w.f3k
  -- Rückfrage «Runde fortsetzen?» noch offen: Runde weiter als laufend mit der alten Uhrzeit sichern (Auszeit bleibt)
  local warten = w.dialog == "f3kWeiter" and k ~= nil and k.uhrHi ~= nil
  if k and (k.an or warten or #(k.fl or {}) > 0) then
    -- Uhrzeit beim Sichern (beim Fortsetzen läuft die Arbeitszeit nach) als zwei ganze Teile, nie mit %.0f
    -- (Ethos schreibt dann «2e+09»). Bei offener Rückfrage die alte Uhrzeit behalten.
    local uhr = ","
    if warten then uhr = string.format("%d,%d", k.uhrHi, k.uhrLo)
    else
      local okU, u = pcall(os.time)
      if okU and type(u) == "number" then u = math.floor(u) uhr = string.format("%d,%d", u // 100000, u % 100000) end
    end
    z[#z + 1] = string.format("k=%d,%d,%s,%s,%d,%d,%d,%s,%d,%s", k.nr or 1, (k.an or warten) and 1 or 0, k.rest and string.format("%.1f", k.rest) or "-1",
      k.lauf and string.format("%.1f", k.lauf) or "", k.starts or 0, k.treffer or 0, k.zielFest and 1 or 0,
      k.zielAkt and string.format("%d", math.floor(k.zielAkt + 0.5)) or "", k.wFertig and 1 or 0, uhr)
    local t = {}
    for i, x in ipairs(k.fl) do t[i] = string.format("%.1f", x) .. ":" .. ((k.zl and k.zl[i]) and string.format("%.1f", k.zl[i]) or "") end
    z[#z + 1] = "kf=" .. table.concat(t, ";")
  end
  if #z == 0 then return "" end
  return table.concat(z, "\n") .. "\n"
end

function M.schreibeText(text)
  if os and os.mkdir then pcall(os.mkdir, (M.DIR or "") .. "daten") end
  local ok, f = pcall(io.open, M.datei(), "w")
  if not ok or not f then return false end
  local okw = pcall(f.write, f, text)
  pcall(f.close, f)
  return okw
end

-- Alles auf einmal (Mac-Tests); auf dem Sender schreibt der Kern in zwei Aufrufen.
function M.schreibeDatei(w)
  return M.schreibeText(M.textEinst(w) .. M.textListe(w))
end

return M
