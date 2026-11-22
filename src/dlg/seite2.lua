-- DLG: Seite F3K. Links Aufgabe und Arbeitszeit (antippen: Start/Stopp), rechts die Flüge der Runde mit der
-- gewerteten Zeit, unten die Wertung. Rechnet nur die Wertung zum Zeichnen (K.wertung, kurze Liste).
local S = {}

function S.zeichne(w, L, Z)
  local C, W, s, gp, T = Z.C, L.W, L.s, L.gp, w.T
  local k, f = w.f3k, w.flug
  local nr = w.cfg.aufgabe or 1
  local a = w.K.AUFGABEN[nr] or w.K.AUFGABEN[1]
  local unten = Z.tasten(w, L)
  local y, fh = L.y0, unten - gp - L.y0

  -- links: Aufgabe, Arbeitszeit
  local lb = math.floor(W * 0.45)
  Z.kasten(L, gp, y, lb, fh, nil)
  Z.ziel(w, "az", gp, y, lb, fh)
  local kb = math.max(44 * s, L.tipp)
  local titel = a[1] .. " " .. T["a" .. nr] .. (a[2] and ("  " .. math.floor(a[2] / 60) .. "'") or "")
  Z.text(L, gp + lb / 2, y + 22 * s, titel, 17, C.text, CENTERED, lb - 2 * kb - 16 * s)
  if not k.an then
    Z.knopf(w, L, "aufg_m", gp + 6 * s, y + 4 * s, kb, kb * 0.8, "<", C.hblau, false, 18)
    Z.knopf(w, L, "aufg_p", gp + lb - kb - 6 * s, y + 4 * s, kb, kb * 0.8, ">", C.hblau, false, 18)
  end
  Z.text(L, gp + lb / 2, y + 62 * s, T.arbeitszeit, 13, C.dim, CENTERED)
  local zeit
  if a[2] == nil then zeit = k.lauf or 0 else zeit = k.an and k.rest or a[2] end
  local farbe = (k.an and a[2] and k.rest < 60) and C.orange or (k.an and C.gruen or C.text)
  if k.ende and not k.an and a[2] then zeit, farbe = 0, C.dim end
  Z.wert(L, gp + lb / 2, y + fh * 0.48, Z.zeit(a[2] and math.ceil(zeit) or zeit), 64, farbe, CENTERED, lb - 20 * s)
  if a[3] == "poker" then                         -- Poker: Zielzeit wählen (−/+ 5 s, W = Ende Arbeitszeit), fest ab Wurf bis erreicht
    local zh2 = math.max(36 * s, L.tipp)
    local zy = y + fh * 0.72 - zh2 / 2
    local zt
    if k.zielFest then zt = (k.zielAkt == -1) and T.zielW or Z.zeit(k.zielAkt)
    else zt = k.zielW and T.zielW or Z.zeit(w.cfg.pokerZiel or 60) end
    Z.text(L, gp + lb / 2, zy + zh2 / 2, T.ziel .. " " .. zt, 20, k.zielFest and C.orange or C.text, CENTERED, lb - 3 * kb - 30 * s)
    if not k.zielFest then
      Z.knopf(w, L, "z_m", gp + 8 * s, zy, kb, zh2, "-", C.hblau, false, 18)
      Z.knopf(w, L, "z_p", gp + lb - 2 * kb - 14 * s, zy, kb, zh2, "+", C.hblau, false, 18)
      if not k.wFertig then Z.knopf(w, L, "z_w", gp + lb - kb - 8 * s, zy, kb, zh2, T.zielW, k.zielW and C.gruen or C.hblau, false, 16) end
    end
  end
  if f and f.f3k then
    Z.text(L, gp + lb / 2, y + fh - 46 * s, T.flugKurz .. " " .. Z.zeit(f.t), 22, C.hblau, CENTERED, lb - 20 * s)
  end
  if L.klasse ~= "M" then Z.text(L, gp + lb / 2, y + fh - 16 * s, T.tippStart, 11, C.dim, CENTERED, lb - 20 * s) end

  -- rechts: Flüge der Runde
  local x2 = 2 * gp + lb
  local rb = W - x2 - gp
  Z.kasten(L, x2, y, rb, fh, nil)
  Z.text(L, x2 + 12 * s, y + 18 * s, T.flugeAufgabe, 13, C.dim, LEFT, rb - 24 * s)
  local sc, sum = w.K.wertung(a, k.fl, k.zl)
  local zh = 32 * s
  local platz = math.max(1, math.floor((fh - 80 * s) / zh))
  local n = #k.fl + ((f and f.f3k) and 1 or 0)
  local ab = math.max(1, n - platz + 1)
  if n == 0 then Z.text(L, x2 + rb / 2, y + fh / 2, T.noFlug, 16, C.dim, CENTERED, rb - 20 * s) end
  for i = ab, n do
    local yy = y + 48 * s + (i - ab) * zh
    Z.text(L, x2 + 14 * s, yy, tostring(i), 17, C.dim, LEFT)
    if i <= #k.fl then
      Z.text(L, x2 + rb * 0.5, yy, Z.zeit(k.fl[i]), 20, C.text, RIGHT)
      if sc[i] then Z.text(L, x2 + rb - 12 * s, yy, Z.zeit(sc[i]), 17, C.hblau, RIGHT) end
    else
      Z.text(L, x2 + rb * 0.5, yy, Z.zeit(f.t), 20, C.text, RIGHT)
      Z.text(L, x2 + rb - 12 * s, yy, T.laeuft, 15, C.gruen, RIGHT)
    end
  end
  local wt = T.wertung .. " " .. Z.zeit(sum or 0)
  if a[3] == "poker" then wt = wt .. "   " .. string.format(T.treffer, tostring(k.treffer or 0)) end
  Z.text(L, x2 + 12 * s, y + fh - 18 * s, wt, 15, C.text, LEFT, rb - 24 * s)
end

return S
