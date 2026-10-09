// Opmaak van het boek. build.py maakt de hoofdstukken (via pandoc en filter.lua)
// en een hoofdbestand per uitgave; dit bestand bepaalt hoe alles eruitziet.
//
// Invoer (typst --input):
//   modus   scherm | print   scherm: links klikbaar, geen lege pagina's
//                            print:  recto-verso, rugmarge, hoofdstukken op een rechterpagina
//   versie  bijvoorbeeld v0.3.0

#let modus = sys.inputs.at("modus", default: "scherm")
#let print = modus == "print"
#let versie = sys.inputs.at("versie", default: "ontwikkelversie")
#let repo = "https://github.com/DDecoene/cpu-design-cursus"
#let gegevens = json("/build/typst/weken.json")

// ---------------------------------------------------------------- kleuren en letters
#let blauw = rgb("#0b3d91")
#let blauw-licht = rgb("#c9d6ee")
#let blauw-bleek = rgb("#eef3fb")
#let oranje = rgb("#d9822b")
#let rood = rgb("#b3261e")
#let rood-bleek = rgb("#fbeceb")
#let grijs = rgb("#6b7280")
#let lijn = rgb("#d5dbe5")
#let codebg = rgb("#f6f8fa")

#let serif = ("IBM Plex Serif", "Libertinus Serif")
#let sans = ("IBM Plex Sans", "Libertinus Serif")
#let mono = ("IBM Plex Mono", "DejaVu Sans Mono")

// ---------------------------------------------------------------- hulpjes
#let sectienr = (..n) => n.pos().slice(1).map(str).join(".")

#let paginanr(loc) = numbering("1", ..counter(page).at(loc))

#let paginaverwijzing(lab, tekst: none) = context {
  let q = query(lab)
  if q.len() > 0 {
    let loc = q.first().location()
    link(loc, if tekst == none [blz. #paginanr(loc)] else [#tekst])
  }
}

#let week-titel(nr) = gegevens.weken.at(str(nr)).titel

#let taal-van(pad) = {
  let ext = pad.split(".").last()
  (
    v: "verilog", vh: "verilog", sv: "verilog",
    py: "python", sh: "bash",
    asm: "w8asm", tta: "w8asm", fs: "forth",
  ).at(ext, default: "text")
}

#let hoofdstuk-begin() = pagebreak(weak: true, to: if print { "odd" } else { none })

#let hoofdstuk-einde() = [#metadata("einde") <hoofdstukeinde>]

// ---------------------------------------------------------------- code
#let lees-code(pad, van: none, tot: none) = {
  let r = read("/labs/" + pad).split("\n")
  if r.len() > 0 and r.last() == "" { r = r.slice(0, -1) }
  let a = if van == none { 1 } else { van }
  let b = if tot == none { r.len() } else { tot }
  (r.slice(a - 1, b).join("\n"), a)
}

#let code-met-nummers(tekst, taal, start: 1) = {
  // het nummer in een vaste kolom; een te lange regel loopt verder in zijn eigen kolom
  show raw.where(block: true): it => grid(
    columns: (2.3em, 1fr), column-gutter: 0.9em, row-gutter: 0.48em,
    ..it.lines.map(l => (
      align(right, text(fill: grijs.lighten(20%), size: 0.85em, str(l.number + start - 1))),
      l.body,
    )).flatten(),
  )
  set par(justify: false, leading: 0.48em)
  raw(tekst, lang: taal, block: true)
}

#let listing-kop(nr, pad, extra: none) = text(font: sans, size: 8pt, fill: grijs)[
  #text(fill: blauw, weight: "semibold")[Listing #nr]
  #h(0.5em) #text(font: mono)[labs/#pad] #extra
]

#let listing(nr: "", pad: "", regels: 0, van: none, tot: none) = {
  let (tekst, start) = lees-code(pad, van: van, tot: tot)
  let kort = tekst.split("\n").len() <= 15
  let extra = if van != none [ · regels #van–#tot van #regels] else []
  block(
    width: 100%, breakable: not kort, above: 1.1em, below: 1.1em,
    fill: codebg, stroke: (left: 2pt + blauw), inset: (x: 8pt, top: 6pt, bottom: 7pt),
  )[
    #listing-kop(nr, pad, extra: extra)
    #v(-3pt)
    #code-met-nummers(tekst, taal-van(pad), start: start)
  ]
}

