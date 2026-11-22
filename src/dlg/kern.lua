-- DLG: Kern des Widgets. Liest die gewählten Quellen, rechnet Höchstwerte und Warnungen und ruft die Seite
-- zum Zeichnen. Alles Rechnen passiert in wecke(), zeichne() zeichnet nur.
-- Absturzsicher: jeder Wert wird geprüft (nil, Text, NaN, unendlich, riesig), jede Ethos-Abfrage läuft in pcall.
-- Inhalt: Flug- und Wurferkennung (Wurfhöhe), Flugphase, F3K-Aufgaben mit Arbeitszeit und Wertung, Startliste,
-- Höhe, Vario (nur Anzeige: kein Vario-Ton, kein Thermik-Hinweis), Empfänger-Akku und Empfang mit Warnung/Alarm.
local K = {}
local Z = nil          -- zeichnen.lua
local SEITE = {}       -- geladene Seite (immer nur die sichtbare)
local SEITEN = 3       -- Zahl der Seiten (seite1.lua … seiteN.lua); Wisch links/rechts blättert

local TEST = nil  -- TESTHAKEN: der Simulator-Ablauf ersetzt genau diese Zeile (bauplan.md, Abschnitt Testhaken)
local ZUSTAND = nil  -- testzustand.lua, nur geladen mit TEST.zustand im Simulator
local STUDIO = nil   -- studio.lua (Lua-Studio-Format 2 ohne Symbole): nur geladen, solange eine Studio-Datei gilt oder geladen wird
local ANSICHT = nil  -- ansicht.lua: zeichnet die Plätze einer Studio-Ansicht (nur Seite FLUG)
local STUDIO_HINWEIS_S = 8   -- s: so lange steht ein Studio-Hinweis in der Meldezeile, danach bleibt oben rechts ein «!»
local WIDGETS = setmetatable({}, { __mode = "k" })   -- alle Instanzen des Widgets (schwach: entfernte fallen weg)

local DT_LESEN = 0.2   -- s: Werte lesen und rechnen
local DT_BILD = 0.2    -- s: Bild höchstens so oft auffrischen
local AN_S = 1.0       -- s: so lange muss eine Bedingung gelten, bis die Warnung kommt
local AUS_S = 3.0      -- s: so lange muss sie weg sein, bis die Warnung geht
local ANSAGE_ABSTAND = 3.0
local DAUER_S = 60     -- s: dauerhafte Werte höchstens so oft in die Datei schreiben
local SLOP = 14        -- Pixel: ab hier gilt eine Bewegung als Wisch
local GROSS = 1e7      -- Werte darüber gelten als unplausibel
-- Glaubhafter Bereich je Messwert: was ausserhalb liegt, gilt als «kein Wert» (Strich) und wird nie zum Tiefst-
-- oder Höchstwert. Für jeden neuen Messwert eine Zeile, in der Einheit des Sensors.
local BEREICH = { h = { -500, 5000 }, vs = { -60, 60 }, rx = { 0, 30 }, lq = { 0, 120 } }
local MIN_W, MIN_H = 400, 250   -- kleineres Feld: nur Hinweis «nur im Vollbild»

local floor, abs = math.floor, math.abs
local MAX_STARTS = 50
local WURF_MAX_S = { 6, 15, 15 }   -- s: spätestens dann endet der Wurf (automatisch / Schalter / Flugphase)
local RUHIG_S = 5                  -- s: so lange ruhig unter «Landung unter Höhe», dann gilt der Flug als beendet

-- F3K-Aufgaben nach FAI Sporting Code Volume F3, Ausgabe 2025, F3K.11. az = Arbeitszeit (s), art: «letzte» n,
-- «beste» n, «ziele» der Reihe nach, «h» = vier längste auf 240/180/120/60 s, «alle» (C), «poker» (keine Wertung).
local AUFGABEN = {
  { "A", 420, "letzte", 1, 300 }, { "A", 600, "letzte", 1, 300 }, { "B", 600, "letzte", 2, 240 },
  { "B", 420, "letzte", 2, 180 }, { "C", nil, "alle", 5, 180, 5 }, { "D", 600, "beste", 2, 300, 2 },
  { "E", 600, "poker" }, { "E", 900, "poker" }, { "F", 600, "beste", 3, 180, 6 }, { "G", 600, "beste", 5, 120 },
  { "H", 600, "h", 4, nil, nil, { 240, 180, 120, 60 } }, { "I", 600, "beste", 3, 200 }, { "J", 600, "letzte", 3, 180 },
  { "K", 600, "ziele", 5, nil, 5, { 60, 90, 120, 150, 180 } }, { "L", 600, "beste", 1, 599, 1 },
  { "M", 900, "ziele", 3, nil, 3, { 180, 300, 420 } }, { "N", 600, "beste", 1, 599 },
}
K.AUFGABEN = AUFGABEN

-- Feste Ansagen der Flugphasen (Sprachdatei, Wortteile im Namen der Ethos-Flugphase, klein, deutsch und englisch).
-- Reihenfolge wie die Auswahl «Ansage Phase n» in felder.lua (1 … 7; 0 = automatisch, 8 = aus).
local PHASEN = {
  { "phase_start", { "start", "launch" } }, { "phase_zoom", { "zoom" } }, { "phase_speed", { "speed", "schnell" } },
  { "phase_thermik", { "therm" } }, { "phase_strecke", { "strecke", "cruise", "reise" } },
  { "phase_landung", { "land" } }, { "phase_normal", { "normal" } },
}
local function phaseWav(name)
  if type(name) ~= "string" then return nil end
  local n = string.lower(name)
  for _, p in ipairs(PHASEN) do
    for _, t in ipairs(p[2]) do
      if n:find(t, 1, true) then return p[1] end
    end
  end
  return nil
end
K.phaseWav = phaseWav

local function lade(datei)
  local f, e = loadfile(datei)
  if not f then error(e, 0) end
  return f()
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

-- Zahl prüfen: nil bei nil, Text, NaN, unendlich oder unplausibel gross.
local function gut(v)
  if type(v) ~= "number" or v ~= v or v > GROSS or v < -GROSS then return nil end
  return v
end

-- Wert einer Quelle als Zahl, sonst nil. Fehler der Quelle werden geschluckt.
-- Optionen (z. B. einzelne Zelle) nur als Tabelle: q:value(OPTION_…) liefert die Gesamtspannung (gemessen 26.1.2).
local function zahl(q, opt)
  if q == nil then return nil end
  local ok, v
  if opt ~= nil then ok, v = pcall(q.value, q, { options = opt }) else ok, v = pcall(q.value, q) end
  if not ok then return nil end
  return gut(v)
end

-- Schalter oder Kanal aktiv (über der Mitte)? nil = keine Quelle oder kein Wert.
local function aktiv(q)
  local v = zahl(q)
  if v == nil then return nil end
  return v > 0
end

local function einheit(q)
  if q == nil then return "" end
  local ok, e = pcall(q.stringUnit, q)
  if ok and type(e) == "string" then return e end
  return ""
end

local function stellen(q, sonst)
  if q == nil then return sonst end
  local ok, d = pcall(q.decimals, q)
  if ok and type(d) == "number" and d >= 0 and d <= 3 then return floor(d) end
  return sonst
end

