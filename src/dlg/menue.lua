-- DLG: Einstellungen im Ethos-Menü (Modell › Bildschirme › Widget antippen, oder Widget lange drücken ›
-- Widget konfigurieren). Baut sich aus felder.lua: Gruppen als aufklappbare Felder, oben der Knopf zum
-- automatischen Zuweisen der Sensoren. Texte in der gewählten Sprache (felder.lua, texte.lua).
-- Diese Datei bleibt bei einem neuen Lua unverändert.
return function(w, F, fertig, suche, zurueck, extra)
  local c = w.cfg
  local name = tostring(w.name)
  local sp, T = w.sp or 1, w.T or {}       -- Sprache beim Öffnen; ein Wechsel gilt im Menü ab dem nächsten Öffnen
  local function tx(t) return F.text(t, sp) end

  local kopf = form.addLine(T.mSuchen or "Sensoren suchen")
  if form.addButton then
    form.addButton(kopf, nil, { text = T.mKnopf or "Suchen", press = function()
      local ok, n = pcall(suche)
      if ok then
        print(name .. ": Suche: " .. tostring(n) .. " neu zugewiesen")
      else
        print(name .. ": Fehler bei der Suche: " .. tostring(n))
        w.fehler = "Suche: " .. tostring(n)
      end
    end })
  end
  form.addStaticText(form.addLine(name), nil, "Version " .. tostring(w.version or ""))

  -- Alles, was auf der Seite nur per Berührung geht, gibt es auch hier: X14, X10 und X12 haben keine Berührung.
  -- Auch hier nur über eine Rückfrage.
  if form.addButton and zurueck then
    form.addButton(form.addLine(T.mReset or "Reset"), nil, { text = T.mResetKnopf or "Reset", press = function()
      if not form.openDialog then return end
      pcall(form.openDialog, {
        title = T.resetTitel, message = T.resetZeile,
        buttons = {     -- Ethos zeigt den letzten Knopf links und wählt ihn vor (gemessen 26.1.2): ABBRECHEN zuletzt
          { label = T.resetJa, action = function() pcall(zurueck) return true end },
          { label = T.abbrechen, action = function() return true end },
        },
      })
    end })
  end

  if form.addButton and extra then
    local nr = 1                                    -- einzelnen Start löschen (Nummer wählen, dann Rückfrage)
    local zl = form.addLine(T.mLoesch or "Nr.")
    form.addNumberField(zl, nil, 1, 50, function() return nr end, function(x) nr = x end)
    form.addButton(zl, nil, { text = T.mResetKnopf or "Delete", press = function()
      if not form.openDialog or nr > extra.anzahl() then return end
      pcall(form.openDialog, {
        title = string.format(T.loeschTitel or "%s", tostring(nr)), message = T.loeschZeile,
        buttons = {
          { label = T.loeschJa, action = function() pcall(extra.loesche, nr) return true end },
          { label = T.abbrechen, action = function() return true end },
        },
      })
    end })
    form.addButton(form.addLine(T.mAz or "F3K"), nil, { text = T.mAzKnopf or "Start", press = function()
      pcall(extra.az)
    end })
  end

  -- Studio-Datei (Lua-Studio): Zustand, «Zurück auf Studio-Stand» (löscht .funke.lua) und Wahl der Datei
  if extra and extra.studioModul then
    local zs = w.studioZustand
    local zt = (zs == "geladen" and T.sGeladen) or (zs == "kaputt" and T.sKaputt) or (zs == "zuNeu" and T.sZuNeu) or T.sFehlt
    if zs == "geladen" and (w.studioFehler or 0) > 0 then zt = zt .. ", " .. string.format(T.studioFehler, tostring(w.studioFehler)) end
    local ls = form.addLine(tostring(T.mStudio) .. ": " .. tostring(zt))
    if form.addButton and w.studio then
      form.addButton(ls, nil, { text = T.mStudioK, press = function()
        if not form.openDialog then return end
        pcall(form.openDialog, {
          title = T.qStudio, message = T.qStudioZ,
          buttons = {
            { label = T.jaStudio, action = function() pcall(extra.studioZurueck) return true end },
            { label = T.abbrechen, action = function() return true end },
          },
        })
      end })
    end
    local okL, ST = pcall(extra.studioModul)
    if okL and ST then ST.textStandard = T.mLayoutStd end
    local dateien = okL and ST and ST.liste() or {}
    -- «automatisch» zeigt in Klammern, was gerade gilt: Modelldatei (Kennung) oder Standard
    local auto = T.mLayoutAuto
    if w.studio and w.studioWahlArt == "standard" then auto = auto .. " (" .. T.mLayoutStdKurz .. ")"
    elseif w.studio and w.studioWahlArt == "auto" and w.studioKennung then auto = auto .. " (" .. w.studioKennung .. ")" end
    local wahlen, akt = { { auto, 0 } }, 0
    for i, d in ipairs(dateien) do
      wahlen[#wahlen + 1] = { d[2], i }
      if d[1] == w.studioWahl then akt = i end
    end
    if akt == 0 and type(w.studioWahl) == "string" and w.studioWahl ~= "" then   -- gewählt, aber nicht mehr da
      dateien[#dateien + 1] = { w.studioWahl, w.studioWahl:match("[^/]*$") .. " (?)" }
      akt = #dateien
      wahlen[#wahlen + 1] = { dateien[akt][2], akt }
    end
    form.addChoiceField(form.addLine(T.mLayout), nil, wahlen, function() return akt end, function(v)
      akt = (v > 0 and dateien[v]) and v or 0       -- nur Einträge der Liste, sonst automatisch
      w.studioWahl = akt > 0 and dateien[akt][1] or ""
      pcall(extra.studioNeu)
    end)
  end

  for _, g in ipairs(F.gruppen) do
    local panel = form.addExpansionPanel(tx(g[1]))
    pcall(panel.open, panel, false)
    for _, f in ipairs(g[2]) do
      local feld, art = f[1], f[2]
      local line = form.addLine(tx(f[3]), panel)
      local function get() return c[feld] end
      local function set(v)
        if art == "q" and not F.istQuelle(v) then v = nil end
        c[feld] = v
        fertig()
      end
      if art == "q" then
        form.addSourceField(line, nil, get, set)
      elseif art == "b" then
        form.addBooleanField(line, nil, get, set)
      elseif art == "w" then
        local wahl = {}
        for i, a in ipairs(f[5]) do wahl[i] = { tx(a[1]), a[2] } end
        form.addChoiceField(line, nil, wahl, get, set)
      elseif art == "z" then
        local fe = form.addNumberField(line, nil, f[5], f[6], get, set)
        if fe then
          if f[7] and f[7] > 0 then pcall(fe.decimals, fe, f[7]) end
          if f[8] then pcall(fe.suffix, fe, f[8]) end
          if f[9] then pcall(fe.step, fe, f[9]) end
          pcall(fe.default, fe, f[4])
        end
      end
    end
  end
end
