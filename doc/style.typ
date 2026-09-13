#import "@preview/subpar:0.2.2"

#let title-page(
  font: "Libertinus Serif",
  title: "",
  author: "",
  date: datetime.today(),
) = {
  set page(margin: (x: 30mm, y: 50mm), numbering: none)
  set text(font: font, size: 12pt, lang: "en")
  set par(leading: 1em)

  align(center, image("resources/images/ur_logo.svg", width: 30%))
  align(center, text(size: 2em, weight: 700, "University of Regensburg"))
  v(15mm)
  align(center, text(size: 1.75em, weight: 700, title))
  v(10mm)
  align(center, text(size: 1.5em, weight: 500, author))
  v(5mm)
  align(center, text(size: 1.25em, weight: 500, date.display("[year].[month].[day]")))
}

#let style(
  title: "Thesis title",
  degree: "Degree",
  program: "Program",
  author: "Author",
  date: datetime.today(),
  body,
) = {
  let font = "Libertinus Serif"

  title-page(font: font, title: title, author: author, date: date)

  pagebreak()

  set page(margin: (x: 30mm, y: 40mm), numbering: "1", number-align: center)
  set text(font: font, size: 12pt, lang: "en")
  set par(leading: 0.7em, justify: true, first-line-indent: 2em)

  set cite(style: "ieee")
  show link: set text(fill: blue)
  show ref: set text(fill: blue)
  show cite: set text(fill: blue)

  set figure.caption(separator: [ --- ])
  show figure: set text(size: 0.8em)
  show figure: set block(inset: (top: 0.5em, bottom: 0.5em))
  show figure.caption: box.with(width: 95%)

  set heading(numbering: "1.1")
  show heading: set block(below: 0.8em, above: 1.5em)
  show heading: set text(font: font)

  show outline.entry.where(level: 1): set text(weight: 600)
  let in-outline = state("in-outline", false)
  let flex-caption(short, long) = context if in-outline.get() { short } else { long }
  show outline: it => {
    in-outline.update(true)
    it
    in-outline.update(false)
  }

  show heading.where(level: 1): it => {
    counter(math.equation).update(0)
    it
  }
  set math.equation(numbering: num => {
    "(" + ((counter(heading.where(level: 1)).get() + (num, )).map(str).join(".") + ")")
  })
  show ref: it => {
    if it.element != none and it.element.func() == math.equation {
      numbering(
        it.element.numbering,
        ..counter(math.equation).at(it.element.location())
      )
    } else {
      it
    }
  }

  outline(title: {
    text(size: 1.25em, weight: 700, "Contents")
    v(0.5em)
  }, indent: 2em)

  pagebreak()

  body

  pagebreak()

  set page(margin: (x: 30mm, y: 40mm))
  show outline.entry.where(level: 1): set text(weight: 100)

  heading(numbering: none)[List of Figures]
  v(-10mm)
  outline(title: "", target: figure.where(supplement: [Figure]))

  pagebreak()

  heading(numbering: none)[List of Tables]
  v(-10mm)
  outline(title: "", target: figure.where(kind: table))

  pagebreak()
  bibliography("resources/references.bib", full: true, style: "ieee")
}
