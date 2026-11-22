-- DLG: Seite STARTS. Bestwert oben, darunter die Starts (neuester oben) mit Wurfhöhe und Flugzeit. Jeder Eintrag
-- lässt sich einzeln löschen (X, Rückfrage), alle zusammen über «ALLE LÖSCHEN» (Rückfrage).
local S = {}

function S.zeichne(w, L, Z)
  local C, W, s, gp, T = Z.C, L.W, L.s, L.gp, w.T
  local liste = w.liste
  local unten = Z.tasten(w, L)
  local y, fh = L.y0, unten - gp - L.y0
  Z.kasten(L, gp, y, W - 2 * gp, fh, nil)

  -- Kopf: Bestwert, Blättern, alle löschen
  local kh = math.max(36 * s, L.tipp)
  local best, bi = nil, nil
  for i, e in ipairs(liste) do if e.wurf and (best == nil or e.wurf > best) then best, bi = e.wurf, i end end
  local bt = best and string.format(T.bestwert, Z.zahl(best, 0), tostring(bi)) or T.bestLeer
  local ab = math.max(120 * s, 110)
  local pb = math.max(40 * s, L.tipp)
  Z.text(L, gp + 14 * s, y + 6 * s + kh / 2, bt, 16, best and C.gruen or C.dim, LEFT, W - ab - 2 * pb - 60 * s)
  local xa = W - gp - 8 * s - ab
  Z.knopf(w, L, "alle", xa, y + 6 * s, ab, kh, T.alleLoeschen, C.rot, false, 12)
  Z.knopf(w, L, "runter", xa - pb - 6 * s, y + 6 * s, pb, kh, "", C.text, false, 12)
  Z.pfeil(xa - pb - 6 * s + pb * 0.3, y + 6 * s + kh * 0.35, pb * 0.4, kh * 0.3, false, C.text)
  Z.knopf(w, L, "hoch", xa - 2 * pb - 12 * s, y + 6 * s, pb, kh, "", C.text, false, 12)
  Z.pfeil(xa - 2 * pb - 12 * s + pb * 0.3, y + 6 * s + kh * 0.35, pb * 0.4, kh * 0.3, true, C.text)

  -- Zeilen, neuester Start oben
  local zh = math.max(34 * s, L.tipp + 2)
  local y0 = y + 12 * s + kh
  local platz = math.max(1, math.floor((y + fh - y0 - 4 * s) / zh))
  local n = #liste
  if n == 0 then Z.text(L, W / 2, y + fh / 2, T.keineStarts, 18, C.dim, CENTERED) return end
  w.oben = math.max(0, math.min(w.oben or 0, n - platz))
  for k = 1, platz do
    local i = n - w.oben - k + 1
    if i < 1 then break end
    local e = liste[i]
    local yy = y0 + (k - 1) * zh
    local ym = yy + zh / 2
    Z.text(L, gp + 18 * s, ym, tostring(i), 18, C.dim, LEFT)
    Z.wert(L, W * 0.42, ym, e.wurf and (Z.zahl(e.wurf, 0) .. " m"), 22, i == bi and C.gruen or C.text, RIGHT, W * 0.25)
    Z.text(L, W * 0.68, ym, Z.zeit(e.t), 20, C.hblau, RIGHT)
    local xb = math.max(44 * s, L.tipp)
    Z.knopf(w, L, "x" .. i, W - gp - 12 * s - xb, yy + 2, xb, zh - 4, "X", C.rot, false, 14)
  end
end

return S
