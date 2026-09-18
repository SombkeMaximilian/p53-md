#import "../utilities.typ": flex-caption
#import "@preview/subpar:0.2.2"

= Results <results>

== Unseeded 300 K NPT simulations

In the four 30 ns NPT simulations started from random coil conformations (@figures:simulation_dssp, a-d), no stable secondary structure formed. The DSSP assignments consist mostly of isolated bends and turns, which, on visual inspection, do not correspond to well-defined structure. The exceptions are parts of the TAD1 helix (R 17-26) nearly forming on several occasions as $3_10$ helices (e.g., frames 1750-2000 of @figures:300K_simulation_dssp_rep1). They did, however, not persist or extend to the full length helix.

== Unseeded 600 K NVT simulations

In the four 20 ns NVT simulations at 600 K (@figures:simulation_dssp, e-h), conformational dynamics were fast and the secondary structure elements were extremely short-lived. The three elements of interest @Raj2016 @Lee2010, TAD1 helix (17-26), turn at 40-44, and TAD2 helix (45-53), appeared repeatedly in all four replicas. Starting frames were selected from these replicas containing the TAD1 helix (replicas 1, 2) or the TAD2 helix (replicas 3, 4). Seeds were taken at frames 1823, 1439, 1753 and 1843, corresponding to 18.2, 14.4, 17.5 and 18.4 ns.

== Seeded 300 K NPT simulations

In replicas 1 and 2 (@figures:simulation_dssp, i-j), the seed contained the TAD1 helix, which persisted for the full 20 ns in both. Parts of it were occasionally assigned as $3_10$ helices or turns rather than #{sym.alpha}-helices. In replica 1, the seed also contained the 40-44 turn, which disappeared and reappeared over the run, at times becoming a bend. In replica 2, the turn was not present in the seed, but formed transiently toward the last 5 ns.

In replica 2, residues 28-32 were a turn in the seed, but immediately formed a short helix that flipped between helix and turn for about 7 ns before stabilizing as an #{sym.alpha}-helix until the end (@figures:300K_from_600K_simulation_dssp_rep2). Residues 17-26 of the TAD1 helix remained helical throughout. P27 was assigned coil, separating the two helices as would be expected from proline's helix-breaking properties.

Replicas 3 and 4 were seeded with incomplete TAD2 helices (@figures:simulation_dssp, k-l). Replica 3 contained the helix at residues 48-53, while replica 4 contained the helix at residues 45-49, which became a turn in the last 5 ns. Neither of these helices was fully stable, flipping between $3_10$-helix, #{sym.alpha}-helix, and turn, and neither replica completed the full TAD2 helix (R 45-53). The 40-44 turn only sparsely appeared in both replicas. The TAD1 helix also persisted throughout the runs, similar to replicas 1 and 2.

Visualizations of the secondary structure elements in the seeded 300 K NPT simulations are shown in @figures:300K_from_600K_simulation_helices. The full TAD1 helix is visible in the foreground of @figures:vmd_image_rep1, with hydrogen bonds shown in color. The TAD1 helix is also visible in the background of @figures:vmd_image_rep2, with the adjacent short helix at residues 28-32 in the foreground. In @figures:vmd_image_rep3, the TAD2 helix is visible on the left, with the TAD1 helix in the background on the right. In @figures:vmd_image_rep4, the first coil of the TAD2 helix is visible in the foreground, with the TAD1 helix in the background behind it.

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
    long: [Secondary structures for simulated replicas at (a-d) 300 K NPT starting from random coil conformations, (e-h) 600 K NVT starting from random coil conformations, (i-l) 300 K NPT starting from helical conformations obtained in (e-h).],
  ),
  label: <figures:simulation_dssp>,
  supplement: [Figure],
  ..dssp-plots
    .at("T300_npt")
    .enumerate(start: 1)
    .map(((rep, image)) => {
      [
        #figure(
          caption: [Replica #rep (300 K NPT)],
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
          caption: [Replica #rep (600 K NVT)],
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
    short: [Visualizations of helices],
    long: [Visualizations of helices in 300 K NPT simulations starting from 600 K NVT helical conformations. Grey: Protein, Cyan: Solvent-Solvent Hydrogen Bonds, Purple: Protein-Solvent Hydrogen Bonds, Magenta: Protein-Protein Hydrogen Bonds. The images were generated using VMD @Humphrey1996.],
  ),
  label: <figures:300K_from_600K_simulation_helices>,
  supplement: [Figure],
  figure(
    caption: [Replica 1: TAD1 main helix (R 17-26) and turn (R 40-44).],
    vmd-images.at(0),
  ),
  <figures:vmd_image_rep1>,
  figure(
    caption: [Replica 2: TAD1 secondary helix (R 28-32) and turn (R 40-44).],
    vmd-images.at(1),
  ),
  <figures:vmd_image_rep2>,
  figure(
    caption: [Replica 3: TAD2 main helix (R 47-55) and turn (R 40-44).],
    vmd-images.at(2),
  ),
  <figures:vmd_image_rep3>,
  figure(
    caption: [Replica 4: TAD2 first coil of the helix (R 45-49) and turn (R 40-44).],
    vmd-images.at(3),
  ),
  <figures:vmd_image_rep4>,
)
