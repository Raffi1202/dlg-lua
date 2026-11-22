-- Simulator-Makro: automatische Sensorzuweisung von DLG auf echter Firmware mit per Lua angelegten Sensoren.
-- Läuft über test/22-suche-sensoren.json. Fall 1: frisches Modell mit Höhe 0x0100 und Vario 0x0110.
-- Fall 2: «Empf.» (0xF101, zweiter RSSI-Wert) steht vor «Empf.-Batt.» (0xF104): RX-Akku muss 0xF104 bekommen.
local aus, fehler = {}, 0
local function melde(t) aus[#aus + 1] = t end
local function pruefe(name, ok) if not ok then fehler = fehler + 1 melde("FEHLER " .. name) else melde("ok " .. name) end end
local function suche(cfg)
  local f = loadfile("/scripts/dlg/suche.lua") or loadfile("scripts/dlg/suche.lua")
  local w = { cfg = cfg or {} }
  local ok, n = pcall(function() return f()(w) end)
  if not ok then melde("FEHLER Suche: " .. tostring(n)) fehler = fehler + 1 return w, -1 end
  return w, n
end
local function app(q) if q == nil then return -1 end local ok, v = pcall(q.appId, q) return ok and v or -1 end
local function name(q) if q == nil then return "-" end local ok, v = pcall(q.name, q) return ok and tostring(v) or "?" end
local function neu(id, ph, nm)
  local s = model.createSensor({ type = SENSOR_TYPE_SPORT, appId = id, physId = ph })
  if s and nm then pcall(s.name, s, nm) end
  return s
end

local w0, n0 = suche()
pruefe("leeres Modell: 0 zugewiesen", n0 == 0)
-- Reihenfolge wie am Sender mit SR10: Empf. vor Empf.-Batt.
neu(0xF101, 0x00, "Empf.")
neu(0xF104, 0x00, "Empf.-Batt.")
neu(0x0100, 0x00)
neu(0x0110, 0x00)
local liste = system.getSources(CATEGORY_TELEMETRY_SENSOR) or {}
melde("Sensoren angelegt: " .. #liste)
for _, q in ipairs(liste) do melde(string.format("  %04X %s", app(q), name(q))) end
local w, n = suche()
local c = w.cfg
melde(string.format("zugewiesen %s: hoehe=%04X %s, vario=%04X %s, rx=%04X %s, lq=%04X %s", tostring(n),
  app(c.hoehe), name(c.hoehe), app(c.vario), name(c.vario), app(c.rx), name(c.rx), app(c.lq), name(c.lq)))
pruefe("Höhe = 0x0100", app(c.hoehe) == 0x0100)
pruefe("Vario = 0x0110", app(c.vario) == 0x0110)
pruefe("RX-Akku = 0xF104 (nicht Empf. 0xF101)", app(c.rx) == 0xF104)
melde(fehler == 0 and "MAKRO: alles bestanden" or ("MAKRO: " .. fehler .. " Fehler"))
print(table.concat(aus, "\n"))
return table.concat(aus, "\n")
