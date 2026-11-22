-- DLG: Ethos-Widget nach dem festen Bauplan (Skill ethos-lua, bauplan.md).
-- Diese Datei meldet nur das Widget an. Die Arbeit steckt in kern.lua und wird erst beim ersten Gebrauch geladen.
-- Für ein neues Lua ändern sich hier nur die vier Zeilen NAME, KEY, VERSION und INFO.
local NAME = "DLG"     -- Anzeigename in Ethos und Vorsatz aller Meldungen
local KEY = "dlg"       -- Schlüssel des Widgets: kurz, klein, eindeutig; nach der ersten Abgabe nie mehr ändern
local VERSION = "0.3.0"    -- die Versionsnummer steht nur hier (x.y.z); das Suite-Paket liest sie von hier
local INFO = "DLG: flight mode, launch height per launch, F3K tasks with working time, vario, flight time and launch list for discus launch gliders."   -- ein Satz für die FrSky Suite
local K = nil
local gemeldet = {}

local function kern()
  if K == nil then
    local f, e = loadfile("kern.lua")
    if not f then error(e, 0) end
    K = f()
    K.VERSION, K.NAME, K.INFO = VERSION, NAME, INFO
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

local function paint(w)
  if w.cfg then ruf("zeichne", w) end
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
    wakeup = function(w) if w.cfg then ruf("wecke", w) end end,
    paint = paint,
    event = function(w, kat, wert, x, y) if w.cfg then return ruf("ereignis", w, kat, wert, x, y) end end,
    configure = function(w) if w.cfg then ruf("menue", w) end end,
    read = function(w) if w.cfg then ruf("lies", w) end end,
    write = function(w) if w.cfg then ruf("schreibe", w) end end,
    title = false,
  })
end

return { init = init }
