-- DLG: Sensoren automatisch zuweisen. Füllt nur leere Felder; was von Hand gesetzt ist, bleibt.
-- Rangfolge über alle Sensoren: 1. Application ID, 2. genauer Name, 3. Namensteil, 4. Einheit.
-- Eine höhere Stufe gewinnt immer, egal in welcher Reihenfolge Ethos die Sensoren liefert. Der Ausschluss einer
-- Regel gilt auch für die Einheit (die Empfängerspannung wird nie zur «Spannung», nur weil sie Volt hat).
-- Gibt die Zahl der neu zugewiesenen Felder zurück. Für ein neues Lua ändern sich nur die drei Tabellen oben.
return function(w)
  local c = w.cfg
  if not (system.getSources and CATEGORY_TELEMETRY_SENSOR) then return 0 end
  local ok, liste = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
  if not ok or type(liste) ~= "table" then return 0 end

  -- 1. Application ID -> Feld (am sichersten; system.getSource beachtet die Physical ID nicht, darum hier selbst suchen)
  local APPID = {}                                   -- z. B. [0x0B50] = "t"
  -- 2. genauer Name (klein geschrieben) -> Felder; gibt es den Namen zweimal, bekommt der zweite das 2. Feld
  local NAMEN = { ["alt"] = { "hoehe" }, ["altitude"] = { "hoehe" }, ["vspd"] = { "vario" }, ["vario"] = { "vario" },
    ["rxbt"] = { "rx" }, ["rx batt"] = { "rx" }, ["rssi"] = { "lq" }, ["lq"] = { "lq" } }
  -- 3. und 4. je Feld: Namensteile, Ausschluss (gilt für Namensteil und Einheit), Einheit (nil = nie nach Einheit)
  local REGELN = {
    { feld = "hoehe", teile = { "alt", "höhe", "hoehe", "height" }, ohne = { "gps", "galt" } },
    { feld = "vario", teile = { "vario", "vspd", "steig", "climb" }, ohne = {}, einheit = UNIT_METER_PER_SECOND },
    { feld = "rx", teile = { "rxbt", "rx batt", "rxbatt", "rx bat", "empf" }, ohne = { "cell", "zelle" } },
    { feld = "lq", teile = { "rssi", "lq", "link" }, ohne = {} },
  }

  local function rufe(q, f)
    local okf, v = pcall(q[f], q)
    if okf then return v end
    return nil
  end
  local function hat(name, teile)
    for _, m in ipairs(teile) do
      if name:find(m, 1, true) then return true end
    end
    return false
  end

  -- Namen, Application ID und Einheit jedes Sensors einmal lesen
  local S = {}
  for _, q in ipairs(liste) do
    local name = rufe(q, "name")
    S[#S + 1] = { q = q, name = type(name) == "string" and string.lower(name) or "", id = rufe(q, "appId"),
      einheit = rufe(q, "unit") }
  end

  local n = 0
  local function setze(feld, s)
    if c[feld] ~= nil or s.vergeben then return false end
    c[feld] = s.q
    s.vergeben = true
    n = n + 1
    return true
  end

  for _, s in ipairs(S) do                           -- 1. Application ID
    if type(s.id) == "number" and APPID[s.id] then setze(APPID[s.id], s) end
  end
  for _, s in ipairs(S) do                           -- 2. genauer Name
    local felder = NAMEN[s.name]
    if felder and not s.vergeben then
      for _, f in ipairs(felder) do
        if setze(f, s) then break end
      end
    end
  end
  for _, r in ipairs(REGELN) do                      -- 3. Namensteil
    if c[r.feld] == nil then
      for _, s in ipairs(S) do
        if not s.vergeben and hat(s.name, r.teile) and not hat(s.name, r.ohne) and setze(r.feld, s) then break end
      end
    end
  end
  for _, r in ipairs(REGELN) do                      -- 4. Einheit
    if c[r.feld] == nil and r.einheit ~= nil then
      for _, s in ipairs(S) do
        if not s.vergeben and s.einheit == r.einheit and not hat(s.name, r.ohne) and setze(r.feld, s) then break end
      end
    end
  end
  return n
end
