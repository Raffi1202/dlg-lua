local function nichts() end
local HOEHE = { 12, 14, 16, 20, 26, 34, 46 }
FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4, 5, 6, 7
local schrift, W, H = 4, 800, 480
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  font = function(f) schrift = f end,
  getTextSize = function(t) return #tostring(t) * HOEHE[schrift] * 0.55, HOEHE[schrift] end,
  getWindowSize = function() return W, H end,
  isVisible = function() return true end,
}, { __index = function() return nichts end })
CENTERED, LEFT, RIGHT = 1, 0, 2
UNIT_METER, UNIT_SECOND, UNIT_MINUTE, UNIT_VOLT, UNIT_PERCENT = 1, 2, 3, 4, 5
local uhr = 0
os.clock = function() return uhr end
model = { name = function() return "Test" end, path = function() return "TEST/test.bin" end }
system = { getVersion = function() return {} end, getLocale = function() return "de" end, playFile = nichts,
  playNumber = nichts, playTone = nichts, playHaptic = nichts }
-- ===== DLG 0.3.2: Belege für Rückrufe mit nil, F3K-Fortsetzen, Daten bis 0.3.0, Auto-Suche (Mac, ohne Simulator) =====
-- Aufruf aus einer Kopie von src/dlg (mit leerem Ordner daten/): lua <Projekt>/test/fortsetzen-faelle.lua
local fehler = 0
local function pruef(was, ok) print((ok and "ok    " or "FEHLER ") .. was) if not ok then fehler = fehler + 1 end end
local function datei(n) local f = io.open(n, "r") if not f then return nil end local t = f:read("a") f:close() return t end
-- 2. main.lua: alle Rückrufe mit nil und mit {}
local R
system.registerWidget = function(t) R = t end
local logz = {}
local echtPrint = print
print = function(...) logz[#logz + 1] = table.concat({ ... }, " ") end
assert(loadfile("main.lua"))().init()
for _, n in ipairs({ "wakeup", "paint", "event", "configure", "read", "write" }) do
  for _, arg in ipairs({ "nil", "{}" }) do
    local ok, e = pcall(R[n], arg == "{}" and {} or nil, 0, 0, 0, 0)
    print = echtPrint
    pruef("2. " .. n .. "(" .. arg .. ") ohne Fehler", ok)
    print = function(...) logz[#logz + 1] = table.concat({ ... }, " ") end
  end
end
print = echtPrint
pruef("2. kein Log-Eintrag", #logz == 0)
-- 3./6./10. gespeicherte Runde lesen
local K = assert(loadfile("kern.lua"))()
K.DIR = ""
local F = assert(loadfile("felder.lua"))()
local pfad = F.datei()
local function runde(rest, uhr, an)
  local f = io.open(pfad, "w")
  f:write(string.format("k=1,%d,%.1f,0,0,0,0,,0,%d\nkf=\n", an, rest, uhr)) f:close()
  local w = K.neu() K.lies(w) return w
end
local jetzt = os.time()
local w = runde(400, jetzt - 100, 1)
pruef("3. lief: Rückfrage", w.dialog == "f3kWeiter")
pruef("3./7. angezeigte Restzeit 400 - 100 s = 300 (ist " .. tostring(w.weiterRest) .. ")", w.weiterRest == 300 or w.weiterRest == 299)
local vorher = (datei(pfad) or ""):match("k=[^\n]*")
w.dateiOffen, w.dateiJetzt = true, true
for _ = 1, 4 do uhr = uhr + 1 K.wecke(w) end
local nachher = (datei(pfad) or ""):match("k=[^\n]*")
pruef("10. Sichern bei offener Rückfrage: weiter läuft=1, alte Uhrzeit (" .. tostring(nachher) .. ")", nachher ~= nil and nachher:match("^k=%d+,(%d)") == "1" and nachher:match("(%d+)$") == vorher:match("(%d+)$"))
K.knopf(w, "ja_f3kWeiter", os.clock())
pruef("3. nach Ja: Runde läuft, Rest 400 - 100 s (ist " .. tostring(w.f3k.rest) .. ")", w.f3k.an and w.f3k.rest >= 299 and w.f3k.rest <= 300)
w = runde(400, jetzt - 100, 1)
K.knopf(w, "abbrechen", os.clock())
w.tDatei = -100
for _ = 1, 10 do uhr = uhr + 1 K.wecke(w) end
print("   Datei: " .. tostring((datei(pfad) or ""):match("k=[^\n]*")) .. " dialog=" .. tostring(w.dialog) .. " offen=" .. tostring(w.dateiOffen) .. " fehler=" .. tostring(w.fehler) .. " teil=" .. tostring(w.dateiTeil ~= nil))
pruef("5. Abbrechen: Runde beendet, gesichert ohne laufende Runde", w.f3k.ende == true and (datei(pfad) or ""):find("k=1,1,", 1, true) == nil)
w = runde(400, jetzt - 500, 1)
pruef("6. abgelaufen: keine Rückfrage", w.dialog ~= "f3kWeiter")
pruef("6. abgelaufen: als beendet geladen, Rest 0", w.f3k.ende == true and w.f3k.rest == 0)
w = runde(400, jetzt - 50, 0)
pruef("3. Landung vor reload (an=0): keine Rückfrage", w.dialog ~= "f3kWeiter" and w.f3k.ende == true)
-- 8. Daten bis 0.3.0 relativ, neuer Ordner leer
os.execute("mkdir -p neu/daten")
F.DIR = "neu/"
local f = io.open(pfad, "w") f:write("s=55,70.0,60\n") f:close()
local w8 = { cfg = {}, dauer = {} }
F.lies(w8)
pruef("8. Startliste aus altem relativem Pfad gelesen", w8.liste and #w8.liste == 1)
F.DIR = ""
os.remove(pfad)
-- 9. Auto-Suche beim ersten Start: zuerst nur RX-Akku da, Höhe und Vario melden sich später
CATEGORY_TELEMETRY_SENSOR = 1
local function q(id, nm, v) return { appId = function() return id end, name = function() return nm end, unit = function() return nil end,
  value = function() return v end, stringValue = function() return "" end, state = function() return true end } end
local quellen = { q(0xF104, "Empf.-Batt.", 7.9) }
system.getSources = function() return quellen end
local w9 = K.neu()
w9.autoOffen, w9.gelesen = true, false
for i = 1, 30 do
  uhr = uhr + 1
  w9.v.tele = true
  if i == 8 then quellen = { q(0xF104, "Empf.-Batt.", 7.9), q(0x0100, "Flughöhe", 50), q(0x0110, "Steigr. Vario", 1), q(0xF101, "RSSI", 90) } end
  pcall(K.wecke, w9)
end
local c9 = w9.cfg
pruef("9. Auto-Suche: RX zuerst, Höhe/Vario/LQ später zugewiesen (Versuche " .. tostring(w9.nAuto) .. ")",
  c9.rx ~= nil and c9.hoehe ~= nil and c9.vario ~= nil and c9.lq ~= nil and w9.autoOffen == false)
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
