#!/usr/bin/env python3

"""
Builds a random-coil starting conformer for a construct.
"""

import argparse
import random
import sys

import numpy as np
from Bio.PDB import PDBIO
from PeptideBuilder import Geometry
import PeptideBuilder

# (phi, psi, sd_phi, sd_psi, weight)
BASINS = {
    "gen": [(-70, 145, 15, 15, 0.42),    # PPII
            (-125, 135, 25, 25, 0.28),   # beta
            (-63, -43, 12, 12, 0.28),    # alpha_R
            (57, 40, 12, 12, 0.02)],     # alpha_L
    "G":   [(-80, 150, 30, 30, 0.30),
            (-70, -15, 25, 25, 0.20),
            (75, 10, 25, 25, 0.30),
            (95, 170, 30, 30, 0.20)],
    "P":   [(-65, 150, 8, 15, 0.60),
            (-65, -35, 8, 12, 0.40)],
}

# residue preceding a proline
PREPRO = [(-70, 145, 15, 15, 0.55),
          (-125, 135, 25, 25, 0.40),
          (-63, -43, 12, 12, 0.05)]

CHI1_ROTAMERS = [-60.0, 60.0, 180.0]


def read_construct(path):
    """Returns (sequence, first_residue_number, ncap, ccap) from the seq.fasta header."""

    with open(path) as fh:
        lines = [l.strip() for l in fh if l.strip()]
    header = lines[0]
    seq = "".join(l for l in lines[1:] if not l.startswith(">")).upper()
    meta = dict(tok.split("=", 1) for tok in header.split() if "=" in tok)
    lo = int(header.split("_")[1].split("-")[0])

    return seq, lo, meta.get("ncap", "none"), meta.get("ccap", "none")


def sample_basin(basins, rng):
    """Samples the basins."""

    r = rng.random() * sum(b[4] for b in basins)
    acc = 0.0
    for phi, psi, sp, ss, w in basins:
        acc += w
        if r <= acc:
            return rng.gauss(phi, sp), rng.gauss(psi, ss)

    return basins[-1][0], basins[-1][1]


def sample_torsions(seq, rng):
    """Returns list of (phi, psi) per residue."""

    out = []
    for i, aa in enumerate(seq):
        nxt = seq[i + 1] if i + 1 < len(seq) else None
        if aa in BASINS:
            basins = BASINS[aa]
        elif nxt == "P":
            basins = PREPRO
        else:
            basins = BASINS["gen"]
        out.append(sample_basin(basins, rng))

    return out


def set_chi1(geo, rng):
    """Sets primary side-chain dihedral angle."""

    if getattr(geo, "residue_name", None) == "P":
        return
    attrs = sorted(a for a in dir(geo)
                    if a.startswith("N_CA_CB_") and a.endswith("_diangle"))
    if not attrs:
        return
    ref = getattr(geo, attrs[0])
    base = rng.choice(CHI1_ROTAMERS) + rng.gauss(0, 10)
    for a in attrs:
        setattr(geo, a, base + (getattr(geo, a) - ref))


def build(seq, torsions, rng):
    """Builds the structure."""

    structure = None
    for i, aa in enumerate(seq):
        geo = Geometry.geometry(aa)
        geo.phi = torsions[i][0]
        # PeptideBuilder's psi_im1 is the psi of the preceding residue
        geo.psi_im1 = torsions[i - 1][1] if i > 0 else torsions[0][1]
        geo.omega = 180.0
        set_chi1(geo, rng)
        if structure is None:
            structure = PeptideBuilder.initialize_res(geo)
        else:
            PeptideBuilder.add_residue(structure, geo)

    return structure


def heavy_atoms(structure):
    """Returns the coordinates and residues of heavy atoms."""

    coords, resids = [], []
    for res in structure[0]["A"]:
        for atom in res:
            if atom.element != "H":
                coords.append(atom.coord)
                resids.append(res.id[1])

    return np.array(coords, dtype=float), np.array(resids)


