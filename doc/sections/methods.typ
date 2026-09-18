= Methods <methods>

== Force field and system setup

A force field that can accurately capture both the disordered ensemble and any transient secondary structure is required to study the conformational behavior of IDPs and IDRs. This is particularly relevant for the N-terminal domain of p53#sym.alpha, which contains transient helical structures within TAD1 and TAD2 @Raj2016. The Amber ff99SB-disp force field and companion TIP4P-D-like water model TIP4P-disp, developed by @Robustelli2018, were parametrized to perform well for both folded and disordered proteins, and were therefore used for all simulations in this work.

The simulated construct comprises residues 1-55 of human p53#sym.alpha. Initial structure was obtained by generating random coil conformation replicas using the PeptideBuilder Python package @Tien2013 on the basis of the amino acid sequence obtained from UniProt (P04637) @uniprot. These replicas were then used to create topology and coordinate files using the `pdb2gmx` tool in GROMACS @Abraham2015, and finally solvated in a dodecahedron box with TIP4P-disp water molecules and neutralized with Na$#super[+]$ and Cl$#super[-]$ ions. Standard energy minimization was performed using the steepest descent algorithm, followed by equilibration in the NVT and NPT ensembles.

== Production simulations

All simulations used a 2 fs time step. Where applicable, the V-rescale thermostat @Bussi2007 was used to maintain the temperature at 300 K or 600 K, and the Parrinello-Rahman barostat @Parrinello1981 was used to maintain a pressure of 1 bar. GROMACS @Abraham2015 was used to run and analyze the simulations, while Visual Molecular Dynamics (VMD) @Humphrey1996 was used for visualization. Three sets of production simulations with 4 replicas each were performed:

- *Unseeded 300 K NPT:* NPT at 300 K and 1 bar, 30 ns per replica (120ns total), starting from the four independent random coil conformations generated as described above.
- *Unseeded 600 K NVT:* NVT at 600 K, 20 ns per replica (80 ns total), starting from the same four independent random coil conformations. These simulations were only used to generate helical conformations for the following set of simulations, not as a physical ensemble.
- *Seeded 300 K NPT:* NPT at 300 K and 1 bar, 20 ns per replica (80 ns total). Each replica started from a frame of the 600 K NVT trajectory of the same replica number (frames 1823, 1439, 1753, and 1843 for replicas 1-4, respectively) after re-equilibration at 300 K. Frames were selected by visual inspection of DSSP assignment for the presence of the TAD1 helix (R 17-26) in replicas 1 and 2, and of the TAD2 helix (R 45-53) in replicas 3 and 4. The TAD1 helix was present in all four replicas but was not used a selection criterion for replicas 3 and 4.
