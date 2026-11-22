-- DLG: Zeichen-Baukasten (Farben, Schriften, Grundformen, Statusleiste, Knopf, Rückfrage).
-- Zeichnet nur, rechnet nichts aus. Alle Masse gehen vom Entwurf 800 x 480 aus und werden mit L.s verkleinert.
local Z = {}
local floor, max, min = math.floor, math.max, math.min

Z.C = nil       -- Farben
local SCHRIFT   -- vorhandene Schriften mit gemessener Höhe, klein nach gross

-- Feste Farben: grün = gut, orange = Warnung, rot = Alarm, blau = Hinweis, grau = kein Wert.
local function farben()
  local R = lcd.RGB
  Z.C = {
    bg = R(14, 17, 22), panel = R(22, 27, 34), rand = R(48, 54, 61), text = R(230, 237, 243), dim = R(139, 148, 158),
    grau = R(75, 85, 99), blau = R(59, 130, 246), gruen = R(34, 197, 94), orange = R(245, 158, 11), rot = R(239, 68, 68),
    dunkel = R(11, 13, 16), hblau = R(96, 165, 250), weiss = R(255, 255, 255),
  }
  -- Farben der Flugphasen (Auswahl im Menü, Reihenfolge wie FARBEN in felder.lua)
  Z.PHASE = { R(156, 163, 175), R(34, 197, 94), R(96, 165, 250), R(253, 224, 71), R(196, 181, 253), R(45, 212, 191),
    R(249, 168, 212), R(255, 255, 255) }
end

local function schriften()
  SCHRIFT = {}
  local kand = { FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL }
  for i = 1, 7 do
    local f = kand[i]
    if f ~= nil then
      lcd.font(f)
      local _, h = lcd.getTextSize("0")
      local n = #SCHRIFT
      if n == 0 or h > SCHRIFT[n][2] then SCHRIFT[n + 1] = { f, h } end
    end
  end
end

-- Aufteilung für eine Fenstergrösse (wird im Kern je Grösse einmal gerechnet und gemerkt).
function Z.layout(W, H)
  if not Z.C then farben() end
  if not SCHRIFT then schriften() end
  local s = min(W / 800, H / 480)
  -- Displayklasse nach der gemessenen Breite, nie nach dem Namen des Senders (bauplan.md, Abschnitt Sender):
  -- L = 800 x 480 (X20-Reihe, X18R, X18RS), M = 640 x 360 (X14), S = 480 x 320 und 480 x 272 (X18, X18S, X Lite, X10, X12)
  local klasse = W >= 700 and "L" or (W >= 560 and "M" or "S")
  local L = { W = W, H = H, s = s, klasse = klasse, klein = klasse == "S" }
  L.tipp = 32                      -- Pixel: antippbare Flächen sind nie niedriger (bei 480 x 320 sonst zu klein)
  L.sb = floor(44 * s)             -- Statusleiste
  L.top = L.sb + floor(6 * s)      -- Oberkante der Meldezeile
  L.mh = floor(26 * s)             -- Höhe der Meldezeile
  L.gp = floor(6 * s)              -- Abstand zwischen Feldern
  L.y0 = L.top + L.mh + L.gp       -- Oberkante der Felder einer Seite
  L.fi = {}                        -- Schriftwahl je Entwurfsgrösse
  return L
end

-- Schrift für eine Entwurfsgrösse (Schriftgrad im Entwurf 800 x 480) wählen; gibt die Stufe zurück.
local function stufe(L, gr)
  local i = L.fi[gr]
  if i then return i end
  local ziel = gr * 1.25 * L.s + 0.5
  i = 1
  for k = 2, #SCHRIFT do
    if SCHRIFT[k][2] <= ziel then i = k end
  end
  L.fi[gr] = i
  return i
end

-- Text mit senkrechter Mitte ym. ausr: LEFT / RIGHT / CENTERED. maxB: passt der Text nicht, wird die Schrift kleiner.
-- Rückgabe: Textbreite.
function Z.text(L, x, ym, t, gr, farbe, ausr, maxB)
  local i = stufe(L, gr)
  lcd.font(SCHRIFT[i][1])
  local b = lcd.getTextSize(t)
  if maxB then
    while b > maxB and i > 1 do
      i = i - 1
      lcd.font(SCHRIFT[i][1])
      b = lcd.getTextSize(t)
    end
  end
  lcd.color(farbe)
  lcd.drawText(floor(x), floor(ym - SCHRIFT[i][2] / 2), t, ausr or LEFT)
  return b
end