#let codekaart(nr: "", pad: "", regels: 0, deel: false) = [#block(
  width: 100%, breakable: false, above: 1.1em, below: 1.1em,
  fill: blauw-bleek, stroke: 0.6pt + blauw-licht, radius: 3pt, inset: 10pt,
)[
  #grid(
    columns: (auto, 1fr), column-gutter: 10pt, align: horizon,
    box(fill: blauw, radius: 3pt, inset: (x: 6pt, y: 7pt),
      text(font: mono, size: 10pt, fill: white, weight: "bold")[</>]),
    [
      #set par(justify: false)
      #text(font: sans, size: 9.5pt)[
        #text(fill: blauw, weight: "semibold")[Listing #nr] #h(0.4em)
        #text(font: mono, size: 8.5pt)[labs/#pad] #h(0.4em) #text(fill: grijs)[#regels regels]
      ] \
      #text(size: 9pt)[
        #if deel [Het volledige bestand staat] else [De volledige code staat] in het
        #context {
          let q = query(label("cb-" + nr))
          if q.len() > 0 [#link(q.first().location())[codeboek, blz. #paginanr(q.first().location())]] else [codeboek onder listing #nr]
        }
        en op #link(repo + "/blob/main/labs/" + pad)[GitHub].
      ]
    ],
  )
]#label("kaart-" + nr)]

// losse codeblokken uit de tekst: voorbeelden, schema's, commando's
#let codeblok(taal: "text", tekst) = block(
  width: 100%, breakable: true, above: 1em, below: 1em,
  fill: codebg, inset: (x: 8pt, y: 7pt), radius: 2pt,
  raw(tekst, lang: taal, block: true),
)

// ---------------------------------------------------------------- kaders
#let kader(soort: "info", titel: none, body) = {
  let kleur = if soort == "waarschuwing" { rood } else { blauw }
  let fond = if soort == "waarschuwing" { rood-bleek } else { blauw-bleek }
  block(
    width: 100%, breakable: true, above: 1.1em, below: 1.1em,
    fill: fond, stroke: (left: 3pt + kleur), inset: (x: 12pt, y: 9pt),
  )[
    #if titel != none { text(font: sans, weight: "semibold", fill: kleur, titel); h(0.35em) }
    #body
  ]
}

#let leerdoelen(body) = block(
  width: 100%, breakable: false, above: 1.4em, below: 1.6em,
  stroke: 0.8pt + blauw-licht, radius: 3pt, inset: (x: 14pt, top: 10pt, bottom: 12pt),
)[
  #text(font: sans, size: 10pt, weight: "semibold", fill: blauw, upper[Wat je na deze week kunt])
  #v(2pt)
  #set list(marker: text(fill: blauw, font: mono)[☐], indent: 0pt, body-indent: 0.6em)
  #body
]

#let naar-antwoorden(nr, zelftest: false) = block(above: 0.9em, below: 1.2em)[
  #text(font: sans, size: 9pt, fill: grijs)[
    #text(fill: oranje)[▸] #if zelftest [De antwoorden van de zelftest] else [De antwoorden van de oefeningen]
    staan achteraan in het boek, #paginaverwijzing(label("antw-" + str(nr))).
  ]
]