-- Sprache: 1 = Deutsch, 2 = English. Einstellung 0 heisst «wie der Sender» (deutsch nur bei deutschem Sender).
-- Lädt die Texte der Sprache nach w.T, wenn sie sich geändert hat.
local SENDER = nil
local function sprache(w)
  local sp = w.cfg.sprache
  if sp ~= 1 and sp ~= 2 then
    if SENDER == nil then
      SENDER = 2
      if system.getLocale then
        local ok, l = pcall(system.getLocale)
        if ok and type(l) == "string" and l:sub(1, 2):lower() == "de" then SENDER = 1 end
      end
    end
    sp = SENDER
  end
  if w.sp ~= sp or w.T == nil then
    w.sp = sp
    w.T = lade("texte.lua")(sp)
    w.hinweis = nil
  end
end

-- Sprachdatei abspielen: audio/de/<name>.wav oder audio/en/<name>.wav. Gibt false zurück, wenn die Datei fehlt
-- (system.playFile bleibt dann still und meldet nichts; darum vorher nachsehen und das Ergebnis merken).
local AUDIO_DA = {}
local function sage(w, name)
  if not system.playFile then return false end
  local pfad = "audio/" .. (w.sp == 1 and "de" or "en") .. "/" .. name .. ".wav"
  local da = AUDIO_DA[pfad]
  if da == nil then
    local ok, f = pcall(io.open, pfad, "r")
    da = (ok and f ~= nil) or false
    if da then pcall(f.close, f) end
    AUDIO_DA[pfad] = da
  end
  if da then pcall(system.playFile, pfad) end
  return da
end

-- Nummer der Einheit (UNIT_…) für die Zahlenansage, sonst der Ersatz.
local function einheitNr(q, sonst)
  if q == nil then return sonst end
  local ok, e = pcall(q.unit, q)
  if ok and type(e) == "number" then return e end
  return sonst
end

-- Wert nur, wenn er im glaubhaften Bereich liegt.
local function imBereich(k, x)
  local b = BEREICH[k]
  if x == nil or (b and (x < b[1] or x > b[2])) then return nil end
  return x
end

-- Grenzwerte aus den Einstellungen als Zahlen; nil = nicht gesetzt (Warnung aus).
-- Zahlen mit Kommastellen sind als ganze Zahl gespeichert (Teiler 10 bei einer Kommastelle).
local function grenzen(w)
  local c, g = w.cfg, w.g
  if TEST and TEST.cfg and not w.testCfg then
    w.testCfg = true
    for k, x in pairs(TEST.cfg) do c[k] = x end
  end
  local function gz(k, teiler)
    local x = gut(c[k])
    if x and x > 0 then return x / (teiler or 1) end
    return nil
  end
  g.hWarn, g.hAlarm = gz("hWarn"), gz("hAlarm")
  g.rxWarn, g.rxAlarm = gz("rxWarn", 10), gz("rxAlarm", 10)
  g.lqWarn, g.lqAlarm = gz("lqWarn"), gz("lqAlarm")
  g.wurfV = (gut(c.wurfV) or 40) / 10
  g.pause = gut(c.pause) or 30
  sprache(w)
end

function K.neu()
  local F = lade("felder.lua")
  local w = {
    cfg = F.standard(), g = {}, v = {}, eh = {}, dz = {}, un = {},
    meld = {}, aktiv = {}, nAktiv = 0, stufe = 0, zustand = "keine", meldText = "",
    seite = 1, ziele = {}, nZiele = 0,
    dauer = {},            -- dauerhafte Werte (Datei daten/<Modell>.txt): nur der User setzt sie zurück
    gelesen = false, autoOffen = true, version = K.VERSION, name = K.NAME,
    liste = {}, anQ = {}, f3k = { fl = {} }, oben = 0, K = K,
  }
  WIDGETS[w] = true
  grenzen(w)
  if CATEGORY_SYSTEM_EVENT and SYSTEM_EVENT_TELEMETRY_ACTIVE then
    local ok, q = pcall(system.getSource, { category = CATEGORY_SYSTEM_EVENT, member = SYSTEM_EVENT_TELEMETRY_ACTIVE })
    if ok then w.qTele = q end
  end
  if CATEGORY_FLIGHT then                          -- aktive Flugphase des Modells
    local m = FLIGHT_CURRENT_MODE or CURRENT_FLIGHT_MODE
    if m ~= nil then
      local ok, q = pcall(system.getSource, { category = CATEGORY_FLIGHT, member = m })
      if ok then w.qPhase = q end
    end
  end
  return w
end

-- Läuft die Telemetrie? Ohne Auskunft von Ethos gilt sie als vorhanden.
local function telemetrie(w)
  local q = w.qTele
  if q == nil then return true end
  local ok, v = pcall(q.value, q)
  if not ok then return true end
  if type(v) == "number" then return v > 0 end
  if type(v) == "boolean" then return v end
  return true
end

local function hinweis(w, text, now)
  w.hinweis = text
  w.hinweisBis = now + 3
end

-- Tiefst- und Höchstwerte führen; true, wenn sich etwas geändert hat.
local function hoeher(t, k, x)
  if x and (t[k] == nil or x > t[k]) then t[k] = x return true end
  return false
end
local function tiefer(t, k, x)
  if x and (t[k] == nil or x < t[k]) then t[k] = x return true end
  return false
end

-- Werte lesen. Ohne Telemetrie gibt es keine Messwerte (nil = Strich in der Anzeige); Flugphase und Schalter
-- kommen vom Sender und gelten immer.
local function lesen(w, now)
  local c, v, d = w.cfg, w.v, w.dauer
  v.tele = telemetrie(w)
  v.h = v.tele and zahl(c.hoehe) or nil
  v.vs = v.tele and zahl(c.vario) or nil
  v.rx = v.tele and zahl(c.rx) or nil
  v.lq = v.tele and zahl(c.lq) or nil
  v.swStart, v.swLand, v.swWurf, v.swAz = aktiv(c.swStart), aktiv(c.swLand), aktiv(c.swWurf), aktiv(c.swAz)
  local q = w.qPhase
  v.phase, v.phaseName = nil, nil
  if q then
    local n = zahl(q)
    if n then v.phase = floor(n + 0.5) + 1 end
    local ok, t = pcall(q.stringValue, q)
    if ok and type(t) == "string" and t ~= "" then v.phaseName = t end
  end
  if TEST and (TEST.v or TEST.ohne or TEST.tele ~= nil or TEST.folge) then   -- nur TEST.zustand: echte Werte bleiben
    v.tele = TEST.tele ~= false
    for k, x in pairs(TEST.v or {}) do v[k] = x end
    if TEST.folge then                             -- Ablauf über die Zeit: { { ab Sekunde, { Werte } }, … }
      w.tTest0 = w.tTest0 or now
      local el = now - w.tTest0
      for _, e in ipairs(TEST.folge) do
        if el >= e[1] then for k, x in pairs(e[2]) do v[k] = x end end
      end
    end
    for _, k in ipairs(TEST.ohne or {}) do v[k] = nil end
  end
  if TEST and TEST.liste and not w.testListe then  -- Testhaken: vorgefüllte Startliste { { Wurfhöhe, Flugzeit, Höhe } }
    w.testListe, w.liste = true, {}
    for i, e in ipairs(TEST.liste) do w.liste[i] = { wurf = e[1], t = e[2], hmax = e[3] } end
  end
  v.h, v.vs, v.rx, v.lq = imBereich("h", v.h), imBereich("vs", v.vs), imBereich("rx", v.rx), imBereich("lq", v.lq)
  if v.tele then w.teleWar = true end
  if v.tele then
    local neu = tiefer(d, "rxMin", (v.rx and v.rx > 0.5) and v.rx or nil)
    neu = tiefer(d, "lqMin", (v.lq and v.lq > 0) and v.lq or nil) or neu
    if neu then w.dauerNeu = true end
  end
