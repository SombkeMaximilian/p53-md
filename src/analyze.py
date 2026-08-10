#!/usr/bin/env python3

"""
Turns the GROMACS analysis outputs for one replica into plots, a summary report,
and a per-residue helicity table.
"""

import argparse
import os

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np

HELIX = set("HGI")
FIGSIZE = (8, 6)


def read_xvg(path):
    """Returns (data array, list of column legends including the x axis)."""

    legends, rows, xaxis = {}, [], "time"
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("@"):
                parts = line.split()
                if len(parts) > 1 and " legend " in line and parts[1].startswith("s"):
                    legends[int(parts[1][1:])] = line.split('"')[1]
                elif line.startswith("@    xaxis"):
                    xaxis = line.split('"')[1]
            elif line and not line.startswith(("#", "&")):
                rows.append([float(x) for x in line.split()])
    if not rows:
        raise SystemExit(f"no data in {path}")
    data = np.array(rows)
    names = [xaxis] + [legends.get(i, f"col{i + 1}") for i in range(data.shape[1] - 1)]

    return data, names


def column(path, want=None, index=0):
    """Returns (x, y, label). Picks a column by legend substring, else by index."""

    data, names = read_xvg(path)
    pick = index + 1
    if want:
        for i, n in enumerate(names[1:], start=1):
            if want.lower() in n.lower():
                pick = i
                break
    return data[:, 0], data[:, pick], names[pick]


def block_stats(y, nblocks=5):
    """Mean and a block-averaged standard error for correlated data."""

    n = len(y) // nblocks
    if n < 2:
        return float(np.mean(y)), float("nan")
    means = [y[i * n : (i + 1) * n].mean() for i in range(nblocks)]

    return float(np.mean(y)), float(np.std(means, ddof=1) / np.sqrt(nblocks))


def read_dssp(path):
    """Returns (per-residue helical fraction, n_frames) from a gmx dssp .dat file."""

    frames = []
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line and not line.startswith(("#", "@")):
                frames.append(line)
    if not frames:
        raise SystemExit(f"no frames in {path}")
    width = min(len(f) for f in frames)
    arr = np.array([[c in HELIX for c in f[:width]] for f in frames])

    return arr.mean(axis=0), len(frames)


class PlotConfig:
    def __init__(self, indir, outdir, fmt, dpi, title):
        self.indir, self.outdir = indir, outdir
        self.fmt, self.dpi, self.title = fmt, dpi, title
        self.report = [f"# {title}", ""]
        self.written = []

    def infile(self, name):
        p = os.path.join(self.indir, name)
        return p if os.path.exists(p) else None

    def note(self, label, mean, sem, unit):
        self.report.append(f"{label:<26} {mean:9.3f} +/- {sem:6.3f} {unit}")

    def save(self, fig, ax, stem, xlabel, ylabel):
        ax.set_xlabel(xlabel)
        ax.set_ylabel(ylabel)
        ax.set_title(self.title, fontsize=9)
        fig.tight_layout()
        path = os.path.join(self.outdir, f"{stem}.{self.fmt}")
        fig.savefig(path, dpi=self.dpi)
        plt.close(fig)
        self.written.append(path)

    def timeseries(self, src, stem, want, ylabel, label, unit, color, hline=None):
        p = self.infile(src)
        if not p:
            return
        t, y, _ = column(p, want=want)
        fig, ax = plt.subplots(figsize=FIGSIZE)
        ax.plot(t / 1000, y, lw=0.6, color=color)
        m, s = block_stats(y)
        ax.axhline(m, color="0.3", ls="--", lw=1)
        if hline is not None:
            ax.axhline(
                hline,
                color="C3",
                ls=":",
                lw=1.2,
                label=f"minimum image floor = {hline:.1f} nm",
            )
            ax.legend(fontsize=7)
            self.report.append(
                f"{label:<26} {y.min():9.3f}        {unit} (minimum; floor {hline:.1f})"
            )
            if y.min() < hline:
                self.report.append("  !! dips below the floor; the box is too small")
        else:
            self.note(label, m, s, unit)
        self.save(fig, ax, stem, "time (ns)", ylabel)

    def finish(self):
        path = os.path.join(self.outdir, "summary.txt")
        with open(path, "w") as fh:
            fh.write("\n".join(self.report) + "\n")
        self.written.append(path)
        print("\n".join(self.report))
        print("\nwrote:")
        for p in self.written:
            print(f"  {p}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="directory holding the xvg/dat files")
    ap.add_argument("--outdir", help="defaults to --dir")
    ap.add_argument("--title", default="")
    ap.add_argument("--rvdw", type=float, default=1.0)
    ap.add_argument("--format", default="png", choices=["png", "pdf", "svg"])
    ap.add_argument("--dpi", type=int, default=200)
    args = ap.parse_args()

    outdir = args.outdir or args.dir
    os.makedirs(outdir, exist_ok=True)
    p = PlotConfig(args.dir, outdir, args.format, args.dpi, args.title or args.dir)
    p.timeseries("gyrate.xvg", "rg", "Rg", "Rg (nm)", "radius of gyration", "nm", "C0")
    p.timeseries(
        "polystat.xvg",
        "e2e",
        "end to end",
        "Ree (nm)",
        "end-to-end distance",
        "nm",
        "C1",
    )
    p.timeseries(
        "mindist.xvg",
        "mindist",
        None,
        "min image distance (nm)",
        "periodic image distance",
        "nm",
        "C2",
        hline=2 * args.rvdw,
    )
    p.timeseries("energy.xvg", "temp", "Temperature", "T (K)", "temperature", "K", "C4")
    p.timeseries(
        "energy.xvg",
        "dens",
        "Density",
        "density (kg/m^3)",
        "density",
        "kg/m^3",
        "C5",
    )
    p.timeseries("energy.xvg", "pres", "Pressure", "P (bar)", "pressure", "bar", "C6")
    p.finish()


if __name__ == "__main__":
    main()
