-- Pandoc-filter: maakt van een hoofdstuk in src/ Typst voor het boek (zie build.py).
--
-- Metadata (via -M):  sleutel   week17 / syllabus / bijlagen
--                     soort     week / voor / bijlagen
--                     nr, fase  weeknummer en fase (alleen bij soort=week)
--                     uitmap    map waarin de bijbestanden komen
--
-- Wat het doet:
--   * koppen worden Typst-koppen een niveau dieper (deel = 1, hoofdstuk = 2, paragraaf = 3);
--     de hand-nummering "3. " verdwijnt, Typst nummert zelf (17.3)
--   * ```{.verilog include="cpu/alu.v"}``` wordt een listing uit labs/; korte listings blijven
--     in de tekst, lange worden een verwijzingskaart en gaan naar het codeboek (<sleutel>-code.typ)
--   * de paragraaf "Antwoorden" en de antwoorden van de zelftest gaan naar <sleutel>-antw.typ
--   * citaatblokken worden kaders, "Wat je na deze week kunt" wordt een doelenkader

local MAX_REGELS = 40   -- langere listings gaan naar het codeboek

local meta_sleutel, soort, weeknr, uitmap
local listing_nr = 0
local codeboek = {}
local antwoorden = {}
local ondertitel = nil

local function typst_inlines(inl)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inl) }), "typst", { wrap_text = "none" })
  return (s:gsub("%s+$", ""))
end

local function typst_blocks(blocks)
  return pandoc.write(pandoc.Pandoc(blocks), "typst", { wrap_text = "none" })
end

local function raw(s) return pandoc.RawBlock("typst", s) end