end

-- Einheiten und Kommastellen der Sensoren (alle 2 s).
local function liesEinheiten(w)
  local c, eh, dz = w.cfg, w.eh, w.dz
  eh.h, eh.vs, eh.rx, eh.lq = einheit(c.hoehe), einheit(c.vario), einheit(c.rx), einheit(c.lq)
  dz.h, dz.vs, dz.rx, dz.lq = 0, stellen(c.vario, 1), stellen(c.rx, 1), 0
  w.un.h, w.un.rx, w.un.lq = einheitNr(c.hoehe, UNIT_METER), einheitNr(c.rx, UNIT_VOLT), einheitNr(c.lq, UNIT_PERCENT)
  local ok, n = pcall(model.name)                -- oben rechts steht der Modellname, nicht der Name des Skripts
  w.modell = (ok and type(n) == "string" and n ~= "") and n or nil
end

-- Eine Warnung führen: kommt nach AN_S, geht nach AUS_S (so flattert sie an der Grenze nicht).
-- wert/einh/dez: Wert, den Ethos nach dem Text ansagt.
local function melde(w, now, name, stufe, bed, text, wav, wert, einh, dez)
  local m = w.meld[name]
  if m == nil then
    m = { an = false, name = name }
    w.meld[name] = m
  end
  m.text = text
  if bed then
    m.weg = nil
    if not m.an then
      m.seit = m.seit or now
      if now - m.seit >= AN_S then
        m.an = true
        m.tAns = nil
      end
    end
  else
    m.seit = nil
    if m.an then
      m.weg = m.weg or now
      if now - m.weg >= AUS_S then m.an = false end
    end
  end
  if m.an then
    m.stufe, m.wav, m.wert, m.einh, m.dez = stufe, wav, wert, einh, dez
    w.nAktiv = w.nAktiv + 1
    w.aktiv[w.nAktiv] = m
  end
  return m.an
end

-- Ist der Alarm eines Werts an, fällt dessen Warnung weg: Warnung -> Alarm.
local PAAR = { hW = "hA", rxW = "rxA", lqW = "lqA" }

local function warnungen(w, now)
  local v, g, T = w.v, w.g, w.T
  w.nAktiv = 0
  local d = v.tele
  local ha = d and g.hAlarm and v.h and v.h > g.hAlarm
  v.hAlarm = melde(w, now, "hA", 2, ha, T.hHoch, "hoehe_alarm", v.h, w.un.h, 0)
  v.hWarn = melde(w, now, "hW", 1, d and not ha and g.hWarn and v.h and v.h > g.hWarn, T.hHoch, "hoehe_hoch", v.h, w.un.h, 0)
  local ra = d and g.rxAlarm and v.rx and v.rx < g.rxAlarm
  v.rxAlarm = melde(w, now, "rxA", 2, ra, T.rxTief, "rxakku_alarm", v.rx, w.un.rx, w.dz.rx)
  v.rxWarn = melde(w, now, "rxW", 1, d and not ra and g.rxWarn and v.rx and v.rx < g.rxWarn, T.rxTief, "rxakku_tief",
    v.rx, w.un.rx, w.dz.rx)
  local la = d and g.lqAlarm and v.lq and v.lq < g.lqAlarm
  v.lqAlarm = melde(w, now, "lqA", 2, la, T.lqTief, "empfang_alarm", v.lq, w.un.lq, 0)
  v.lqWarn = melde(w, now, "lqW", 1, d and not la and g.lqWarn and v.lq and v.lq < g.lqWarn, T.lqTief, "empfang_schwach",
    v.lq, w.un.lq, 0)
  melde(w, now, "tele", 1, w.teleWar and not d, T.teleWeg, "telemetrie_weg")
  if w.studio and STUDIO then                    -- Grenzen der Studio-Datei für Sensoren, Kanäle, weitere Werte
    STUDIO.grenzenExtra(w, now, melde, d)
  end

  local n = 0
  for i = 1, w.nAktiv do
    local m = w.aktiv[i]
    local alarm = PAAR[m.name] and w.meld[PAAR[m.name]]
    if not (alarm and alarm.an) then
      n = n + 1
      w.aktiv[n] = m
    end
  end
  w.nAktiv = n

  -- höchste Stufe und Text der Meldezeile (Alarme zuerst)
  local st = 0
  for i = 1, n do
    if w.aktiv[i].stufe > st then st = w.aktiv[i].stufe end
  end
  w.stufe = st
  if n > 0 then
    local t = nil
    for s = 2, 1, -1 do
      for i = 1, n do
        local m = w.aktiv[i]
        if m.stufe == s then t = t and (t .. "  |  " .. m.text) or m.text end
      end
    end
    w.meldText = t
  end

  if st == 2 then
    w.zustand = "alarm"
  elseif st == 1 then
    w.zustand = "warnung"
  elseif not d or (v.h == nil and v.vs == nil and v.rx == nil and v.lq == nil) then
    w.zustand = "keine"
  else
    w.zustand = "ok"
  end
end

