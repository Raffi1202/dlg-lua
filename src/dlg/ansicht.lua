-- DLG: zeichnet die Plätze einer Ansicht aus der Studio-Datei (Lua-Studio-Format v1, Abschnitte 6.3 und 7; Format 2
-- ohne Symbole und ohne fette Einheit: nur Schmuck aus Text, Linie und Rahmen).
-- Wird nur geladen, wenn zur Fenstergrösse eine Studio-Ansicht passt. Rechnet nichts aus: Werte kommen aus
-- studio.lua (M.wert), Zustände aus den Grenzen (kern.lua bzw. studio.lua), Min/Max/Mittel und Kurven aus M.wecke.
-- Ersetzt nur die Seite FLUG; F3K und STARTS bleiben wie ohne Studio-Datei. Kopfzeile und Seitentasten zeichnet der
-- Kern bzw. diese Datei selbst (reservierte Flächen, studio/beschreibung.json).
local A = {}
local floor, max, min = math.floor, math.max, math.min

local function rgb(t, sonst)
  if t then return lcd.RGB(t[1], t[2], t[3]) end
  return sonst
end

-- Entwurfsgrösse für Z.text aus einer gewünschten Pixelhöhe (Z.text rechnet gr × 1,25 × L.s)
local function gr(L, px) return max(6, px / (1.25 * L.s)) end

local function zahlText(Z, x, dez, eh, zeit)
  if x == nil then return nil end
  if zeit then return Z.zeit(x) end
  local t = Z.zahl(x, dez)
  if eh and eh ~= "" then t = t .. " " .. eh end
  return t
end

-- Farbe des Werts: Alarm/Warnung (Grenze des Werts) vor Farbstufen vor Grundfarbe (Farben fertig in k)
local function farbeVon(q, k, st, x)
  if st == 2 then return k.fA end
  if st == 1 then return k.fW end
  if k.stufen and x then
    local f = nil
    for _, s in ipairs(k.stufen) do if x >= s[1] then f = s[2] end end
    if f then return f end
  end
  return k.fG
end

-- Kachel: eine gefüllte Fläche; nur bei Alarm mit rotem Rand (Befehlsgrenze: 16 Plätze je Bild)
-- Kachel: eine gefüllte Fläche; nur bei Alarm mit rotem Rand (Befehlsgrenze: bis 16 Plätze je Bild)
local function kachel(q, k, st)
  lcd.color(st == 2 and k.fA or k.hg)
  lcd.drawFilledRectangle(q.x, q.y, q.b, q.h)
  if st == 2 then
    local d = k.rand
    lcd.color(k.hg)
    lcd.drawFilledRectangle(q.x + d, q.y + d, q.b - 2 * d, q.h - 2 * d)
  end
end

local function zusatzText(w, q, Z, dez, eh, zeit)
  if q.zusatz == "keine" then return nil end
  local z = w.studio.zx[q.w]
  if z == nil then return nil end
  local x, vor = z[2], "MAX "
  if q.zusatz == "min" then x, vor = z[1], "MIN " elseif q.zusatz == "mittel" then x, vor = (z[4] > 0 and z[3] / z[4] or nil), "Ø " end
  if x == nil then return nil end
  return vor .. zahlText(Z, x, dez, eh, zeit)
end

-- Flugphase als Status: Name der Phase (sonst «Phase n») in der Farbe der Phase aus dem Menü
local function phaseTF(w, Z)
  local v, C = w.v, Z.C
  local nr = v.phase
  local t = v.phaseName or (nr and string.format(w.T.phaseNr, tostring(nr))) or nil
  local f = nr and Z.PHASE[w.cfg["fp" .. nr] or 1] or C.grau
  return t, f
end

-- steht die Einheit schon im Titel? Nur als eigenes Wort (wie Jet und Electric).
local function imTitel(titel, eh)
  if type(titel) ~= "string" or eh == "" then return false end
  local e = eh:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  return (" " .. titel .. " "):find("[%s%(%[]" .. e .. "[%s%)%]%%]") ~= nil
end
A.imTitel = imTitel

-- Platz, der in die Seitentasten unten reicht, einmal kürzen (gemerkt in q.kurzQ); zu niedrig: nicht zeichnen
local function gekuerzt(q, unten)
  if q.y + q.h <= unten then return q end
  local k = q.kurzQ
  if k == nil or k.unten ~= unten then
    k = {}
    for n, x in pairs(q) do if n ~= "kurzQ" and n ~= "fest" then k[n] = x end end
    k.h, k.unten = unten - q.y, unten
    q.kurzQ = k
  end
  if k.h < 24 then return nil end
  return k
