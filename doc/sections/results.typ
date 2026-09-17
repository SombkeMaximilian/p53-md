#import "../utilities.typ": flex-caption
#import "@preview/subpar:0.2.2"

= Results <results>

#let dssp-plots = {
  ("T300_npt", "T600_nvt", "T300_from_T600").map(name => {
    (
      name,
      range(1, 5)
        .map(rep => str(rep))
        .map(rep => image("../resources/figures/dssp_" + name + "_rep" + rep + ".svg")),
    )
  })
  .to-dict()
}

#subpar.grid(
  columns: (1fr, 1fr),
  align: top,
  caption: flex-caption(
    short: [Secondary structures for 300 K NPT],
    long: [Secondary structures for 300 K NPT simulations. Each replica started from a different random coil conformation. The secondary structure was determined using the DSSP algorithm @Kabsch1983 via gmx dssp @Abraham2015, and the results are shown for each of the four replicas.],
  ),
  label: <figures:300K_simulation_dssp>,
  supplement: [Figure],
  ..dssp-plots
    .at("T300_npt")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      figure(
        caption: [Replica #rep],
        image,
      )
    }),
)

#let start-frames = (1823, 1439, 1753, 1843)

#subpar.grid(
  columns: (1fr, 1fr),
  align: top,
  caption: flex-caption(
    short: [Secondary structures for 600 K NVT],
    long: [Secondary structures for 600 K NVT simulations. Each replica started from a different random coil conformation. The secondary structure was determined using the DSSP algorithm @Kabsch1983 via gmx dssp @Abraham2015, and the results are shown for each of the four replicas.],
  ),
  label: <figures:600K_simulation_dssp>,
  supplement: [Figure],
  ..dssp-plots
    .at("T600_nvt")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      figure(
        caption: [Replica #rep],
        image,
      )
    }),
)

#subpar.grid(
  columns: (1fr, 1fr),
  align: top,
  caption: flex-caption(
    short: [Secondary structures for 300 K NPT starting from from 600 K NVT],
    long: [Secondary structures for 300 K NPT simulations. Each replica started from a different helical conformation obtained from the 600 K NVT simulations in @figures:300K_from_600K_simulation_dssp.],
  ),
  label: <figures:300K_from_600K_simulation_dssp>,
  supplement: [Figure],
  ..dssp-plots
    .at("T300_from_T600")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      figure(
        caption: [Replica #rep (start frame: #start-frames.at(rep - 1))],
        image,
      )
    }),
)