def has_clash(coords, resids, min_sep=3, cutoff=3.0):
    """Detects steric clashes."""

    d = np.linalg.norm(coords[:, None, :] - coords[None, :, :], axis=-1)
    sep = np.abs(resids[:, None] - resids[None, :])
    mask = sep >= min_sep

    return bool((d[mask] < cutoff).any())


def radius_of_gyration(coords):
    """Returns the radius of gyration for the coordinates."""

    return float(np.sqrt(((coords - coords.mean(axis=0)) ** 2).sum(axis=1).mean()))


def flory_rg(n):
    """Random-coil Rg in Angstrom (Kohn et al. 2004)."""

    return 2.54 * n ** 0.522


def make_caps(structure, ncap, ccap, first_resnum):
    """Trim flanking glycines into ACE / NME residues and renumber to native indices."""

    chain = structure[0]["A"]
    residues = list(chain)

    if ncap == "ACE":
        res = residues[0]
        keep = {"CA", "C", "O"}
        for atom in [a for a in res if a.get_name() not in keep]:
            res.detach_child(atom.get_id())
        res.detach_parent()
        res.resname = "ACE"
        res["CA"].name = res["CA"].id = res["CA"].fullname = "CH3"
        res.child_dict["CH3"] = res.child_dict.pop("CA")
        res.set_parent(chain)

    if ccap == "NME":
        res = residues[-1]
        keep = {"N", "CA"}
        for atom in [a for a in res if a.get_name() not in keep]:
            res.detach_child(atom.get_id())
        res.detach_parent()
        res.resname = "NME"
        res["CA"].name = res["CA"].id = res["CA"].fullname = "CH3"
        res.child_dict["CH3"] = res.child_dict.pop("CA")
        res.set_parent(chain)

    # renumber so the construct carries native p53 numbering
    offset = first_resnum - (2 if ncap == "ACE" else 1)
    order = list(chain)
    if offset > 0:  # renumber downwards-first to avoid transient id collisions
        order = order[::-1]
    for res in order:
        res.id = (res.id[0], res.id[1] + offset, res.id[2])

    return structure


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq", required=True, help="seq.fasta from extract_construct.py")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--rg-lo", type=float, default=0.75, help="fraction of Flory Rg")
    ap.add_argument("--rg-hi", type=float, default=1.30, help="fraction of Flory Rg")
    ap.add_argument("--clash", type=float, default=3.0, help="heavy-atom cutoff, A")
    ap.add_argument("--tries", type=int, default=2000)
    args = ap.parse_args()

    seq, lo, ncap, ccap = read_construct(args.seq)
    rng = random.Random(args.seed)

    # flank with glycines that will become the caps
    padded = ("G" if ncap == "ACE" else "") + seq + ("G" if ccap == "NME" else "")

    target = flory_rg(len(seq))
    rg_lo, rg_hi = args.rg_lo * target, args.rg_hi * target

    for attempt in range(1, args.tries + 1):
        torsions = sample_torsions(padded, rng)
        structure = build(padded, torsions, rng)
        coords, resids = heavy_atoms(structure)
        rg = radius_of_gyration(coords)
        if not (rg_lo <= rg <= rg_hi):
            continue
        if has_clash(coords, resids, cutoff=args.clash):
            continue
        structure = make_caps(structure, ncap, ccap, lo)
        io = PDBIO()
        io.set_structure(structure)
        io.save(args.out)
        print(f"seed={args.seed} attempt={attempt} Rg={rg:.2f} A "
              f"(target {target:.2f}, window {rg_lo:.2f}-{rg_hi:.2f}) "
              f"ncap={ncap} ccap={ccap} -> {args.out}")
        return

    sys.exit(f"no acceptable conformer in {args.tries} tries; widen --rg-* or --clash")


if __name__ == "__main__":
    main()
