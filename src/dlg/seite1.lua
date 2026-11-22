-- DLG: Seite FLUG. Oben die aktive Flugphase als farbiges Band, darunter sechs Felder: Flugzeit, Wurfhöhe, Vario,
-- Höhe, Empfänger-Akku, Empfang. Zeichnet nur; Werte aus w.v, w.flug, w.liste, w.dauer, Texte aus w.T.
local S = {}

local function vz(x, t)                          -- Vario-Text t mit Vorzeichen nach dem Wert x
  if x == nil then return nil end
  return (x > 0.05 and "+" or "") .. t
end

function S.zeichne(w, L, Z)
  local C, W, s, gp = Z.C, L.W, L.s, L.gp
  local v, d, T, c = w.v, w.dauer, w.T, w.cfg
  local f, liste = w.flug, w.liste
  local letzter = liste[#liste]
  local unten = Z.tasten(w, L)

  -- Flugphase
  local y = L.y0
  local ph = math.floor(48 * s)
  local nr = v.phase
  local farbe = nr and Z.PHASE[c["fp" .. nr] or 1] or C.grau
  Z.rund(gp, y, W - 2 * gp, ph, 10 * s, farbe)
  Z.text(L, gp + 14 * s, y + ph / 2, T.phase, 13, C.dunkel, LEFT)
  local name = v.phaseName or (nr and string.format(T.phaseNr, tostring(nr)))
  Z.wert(L, W / 2, y + ph / 2, name, 30, C.dunkel, CENTERED, W - 200 * s)
  y = y + ph + gp

  local b, h = (W - 4 * gp) / 3, (unten - gp - y - gp) / 2
  local function feld(sp, zl, titel, wert, st, ut, uw, wb)
    local x, yy = gp + sp * (b + gp), y + zl * (h + gp)
    Z.kasten(L, x, yy, b, h, titel, nil, st == 2 and C.rot or nil)
    Z.wert(L, x + b / 2, yy + h * 0.5, wert, 44, st == 2 and C.rot or (st == 1 and C.orange or C.text), CENTERED, (wb or b) - 24 * s)
    if ut then Z.text(L, x + 12 * s, yy + h - 16 * s, ut, 13, C.dim, LEFT) end
    if ut and uw ~= false then Z.wert(L, x + b - 12 * s, yy + h - 16 * s, uw, 16, C.hblau, RIGHT, b * 0.5) end
    return x, yy
  end
  local function st(a, wn) return a and 2 or (wn and 1 or 0) end
  local function z0(x) return x and Z.zahl(x, 0) end

  -- Flugzeit
  local t = f and f.t or (letzter and letzter.t) or 0
  feld(0, 0, T.flugzeit, Z.zeit(t), 0, string.format(T.startN, tostring(#liste + (f and 1 or 0))), false)
  -- Wurfhöhe: während des Wurfs live, danach der Wert des Flugs bzw. des letzten Starts
  local wurf = f and ((f.w and f.w.peak) or f.wurf) or (letzter and letzter.wurf)
  local best = f and f.wurf
  for _, e in ipairs(liste) do if e.wurf and (best == nil or e.wurf > best) then best = e.wurf end end
  feld(1, 0, T.wurfhoehe, z0(wurf), 0, T.best, z0(best))
  -- Vario: nur Anzeige, Balken rechts (±5 m/s voll)
  local x, yy = feld(2, 0, L.klein and T.varioK or T.vario, vz(v.vs, Z.zahl(v.vs, w.dz.vs or 1)), 0, nil, nil, b - 20 * s)
  local bx, bh, by = x + b - 16 * s, h - 56 * s, yy + 34 * s
  Z.rund(bx, by, 6 * s, bh, 3 * s, C.dunkel)
  if v.vs then
    local m = by + bh / 2
    local l = math.min(1, math.abs(v.vs) / 5) * bh / 2
    if v.vs >= 0 then Z.rechteck(bx, m - l, 6 * s, l, C.gruen) else Z.rechteck(bx, m, 6 * s, l, C.hblau) end
  end
  -- Höhe, Empfänger-Akku, Empfang
  feld(0, 1, T.hoehe, z0(v.h), st(v.hAlarm, v.hWarn), T.max, z0(f and f.hmax or (letzter and letzter.hmax)))
  local rxe = " " .. ((w.eh.rx or "") ~= "" and w.eh.rx or "V")
  feld(1, 1, T.rx, v.rx and (Z.zahl(v.rx, w.dz.rx or 1) .. rxe), st(v.rxAlarm, v.rxWarn), T.tiefst,
    d.rxMin and (Z.zahl(d.rxMin, w.dz.rx or 1) .. rxe))
  local lqe = " " .. ((w.eh.lq or "") ~= "" and w.eh.lq or "%")
  feld(2, 1, T.empfang, v.lq and (Z.zahl(v.lq, 0) .. lqe), st(v.lqAlarm, v.lqWarn), T.tiefst,
    d.lqMin and (Z.zahl(d.lqMin, 0) .. lqe))
end

return S
