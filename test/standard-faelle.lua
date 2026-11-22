-- DLG: Mac-Test Standard-Layout (Standard.dlg.lua für alle Modelle), Fälle S1–S4 ohne Simulator.
-- Aufruf aus dem Projektordner: lua test/standard-faelle.lua [Ausgabeordner für Info-Dateien]
-- Die Laufwerke SCRIPTS:, SD:, RADIO: zeigen auf einen leeren Ordner unter /tmp (nur Testdateien).
local AUS = arg[1]
local WURZEL = os.tmpname() .. "_dlg"
os.execute('mkdir -p "' .. WURZEL .. '/studio"')
local function pfad(p)
  p = p:gsub("^SCRIPTS:/", "/"):gsub("^SD:/scripts/", "/"):gsub("^RADIO:/scripts/", "/")
  return WURZEL .. p
end
local echtOpen, echtRemove, echtRename = io.open, os.remove, os.rename
io.open = function(p, m) return echtOpen(pfad(p), m) end
os.remove = function(p) return echtRemove(pfad(p)) end
os.rename = function(a, b) return echtRename(pfad(a), pfad(b)) end
os.mkdir = function() return true end
local MODELL = "Segler A"
model = { name = function() return MODELL end, path = function() return "" end }
system = {
  listFiles = function(o)
    local r, p = {}, io.popen('ls "' .. pfad(o) .. '" 2>/dev/null')
    for n in p:lines() do r[#r + 1] = n end
    p:close()
    return r
  end,
  getVersion = function() return { board = "X18RS", version = "26.2.0" } end,
  getSources = function() return {} end, getSource = function() return nil end,
}
package.path = "src/dlg/?.lua;" .. package.path
local ST = dofile("src/dlg/studio.lua")
local echt = io.open   -- gemappt
local function schreib(n, t) local f = echt("SCRIPTS:/studio/" .. n, "w") f:write(t) f:close() end
local function da(n) local f = echt("SCRIPTS:/studio/" .. n, "r") if f then f:close() return true end return false end
local function lies(n) local f = echt("SCRIPTS:/studio/" .. n, "r") if not f then return nil end local t = f:read("a") f:close() return t end
local DATEI = 'return { format = 2, studio = "0.5.0", funke = "X18RS", modell = "%s", luaVersion = "0.3.0", '
  .. 'einstellungen = { wurf_v = %s } }\n'
schreib("Standard.dlg.lua", DATEI:format("Standard", "3.5"))

local fehler = 0
local function pruef(was, ok) print((ok and "ok    " or "FEHLER ") .. was) if not ok then fehler = fehler + 1 end end

-- Suche wie beim Modellwechsel, bis die Studio-Datei gewählt ist (Stufe 2) oder fehlt
local function suche(w)
  w.studioJob = nil
  for _ = 1, 10 do
    local r = ST.schritt(w, nil)
    if r then return r end
    if w.studioJob and w.studioJob.stufe == 2 then local J = w.studioJob w.studioJob = nil return J end
  end
end
local function info(w, J, name)
  w.studio, w.studioQuelle, w.studioWahlArt, w.studioZustand = { zustand = "geladen" }, J.quelle, J.wahl, "geladen"
  w.infoJob, w.infoAlt, w.fenster = nil, nil, { { 800, 480 } }
  for _ = 1, 20 do if ST.infoSchritt(w, "0.3.0", { 1, 2 }) then break end end
  local k = ST.kennung() .. ".dlg.info.json"
  local t = lies(k)
  if AUS and t then local f = echtOpen(AUS .. "/" .. name .. ".info.json", "w") f:write(t) f:close() end
  return t or ""
end

-- S1: nur Standard, zwei Modelle
for _, m in ipairs({ "Segler A", "Segler B" }) do
  MODELL = m
  local J = suche({ studioWahl = "" })
  pruef("S1 " .. m .. ": Standard gilt", J.wahl == "standard" and J.quelle == "SCRIPTS:/studio/Standard.dlg.lua")
end
-- S2: Standard + Modelldatei
MODELL = "Segler A"
schreib("Segler_A.dlg.lua", DATEI:format("Segler A", "4.0"))
local J = suche({ studioWahl = "" })
pruef("S2: Modelldatei gewinnt", J.wahl == "auto" and J.quelle == "SCRIPTS:/studio/Segler_A.dlg.lua")
MODELL = "Segler B"
J = suche({ studioWahl = "" })
pruef("S2: anderes Modell ohne eigene Datei bleibt bei Standard", J.wahl == "standard")
-- S3: Standard + Wahl im Menü (eine andere Datei)
schreib("Wettbewerb.dlg.lua", DATEI:format("Wettbewerb", "5.0"))
local w = { studioWahl = "SCRIPTS:/studio/Wettbewerb.dlg.lua" }
J = suche(w)
pruef("S3: Wahl im Menü gewinnt über Standard", J.wahl == "menue" and J.quelle == "SCRIPTS:/studio/Wettbewerb.dlg.lua")
local t = info(w, J, "S3 Mac - Wahl im Menue")
pruef("S3: Info studioWahl menue", t:find('"studioWahl": "menue"', 1, true) ~= nil)
-- Menüliste: Standard-Eintrag mit Text
ST.textStandard = "Standard (alle Modelle)"
local gefunden = false
for _, d in ipairs(ST.liste()) do if d[2] == "Standard (alle Modelle)" then gefunden = true end end
pruef("Menü: Eintrag «Standard (alle Modelle)»", gefunden)
-- S4: Änderung am Sender bei Standard-Layout geht nur in .funke.lua dieses Modells
MODELL = "Segler B"
w = { studioWahl = "" }
J = suche(w)
local vorher = lies("Standard.dlg.lua")
pruef("S4: Segler B nutzt Standard", J.wahl == "standard")
pruef("S4: .funke.lua geschrieben", ST.funkeSchreiben(ST.kennung(), 'return { format = 2, einstellungen = { wurf_v = 6.0 } }\n'))
pruef("S4: Segler_B.dlg.funke.lua da", da("Segler_B.dlg.funke.lua"))
pruef("S4: keine Standard.dlg.funke.lua", not da("Standard.dlg.funke.lua"))
pruef("S4: keine .funke.lua bei Segler A", not da("Segler_A.dlg.funke.lua"))
pruef("S4: Standard.dlg.lua unverändert", lies("Standard.dlg.lua") == vorher)
t = info(w, J, "S4 Mac - Segler B Standard mit Aenderung")
pruef("S4: Info studioWahl standard", t:find('"studioWahl": "standard"', 1, true) ~= nil)
-- Stufe 2 liest die .funke.lua des Modells, nicht die des Standards
MODELL = "Segler B"
w = { studioWahl = "" }
w.studioJob = nil
ST.schritt(w, nil) ST.schritt(w, nil) ST.schritt(w, nil) ST.schritt(w, nil)
pruef("S4: Segler B lädt eigene .funke.lua", w.studioJob and w.studioJob.fu ~= nil)
-- Fall «Modell heisst Standard»: seine Datei gilt als Modelldatei
MODELL = "Standard"
J = suche({ studioWahl = "" })
pruef("Modell «Standard»: gilt als Modelldatei", J.wahl == "auto" and J.quelle == "SCRIPTS:/studio/Standard.dlg.lua")

os.execute('rm -r "' .. WURZEL .. '"')
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
os.exit(fehler == 0 and 0 or 1)
