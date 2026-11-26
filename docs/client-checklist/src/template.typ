// Layout of the client checklist: one page of requirements, as a website
// (HTML) and as a PDF. Same look as the protocol documentation. The Makefile
// compiles with `--input target=html` for the site and with no input for the
// PDF; everything that differs between the two is in this file.

#import "matrix.typ": status-of, status-label

#let inputs = sys.inputs
#let is-html = inputs.at("target", default: "pdf") == "html"
#let depth = int(inputs.at("depth", default: "0"))
#let base = inputs.at("base", default: "")
#let up = if base != "" { base } else { "../" * depth }

#let site-url = "https://ngspades.github.io/shoot-and-destroy/"
#let repo-url = "https://github.com/ngspades/shoot-and-destroy"
#let proto-url = "https://ngspades.github.io/protocol/"
#let site-title = "ngspades-client Checklist"
#let site-desc = "A numbered, testable checklist for writing a client of Ace of Spades 0.75/0.76, the community's 0.75 extensions and ngspades protocol 1.0, with a conformance matrix for ngspades-client."

#let accent = rgb("#b5301f")
#let ink = rgb("#1d1d1f")
#let muted = rgb("#6b6b70")
#let line-colour = rgb("#d9d9de")
#let code-bg = rgb("#f4f4f6")
#let note-bg = rgb("#eaf2fb")
#let note-bar = rgb("#2f6db5")
#let warn-bg = rgb("#fdf1e3")
#let warn-bar = rgb("#c77a12")
#let sans = ("Inter", "Helvetica Neue", "Helvetica", "Arimo", "Liberation Sans", "DejaVu Sans")
#let mono = ("JetBrains Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono")

#let el(tag, ..args) = html.elem(tag, attrs: args.named(), args.pos().join())

// Links into the protocol documentation (anchors are the heading slugs).
#let l075(a, t) = link(proto-url + "protocol075.html#" + a, t)
#let l10(a, t) = link(proto-url + "protocol10.html#" + a, t)
#let lext(a, t) = link(proto-url + "extensions.html#" + a, t)
#let lmaster(a, t) = link(proto-url + "protocolmaster.html#" + a, t)
#let lping(a, t) = link(proto-url + "protocolping.html#" + a, t)

#let callout(kind, bg, bar, body) = {
  if is-html {
    el("div", class: "callout " + kind, body)
  } else {
    block(width: 100%, fill: bg, stroke: (left: 3pt + bar), inset: (x: 10pt, y: 8pt), radius: (right: 2pt),
      above: 1em, below: 1em, breakable: false, body)
  }
}
#let note(body) = callout("note", note-bg, note-bar, body)
#let warning(body) = callout("warning", warn-bg, warn-bar, body)

#let status-colour(s) = (
  supported: rgb("#2e7d32"), partial: rgb("#b26a00"),
  progress: rgb("#2f6db5"), no: rgb("#a33"), na: muted,
).at(s, default: muted)

#let chip(s) = {
  if is-html { el("span", class: "chip " + s, status-label(s)) }
  else { box(fill: status-colour(s).lighten(85%), stroke: 0.5pt + status-colour(s), radius: 2pt,
    inset: (x: 3pt, y: 1.5pt), text(size: 0.8em, fill: status-colour(s).darken(10%), status-label(s))) }
}