// ---------------------------------------------------------------- koppen en openers
#let week-kop(nr: 0, fase: 0, sub: none, titel) = {
  hoofdstuk-begin()
  counter(heading).update((fase, nr - 1))
  v(14mm)
  text(font: sans, size: 10pt, weight: "semibold", fill: oranje, tracking: 0.12em)[WEEK #nr]
  v(2pt)
  grid(
    columns: (auto, 1fr), column-gutter: 12pt, align: horizon,
    text(font: sans, size: 60pt, weight: "bold", fill: blauw-licht, top-edge: "cap-height", bottom-edge: "baseline", str(nr)),
    [#heading(level: 2, numbering: (..n) => str(nr), supplement: [Week], titel)#label("week-" + str(nr))],
  )
  if sub != none {
    v(6pt)
    text(font: sans, size: 10pt, fill: grijs, sub)
  }
  v(4pt)
  line(length: 100%, stroke: 1.5pt + blauw)
  v(6pt)
}

#let bijlage-kop(letter: "", sub: none, titel) = {
  hoofdstuk-begin()
  v(18mm)
  text(font: sans, size: 10pt, weight: "semibold", fill: oranje, tracking: 0.12em)[BIJLAGE #letter]
  v(-4pt)
  [#heading(level: 2, numbering: (..n) => letter, supplement: [Bijlage], titel)#label("bijlage-" + letter)]
  if sub != none { text(font: sans, size: 10pt, fill: grijs, sub) }
  v(4pt)
  line(length: 100%, stroke: 1.5pt + blauw)
  v(6pt)
}

#let voor-kop(sub: none, titel) = {
  hoofdstuk-begin()
  v(18mm)
  heading(level: 2, numbering: none, titel)
  if sub != none { text(font: sans, size: 10pt, fill: grijs, sub) }
  v(4pt)
  line(length: 100%, stroke: 1.5pt + blauw)
  v(6pt)
}

#let deel(nr, titel, weken: (), beschrijving: none, label-naam: none) = {
  pagebreak(weak: true, to: if print { "odd" } else { none })
  [#metadata(nr) <deelpagina>]
  v(45mm)
  if type(nr) == int {
    text(font: sans, size: 12pt, weight: "semibold", fill: oranje, tracking: 0.15em)[DEEL #numbering("I", nr)]
  }
  v(-2pt)
  heading(level: 1, numbering: none, titel)
  v(4pt)
  line(length: 35%, stroke: 2pt + oranje)
  v(10pt)
  if beschrijving != none {
    block(width: 85%, text(size: 11pt, beschrijving))
  }
  if weken.len() > 0 {
    v(10pt)
    set text(font: sans, size: 10.5pt)
    for w in weken {
      block(above: 0.7em, below: 0.7em, grid(
        columns: (2.4em, 1fr, auto), column-gutter: 6pt,
        text(fill: blauw, weight: "semibold", str(w)),
        week-titel(w),
        text(fill: grijs, paginaverwijzing(label("week-" + str(w)))),
      ))
    }
  }
  pagebreak(weak: true)
}

#let antwoorden-week(nr) = [#heading(level: 2, numbering: none, supplement: [Antwoorden], outlined: false, bookmarked: true)[Week #nr · #week-titel(nr)]#label("antw-" + str(nr))]

#let codeboek-week(nr) = heading(level: 2, numbering: none, supplement: [Codeboek], outlined: sys.inputs.at("uitgave", default: "") == "codeboek", bookmarked: true)[Week #nr · #week-titel(nr)]

#let codeboek-listing(nr: "", pad: "") = {
  let (tekst, _) = lees-code(pad)
  [#block(
    width: 100%, sticky: true, above: 1.6em, below: 0.5em,
    stroke: (bottom: 0.8pt + blauw), inset: (bottom: 4pt),
  )[
    #text(font: sans, size: 9.5pt)[
      #text(fill: blauw, weight: "semibold")[Listing #nr] #h(0.5em)
      #text(font: mono, size: 9pt)[labs/#pad]
      #h(1fr)
      #context {
        let q = query(label("kaart-" + nr))
        if q.len() > 0 { text(fill: grijs, size: 8.5pt)[uitleg: #link(q.first().location())[blz. #paginanr(q.first().location())]] }
        else { text(fill: grijs, size: 8.5pt)[week #nr.split(".").first()] }
      }
    ]
  ]#label("cb-" + nr)]
  code-met-nummers(tekst, taal-van(pad))
}

// ---------------------------------------------------------------- titelpagina, colofon, inhoud
#let titelpagina(ondertitel: none) = {
  set page(header: none, footer: none, margin: (x: 25mm, top: 50mm, bottom: 25mm))
  text(font: sans, size: 12pt, weight: "semibold", fill: oranje, tracking: 0.15em)[VAN NUL TOT CHIPBOUWER]
  v(4pt)
  text(font: sans, size: 40pt, weight: "bold", fill: blauw)[CPU Design \ Cursus]
  v(8pt)
  line(length: 40%, stroke: 2pt + oranje)
  v(12pt)
  if ondertitel != none { text(font: sans, size: 14pt, fill: grijs, ondertitel) }
  v(1fr)
  text(font: sans, size: 11pt)[Dennis Decoene]
  v(2pt)
  text(font: sans, size: 9pt, fill: grijs)[#versie]
}

#let colofon() = {
  set page(header: none, footer: none)
  set text(size: 9pt)
  v(1fr)
  [
    *CPU Design Cursus: van nul tot chipbouwer* \
    Dennis Decoene · #versie

    Bron, code en de nieuwste versie: #link(repo)[#repo.replace("https://", "")]. \
    Alle code uit dit boek staat in de map `labs/` van die repository en wordt bij elke wijziging
    automatisch getest.

    De tekst valt onder de licentie Creative Commons Naamsvermelding-GelijkDelen 4.0 (CC BY-SA 4.0),
    de code onder de MIT-licentie. Zie `LICENSE.md`.

    Gezet met Typst in IBM Plex.
    #if print [Deze uitgave is bedoeld om recto-verso af te drukken op A4 en heeft een bredere binnenmarge voor een ringmap.] else [Deze uitgave is bedoeld voor het scherm: de inhoud, de verwijzingen naar listings en antwoorden en de webadressen zijn klikbaar.]
  ]
}

#let inhoud() = {
  pagebreak(weak: true, to: if print { "odd" } else { none })
  [#metadata("inhoud") <deelpagina>]
  v(12mm)
  text(font: sans, size: 24pt, weight: "bold", fill: blauw)[Inhoud]
  v(8pt)
  show outline.entry.where(level: 1): it => {
    set text(font: sans, weight: "semibold", fill: blauw)
    v(10pt, weak: true)
    link(it.element.location(), it.indented(none, [#it.body() #box(width: 1fr) #it.page()]))
  }
  show outline.entry.where(level: 2): it => {
    set text(size: 10pt)
    link(it.element.location(), it.indented(
      box(width: 1.6em, text(font: sans, fill: grijs, if it.prefix() != none { it.prefix() })),
      [#it.body() #box(width: 1fr, repeat(text(fill: lijn)[.], gap: 2pt)) #text(font: sans, it.page())],
    ))
  }
  outline(title: none, depth: 2, indent: 0pt)
}

// ---------------------------------------------------------------- kop- en voettekst
#let kop-en-voet(voet: false) = context {
  let p = here().page()
  let merken = query(selector(heading.where(level: 1)).or(heading.where(level: 2)).or(<hoofdstukeinde>).or(<deelpagina>))
    .filter(e => e.location().page() <= p)
  if merken.len() == 0 { return }
  let laatste = merken.last()
  let pl = laatste.location().page()
  // openingspagina's en lege pagina's na een hoofdstuk krijgen geen kop
  let is-kop = laatste.func() == heading and laatste.supplement not in ([Antwoorden], [Codeboek])
  let is-merk = laatste.func() == metadata
  if is-kop and pl == p { if not voet { return } }
  if is-merk and laatste.value != "einde" and pl == p { return }
  if is-merk and pl < p { return }
  if is-kop and laatste.level == 1 and pl < p { return }   // achterkant van een deelpagina
  let deel-kop = merken.filter(e => e.func() == heading and e.level == 1)
  let hfst = merken.filter(e => e.func() == heading and e.level == 2)
  set text(font: sans, size: 8pt, fill: grijs)
  if voet {
    let nr = text(fill: blauw, weight: "semibold", counter(page).display())
    if print {
      if calc.even(p) { align(left, nr) } else { align(right, nr) }
    } else { align(right, nr) }
    return
  }
  let links = if deel-kop.len() > 0 { deel-kop.last().body } else { [] }
  let rechts = if hfst.len() > 0 {
    let h = hfst.last()
    if h.numbering != none [#numbering(h.numbering, ..counter(heading).at(h.location())) · #h.body] else [#h.body]
  } else { [] }
  let inhoud = if print {
    if calc.even(p) { align(left, links) } else { align(right, rechts) }
  } else { grid(columns: (1fr, auto), links, rechts) }
  block(width: 100%, stroke: (bottom: 0.4pt + lijn), inset: (bottom: 4pt), inhoud)
}

// ---------------------------------------------------------------- het boek
#let boek(body) = {
  set document(title: "CPU Design Cursus", author: "Dennis Decoene")
  set page(
    paper: "a4",
    margin: if print { (inside: 30mm, outside: 20mm, top: 24mm, bottom: 22mm) } else { (x: 25mm, top: 24mm, bottom: 22mm) },
    header: kop-en-voet(),
    footer: kop-en-voet(voet: true),
  )
  set text(font: serif, size: 10pt, lang: "nl", hyphenate: true)
  set par(justify: true, leading: 0.62em, spacing: 0.95em)
  set heading(numbering: none)
  set list(indent: 0.4em, body-indent: 0.5em)
  set enum(indent: 0.2em, body-indent: 0.5em)
  set footnote.entry(separator: line(length: 25%, stroke: 0.5pt + lijn))
  set raw(syntaxes: ("syntaxes/verilog.sublime-syntax", "syntaxes/w8asm.sublime-syntax", "syntaxes/forth.sublime-syntax"))

  show heading.where(level: 1): it => block(below: 0.6em, text(font: sans, size: 32pt, weight: "bold", fill: blauw, it.body))
  show heading.where(level: 2): it => {
    if it.supplement in ([Antwoorden], [Codeboek]) {
      block(above: 2em, below: 1em, sticky: true,
        text(font: sans, size: 15pt, weight: "bold", fill: blauw, it.body))
    } else {
      block(above: 0pt, below: 0.4em, text(font: sans, size: 24pt, weight: "bold", fill: blauw, hyphenate: false, it.body))
    }
  }
  show heading.where(level: 3): it => block(above: 1.8em, below: 0.9em, sticky: true, {
    set text(font: sans, size: 13pt, weight: "semibold", fill: blauw, hyphenate: false)
    if it.numbering != none {
      text(fill: oranje, counter(heading).display(it.numbering))
      h(0.6em)
    }
    it.body
  })
  show heading.where(level: 4): it => block(above: 1.4em, below: 0.7em, sticky: true,
    text(font: sans, size: 11pt, weight: "semibold", fill: rgb("#1f2937"), hyphenate: false, it.body))
  show heading.where(level: 5): it => block(above: 1.2em, below: 0.6em, sticky: true,
    text(font: sans, size: 10pt, weight: "semibold", style: "italic", it.body))

  // code
  show raw: set text(font: mono, size: 8pt)
  // code in de lopende tekst: geen kader, zodat een lange regel gewoon kan afbreken
  show raw.where(block: false): set text(size: 1.12em, fill: rgb("#1e3a6e"))
  show raw.where(block: true): set par(justify: false)

  // tabellen
  show figure.where(kind: table): set block(breakable: true)
  show figure: set block(above: 1.1em, below: 1.1em)
  set table(
    stroke: (x, y) => (bottom: 0.5pt + lijn),
    fill: (x, y) => if y == 0 { blauw },
    inset: (x: 6pt, y: 5pt),
  )
  show table: set text(font: sans, size: 8.5pt)
  show table: set par(justify: false)
  show table.cell.where(y: 0): set text(fill: white, weight: "semibold")

  // koppelingen
  show link: it => {
    if type(it.dest) == str {
      set text(fill: if print { black } else { blauw })
      it
      if print and not (it.body.has("text") and it.body.text == it.dest) {
        footnote(text(font: mono, size: 7.5pt, it.dest))
      }
    } else { it }
  }

  body
}

// pandoc gebruikt dit soms
#let horizontalrule = line(length: 100%, stroke: 0.5pt + lijn)