local function str_lit(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
  return '"' .. s .. '"'
end

local function label(id)
  id = id:gsub("[^A-Za-z0-9%-_]", "")
  if id == "" then return "" end
  return " <" .. meta_sleutel .. "-" .. id .. ">"
end

local function tel_regels(pad)
  local f = io.open("labs/" .. pad, "r")
  if not f then error("listing niet gevonden: labs/" .. pad) end
  local n = 0
  for _ in f:lines() do n = n + 1 end
  f:close()
  return n
end

-- "3. Titel" -> nummer 3, inlines zonder nummer
local function strip_nummer(inl)
  if #inl >= 2 and inl[1].t == "Str" and inl[1].text:match("^%d+%.$") and inl[2].t == "Space" then
    local rest = pandoc.List()
    for i = 3, #inl do rest:insert(inl[i]) end
    return tonumber(inl[1].text:match("^(%d+)")), rest
  end
  return nil, inl
end

local function kop_tekst(inl) return pandoc.utils.stringify(inl) end

local function kop(h)
  local nr, inl = strip_nummer(h.content)
  local niveau = h.level + 1
  local nummering = "none"
  if soort == "week" and h.level == 2 and nr then nummering = "sectienr" end
  return raw(string.format("#heading(level: %d, numbering: %s)[%s]%s",
    niveau, nummering, typst_inlines(inl), label(h.identifier)))
end

local function hoofdstuk_kop(h)
  local titel = h.content
  local sub = ondertitel and ("[" .. ondertitel .. "]") or "none"
  ondertitel = nil
  local tekst = kop_tekst(titel)
  if soort == "week" then
    -- "Week 17: Een assembler ..." -> "Een assembler ..."
    local _, rest = tekst:match("^(Week %d+: )(.*)$")
    local inl = titel
    if rest then
      local i = 1
      while i <= #inl and not (inl[i].t == "Str" and inl[i].text:match(":$")) do i = i + 1 end
      local r = pandoc.List()
      for j = i + 2, #inl do r:insert(inl[j]) end
      inl = r
    end
    return raw(string.format("#week-kop(nr: %d, fase: %d, sub: %s)[%s]", weeknr, tonumber(FASE), sub, typst_inlines(inl)))
  elseif soort == "bijlagen" then
    local letter = tekst:match("^Bijlage (%u):")
    local inl = titel
    if letter then
      local r = pandoc.List()
      for j = 4, #inl do r:insert(inl[j]) end   -- "Bijlage", " ", "A:", " "
      if r[1] and r[1].t == "Space" then r:remove(1) end
      inl = r
    end
    return raw(string.format("#bijlage-kop(letter: %s, sub: %s)[%s]", str_lit(letter or ""), sub, typst_inlines(inl)))
  else
    return raw(string.format("#voor-kop(sub: %s)[%s]", sub, typst_inlines(titel)))
  end
end

local function listing(cb)
  local pad = cb.attributes["include"]
  listing_nr = listing_nr + 1
  local nr = (soort == "week") and (weeknr .. "." .. listing_nr) or tostring(listing_nr)
  local n = tel_regels(pad)
  local extra = ""
  if cb.attributes["van"] then extra = extra .. ", van: " .. cb.attributes["van"] end
  if cb.attributes["tot"] then extra = extra .. ", tot: " .. cb.attributes["tot"] end
  local volledig = cb.classes:includes("volledig") or n <= MAX_REGELS
  if volledig or cb.attributes["van"] then
    local s = string.format("#listing(nr: %s, pad: %s, regels: %d%s)", str_lit(nr), str_lit(pad), n, extra)
    if not volledig then
      table.insert(codeboek, string.format("#codeboek-listing(nr: %s, pad: %s)", str_lit(nr), str_lit(pad)))
      s = s .. string.format("\n#codekaart(nr: %s, pad: %s, regels: %d, deel: true)", str_lit(nr), str_lit(pad), n)
    end
    return raw(s)
  end
  table.insert(codeboek, string.format("#codeboek-listing(nr: %s, pad: %s)", str_lit(nr), str_lit(pad)))
  return raw(string.format("#codekaart(nr: %s, pad: %s, regels: %d)", str_lit(nr), str_lit(pad), n))
end

local WAARSCHUWING = { ["Waarschuwing."] = true, ["Let op."] = true, ["Veiligheid."] = true }

local function kader(bq)
  local blocks = bq.content
  local titel = "none"
  local soort_kader = "info"
  local first = blocks[1]
  if first and first.t == "Para" and first.content[1] and first.content[1].t == "Strong" then
    local t = first.content[1]
    titel = "[" .. typst_inlines(t.content) .. "]"
    if WAARSCHUWING[pandoc.utils.stringify(t)] then soort_kader = "waarschuwing" end
    local rest = pandoc.List()
    for i = 2, #first.content do rest:insert(first.content[i]) end
    while rest[1] and (rest[1].t == "Space" or rest[1].t == "SoftBreak") do rest:remove(1) end
    blocks = pandoc.List(blocks)
    if #rest > 0 then blocks[1] = pandoc.Para(rest) else blocks:remove(1) end
  end
  return raw(string.format("#kader(soort: %s, titel: %s)[\n%s]", str_lit(soort_kader), titel, typst_blocks(blocks)))
end

-- Tabellen: links uitgelijnd; een brede tabel vult de regel, met de langste kolom flexibel.
local function tabel(tbl)
  -- per kolom: langste cel en totale tekstlengte
  local maxlen, som = {}, {}
  local function meet(rows)
    for _, row in ipairs(rows) do
      for c, cell in ipairs(row.cells) do
        local n = utf8.len(pandoc.utils.stringify(cell.contents)) or 0
        if n > (maxlen[c] or 0) then maxlen[c] = n end
        som[c] = (som[c] or 0) + n
      end
    end
  end
  meet(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do meet(body.body) end
  local totaal = 0
  for _, n in ipairs(maxlen) do totaal = totaal + n end
  local s = pandoc.write(pandoc.Pandoc({ tbl }), "typst", { wrap_text = "none" })
  s = s:gsub("align%(center%)%[#table%(", "[#table(")
  s = s:gsub("align: %(col, row%) => %(([^)]*)%)%.at%(col%)", function(a)
    return "align: (col, row) => (" .. a:gsub("auto", "left") .. ").at(col)"
  end)
  s = s:gsub("\n  inset: 6pt,", "")
  if totaal > 70 then
    -- korte kolommen zo smal als nodig, de rest naar verhouding van hun tekst
    local kol = {}
    for c = 1, #maxlen do
      if maxlen[c] <= 18 then kol[c] = "auto" else kol[c] = string.format("%dfr", math.max(som[c], 1)) end
    end
    s = s:gsub("columns: %d+,", "columns: (" .. table.concat(kol, ", ") .. "),", 1)
  end
  return raw(s)
end

local function codeblok(b)
  local taal = b.classes[1] or "text"
  if taal == "asm" then taal = "w8asm" end
  return raw(string.format("#codeblok(taal: %s, %s)", str_lit(taal), str_lit(b.text)))
end

-- blokken die overal (ook in de antwoorden) dezelfde omzetting krijgen
local function enkel(b)
  if b.t == "CodeBlock" and b.attributes["include"] then return listing(b)
  elseif b.t == "CodeBlock" then return codeblok(b)
  elseif b.t == "BlockQuote" then return kader(b)
  elseif b.t == "Table" then return tabel(b)
  end
  return b
end

local function is_antwoorden_para(b)
  return b.t == "Para" and b.content[1] and b.content[1].t == "Str" and b.content[1].text == "Antwoorden:"
end

local function verwerk(blocks)
  local uit = pandoc.List()
  local i = 1
  local sectie = nil          -- naam van de huidige h2
  while i <= #blocks do
    local b = blocks[i]
    if b.t == "RawBlock" and b.format == "html" and b.text:match('class="subtitle"') then
      -- <p class="subtitle">, dan de tekst, dan </p>
      if blocks[i + 1] and (blocks[i + 1].t == "Plain" or blocks[i + 1].t == "Para") then
        ondertitel = typst_inlines(blocks[i + 1].content)
        i = i + 1
      end
      if blocks[i + 1] and blocks[i + 1].t == "RawBlock" and blocks[i + 1].text:match("^</p>") then i = i + 1 end
    elseif b.t == "HorizontalRule" then
      -- streep voor het slotkader: in het boek overbodig
    elseif b.t == "Header" and b.level == 1 then
      uit:insert(hoofdstuk_kop(b))
    elseif b.t == "Header" and b.level == 2 then
      local _, inl = strip_nummer(b.content)
      sectie = kop_tekst(inl)
      if sectie == "Antwoorden" and soort == "week" then
        -- alles tot de volgende kop van niveau <= 2 naar de antwoordenbijlage
        local j = i + 1
        local antw = pandoc.List()
        while j <= #blocks and not (blocks[j].t == "Header" and blocks[j].level <= 2) do
          local x = blocks[j]
          if x.t == "Header" then x.level = x.level + 1 end
          antw:insert(enkel(x))
          j = j + 1
        end
        table.insert(antwoorden, { titel = "Oefeningen", blocks = antw })
        uit:insert(raw(string.format("#naar-antwoorden(%d)", weeknr)))
        i = j - 1
      elseif sectie == "Wat je na deze week kunt" then
        local j = i + 1
        local inhoud = pandoc.List()
        while j <= #blocks and not (blocks[j].t == "Header" and blocks[j].level <= 2) do
          inhoud:insert(blocks[j]); j = j + 1
        end
        uit:insert(raw("#leerdoelen[\n" .. typst_blocks(inhoud) .. "]"))
        i = j - 1
      else
        uit:insert(kop(b))
      end
    elseif b.t == "Header" then
      uit:insert(kop(b))
    elseif soort == "week" and sectie == "Zelftest" and is_antwoorden_para(b) then
      local inl = pandoc.List(b.content)
      inl:remove(1)
      if inl[1] and inl[1].t == "Space" then inl:remove(1) end
      table.insert(antwoorden, { titel = "Zelftest", blocks = { pandoc.Para(inl) } })
      uit:insert(raw(string.format("#naar-antwoorden(%d, zelftest: true)", weeknr)))
    elseif b.t == "CodeBlock" or b.t == "BlockQuote" or b.t == "Table" then
      uit:insert(enkel(b))
    else
      uit:insert(b)
    end
    i = i + 1
  end
  return uit
end

local function schrijf(naam, tekst)
  local f = assert(io.open(uitmap .. "/" .. naam, "w"))
  f:write(tekst)
  f:close()
end

function Pandoc(doc)
  local m = doc.meta
  meta_sleutel = pandoc.utils.stringify(m.sleutel)
  soort = pandoc.utils.stringify(m.soort)
  uitmap = pandoc.utils.stringify(m.uitmap)
  if soort == "week" then
    weeknr = tonumber(pandoc.utils.stringify(m.nr))
    FASE = pandoc.utils.stringify(m.fase)
  end
  local blocks = verwerk(doc.blocks)

  local kop = '#import "/boek/boek.typ": *\n'
  if soort == "week" then
    local a = { kop }
    if #antwoorden > 0 then
      table.insert(a, string.format("#antwoorden-week(%d)\n", weeknr))
      for _, x in ipairs(antwoorden) do
        table.insert(a, string.format("#heading(level: 4, numbering: none, outlined: false)[%s]\n", x.titel))
        table.insert(a, typst_blocks(x.blocks))
      end
    end
    schrijf(meta_sleutel .. "-antw.typ", table.concat(a))
    local c = { kop }
    if #codeboek > 0 then
      table.insert(c, string.format("#codeboek-week(%d)\n", weeknr))
      for _, x in ipairs(codeboek) do table.insert(c, x .. "\n") end
    end
    schrijf(meta_sleutel .. "-code.typ", table.concat(c))
  end
  blocks:insert(1, raw(kop))
  blocks:insert(raw("#hoofdstuk-einde()"))
  return pandoc.Pandoc(blocks, pandoc.Meta({}))
end