-- Textbreite in der Schrift einer Entwurfsgrösse.
function Z.breite(L, t, gr)
  lcd.font(SCHRIFT[stufe(L, gr)][1])
  return (lcd.getTextSize(t))
end

function Z.rechteck(x, y, b, h, farbe)
  if b < 1 or h < 1 then return end
  lcd.color(farbe)
  lcd.drawFilledRectangle(floor(x), floor(y), floor(b + 0.5), floor(h + 0.5))
end

-- Rechteck mit runden Ecken (Ethos kennt keines: zwei Rechtecke und vier Kreise).
function Z.rund(x, y, b, h, r, farbe)
  x, y, b, h, r = floor(x), floor(y), floor(b), floor(h), floor(r)
  if b < 1 or h < 1 then return end
  lcd.color(farbe)
  if r * 2 + 1 > h then r = floor((h - 1) / 2) end
  if r * 2 + 1 > b then r = floor((b - 1) / 2) end
  if r < 2 then
    lcd.drawFilledRectangle(x, y, b, h)
    return
  end
  lcd.drawFilledRectangle(x + r, y, b - 2 * r, h)
  lcd.drawFilledRectangle(x, y + r, b, h - 2 * r)
  lcd.drawFilledCircle(x + r, y + r, r)
  lcd.drawFilledCircle(x + b - r - 1, y + r, r)
  lcd.drawFilledCircle(x + r, y + h - r - 1, r)
  lcd.drawFilledCircle(x + b - r - 1, y + h - r - 1, r)
end

-- Gefülltes Feld mit Rand. d = Randstärke.
function Z.feld(x, y, b, h, r, rand, fuell, d)
  d = d or 1
  Z.rund(x, y, b, h, r, rand)
  Z.rund(x + d, y + d, b - 2 * d, h - 2 * d, r - d, fuell)
end

-- Feld mit Titel oben in der Mitte.
function Z.kasten(L, x, y, b, h, titel, farbe, rand)
  local C = Z.C
  Z.feld(x, y, b, h, 10 * L.s, rand or C.rand, C.panel, rand and max(2, floor(3 * L.s)) or 1)
  if titel then Z.text(L, x + b / 2, y + 18 * L.s, titel, 14, farbe or C.dim, CENTERED, b - 12 * L.s) end
end

-- Pille mit Text; voll = gefüllt, sonst nur Rand.
function Z.pille(L, x, y, b, h, t, farbe, voll, gr)
  local C = Z.C
  if voll then
    Z.rund(x, y, b, h, h / 2, farbe)
  else
    Z.feld(x, y, b, h, h / 2, farbe, C.panel, max(1, floor(2 * L.s)))
  end
  Z.text(L, x + b / 2, y + h / 2, t, gr, voll and C.dunkel or farbe, CENTERED, b - h * 0.3)
end

-- Kreisbogen; Winkel in Grad, 0 = oben, im Uhrzeigersinn. Geht auch über 360 hinaus.
function Z.bogen(cx, cy, r1, r2, a0, a1, farbe)
  if a1 <= a0 then return end
  lcd.color(farbe)
  cx, cy, r1, r2 = floor(cx), floor(cy), floor(r1), floor(r2)
  if a0 >= 360 then a0, a1 = a0 - 360, a1 - 360 end
  if a1 > 360 then
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, 360)
    lcd.drawAnnulusSector(cx, cy, r1, r2, 0, a1 - 360)
  else
    lcd.drawAnnulusSector(cx, cy, r1, r2, a0, a1)
  end
end

-- Zahl mit dez Stellen: deutsch mit Komma, englisch mit Punkt (Z.punkt setzt der Kern je Bild).
-- nil bleibt nil (Z.wert zeichnet dann einen Strich).
function Z.zahl(x, dez)
  if x == nil then return nil end
  local t = string.format("%." .. (dez or 0) .. "f", x)
  if dez and dez > 0 then
    local a, b = t:match("^(-?%d+)%.(%d+)$")
    if a and not Z.punkt then t = a .. "," .. b end
  end
  return t
end

-- Ganze Zahl mit Tausender-Trennung: 6850 -> 6'850 (deutsch) oder 6,850 (englisch).
function Z.tausend(x)
  if x == nil then return nil end
  local n = floor(x + 0.5)
  local v = n < 0 and "-" or ""
  if n < 0 then n = -n end
  if n < 1000 then return v .. string.format("%.0f", n) end
  return v .. string.format("%.0f", floor(n / 1000)) .. (Z.punkt and "," or "'") .. string.format("%03.0f", n % 1000)
end

