-- Zählt die Lua-Befehle je Aufruf von wakeup (K.wecke) und paint (K.zeichne) auf dem Mac, ohne Simulator.
-- Schlimmster Fall: 50 Starts in der Liste, Flug und Wurf laufen, F3K-Runde mit vielen Flügen, Warnungen an,
-- alle drei Seiten, alle vier Displaygrössen. Grenzen nach Auftrag: paint < 10 000, wakeup < 5 000.
-- Aufruf in einer Kopie von src/dlg mit leerem Ordner daten/ (schreibt die Datei des Testmodells):
--   /opt/homebrew/opt/lua@5.4/bin/lua <Projekt>/test/befehle.lua
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
local K = assert(loadfile("kern.lua"))()
local w = K.neu()
w.autoOffen = false
w.cfg.lqWarn, w.cfg.lqAlarm, w.cfg.rxWarn, w.cfg.rxAlarm, w.cfg.aufgabe = 50, 35, 72, 65, 10
local Q = function(v) return { value = function() return v end, stringValue = function() return "" end } end
w.cfg.hoehe, w.cfg.vario, w.cfg.rx, w.cfg.lq = Q(40), Q(5), Q(6.0), Q(20)
for i = 1, 50 do w.liste[i] = { wurf = 40 + i % 15, t = 60 + i, hmax = 50 + i % 20 } end
w.f3k = { an = true, rest = 300, t0 = 0, fl = {}, starts = 0 }
for i = 1, 30 do w.f3k.fl[i] = 20 + i end
local max = { wecke = 0, zeichne = 0 }
local function zaehle(name, ...)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1)
  K[name](...)
  debug.sethook()
  if n > max[name] then max[name] = n end
  return n
end
for _, g in ipairs({ { 800, 480 }, { 640, 360 }, { 480, 320 }, { 480, 272 } }) do
  W, H = g[1], g[2]
  for seite = 1, 3 do
    w.seite = seite
    for k = 1, 30 do
      uhr = uhr + 0.21
      zaehle("wecke", w)
      local n = zaehle("zeichne", w)
      if k == 30 then print(string.format("%dx%d Seite %d: paint %d", W, H, seite, n)) end
    end
  end
end
print(string.format("Ohne Studio-Datei: wakeup %d, paint %d", max.wecke, max.zeichne))

-- Schlimmster Fall mit Studio-Datei: die grösste zulässige Datei (test/studio/gross.dlg.lua: 16 Plätze, 2 Kurven,
-- 24 Schmuck-Elemente, 24 Grenzen, 20 Wert-Anpassungen, alle Einstellungen) wird in Schritten geladen und
-- angewendet; danach alle Seiten und Grössen wie oben. SCRIPTS:/studio/ zeigt auf den Ordner studio/ der Kopie.
local quelle = assert(io.open(arg and arg[1] or "../test/studio/gross.dlg.lua", "r"))
local inhalt = quelle:read("a")
quelle:close()
os.execute("mkdir -p studio")
local f = assert(io.open("studio/Test.dlg.lua", "w"))
f:write(inhalt)
f:close()
local ioOpen = io.open
io.open = function(p, m)
  if type(p) == "string" then p = p:gsub("^SCRIPTS:/studio/", "studio/"):gsub("^SD:/scripts/studio/", "studio_sd/"):gsub("^RADIO:/scripts/studio/", "studio_radio/") end
  return ioOpen(p, m)
end
CATEGORY_TELEMETRY_SENSOR, CATEGORY_NONE = 1, 0
system.getSource = function() return { value = function() return 15 end, category = function() return 1 end,
  decimals = function() return 1 end, unit = function() return 1 end, stringValue = function() return "" end } end
system.getUnitName = function() return "V" end
K.studioNeu(w)                                     -- Studio-Datei neu suchen und anwenden (Zustand sonst wie oben)
local schritte = 0
W, H = 800, 480
for _ = 1, 400 do
  uhr = uhr + 0.11
  zaehle("wecke", w)
  zaehle("zeichne", w)
  schritte = schritte + 1
  if w.studioFertig and w.studio and not w.infoOffen then break end
end
print(string.format("Studio-Datei: Zustand %s, %s Fehler, nach %d Aufrufen", tostring(w.studioZustand), tostring(w.studioFehler), schritte))
assert(w.studio, "Studio-Datei nicht geladen")
for _ = 1, 700 do uhr = uhr + 0.21 K.wecke(w) end    -- Kurven füllen (120 Punkte je Kurve), ohne zu zählen
for _, g in ipairs({ { 800, 480 }, { 640, 360 }, { 480, 320 }, { 480, 272 } }) do
  W, H = g[1], g[2]
  for seite = 1, 3 do
    w.seite = seite
    for k = 1, 30 do
      uhr = uhr + 0.21
      zaehle("wecke", w)
      local n = zaehle("zeichne", w)
      if k == 30 then print(string.format("Studio %dx%d Seite %d: paint %d", W, H, seite, n)) end
    end
  end
end
w.funkeOffen = true                                -- Änderung im Menü: .funke.lua schreiben
for _ = 1, 10 do uhr = uhr + 0.5 zaehle("wecke", w) end
print(string.format("Höchstwerte: wakeup %d (Grenze 5000), paint %d (Grenze 10000)", max.wecke, max.zeichne))
print((max.wecke < 5000 and max.zeichne < 10000) and "ERGEBNIS: unter den Grenzen" or "ERGEBNIS: GRENZE ÜBERSCHRITTEN")