end

-- Festes je Platz einmal rechnen (Befehlsgrenze in paint); neu bei anderer Sprache, Einheit oder Grösse.
-- Wird aus wakeup vorbereitet (A.vorbereiten), sonst beim ersten Zeichnen.
local function fest(w, L, Z, q, ST, eh, name)
  local C, h = Z.C, q.h
  local def = q.art == "lua" and ST.WERTE[q.s]
  local k = { sp = w.sp, eh0 = eh, s = L.s, def = def, zeit = def and def.zeit, u = def and def.u, titel = q.titel or name }
  k.th = min(18, max(9, h * 0.2))                   -- Titelhöhe in Pixeln
  k.pad = max(4, floor(8 * L.s))
  k.ohneEh = q.ohneEinheit or k.zeit or q.darst == "status" or (eh ~= "" and imTitel(k.titel, eh))
  k.lo = q.min or (def and def[4]) or 0
  k.hi = q.max or (def and def[5]) or 100
  if k.hi <= k.lo then k.hi = k.lo + 1 end
  k.uA, k.uW = k.u and (k.u .. "Alarm"), k.u and (k.u .. "Warn")
  k.fehltArt = q.art == "sensor" or q.art == "kanal"
  k.hg, k.fA, k.fW, k.fG = rgb(q.hintergrund, C.panel), rgb(q.farbeAlarm, C.rot), rgb(q.farbeWarn, C.orange), rgb(q.farbe, C.hblau)
  k.rand = max(2, floor(3 * L.s))
  if q.stufen then
    k.stufen = {}
    for j, e in ipairs(q.stufen) do k.stufen[j] = { e.ab, rgb(e.farbe) } end
  end
  q.fest = k
  return k
end