-- Sekunden als m:ss oder h:mm:ss.
function Z.zeit(sek)
  if sek == nil then return nil end
  local n = floor(sek)
  if n < 0 then n = 0 end
  if n >= 3600 then return string.format("%.0f:%02.0f:%02.0f", n // 3600, (n % 3600) // 60, n % 60) end
  return string.format("%.0f:%02.0f", n // 60, n % 60)
end

function Z.grund(L)
  lcd.color(Z.C.bg)
  lcd.drawFilledRectangle(0, 0, L.W, L.H)
end

-- Hinweis, wenn das Feld für die Anzeige zu klein ist.
function Z.zuKlein(w, L)
  local C = Z.C
  Z.text(L, L.W / 2, L.H / 2 - 12, tostring(w.name), 26, C.text, CENTERED, L.W - 8)
  Z.text(L, L.W / 2, L.H / 2 + 12, w.T.vollbild, 20, C.dim, CENTERED, L.W - 8)
end

-- Kurzer waagrechter Strich für «kein Wert» (die Ethos-Schrift hat keinen Gedankenstrich). gr = Entwurfsgrösse.
function Z.strich(L, x, ym, gr, farbe, ausr)
  local b = floor(gr * 0.7 * L.s + 0.5)
  local d = max(2, floor(gr * 0.09 * L.s + 0.5))
  if ausr == CENTERED then x = x - b / 2 elseif ausr == RIGHT then x = x - b end
  Z.rechteck(x, ym - d / 2, b, d, farbe or Z.C.grau)
  return b
end

-- Text oder, wenn t nil ist, ein Strich. Jeder Messwert wird mit Z.wert gezeichnet, nie mit Z.text.
function Z.wert(L, x, ym, t, gr, farbe, ausr, maxB)
  if t == nil then return Z.strich(L, x, ym, gr, Z.C.grau, ausr) end
  return Z.text(L, x, ym, t, gr, farbe, ausr, maxB)
end

local ZUSTAND_FARBE = { ok = "gruen", warnung = "orange", alarm = "rot" }

-- Statusleiste und Meldezeile (auf allen Seiten gleich): links der Zustand als Pille, rechts Name und Seite,
-- darunter die aktiven Warnungen aller Seiten oder ein kurzer Hinweis.
function Z.kopf(w, L)
  local C, s, W = Z.C, L.s, L.W
  local sb = L.sb
  Z.rechteck(0, 0, W, sb, C.panel)
  -- Pille: Schrift so gross, wie die Pille hoch ist (sonst gehen die Umlaut-Punkte von Ä/Ü in der kleinen Schrift unter)
  local ph = max(22, floor(28 * s))
  local py = floor((sb - ph) / 2)
  local gr = ph * 0.92 / (1.25 * s)
  local zf = C[ZUSTAND_FARBE[w.zustand] or "grau"]
  local voll = not (w.stufe == 2 and w.blink)        -- Alarm blinkt: gefüllt / nur Rand
  local zt = w.T[w.zustand] or ""
  local zb = max(112 * s, Z.breite(L, zt, gr) + 24 * s)
  Z.pille(L, 8 * s, py, zb, ph, zt, zf, voll, gr)

  local rechts = tostring(w.modell or w.name)
  if (w.seiten or 1) > 1 then rechts = rechts .. "  " .. w.seite .. "/" .. w.seiten end
  local xr = W - 10 * s
  if w.sAusruf and not w.sHinweis then             -- Studio-Datei mit Hinweis: «!» oben rechts (Text im Log)
    local r = max(8, floor(11 * s))
    lcd.color(C.orange)
    lcd.drawFilledCircle(floor(W - 8 * s - r), floor(sb / 2), r)
    Z.text(L, W - 8 * s - r, sb / 2, "!", 16, C.dunkel, CENTERED)
    xr = W - 16 * s - 2 * r
  end
  Z.text(L, xr, sb / 2, rechts, 16, C.text, RIGHT, xr - zb - 30 * s)

  local mt, mf, tf
  if w.hinweis then
    mt, mf, tf = w.hinweis, C.blau, C.weiss
  elseif w.nAktiv > 0 then
    mt, mf, tf = w.meldText, w.stufe == 2 and C.rot or C.orange, C.dunkel
  elseif w.sHinweis or w.sDauer then              -- Hinweis der Studio-Datei (bleibend: grau)
    mt, mf, tf = w.sHinweis or w.sDauer, w.sHinweis and C.blau or C.grau, C.weiss
  end
  if mt then
    Z.rund(L.gp, L.top, W - 2 * L.gp, L.mh, 8 * s, mf)
    Z.text(L, W / 2, L.top + L.mh / 2, mt, 16, tf, CENTERED, W - 2 * L.gp - 16 * s)
  end
end

-- Antippbare Fläche merken (beim Zeichnen); der Kern prüft damit die Berührungen.
function Z.ziel(w, id, x, y, b, h)
  local n = (w.nZiele or 0) + 1
  w.nZiele = n
  local z = w.ziele[n] or {}
  z.id, z.x, z.y, z.b, z.h = id, x, y, b, h
  w.ziele[n] = z
end

-- Knopf mit Rand oder gefüllt; meldet seine Fläche als Ziel.
function Z.knopf(w, L, id, x, y, b, h, t, farbe, voll, gr)
  local C = Z.C
  if voll then
    Z.rund(x, y, b, h, 8 * L.s, farbe)
  else
    Z.feld(x, y, b, h, 8 * L.s, farbe, C.panel, max(1, floor(2 * L.s)))
  end
  Z.text(L, x + b / 2, y + h / 2, t, gr, voll and C.dunkel or farbe, CENTERED, b - 12 * L.s)
  Z.ziel(w, id, x, y, b, h)
end

-- Rückfrage über der Seite. Nur «JA, …» ändert etwas.
-- { Titel, Zeile, Text Ja, Ziel Ja, Text links, Ziel links }; die Texte sind Namen aus texte.lua.
local DIALOG = {
  reset = { "resetTitel", "resetZeile", "resetJa", "ja_reset", "abbrechen", "abbrechen" },
  loesch = { "loeschTitel", "loeschZeile", "loeschJa", "ja_loesch", "abbrechen", "abbrechen" },
  f3kStopp = { "stoppTitel", "stoppZeile", "stoppJa", "ja_f3kStopp", "abbrechen", "abbrechen" },
  f3kNeu = { "neuTitel", "neuZeile", "neuJa", "ja_f3kNeu", "abbrechen", "abbrechen" },
  f3kWeiter = { "weiterTitel", "weiterZeile", "weiterJa", "ja_f3kWeiter", "abbrechen", "abbrechen" },
}

function Z.dialog(w, L)
  local d = DIALOG[w.dialog]
  if d == nil then return end
  local C, s, W, H, T = Z.C, L.s, L.W, L.H, w.T
  lcd.color(lcd.RGB(0, 0, 0, 0.6))                   -- Seite abdunkeln
  lcd.drawFilledRectangle(0, 0, W, H)
  local b, h = min(W - 16, max(460 * s, 400)), max(200 * s, 130)   -- auf kleinen Displays nicht schmaler als 400 Pixel
  local x, y = (W - b) / 2, (H - h) / 2
  Z.feld(x, y, b, h, 14 * s, C.hblau, C.bg, max(2, floor(2 * s)))
  local titel = T[d[1]]
  if w.dialog == "loesch" then titel = string.format(titel, tostring(w.loeschNr)) end
  Z.text(L, W / 2, y + 42 * s, titel, 26, C.text, CENTERED, b - 30 * s)
  if d[2] then Z.text(L, W / 2, y + 82 * s, T[d[2]], 15, C.dim, CENTERED, b - 30 * s) end
  local kb, kh = (b - 3 * 22 * s) / 2, max(46 * s, L.tipp or 0)
  local ky = y + h - kh - 22 * s
  Z.knopf(w, L, d[6], x + 22 * s, ky, kb, kh, T[d[5]], C.dim, false, 15)
  Z.knopf(w, L, d[4], x + 44 * s + kb, ky, kb, kh, T[d[3]], C.gruen, true, 15)
end

-- Untere Knopfreihe FLUG / F3K / STARTS (Seite wechseln; Wisch geht auch). Gibt die Oberkante zurück.
function Z.tasten(w, L)
  local C, s, W, H, gp, T = Z.C, L.s, L.W, L.H, L.gp, w.T
  local kh = max(40 * s, L.tipp)
  local kb = (W - 4 * gp) / 3
  local namen = { T.flug, T.f3k, T.starts }
  for i = 1, 3 do
    local f = i == w.seite and C.hblau or C.text
    Z.knopf(w, L, "s" .. i, gp + (i - 1) * (kb + gp), H - gp - kh, kb, kh, namen[i], f, false, 14)
  end
  return H - gp - kh
end

-- Dreieck (Pfeil) nach oben oder unten, in x, y, b, h.
function Z.pfeil(x, y, b, h, hoch, farbe)
  lcd.color(farbe)
  if hoch then pcall(lcd.drawFilledTriangle, x, y + h, x + b, y + h, x + b / 2, y)
  else pcall(lcd.drawFilledTriangle, x, y, x + b, y, x + b / 2, y + h) end
end

return Z
