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

#let start-frames = (1823, 1439, 1753, 1843)

#subpar.grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  align: top,
  caption: flex-caption(
    short: [Secondary structures for 300 K NPT],
    long: [Secondary structures for simulations at (a-d) 300 K NPT starting from random coil conformations, (e-h) 600 K NVT starting from random coil conformations, (i-l) 300 K NPT starting from helical conformations obtained in (e-h). Each replica started from a different random coil conformation. The secondary structure was determined using the DSSP algorithm @Kabsch1983 via `gmx dssp` @Abraham2015.],
  ),
  label: <figures:300K_simulation_dssp>,
  supplement: [Figure],
  ..dssp-plots
    .at("T300_npt")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      [
        #figure(
          caption: [Replica #rep],
          image,
        )
        #label("figures:300K_simulation_dssp_rep" + str(rep))
      ]
    }),
  ..dssp-plots
    .at("T600_nvt")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      [
        #figure(
          caption: [Replica #rep],
          image,
        )
        #label("figures:600K_simulation_dssp_rep" + str(rep))
      ]
    }),
  ..dssp-plots
    .at("T300_from_T600")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      [
        #figure(
          caption: [Replica #rep (start: #start-frames.at(rep - 1))],
          image,
        )
        #label("figures:300K_from_600K_simulation_dssp_rep" + str(rep))
      ]
    }),
)

#let vmd-images = {
  range(1, 5)
    .map(rep => "rep" + str(rep))
    .zip((220, 1566, 1003, 718))
    .map(((rep, frame)) => rep + "_f" + str(frame))
    .map(name => image("../resources/images/" + name + ".png"))
}

#subpar.grid(
  columns: (1fr, 1fr),
  align: top,
  caption: flex-caption(
    short: [Helical conformations for 300 K NPT simulations starting from 600 K NVT],
    long: [Helical conformations for 300 K NPT simulations starting from 600 K NVT. Grey: Protein, Cyan: Solvent-Solvent Hydrogen Bonds, Purple: Protein-Solvent Hydrogen Bonds, Magenta: Protein-Protein Hydrogen Bonds. The images were generated using VMD @Humphrey1996.],
  ),
  label: <figures:300K_from_600K_simulation_helices>,
  supplement: [Figure],
  figure(
    caption: [TAD1 main helix.],
    vmd-images.at(0),
  ),
  <figures:vmd_image_rep1>,
  figure(
    caption: [TAD1 secondary helix.],
    vmd-images.at(1),
  ),
  <figures:vmd_image_rep2>,
  figure(
    caption: [TAD2 second half of the helix.],
    vmd-images.at(2),
  ),
  <figures:vmd_image_rep3>,
  figure(
    caption: [TAD2 middle coil of the helix.],
    vmd-images.at(3),
  ),
  <figures:vmd_image_rep4>,
)