local function zeichnePlatz(w, L, Z, q, ST, i, unten)
  local C = Z.C
  q = gekuerzt(q, unten)
  if q == nil then return end
  local x0, y0, b, h = q.x, q.y, q.b, q.h
  if q.art == "leer" then lcd.color(rgb(q.hintergrund, C.panel)) lcd.drawFilledRectangle(x0, y0, b, h) return end
  local x, eh, dez, name = ST.wert(w, q.w, q.art, q.s, w.sp)
  local k = q.fest
  if k == nil or k.sp ~= w.sp or k.eh0 ~= eh or k.s ~= L.s then
    -- je Bild höchstens 3 Plätze neu vorbereiten (sonst macht es wakeup); der Rest steht ein Bild lang leer
    if (w.festBudget or 0) <= 0 then
      lcd.color(C.panel)
      lcd.drawFilledRectangle(x0, y0, b, h)
      w.festOffen = true
      return
    end
    w.festBudget = w.festBudget - 1
    k = fest(w, L, Z, q, ST, eh, name)
  end
  local zeit = k.zeit
  local st = w.studio.st[q.w]
  if k.u then st = w.v[k.uA] and 2 or (w.v[k.uW] and 1 or 0) end   -- überwacht: wie Seite FLUG
  local fg = farbeVon(q, k, st, x)
  kachel(q, k, st)
  local titel, th, pad, d = k.titel, k.th, k.pad, q.darst
  if k.ohneEh then eh = "" end
  local tx = pad                                        -- Titel links: Abstand vom Rand des Platzes
  local tb = max(8, b - tx - pad)                       -- Titel links: verfügbare Breite (nie negativ)
  local tcx = x0 + b / 2
  local fehlt = k.fehltArt and w.studio.quellen[q.w] == false
  local vz = (q.s == "vario" and x and x > 0.05) and "+" or ""
  local wert = fehlt and "---" or (x ~= nil and vz .. zahlText(Z, x, dez, eh, zeit) or nil)
  local zt = q.zusatz ~= "keine" and zusatzText(w, q, Z, dez, eh, zeit) or nil
  local lo, hi = k.lo, k.hi
  local anteil = x and max(0, min(1, (x - lo) / (hi - lo))) or nil

  if d == "status" then
    Z.text(L, x0 + tx, y0 + pad + th / 2, titel, gr(L, th), C.dim, LEFT, tb)
    local t, f = nil, C.grau
    if q.s == "flight_phase" then t, f = phaseTF(w, Z) end
    Z.wert(L, x0 + b / 2, y0 + (h + th) / 2 + pad / 2, t, gr(L, min(h * 0.4, 34)), f, CENTERED, b - 2 * pad)

  elseif d == "ring" then
    Z.text(L, tcx, y0 + pad + th / 2, titel, gr(L, th), st == 2 and fg or C.dim, CENTERED, tb)
    local zh = zt and th or 0
    local r = min(b * 0.42, (h - th - zh - 3 * pad) * 0.5)
    local cx, cy = x0 + b / 2, y0 + pad + th + pad + r
    local ri = max(2, r - max(4, r * 0.22))
    Z.bogen(cx, cy, ri, r, 225, 495, C.dunkel)
    if anteil and anteil > 0 then Z.bogen(cx, cy, ri, r, 225, 225 + anteil * 270, fg) end
    local zahl = fehlt and "---" or (x ~= nil and (zeit and Z.zeit(x) or (vz .. Z.zahl(x, dez))) or nil)
    Z.wert(L, cx, cy - r * 0.08, zahl, gr(L, r * 0.62), st and st > 0 and fg or C.weiss, CENTERED, 2 * ri - 4)
    if eh ~= "" then Z.text(L, cx, cy + r * 0.38, eh, gr(L, max(8, r * 0.2)), C.dim, CENTERED, 2 * ri - 4) end
    if zt then Z.text(L, cx, y0 + h - pad - th / 2, zt, gr(L, th), C.hblau, CENTERED, b - 2 * pad) end

  elseif d == "balken_w" then
    Z.text(L, x0 + tx, y0 + pad + th / 2, titel, gr(L, th), C.dim, LEFT, max(8, b * 0.5 - (tx - pad)))
    local bh = max(6, floor(h * 0.22))
    local by = y0 + h - pad - bh - (zt and th or 0)
    local vh = by - (y0 + pad + th) - pad
    Z.wert(L, x0 + b - pad, y0 + pad + th / 2 + max(0, vh - th) / 2, wert, gr(L, max(th, min(vh + th, 44))), fg, RIGHT, b * 0.55)
    Z.rechteck(x0 + pad, by, b - 2 * pad, bh, C.dunkel)
    if anteil and anteil > 0 then Z.rechteck(x0 + pad, by, max(2, (b - 2 * pad) * anteil), bh, fg) end
    if zt then Z.text(L, x0 + b - pad, y0 + h - pad - th / 2, zt, gr(L, th), C.hblau, RIGHT, b - 2 * pad) end

  elseif d == "balken_s" then
    Z.text(L, tcx, y0 + pad + th / 2, titel, gr(L, th), C.dim, CENTERED, tb)
    local vh = min(30, max(12, h * 0.16))
    local zh = zt and th or 0
    local bt = y0 + 2 * pad + th
    local bhoch = y0 + h - pad - vh - zh - pad - bt
    local bb = min(b * 0.4, 40)
    local bx = x0 + (b - bb) / 2
    if bhoch > 4 then
      Z.rechteck(bx, bt, bb, bhoch, C.dunkel)
      if anteil and anteil > 0 then local f = max(2, bhoch * anteil) Z.rechteck(bx, bt + bhoch - f, bb, f, fg) end
    end
    Z.wert(L, x0 + b / 2, y0 + h - pad - zh - vh / 2, wert, gr(L, vh), fg, CENTERED, b - 2 * pad)
    if zt then Z.text(L, x0 + b / 2, y0 + h - pad - th / 2, zt, gr(L, th), C.hblau, CENTERED, b - 2 * pad) end

  elseif d == "kurve" then
    Z.text(L, x0 + tx, y0 + pad + th / 2, titel, gr(L, th), C.dim, LEFT, max(8, b * 0.5 - (tx - pad)))
    Z.wert(L, x0 + b - pad, y0 + pad + th / 2, wert, gr(L, th * 1.3), fg, RIGHT, b * 0.48)
    local px, py, pb, ph = x0 + pad, y0 + 2 * pad + th, b - 2 * pad, h - 3 * pad - th - (zt and th or 0)
    if ph > 4 then
      Z.rechteck(px, py + ph, pb, 1, C.rand)
      local K = w.studio.kurven[i]
      if K and K.n > 0 then
        local n = K.voll and 120 or K.n
        -- Befehle in paint: höchstens 40 Linien je Kurve (jeder 2. bzw. 3. Punkt, der neueste immer)
        local sp = n > 80 and 3 or (n > 40 and 2 or 1)
        local dx, rng, p, basis = pb / 119, hi - lo, K.p, K.voll and K.n or 0
        lcd.color(fg)
        local lx, ly = nil, nil
        for j = (n - 1) % sp + 1, n, sp do
          local v = p[(basis + j - 1) % 120 + 1]                  -- älteste zuerst
          if v then
            local a = (v - lo) / rng
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            local sx, sy = floor(px + (120 - n + j - 1) * dx), floor(py + ph - a * ph)
            if lx then lcd.drawLine(lx, ly, sx, sy) end
            lx, ly = sx, sy
          else
            lx = nil
          end
        end
      end
    end
    if zt then Z.text(L, x0 + b - pad, y0 + h - pad - th / 2, zt, gr(L, th), C.hblau, RIGHT, b - 2 * pad) end

  else                                                   -- "zahl"
    Z.text(L, x0 + tx, y0 + pad + th / 2, titel, gr(L, th), st == 2 and fg or C.dim, LEFT, tb)
    local vy = y0 + pad + th + (h - 2 * pad - th - (zt and th or 0)) / 2
    Z.wert(L, x0 + b - pad, vy, wert, gr(L, min(h * 0.42, 52)), fg, RIGHT, b - 2 * pad)
    if zt then Z.text(L, x0 + b - pad, y0 + h - pad - th / 2, zt, gr(L, th), C.hblau, RIGHT, b - 2 * pad) end
  end

  -- antippbar: Starts öffnet die Seite STARTS, die Arbeitszeit die Seite F3K
  if q.w == "lua:launches" then Z.ziel(w, "s3", x0, y0, b, h)
  elseif q.w == "lua:f3k_working_time" then Z.ziel(w, "s2", x0, y0, b, h) end