// One numbered requirement. `id` is unique and must have a row in the
// conformance matrix (tools/check_reqs.py checks both).
#let req(id, title, body, why: none, test: none) = {
  [#metadata((id: id, title: title)) <req>]
  let s = status-of(id)
  if is-html {
    el("div", class: "req", id: id, {
      el("p", class: "req-head", {
        el("a", class: "req-id", href: "#" + id, id)
        el("strong", title)
        chip(s)
      })
      el("div", class: "req-body", body)
      if why != none { el("p", class: "req-why", { el("em", "Why: "); why }) }
      if test != none { el("p", class: "req-test", { el("em", "Check: "); test }) }
    })
  } else {
    block(width: 100%, stroke: (left: 2pt + accent.lighten(40%)), inset: (left: 9pt, y: 3pt),
      above: 1.1em, below: 0.9em, breakable: true, {
      text(font: mono, size: 0.85em, fill: accent, id); [ ]; strong(title); h(1fr); chip(s)
      body
      if why != none { par(text(size: 0.92em)[_Why:_ #why]) }
      if test != none { par(text(size: 0.92em)[_Check:_ #test]) }
    })
  }
}

#let swatch(hex) = if is-html {
  el("span", class: "sw", style: "background:#" + hex, "")
} else { box(width: 1.1em, height: 0.8em, fill: rgb("#" + hex), stroke: 0.3pt + line-colour) }

#let heading-id(h) = {
  let l = h.at("label", default: none)
  if l == none { none } else { str(l).split(":").slice(1).join(":") }
}

#let html-sidebar() = context {
  let heads = query(heading).filter(h => h.level <= 2 and heading-id(h) != none)
  el("nav", class: "sidebar", {
    el("a", class: "brand", href: up + "index.html", "ngspades-client")
    el("p", class: "brand-sub", "Checklist")
    el("ul", class: "toc", {
      for h in heads {
        el("li", class: "l" + str(h.level), el("a", href: "#" + heading-id(h), h.body))
      }
    })
    el("p", class: "side-links", {
      el("a", href: up + "pdf/client-checklist.pdf", "Download as PDF")
      el("a", href: proto-url, "Protocol documentation")
      el("a", href: repo-url, "Source on GitHub")
    })
  })
}

#let html-doc(it) = {
  set smartquote(enabled: false)
  show heading: h => {
    let id = heading-id(h)
    let tag = "h" + str(calc.min(h.level + 1, 6))
    el(tag, id: id, el("a", class: "hl", href: "#" + id, h.body))
  }
  show table: t => el("div", class: "table-wrap", t)
  el("html", lang: "en", {
    el("head", {
      el("meta", charset: "utf-8")
      el("meta", name: "viewport", content: "width=device-width, initial-scale=1")
      el("title", site-title)
      el("meta", name: "description", content: site-desc)
      el("link", rel: "canonical", href: site-url)
      el("link", rel: "stylesheet", href: up + "style.css")
    })
    el("body", el("div", class: "layout", {
      html-sidebar()
      el("main", {
        el("article", class: "doc", { el("h1", site-title); it })
        el("footer", {
          [Text: CC BY 4.0. Built with Typst from ]
          el("a", href: repo-url + "/tree/main/docs/client-checklist", "docs/client-checklist")
          [.]
        })
      })
    }))
  })
}

#let pdf-doc(it) = {
  set smartquote(enabled: false)
  set document(title: site-title, author: "ngspades")
  set text(font: sans, size: 10pt, fill: ink, lang: "en")
  set par(justify: false, leading: 0.62em, spacing: 0.95em)
  set page(paper: "a4", margin: (x: 2.2cm, top: 2.4cm, bottom: 2.2cm),
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8.5pt, fill: muted)
        grid(columns: (1fr, auto), site-title, site-url)
        v(-0.4em)
        line(length: 100%, stroke: 0.4pt + line-colour)
      }
    },
    footer: context { set text(size: 8.5pt, fill: muted); align(center, counter(page).display()) })
  set heading(numbering: none)
  show heading: set text(fill: ink)
  show heading.where(level: 1): set text(size: 18pt, fill: accent)
  show heading.where(level: 1): set block(above: 1.6em, below: 0.9em)
  show heading.where(level: 2): set text(size: 13.5pt)
  show heading.where(level: 2): set block(above: 1.5em, below: 0.7em)
  show heading.where(level: 3): set text(size: 11pt)
  show link: set text(fill: note-bar)
  show raw: set text(font: mono, size: 0.88em)
  show raw.where(block: false): it => box(fill: code-bg, inset: (x: 2pt), outset: (y: 2.5pt), radius: 2pt, it)
  show raw.where(block: true): it => block(width: 100%, fill: code-bg, stroke: 0.5pt + line-colour,
    inset: 8pt, radius: 3pt, above: 1em, below: 1em, breakable: false, it)
  set table(stroke: 0.5pt + line-colour, inset: (x: 5pt, y: 4pt))
  show table: set text(size: 8.5pt)
  show table.cell.where(y: 0): set text(weight: "semibold")
  set table(fill: (_, y) => if y == 0 { rgb("#eeeef1") } else if calc.odd(y) { rgb("#fafafb") } else { white })
  set list(indent: 0.6em, body-indent: 0.7em)
  set enum(indent: 0.6em, body-indent: 0.7em)
  block(below: 1.4em, {
    text(size: 8.5pt, fill: accent, weight: "semibold", tracking: 0.08em, upper("ngspades"))
    v(0.3em)
    text(size: 24pt, weight: "bold", site-title)
  })
  outline(title: [Contents], depth: 2)
  it
}

#let site-page(it) = if is-html { html-doc(it) } else { pdf-doc(it) }

#let not-found-page(it) = {
  el("html", lang: "en", {
    el("head", {
      el("meta", charset: "utf-8")
      el("title", "Not found | " + site-title)
      el("link", rel: "stylesheet", href: up + "style.css")
    })
    el("body", el("div", class: "layout", el("main", el("article", class: "doc", { el("h1", "Not found"); it }))))
  })
}

#import "matrix.typ": matrix

#let matrix-table() = context {
  let titles = query(<req>).map(m => m.value)
  let count(s) = matrix.filter(r => r.at(1) == s).len()
  [#matrix.len() requirements: #count("supported") supported, #count("partial") partial, #count("progress") in progress, #count("no") not implemented.]
  table(columns: (auto, 1fr, auto, 1.1fr),
    table.header([Id], [Requirement], [ngspades-client], [Note]),
    ..matrix.map(r => (
      if is-html { el("a", href: "#" + r.at(0), r.at(0)) } else { raw(r.at(0)) },
      titles.find(t => t.id == r.at(0)).title,
      chip(r.at(1)), r.at(2))).flatten())
}
