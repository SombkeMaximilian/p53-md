#!/usr/bin/env python3

"""
Slices a construct out of the p53 sequence.
"""

import argparse

LANDMARKS = {1: "M", 19: "F", 23: "W", 53: "W"}


def read_fasta(path):
    with open(path) as fh:
        return "".join(l.strip() for l in fh if not l.startswith(">")).upper()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fasta", required=True)
    ap.add_argument("--range", required=True, help="inclusive, 1-based, e.g. 1-30")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    seq = read_fasta(args.fasta)
    assert len(seq) == 393, f"got {len(seq)} residues, expected 393"
    for pos, aa in LANDMARKS.items():
        assert seq[pos - 1] == aa, f"residue {pos} is {seq[pos - 1]}, expected {aa}"

    lo, hi = (int(x) for x in args.range.split("-"))
    fragment = seq[lo - 1:hi]

    ncap = "none" if lo == 1 else "ACE"
    ccap = "none" if hi == len(seq) else "NME"

    with open(args.out, "w") as fh:
        fh.write(f">p53_{lo}-{hi} ncap={ncap} ccap={ccap}\n{fragment}\n")

    print(f"{lo}-{hi}: {fragment} (ncap={ncap} ccap={ccap})")


if __name__ == "__main__":
    main()