end

-- Schmuck (Format 2 §3.4, ohne Symbole): nach dem Hintergrund, vor den Plätzen; Farbe fest
local function deko(L, Z, liste)
  local C = Z.C
  for _, e in ipairs(liste) do
    local f = e.fc
    if f == nil then f = rgb(e.farbe, C.dim) e.fc = f end
    if e.art == "text" then
      Z.text(L, e.x, e.y + e.h / 2, e.text, gr(L, e.h * 0.8), f, LEFT, e.b)
    elseif e.art == "linie" then
      lcd.color(f)
      lcd.drawLine(e.x, e.y, e.x + e.b, e.y + e.h)
    elseif e.art == "rahmen" then
      lcd.color(f)
      lcd.drawRectangle(e.x, e.y, e.b, e.h)
    end
  end
end

-- Aus wakeup: Festes von höchstens n Plätzen vorbereiten (damit das erste Bild nicht über die Befehlsgrenze kommt)
function A.vorbereiten(w, L, Z, ans, ST, n)
  for _, q in ipairs(ans.plaetze) do
    if n <= 0 then return false end
    local k = q.fest
    if q.art ~= "leer" then
      local _, eh, _, name = ST.wert(w, q.w, q.art, q.s, w.sp)
      if k == nil or k.sp ~= w.sp or k.eh0 ~= eh or k.s ~= L.s then fest(w, L, Z, q, ST, eh, name) n = n - 1 end
    end
  end
  return true
end

function A.zeichne(w, L, Z, ans, ST)
  local unten = Z.tasten(w, L) - L.gp              -- Seitentasten FLUG / F3K / STARTS bleiben unten (reserviert)
  if ans.deko then
    local ok, e = pcall(deko, L, Z, ans.deko)
    if not ok and not w.dekoFehler then
      w.dekoFehler = true
      print(tostring(w.name) .. ": Fehler beim Zeichnen des Schmucks: " .. tostring(e))
    end
  end
  local P = ans.plaetze
  local i = 1
  w.festBudget, w.festOffen = 3, false
  while i <= #P do                                 -- ein pcall für alle Plätze; nach einem Fehler weiter mit dem nächsten
    local ok, e = pcall(function()
      while i <= #P do
        zeichnePlatz(w, L, Z, P[i], ST, i, unten)
        i = i + 1
      end
    end)
    if not ok then
      if not w.platzFehler then
        w.platzFehler = true
        print(tostring(w.name) .. ": Fehler beim Zeichnen von " .. tostring(P[i] and P[i].w) .. ": " .. tostring(e))
      end
      i = i + 1
    end
  end
  if w.festOffen and lcd.invalidate then lcd.invalidate() end   -- fehlende Plätze im nächsten Bild
end

return A