-- Ansage und Vibration: sofort beim Auftreten, danach alle «Wiederholung» Sekunden; Alarme gehen vor.
-- Zwei Stufen: Warnung (orange) zeigt nur an, Alarm (rot) meldet sich mit Ton oder Ansage. Wer die Warnung auch
-- hören will, schaltet «Warnung auch ansagen» ein. Fehlt die Sprachdatei, kommt ein Ton.
local function ansage(w, wav, wert, einh, dez)
  if #w.anQ >= 4 then return end
  w.anQ[#w.anQ + 1] = { wav = wav, wert = wert, einh = einh, dez = dez }
end

local function ansagen(w, now)
  if w.tAnsage and now - w.tAnsage < ANSAGE_ABSTAND then return end
  local c = w.cfg
  local wahl = nil
  for i = 1, w.nAktiv do
    local m = w.aktiv[i]
    if (m.stufe == 2 or c.warnAnsage) and (m.tAns == nil or now - m.tAns >= w.g.pause)
      and (wahl == nil or m.stufe > wahl.stufe) then
      wahl = m
    end
  end
  if wahl == nil then                             -- keine Warnung fällig: Ereignis-Ansagen der Reihe nach
    local e = table.remove(w.anQ, 1)
    if e == nil then return end
    w.tAnsage, w.anLetzt = now, e.wav
    w.nAnsage = (w.nAnsage or 0) + 1
    if e.wav and not sage(w, e.wav) and system.playTone then pcall(system.playTone, 1200, 120, 40) end
    if e.wert and e.einh and system.playNumber then pcall(system.playNumber, e.wert, e.einh, e.dez or 0) end
    return
  end
  wahl.tAns, w.tAnsage = now, now
  -- Studio-Datei: Ansage und Vibration je Wert (ansage = false heisst nur Ton, Format 2 §7.5)
  local key, S = wahl.name:sub(1, -2), w.studio
  local sprechen, vib = c.ansage, c.vibration
  if S and S.gAns[key] == false then sprechen = false end
  if S and S.gVib[key] ~= nil then vib = S.gVib[key] end
  if c.ansage then
    if not (sprechen and wahl.wav and sage(w, wahl.wav)) and system.playTone then
      pcall(system.playTone, wahl.stufe == 2 and 2200 or 1500, 180, 60)
    end
    local x = wahl.wert
    if x and S and STUDIO and STUDIO.UEBERWACHT[key] then   -- angepassten Wert der Studio-Datei ansagen
      local a = S.werte["lua:" .. STUDIO.UEBERWACHT[key][1]]
      if a then x = x * a.faktor + a.versatz end
    end
    if sprechen and c.zahl and x and wahl.einh and system.playNumber then
      pcall(system.playNumber, x, wahl.einh, wahl.dez or 0)
    end
  end
  if vib and wahl.stufe == 2 and system.playHaptic then pcall(system.playHaptic, "- . -") end
end

-- F3K-Wertung: gewertete Sekunden je Flug (false = zählt nicht) und Summe; Poker (E) ohne Wertung (nil).
local function wertung(a, fl, zl)
  local art, n, mx, ziele = a[3], a[4], a[5], a[7]
  local sc, sum = {}, 0
  for i = 1, #fl do sc[i] = false end
  if art == "poker" then                           -- E: angesagte Zielzeit erreicht = Zielzeit zählt, höchstens 3 Ziele
    local k = 0
    for i = 1, #fl do
      local z = zl and zl[i]
      if z and k < 3 and fl[i] >= z - 0.05 then sc[i], sum, k = z, sum + z, k + 1 end
    end
    return sc, sum
  end
  local function nimm(i, grenze)
    local x = fl[i]
    if grenze and x > grenze then x = grenze end
    sc[i], sum = x, sum + x
  end
  if art == "letzte" then
    for i = math.max(1, #fl - n + 1), #fl do nimm(i, mx) end
  elseif art == "alle" then
    for i = 1, math.min(#fl, n) do nimm(i, mx) end
  elseif art == "ziele" then
    for i = 1, math.min(#fl, #ziele) do nimm(i, ziele[i]) end
  else                                             -- «beste» und «h»: die längsten Flüge
    local idx = {}
    for i = 1, #fl do idx[i] = i end
    table.sort(idx, function(x, y) return fl[x] > fl[y] end)
    for k = 1, math.min(n, #idx) do nimm(idx[k], art == "h" and ziele[k] or mx) end
  end
  return sc, sum
end
K.wertung = wertung

local function aufgabe(w)
  return AUFGABEN[w.cfg.aufgabe or 1] or AUFGABEN[1]
end

-- Arbeitszeit starten (neue Runde, die Flüge der letzten Runde fallen weg) oder beenden.
local function f3kStart(w, now)
  local a = aufgabe(w)
  w.f3k = { an = true, rest = a[2], t0 = now, fl = {}, zl = {}, starts = 0, treffer = 0, nr = w.cfg.aufgabe or 1, tSp = now }
  if w.flug then w.flug.f3k = nil end              -- ein schon laufender Flug zählt nicht
  ansage(w, "arbeitszeit_start")
end
local function f3kStopp(w)
  local f = w.f3k
  if f.an then f.an, f.ende = false, true end
  if w.flug and w.flug.f3k and w.flug.tF3k == nil then w.flug.tF3k = w.flug.t end
end

-- Arbeitszeit rückwärts, Ansagen: jede volle Minute, die letzten 10 s zählen, am Ende «Arbeitszeit vorbei».
local function f3kLauf(w, now, dt)
  local f, c = w.f3k, w.cfg
  if not f.an then return end
  if now - (f.tSp or now) >= 30 then f.tSp, w.dateiOffen = now, true end   -- laufende Runde alle 30 s sichern
  f.tSp = f.tSp or now
  if f.rest == nil then                            -- Aufgabe C: keine Arbeitszeit, zählt vorwärts
    f.lauf = now - f.t0
    return
  end
  local alt = f.rest
  f.rest = math.max(0, f.rest - dt)
  if c.ansAz then
    local m0, m1 = math.ceil(alt / 60), math.ceil(f.rest / 60)
    if m1 < m0 and m1 >= 1 and f.rest > 10 then ansage(w, "arbeitszeit", m1, UNIT_MINUTE or UNIT_SECOND, 0) end
    local s0, s1 = math.ceil(alt), math.ceil(f.rest)
    if s1 < s0 and s1 >= 1 and s1 <= 10 and system.playNumber then pcall(system.playNumber, s1, UNIT_RAW or 0, 0) end
  end
  if f.rest <= 0 then
    f3kStopp(w)
    ansage(w, "arbeitszeit_ende")
  end
end

local function flugStart(w, now)
  local v = w.v
  local f = { t = 0, hmax = v.h, wurf = nil, w = { peak = v.h, t = 0 }, ruhig = 0 }
  local k = w.f3k
  local a = aufgabe(w)
  local maxS = a[1] == "C" and (w.cfg.cStarts or 5) or a[6]
  if k.an and not (maxS and k.starts >= maxS) then
    k.starts = k.starts + 1
    f.f3k = true
    if a[3] == "poker" and (k.treffer or 0) < 3 and not k.wFertig then   -- Zielzeit beim Wurf festlegen und ansagen
      if not k.zielFest then
        k.zielAkt = k.zielW and -1 or (w.cfg.pokerZiel or 60)
        k.zielFest = true
      end
      f.ziel = k.zielAkt == -1 and k.rest or k.zielAkt
      f.zielW = k.zielAkt == -1
      if f.ziel then ansage(w, "zielzeit", floor(f.ziel + 0.5), UNIT_SECOND, 0) end
    end
  end
  w.flug = f
  w.dateiOffen = true
  if STUDIO and w.studio then STUDIO.flugNeu(w) end   -- Min/Max/Mittel der Studio-Plätze je Flug
end

local function wurfEnde(w, f, now)
  local x = f.w and f.w.peak
  f.w = nil
  if x == nil then return end
  f.wurf = x
  if w.cfg.ansWurf then ansage(w, "wurfhoehe", floor(x + 0.5), w.un.h or UNIT_METER, 0) end
  w.dateiOffen = true
end

local function flugEnde(w, now)
  local f = w.flug
  if f == nil then return end
  if f.w then wurfEnde(w, f, now) end
  w.flug = nil
  if f.f3k then
    local t = f.tF3k and math.min(f.t, f.tF3k) or f.t
    local fl = w.f3k.fl
    fl[#fl + 1] = floor(t * 10 + 0.5) / 10
    local k = w.f3k
    k.zl = k.zl or {}
    k.zl[#fl] = f.ziel or false
    if f.ziel then
      if t >= f.ziel - 0.05 then k.treffer, k.zielFest = (k.treffer or 0) + 1, false end
      if f.zielW then k.wFertig, k.zielW = true, false end    -- «Ende Arbeitszeit»: nur ein Versuch
    end
    local a = aufgabe(w)
    if a[2] == nil and #fl >= (w.cfg.cStarts or 5) then f3kStopp(w) end   -- C: Runde nach dem letzten Flug zu Ende
  end
  local L = w.liste
  L[#L + 1] = { wurf = f.wurf, t = f.t, hmax = f.hmax }
  while #L > MAX_STARTS do table.remove(L, 1) end
  if w.cfg.ansFlug then ansage(w, "flugzeit", floor(f.t + 0.5), UNIT_SECOND, 0) end
  hinweis(w, string.format(w.T.startGespeichert, tostring(#L)), now)
  w.dateiOffen, w.dateiJetzt = true, true
end

-- Start, Wurf, Landung. Start: Steigen über «Wurf ab Steigen» oder Schalter. Wurf endet je nach Einstellung beim
-- ersten Sinken, wenn der Schalter (Snapflap) wieder aus ist oder die gewählte Flugphase verlassen wird; spätestens
-- nach WURF_MAX_S. Wurfhöhe = höchster Punkt vom Wurf bis dahin. Landung: unter «Landung unter Höhe» und ruhig
-- RUHIG_S Sekunden, oder Schalter.
local function flugLogik(w, now, dt)
  local c, v, g = w.cfg, w.v, w.g
  local h = v.h
  local f = w.flug
  if f == nil then
    local los
    if c.startArt == 2 then los = v.swStart and w.swStartAlt == false
    else los = v.tele and v.vs ~= nil and v.vs >= g.wurfV end
    if los then
      flugStart(w, now)
      f = w.flug
    end
  end
  w.swStartAlt = v.swStart
  if f == nil then
    w.swLandAlt = v.swLand
    return
  end
  f.t = f.t + dt
  if h and (f.hmax == nil or h > f.hmax) then f.hmax = h end
  local ww = f.w
  if ww then
    ww.t = ww.t + dt
    if h and (ww.peak == nil or h > ww.peak) then ww.peak = h end
    local art, ende = c.wurfEnde or 1, false
    if art == 2 then
      if v.swWurf then ww.an = true end
      ende = ww.an and v.swWurf == false
    elseif art == 3 then
      if v.phase == c.wurfPhase then ww.an = true end
      ende = ww.an and v.phase ~= nil and v.phase ~= c.wurfPhase
    else
      ende = ww.t >= 0.5 and v.vs ~= nil and v.vs < 0
    end
    if ende or ww.t >= WURF_MAX_S[art] or WURF_MAX_S[art] == nil then wurfEnde(w, f, now) end
  end
  if c.landArt == 2 then
    if v.swLand and w.swLandAlt == false then flugEnde(w, now) end
  elseif f.t >= 3 then
    local ruhig = h and h < (c.endH or 2) and (v.vs == nil or abs(v.vs) < 0.5)
    f.ruhig = ruhig and (f.ruhig or 0) + dt or 0
    if f.ruhig >= RUHIG_S then flugEnde(w, now) end
  end
  w.swLandAlt = v.swLand
end

-- Phasenwechsel ansagen: feste Ansage nach dem Namen der Phase (oder nach Wahl im Menü), sonst «Flugphase» + Nummer.
local function phasen(w)
  local p = w.v.phase
  if p ~= nil and w.phaseAlt ~= nil and p ~= w.phaseAlt and w.cfg.ansPhase then
    local wahl = w.cfg["pa" .. p] or 0
    if wahl ~= 8 then
      local wav = (wahl >= 1 and wahl <= #PHASEN) and PHASEN[wahl][1] or phaseWav(w.v.phaseName)
      if wav then ansage(w, wav) else ansage(w, "flugphase", p, UNIT_RAW or 0, 0) end
    end
  end
  if p ~= nil then w.phaseAlt = p end
end

-- Start löschen (nr = Platz in der Liste). Spätere Nummern rücken lückenlos nach.
local function loesche(w, nr, now)
  if not w.liste[nr] then return end
  table.remove(w.liste, nr)
  hinweis(w, string.format(w.T.startGeloescht, tostring(nr)), now)
  w.dateiOffen, w.dateiJetzt = true, true
end
K.loesche = loesche

-- «JA, ALLE LÖSCHEN»: einzige Stelle, an der Startliste und Tiefstwerte gelöscht werden.
local function zurueck(w, now)
  w.liste, w.dauer = {}, {}
  hinweis(w, w.T.zurueckgesetzt, now)
  w.dateiOffen, w.dateiJetzt = true, true
end

-- Testhaken: Zustand alle 0,5 s als JSON in test-zustand.json (nur Simulator, nur mit TEST.zustand).
local function testZustand(w, now)
  if now - (w.tZustand or -10) < 0.5 then return end
  w.tZustand = now
  if ZUSTAND == nil then
    local ok, v = pcall(system.getVersion)
    if not (ok and type(v) == "table" and v.simulation) then TEST.zustand = nil return end
    local okL, f = pcall(lade, "testzustand.lua")
    if not okL then TEST.zustand = nil print(tostring(w.name) .. ": Fehler: testzustand.lua " .. tostring(f)) return end
    ZUSTAND = f
  end
  local ok, e = pcall(ZUSTAND, w, now, "test-zustand.json")
  if not ok or not e then print(tostring(w.name) .. ": Fehler: Testzustand konnte nicht geschrieben werden " .. tostring(e)) end
end

-- ---------------------------------------------------------------- Studio-Datei
-- Studio-Hinweis: in der Meldezeile (8 s), danach «!» oben rechts bis zum nächsten Modellwechsel; Text auch ins Log
local function studioHinweis(w, text, now, dauer)
  -- mit eigener Dauer (Ansicht angepasst): nur der Hinweis, danach kein «!» (einmaliger Hinweis)
  w.sHinweis, w.sHinweisBis, w.sAusruf = text, now + (dauer or STUDIO_HINWEIS_S), w.sAusruf or not dauer
  print(tostring(w.name) .. ": " .. text)
end

-- Ansicht für die aktuelle Fenstergrösse: genau passend, sonst einmal je Grösse umrechnen (R3); keine: Hinweiszeile.
-- Kopf dieses Luas = Statusleiste und Meldezeile (L.y0).
local function ansichtPruefen(w, now)
  local S, W, H, T = w.studio, w.L.W, w.L.H, w.T
  local key = W .. "x" .. H
  local a = S.ansichten[key]
  if a == nil and not w.ansichtVersucht[key] then
    w.ansichtVersucht[key] = true
    a = STUDIO.anpassen(S.ansichten, W, H, function(b, h) return Z.layout(b, h).y0 end)
    if a then
      S.ansichten[key] = a
      local t = string.format(T.studioAngepasst, a.quelle)
      if a.weg > 0 then t = t .. ", " .. string.format(T.studioWeg, tostring(a.weg)) end
      studioHinweis(w, t, now, 5)
    end
  end
  -- Plätze einer passenden Ansicht, die in die eigene Kopfzeile reichen, einmal darunter schieben (wie Jet)
  if a and not a.angepasst and not a.kopfGeprueft then
    a.kopfGeprueft = true
    local kz, oben = w.L.y0, H
    for _, q in ipairs(a.plaetze) do if q.y < oben then oben = q.y end end
    if oben < kz then
      local v = STUDIO.anpassen({ a }, W, H, function() return kz end, 0)
      if v then v.angepasst, v.verschoben, v.kopfGeprueft = nil, true, true S.ansichten[key] = v a = v end
    end
  end
  local gen = a and (a.angepasst and a.quelle or key) or ""
  local dauer = (a == nil and w.seite == 1) and T.studioKeineAnsicht or nil
  if gen ~= w.ansichtGenutzt or (a and a.angepasst or false) ~= w.angepasst or dauer ~= w.sDauerAnsicht then
    w.ansichtGenutzt, w.angepasst, w.infoOffen = gen, a and a.angepasst or false, true
    if w.sDauer == nil or w.sDauer == w.sDauerAnsicht then w.sDauer = dauer end
    w.sDauerAnsicht = dauer
  end
end

-- Studio-Datei (Lua-Studio-Format 2 ohne Symbole): einmal nach dem Lesen der Einstellungen in Schritten lesen und
-- anwenden, danach laufend Quellen suchen, Min/Max/Kurven führen, Änderungen aus dem Menü in .funke.lua schreiben
-- und die Info-Datei. Die Warnlogik bleibt im Kern; die Datei setzt nur Einstellungen, Grenzen und Ansichten.
local function studioWecke(w, now)
  local T = w.T
  if STUDIO == nil then
    local ok, m = pcall(lade, "studio.lua")
    if not ok then
      print(tostring(w.name) .. ": studio.lua nicht ladbar: " .. tostring(m))
      w.studioFertig, w.infoOffen = true, false
      return
    end
    STUDIO = m
  end
  if not w.studioFertig then
    -- felder.lua nur einmal je Ladevorgang laden (Verzeichnisse bleiben), danach wieder freigeben
    if w.studioF == nil then w.studioF = lade("felder.lua") return end
    local F = w.studioF
    if TEST and TEST.kennung then w.testKennung = TEST.kennung end   -- neutrale Kennung für Testbilder
    local J = w.studioErg
    if J == nil then                                -- Datei lesen und prüfen, ein Schritt je Aufruf
      J = STUDIO.schritt(w, F)
      if J == nil then return end
      if J.zustand == "geladen" then w.studioErg = J return end   -- Anwenden ab dem nächsten Aufruf (Befehlsgrenze)
    elseif not STUDIO.anwendenSchritt(w, J, F) then -- Anwenden in Schritten; cfg und w.studio erst im letzten
      return
    end
    w.studioErg, w.studioF = nil, nil
    w.studioFertig, w.infoOffen, w.studioZustand = true, true, J.zustand
    if J.zustand ~= "geladen" then w.studio = nil end
    w.studioKennung = J.k
    w.studioFehler = 0
    -- Woher die Datei kam (Info-Datei) und die bleibende Hinweiszeile, wenn trotz Datei der Standard gilt
    w.studioQuelle, w.studioWahlArt = J.quelle or "", J.wahl or "auto"
    w.sDauer, w.angepasst, w.ansichtGenutzt, w.ansichtVersucht = nil, false, "", {}
    local dname = J.quelle and J.quelle:match("[^/]*$") or ""
    if J.zustand == "kaputt" then w.sDauer = string.format(T.studioDateiFehler, dname)
    elseif J.zustand == "zuNeu" then w.sDauer = T.studioZuNeu
    elseif J.zustand == "fehlt" and J.wahl == "menue" then w.sDauer = string.format(T.studioDateiFehlt, dname) end
    if J.zustand == "geladen" then
      grenzen(w)
      w.studioFehler = J.fehler
      if J.fehler > 0 then studioHinweis(w, string.format(T.studioFehler, tostring(J.fehler)), now) end
      if J.funkeVerworfen then studioHinweis(w, T.funkeVerworfen, now) end
    elseif J.zustand == "kaputt" then
      studioHinweis(w, T.studioKaputt, now)
    elseif J.zustand == "zuNeu" then
      studioHinweis(w, T.studioZuNeu, now)
    end
    return
  end
  -- Änderungen aus dem Menü nach .funke.lua: vor allem anderen, das früh aussteigt (sonst gingen sie beim Neustart verloren)
  if w.funkeOffen and w.studio and now - (w.tFunke or -100) >= 2 then
    w.funkeOffen, w.tFunke = false, now
    local ok, gut = pcall(function() return STUDIO.funkeSchreiben(w.testKennung or STUDIO.kennung(), STUDIO.funkeAusCfg(w, lade("felder.lua"))) end)
    if not (ok and gut) then studioHinweis(w, T.funkeNicht, now) end
  end
  if w.studio and w.L then
    ansichtPruefen(w, now)
    local a = w.studio.ansichten[w.L.W .. "x" .. w.L.H]
    if a and a.bereit ~= w.sp and Z then             -- Festes der Plätze vorbereiten, nicht im ersten Bild
      if ANSICHT == nil then ANSICHT = lade("ansicht.lua") end
      if ANSICHT.vorbereiten(w, w.L, Z, a, STUDIO, 6) then a.bereit = w.sp end
      return
    end
  end
  if w.studio then STUDIO.wecke(w, now) end
  if w.infoOffen then
    local ok, fertig = pcall(STUDIO.infoSchritt, w, w.version, STUDIO.FORMATE or { STUDIO.FORMAT })
    if not ok then print(tostring(w.name) .. ": Info-Datei: " .. tostring(fertig)) end
    if not ok or fertig then
      w.infoOffen = false
      -- ohne Studio-Datei kein Speicher dafür; nur, wenn auch keine andere Instanz des Widgets studio.lua braucht
      local braucht = false
      for x in pairs(WIDGETS) do
        if x.studio or (x ~= w and (not x.studioFertig or x.infoOffen)) then braucht = true end
      end
      if not braucht then STUDIO = nil collectgarbage() end
    end
  end
end

function K.wecke(w)
  local now = os.clock()
  if w.tL == nil then w.tL, w.tE, w.tB = now - 1, now - 3, now - 1 end
  -- Studio-Datei: eigene Aufrufe ohne Lesen und Rechnen (Befehlsgrenze am Sender je Aufruf); kommt länger als 1 s
  -- kein solcher Aufruf, läuft der Schritt trotzdem. Nie Studio-Schritt und Lesen im selben Aufruf.
  local lesenJetzt = now - w.tL >= DT_LESEN
  if (not w.studioFertig or w.studio or w.infoOffen)
    and (not lesenJetzt or (w.gelesenZuletzt and now - (w.tStudio or -100) >= 1)) then
    w.tStudio = now
    if w.T == nil then sprache(w) end
    local ok, e = pcall(studioWecke, w, now)
    if not ok then
      print(tostring(w.name) .. ": Fehler in der Studio-Datei: " .. tostring(e))
      w.studio, w.studioFertig, w.infoOffen, w.studioErg, w.studioF = nil, true, false, nil, nil
    end
    lesenJetzt, w.gelesenZuletzt = false, false
  end
  if lesenJetzt then
    w.gelesenZuletzt = true
    w.tL = now
    local dt = math.min(now - (w.tLogik or now), 1)
    w.tLogik = now
    lesen(w, now)
    if w.offen and not w.flug then                 -- beim Ausschalten offener Flug: weiterführen
      w.flug = { t = w.offen.t, wurf = w.offen.wurf, hmax = w.offen.hmax, ruhig = 0 }
      w.offen = nil
    end
    local sw = w.v.swAz
    if sw and w.swAzAlt == false then
      if w.f3k.an then f3kStopp(w) else f3kStart(w, now) end
    end
    w.swAzAlt = sw
    flugLogik(w, now, dt)
    f3kLauf(w, now, dt)
    phasen(w)
    if now - w.tE >= 2 then
      w.tE = now
      liesEinheiten(w)
    end
    warnungen(w, now)
    ansagen(w, now)
    if TEST and TEST.zustand then
      local f, k = w.flug, w.f3k
      local _, sum = wertung(aufgabe(w), k.fl, k.zl)
      w.testExtra = { flug = f and { t = f.t, wurf = f.wurf, hmax = f.hmax, imWurf = f.w ~= nil } or false,
        nListe = #w.liste, letzter = w.liste[#w.liste] or false, phase = w.v.phase or false,
        phaseName = w.v.phaseName or false, f3k = { an = k.an or false, rest = k.rest or false, n = #k.fl,
        starts = k.starts or 0, summe = sum or false, aufgabe = w.cfg.aufgabe, treffer = k.treffer or 0,
        zielFest = k.zielFest or false }, anLetzt = w.anLetzt or false,
        nAnsage = w.nAnsage or 0, studio = w.studioZustand or "", studioFehler = w.studioFehler or 0,
        kennung = w.studioKennung or "", studioHinweis = w.sHinweis or "", sDauer = w.sDauer or "",
        studioWahl = w.studioWahlArt or "", angepasst = w.angepasst or false, ansichtGenutzt = w.ansichtGenutzt or "",
        ansicht = (w.studio and w.L and w.studio.ansichten[w.L.W .. "x" .. w.L.H]) and true or false,
        meldText = w.nAktiv > 0 and w.meldText or "", cfgH = { w.cfg.hWarn or 0, w.cfg.hAlarm or 0 } }
      testZustand(w, now)
    end
    if w.hinweis and now >= w.hinweisBis then w.hinweis = nil end
    if w.sHinweis and now >= w.sHinweisBis then w.sHinweis = nil end
    -- dauerhafte Werte vormerken (höchstens einmal pro DAUER_S)
    if w.dauerNeu and now - (w.tDauer or -1000) >= DAUER_S then
      w.dauerNeu, w.tDauer, w.dateiOffen = false, now, true
    end
    -- Datei schreiben: sofort nach einer Rückfrage, sonst frühestens 2 s nach dem letzten Schreiben. In zwei
    -- Aufrufen (Einstellungen, dann Startliste), damit kein Aufruf an die Befehlsgrenze von Ethos kommt.
    if w.dateiTeil then
      local ok, erfolg = pcall(function() return w.dateiF.schreibeText(w.dateiTeil .. w.dateiF.textListe(w)) end)
      w.dateiTeil, w.dateiF = nil, nil
      if not (ok and erfolg) then
        if not w.dateiFehler then print(tostring(w.name) .. ": Fehler: Datei konnte nicht geschrieben werden") end
        w.dateiFehler = true
        w.fehler = "Datei schreiben"
      end
    elseif w.dateiOffen and (w.dateiJetzt or now - (w.tDatei or -100) >= 2) then
      w.dateiOffen, w.dateiJetzt, w.tDatei = false, false, now
      local ok, F = pcall(lade, "felder.lua")
      local okT, t = false, nil
      if ok then okT, t = pcall(F.textEinst, w) end
      if okT and type(t) == "string" then
        w.dateiTeil, w.dateiF = t, F
      else
        if not w.dateiFehler then print(tostring(w.name) .. ": Fehler: Datei konnte nicht geschrieben werden") end
        w.dateiFehler = true
        w.fehler = "Datei schreiben"
      end
    end
    -- Erster Start ohne gespeicherte Einstellungen: Sensoren automatisch suchen, sobald Telemetrie da ist
    if w.autoOffen and w.v.tele and not (TEST and (TEST.v or TEST.ohne or TEST.tele ~= nil or TEST.folge)) and now - (w.tAuto or -100) >= 5 then
      w.tAuto = now
      w.nAuto = (w.nAuto or 0) + 1
      local ok, n = pcall(function() return lade("suche.lua")(w) end)
      if ok and type(n) == "number" and n > 0 then
        grenzen(w)
        hinweis(w, string.format(w.T.autoSuche, tostring(n)), now)
        if model and model.dirty then pcall(model.dirty) end
      end
      if not ok then
        print(tostring(w.name) .. ": Fehler in der automatischen Suche: " .. tostring(n))
        w.fehler = "Suche: " .. tostring(n)
        w.autoOffen = false
      end
      if w.nAuto >= 10 or (ok and type(n) == "number" and n > 0) then w.autoOffen = false end
    end
  end

  if lcd.isVisible and not lcd.isVisible() then return end
  if now - w.tB >= DT_BILD then
    w.tB = now
    if Z == nil then Z = lade("zeichnen.lua") end
    if SEITE[w.seite] == nil then
      for i = 1, SEITEN do SEITE[i] = nil end
      collectgarbage()
      SEITE[w.seite] = lade("seite" .. w.seite .. ".lua")
    end
    w.blink = floor(now * 2) % 2 == 0
    w.seiten = SEITEN
    lcd.invalidate()
  end
end

function K.zeichne(w)
  if Z == nil then return end
  local W, H = lcd.getWindowSize()
  local L = w.L
  if L == nil or L.W ~= W or L.H ~= H then
    L = Z.layout(W, H)
    w.L = L
  end
  Z.punkt = w.sp == 2            -- Englisch: Dezimalpunkt, Tausender mit Komma
  Z.grund(L)
  w.nZiele = 0
  if W < MIN_W or H < MIN_H then
    Z.zuKlein(w, L)
    return
  end
  local fe = w.fenster or {}                       -- Fenstergrössen für die Info-Datei der Studio-Datei
  w.fenster = fe
  local neu = true
  for _, f in ipairs(fe) do if f[1] == W and f[2] == H then neu = false end end
  if neu and #fe < 8 then fe[#fe + 1] = { W, H } w.infoOffen = true end
  local S = SEITE[w.seite]
  local A = w.studio and w.seite == 1 and w.studio.ansichten[W .. "x" .. H]
  if A and STUDIO then                             -- Ansicht der Studio-Datei für genau diese Fenstergrösse
    if ANSICHT == nil then ANSICHT = lade("ansicht.lua") end
    ANSICHT.zeichne(w, L, Z, A, STUDIO)
  elseif S then
    S.zeichne(w, L, Z)
  end
  Z.kopf(w, L)
  if w.dialog then
    w.zielAb = w.nZiele + 1      -- bei offener Rückfrage zählen nur ihre eigenen Knöpfe
    Z.dialog(w, L)
  end
end

local function treffer(w, x, y)
  local ab = w.dialog and (w.zielAb or 1) or 1
  for i = w.nZiele or 0, ab, -1 do         -- zuletzt gezeichnet liegt oben
    local z = w.ziele[i]
    if x >= z.x and x < z.x + z.b and y >= z.y and y < z.y + z.h then return z.id end
  end
  return nil
end

-- Ein Knopf wurde angetippt (Finger auf und ab auf demselben Knopf, ohne Wisch).
-- Alles, was Daten löscht, geht nur über eine Rückfrage mit «JA, …».
local function knopf(w, id, now)
  local nr = tonumber(id:match("^x(%d+)$") or "")
  if id:sub(1, 1) == "s" and tonumber(id:sub(2)) then
    w.seite = clamp(tonumber(id:sub(2)), 1, SEITEN)
  elseif nr then
    w.loeschNr, w.dialog = nr, "loesch"
  elseif id == "ja_loesch" and w.dialog == "loesch" then
    w.dialog = nil
    loesche(w, w.loeschNr, now)
  elseif id == "alle" then
    w.dialog = "reset"
  elseif id == "ja_reset" and w.dialog == "reset" then
    w.dialog = nil
    zurueck(w, now)
  elseif id == "az" then
    if w.f3k.an then w.dialog = "f3kStopp"
    elseif #w.f3k.fl > 0 then w.dialog = "f3kNeu"
    else f3kStart(w, now) end
  elseif id == "ja_f3kStopp" and w.dialog == "f3kStopp" then
    w.dialog = nil
    f3kStopp(w)
  elseif id == "ja_f3kNeu" and w.dialog == "f3kNeu" then
    w.dialog = nil
    f3kStart(w, now)
  elseif (id == "aufg_m" or id == "aufg_p") and not w.f3k.an then
    w.cfg.aufgabe = (((w.cfg.aufgabe or 1) - 1 + (id == "aufg_p" and 1 or -1)) % #AUFGABEN) + 1
    w.f3k = { fl = {} }
    w.dateiOffen = true
  elseif (id == "z_m" or id == "z_p") and not w.f3k.zielFest then
    w.f3k.zielW = false
    w.cfg.pokerZiel = clamp((w.cfg.pokerZiel or 60) + (id == "z_p" and 5 or -5), 5, 900)
    w.dateiOffen = true
  elseif id == "z_w" and not w.f3k.zielFest and not w.f3k.wFertig then
    w.f3k.zielW = not w.f3k.zielW
  elseif id == "ja_f3kWeiter" and w.dialog == "f3kWeiter" then
    w.dialog = nil
    local k = w.f3k
    -- Die Arbeitszeit läuft in Wirklichkeit weiter: die Zeit seit dem letzten Sichern (Uhrzeit des Senders) abziehen
    local ok, uhr = pcall(os.time)
    local weg = (ok and type(uhr) == "number" and k.uhr and uhr >= k.uhr) and (uhr - k.uhr) or 0
    if k.rest then k.rest = math.max(0, k.rest - weg) end
    k.lauf = (k.lauf or 0) + weg
    k.an, k.ende, k.t0, k.tSp = true, nil, now - k.lauf, now
    if k.rest and k.rest <= 0 then f3kStopp(w) end
  elseif id == "hoch" then
    w.oben = math.max(0, (w.oben or 0) - 1)
  elseif id == "runter" then
    w.oben = (w.oben or 0) + 1
  elseif id == "abbrechen" then
    w.dialog = nil
  end
  w.tB = 0
end

-- Wisch nach links/rechts blättert zwischen den Seiten. Am Rand (Seite 1 nach rechts, letzte Seite nach links)
-- bleibt der Wisch bei Ethos, damit man wie gewohnt zum nächsten Bildschirm kommt (gemessen 26.1.2: Ethos blättert
-- nur, wenn das Widget die Bewegung nicht für sich behält). Bei offener Rückfrage wird nicht geblättert.
function K.ereignis(w, kat, wert, x, y)
  if kat ~= EVT_TOUCH then return false end
  x, y = gut(x), gut(y)
  if x == nil or y == nil then return false end
  local t = w.touch
  if wert == TOUCH_START then
    w.touch = { x = x, y = y, id = treffer(w, x, y) }
    return w.dialog ~= nil
  elseif wert == TOUCH_MOVE and t then
    local dx, dy = x - t.x, y - t.y
    if abs(dx) > SLOP or abs(dy) > SLOP then t.id = nil end
    if w.dialog then return true end
    if not t.mein and not t.ethos and abs(dx) > SLOP and abs(dx) > abs(dy) then
      local hinein = (dx < 0 and w.seite < SEITEN) or (dx > 0 and w.seite > 1)
      if hinein then t.mein = true else t.ethos = true end
    end
    t.dx = dx
    return not t.ethos
  elseif wert == TOUCH_END and t then
    w.touch = nil
    if t.mein then
      if abs(t.dx or 0) >= 50 then
        w.seite = clamp(w.seite + ((t.dx < 0) and 1 or -1), 1, SEITEN)
        w.tB = 0
      end
      return true
    end
    if t.id and t.id == treffer(w, x, y) then
      knopf(w, t.id, os.clock())
      return true
    end
    return w.dialog ~= nil
  end
  return false
end

function K.menue(w)
  local F = lade("felder.lua")
  lade("menue.lua")(w, F, function()
    local k = w.f3k                                -- Aufgabe im Menü geändert: wie die Pfeile auf Seite F3K
    if k.nr and k.nr ~= w.cfg.aufgabe then          -- (läuft die Runde, bleibt ihre Aufgabe; sonst neue Runde)
      if k.an then w.cfg.aufgabe = k.nr else w.f3k = { fl = {} } end
    end
    grenzen(w)
    -- ein angefangener Schreibvorgang trägt noch den alten Stand: verwerfen und sofort neu beginnen
    w.dateiTeil, w.dateiF, w.dateiOffen, w.dateiJetzt = nil, nil, true, true
    if w.studio then w.funkeOffen = true end     -- mit Studio-Datei gehen Änderungen nach .funke.lua
    if model and model.dirty then pcall(model.dirty) end
  end, function()
    local n = lade("suche.lua")(w)
    grenzen(w)
    hinweis(w, string.format(w.T.neuSuche, tostring(n)), os.clock())
    if model and model.dirty then pcall(model.dirty) end
    return n
  end, function()
    zurueck(w, os.clock())
  end, {
    loesche = function(nr) loesche(w, nr, os.clock()) end,
    az = function() if w.f3k.an then f3kStopp(w) else f3kStart(w, os.clock()) end end,
    anzahl = function() return #w.liste end,
    studioModul = function() return K.studioModul() end,
    studioNeu = function() K.studioNeu(w) w.dateiOffen = true end,
    studioZurueck = function()                    -- Zurück auf Studio-Stand: .funke.lua löschen, neu laden
      K.studioModul().funkeSchreiben(w.testKennung or STUDIO.kennung(), nil)
      K.studioNeu(w)
      hinweis(w, w.T.studioZurueck, os.clock())
    end,
  })
end

function K.studioModul()
  if STUDIO == nil then STUDIO = lade("studio.lua") end
  return STUDIO
end
function K.studioNeu(w)
  w.studio, w.studioFertig, w.studioJob, w.studioErg, w.studioF, w.funkeOffen = nil, false, nil, nil, nil, false
  w.sDauer, w.sDauerAnsicht, w.sHinweis, w.sAusruf = nil, nil, nil, nil
end

function K.lies(w)
  local F = lade("felder.lua")
  w.gelesen = F.lies(w)
  local d = w.dauer                              -- gespeicherte Werte: nur glaubhafte übernehmen
  d.rxMin, d.lqMin = imBereich("rx", d.rxMin), imBereich("lq", d.lqMin)
  w.liste = w.liste or {}
  local g = w.f3kGesp                              -- gespeicherte F3K-Runde: Flüge zurück, lief sie, nachfragen
  if g then
    w.f3kGesp = nil
    w.f3k = { an = false, nr = g.nr, rest = g.rest, lauf = g.lauf, fl = g.fl, zl = g.zl, starts = g.starts,
      treffer = g.treffer, zielFest = g.zielFest, zielAkt = g.zielAkt, wFertig = g.wFertig, ende = not g.warAn, uhr = g.uhr }
    w.cfg.aufgabe = g.nr
    if g.warAn then w.dialog = "f3kWeiter" end
  end
  w.autoOffen = not w.gelesen
  w.testCfg = nil                                  -- Testwerte nach dem Lesen einmal neu setzen
  K.studioNeu(w)                                   -- die Studio-Datei gilt über den gelesenen Einstellungen: neu anwenden
  grenzen(w)
end

function K.schreibe(w)
  local F = lade("felder.lua")
  F.schreibe(w)
end

return K
