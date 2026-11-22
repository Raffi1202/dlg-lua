-- Prüft die F3K-Wertung (kern.lua, K.wertung) mit den Beispielen aus FAI SC4 Vol F3 2025, F3K.11.
-- Aufruf: lua5.4 test/wertung-test.lua <Projektordner>
local dir = (arg[1] or ".") .. "/src/dlg/"
local K = assert(loadfile(dir .. "kern.lua"))()
local A, fehler = K.AUFGABEN, 0
local function pruefe(name, nr, fl, soll, zl)
  local _, sum = K.wertung(A[nr], fl, zl)
  local ok = sum == soll
  if not ok then fehler = fehler + 1 end
  print((ok and "ok    " or "FEHLER ") .. name .. ": " .. tostring(sum) .. " (soll " .. tostring(soll) .. ")")
end
pruefe("A letzter Flug, max 300", 2, { 100, 320 }, 300)
pruefe("B Beispiel Reglement", 3, { 65, 45, 55, 85 }, 140)
pruefe("B 7 min, max 180", 4, { 200, 190 }, 360)
pruefe("C Beispiel Wettbewerber B", 5, { 50, 50, 60 }, 160)
pruefe("D zwei Flüge, max 300", 6, { 310, 200 }, 500)
pruefe("E Poker Beispiel Reglement", 7, { 46, 48, 52, 49 }, 142, { 45, 50, 50, 47 })
pruefe("E Poker höchstens 3 Ziele", 8, { 60, 60, 60, 60 }, 180, { 60, 60, 60, 60 })
pruefe("E Poker Ziel nicht erreicht", 7, { 40 }, 0, { 45 })
pruefe("F 3 aus 6, max 180", 9, { 100, 200, 50, 170, 10, 90 }, 450)
pruefe("G 5 längste, max 120", 10, { 130, 100, 90, 80, 70, 60 }, 460)
pruefe("H Beispiel Reglement", 11, { 63, 239, 182, 90 }, 569)
pruefe("I 3 längste, max 200", 12, { 210, 150, 100, 50 }, 450)
pruefe("J Beispiel Reglement", 13, { 150, 45, 180, 150 }, 375)
pruefe("K Leiter, bis Zielzeit", 14, { 70, 80, 130, 150, 200 }, 60 + 80 + 120 + 150 + 180)
pruefe("L ein Flug, max 599", 15, { 650 }, 599)
pruefe("M Riesenleiter", 16, { 200, 250, 420 }, 180 + 250 + 420)
pruefe("N bester Flug", 17, { 100, 300, 200 }, 300)
-- Flugphasen: Name der Ethos-Flugphase -> Ansage
local function ph(name, soll)
  local ist = K.phaseWav(name)
  if ist ~= soll then fehler = fehler + 1 end
  print((ist == soll and "ok    " or "FEHLER ") .. "Phase «" .. tostring(name) .. "»: " .. tostring(ist))
end
ph("Start", "phase_start") ph("LAUNCH", "phase_start") ph("Zoom", "phase_zoom") ph("Speed", "phase_speed")
ph("Thermik", "phase_thermik") ph("thermal", "phase_thermik") ph("Strecke", "phase_strecke") ph("Cruise", "phase_strecke")
ph("Landung", "phase_landung") ph("Landing", "phase_landung") ph("Normal", "phase_normal") ph("Preset 1", nil) ph(nil, nil)
print(fehler == 0 and "ERGEBNIS: kein Fehler" or ("ERGEBNIS: " .. fehler .. " Fehler"))
