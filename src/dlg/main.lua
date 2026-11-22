-- DLG: Ethos-Widget nach dem festen Bauplan (Skill ethos-lua, bauplan.md).
-- Diese Datei meldet nur das Widget an. Die Arbeit steckt in kern.lua und wird erst beim ersten Gebrauch geladen.
-- Für ein neues Lua ändern sich hier nur die vier Zeilen NAME, KEY, VERSION und INFO.
local NAME = "DLG"     -- Anzeigename in Ethos und Vorsatz aller Meldungen
local KEY = "dlg"       -- Schlüssel des Widgets: kurz, klein, eindeutig; nach der ersten Abgabe nie mehr ändern
local VERSION = "0.3.2"    -- die Versionsnummer steht nur hier (x.y.z); das Suite-Paket liest sie von hier
local INFO = "DLG: flight mode, launch height per launch, F3K tasks with working time, vario, flight time and launch list for discus launch gliders."   -- ein Satz für die FrSky Suite
local K = nil
local gemeldet = {}

-- Ordner dieses Skripts (z. B. «SD:/scripts/dlg/»): Nach «reload SCRIPTS» stimmt der relative Pfad im Simulator nicht
-- mehr («cannot open /kern.lua»). Ohne debug-Bibliothek bleibt es beim relativen Pfad wie bisher.
local DIR = ""
pcall(function()
  local q = debug.getinfo(1, "S").source
  DIR = (type(q) == "string" and q:match("^@?(.*/)")) or ""
end)

local function kern()
  if K == nil then
    local f, e = loadfile(DIR .. "kern.lua")
    if not f and DIR ~= "" then f, e = loadfile("kern.lua") end
    if not f then error(e, 0) end
    K = f()
    K.VERSION, K.NAME, K.INFO, K.DIR = VERSION, NAME, INFO, DIR
  end
  return K
end

-- Ein Fehler im Skript darf die Funke nicht stören: einmal pro Stelle melden und weiterlaufen.
local function ruf(name, w, ...)
  local ok, a = pcall(function(...) return kern()[name](w, ...) end, ...)
  if ok then return a end
  if not gemeldet[name] then
    gemeldet[name] = true
    print(NAME .. ": Fehler in " .. name .. ": " .. tostring(a))
  end
  if type(w) == "table" then w.fehler = name .. ": " .. tostring(a) end
  return nil
end

local function create()
  local ok, w = pcall(function() return kern().neu() end)
  if ok and type(w) == "table" then return w end
  print(NAME .. ": Fehler in create: " .. tostring(w))
  return { fehler = "create: " .. tostring(w) }
end

-- Nach «reload SCRIPTS» ruft Ethos die Widget-Funktionen am Sender auch mit w = nil auf: dann nichts tun
local function bereit(w) return type(w) == "table" and w.cfg ~= nil end

local function paint(w)
  if type(w) ~= "table" then return end
  if bereit(w) then ruf("zeichne", w) end
  if w.fehler then                             -- Fehler klein und sichtbar über dem Bild, unten links
    pcall(function()
      local t = NAME .. ": " .. tostring(w.fehler)
      local _, H = lcd.getWindowSize()
      lcd.font(FONT_S)
      lcd.color(lcd.RGB(0, 0, 0))
      lcd.drawFilledRectangle(0, H - 26, lcd.getTextSize(t) + 16, 26)
      lcd.color(lcd.RGB(239, 68, 68))
      lcd.drawText(8, H - 24, t)
    end)
  end
end

local function init()
  system.registerWidget({
    key = KEY,
    name = NAME,
    create = create,
    wakeup = function(w) if bereit(w) then ruf("wecke", w) end end,
    paint = paint,
    event = function(w, kat, wert, x, y) if bereit(w) then return ruf("ereignis", w, kat, wert, x, y) end end,
    configure = function(w) if bereit(w) then ruf("menue", w) end end,
    read = function(w) if bereit(w) then ruf("lies", w) end end,
    write = function(w) if bereit(w) then ruf("schreibe", w) end end,
    title = false,
  })
end

return { init = init }
