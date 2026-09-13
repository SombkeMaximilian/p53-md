#let flex-caption(short: none, long: none) = context if state("in-outline", false).get() {
  short
} else {
  long
}

#let unnumbered_eq(content, block: true) = math.equation(
  block: block,
  numbering: none,
  content,
)

#let TODO(body, color: none, width: 100%, breakable: true) = {
  block(width: width, radius: 3pt, stroke: 0.5pt, fill: color, inset: 10pt, breakable: breakable)[
    #body
  ]
}
