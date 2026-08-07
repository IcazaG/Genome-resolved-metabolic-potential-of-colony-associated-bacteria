#!/usr/bin/env python3
"""
01_filter_kofam.py

Convert KofamScan (kofam_scan / KofamKOALA) per-genome output into the
two-column KOALA format expected by KEGG-Decoder, retaining only hits that
exceed each KO-specific adaptive score threshold.

Background
----------
KofamScan reports every candidate KO assignment for every query gene and marks
with a leading asterisk those whose score exceeds the KO-specific threshold.
GhostKOALA and BlastKOALA, the other inputs accepted by KEGG-Decoder, return
an already-filtered two-column file. Converting KofamScan output without
applying the asterisk filter therefore passes an order of magnitude more KO
assignments than are supported, and inflates downstream pathway-completeness
scores.

This script makes that filter explicit and reports the magnitude of the
difference so it can be inspected rather than assumed.

Usage
-----
    python 01_filter_kofam.py \
        --kofam-dir data/kofam \
        --suffix _kofam.tsv \
        --out results/koala_input_filtered.txt \
        --report results/kofam_filter_report.tsv

    # to reproduce the unfiltered behaviour for comparison:
    python 01_filter_kofam.py ... --no-filter --out results/koala_input_unfiltered.txt

Notes
-----
KEGG-Decoder derives the genome name from the substring preceding the first
underscore in each gene identifier. Genome names containing underscores are
therefore collapsed. --genome-name-mode controls how this is handled.
"""

import argparse
import csv
import os
import re
import sys
from glob import glob

# a KofamScan detail line looks like:
#   * gene_id   K00432   57.03   242.0   1.8e-72   glutathione peroxidase
# where the leading '*' marks a hit above the KO-specific threshold
LINE_RE = re.compile(r"^(?P<star>[*\s])\s*(?P<gene>\S+)\s+(?P<ko>K\d{5})\s")


def parse_kofam(path, significant_only=True):
    """Return (list of (gene, ko), n_significant, n_candidate)."""
    hits = []
    n_sig = 0
    n_all = 0
    with open(path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            m = LINE_RE.match(line)
            if not m:
                continue
            n_all += 1
            starred = m.group("star") == "*"
            if starred:
                n_sig += 1
            if significant_only and not starred:
                continue
            hits.append((m.group("gene"), m.group("ko")))
    return hits, n_sig, n_all


def sanitise(name, mode):
    """KEGG-Decoder splits the genome name on the first underscore."""
    if mode == "strip":
        # Mx_All_1 -> MxAll1 ; MAG_1 -> MAG1
        return name.replace("_", "")
    if mode == "first-token":
        return name.split("_")[0]
    return name


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kofam-dir", required=True,
                    help="directory containing one KofamScan output per genome")
    ap.add_argument("--suffix", default="_kofam.tsv",
                    help="filename suffix identifying KofamScan outputs")
    ap.add_argument("--out", required=True,
                    help="output path for the KOALA-format file")
    ap.add_argument("--report", default=None,
                    help="optional per-genome summary of filtering effect")
    ap.add_argument("--genomes", default=None,
                    help="optional file listing genome names to include, one per line")
    ap.add_argument("--no-filter", action="store_true",
                    help="retain all candidate hits (reproduces the unfiltered artefact)")
    ap.add_argument("--genome-name-mode", default="strip",
                    choices=["strip", "first-token", "asis"],
                    help="how to make genome names safe for KEGG-Decoder parsing")
    args = ap.parse_args()

    paths = sorted(glob(os.path.join(args.kofam_dir, "*" + args.suffix)))
    if not paths:
        sys.exit(f"No files matching *{args.suffix} in {args.kofam_dir}")

    wanted = None
    if args.genomes:
        with open(args.genomes) as fh:
            wanted = {l.strip() for l in fh if l.strip()}

    significant_only = not args.no_filter
    rows = []
    report = []
    total_sig = total_all = 0

    for p in paths:
        genome = os.path.basename(p)[: -len(args.suffix)]
        if wanted is not None and genome not in wanted:
            continue
        hits, n_sig, n_all = parse_kofam(p, significant_only=significant_only)
        safe = sanitise(genome, args.genome_name_mode)
        for i, (_gene, ko) in enumerate(hits, start=1):
            # gene identifier is rewritten so that the genome name survives
            # KEGG-Decoder's split-on-first-underscore parsing
            rows.append((f"{safe}_g{i}", ko))
        n_unique = len({ko for _g, ko in hits})
        report.append((genome, safe, n_all, n_sig, len(hits), n_unique,
                       round(n_all / n_sig, 1) if n_sig else float("nan")))
        total_sig += n_sig
        total_all += n_all

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerows(rows)

    mode = "ALL candidate hits (UNFILTERED)" if args.no_filter else "significant hits only"
    print(f"Mode                : {mode}")
    print(f"Genomes processed   : {len(report)}")
    print(f"Candidate hits total: {total_all}")
    print(f"Significant hits    : {total_sig}")
    if total_sig:
        print(f"Inflation factor    : {total_all / total_sig:.1f}x")
    print(f"Rows written        : {len(rows)} -> {args.out}")

    if args.report:
        with open(args.report, "w", newline="") as fh:
            w = csv.writer(fh, delimiter="\t")
            w.writerow(["genome", "genome_name_used", "candidate_hits",
                        "significant_hits", "hits_written", "unique_KOs",
                        "candidate_to_significant_ratio"])
            w.writerows(report)
        print(f"Per-genome report   -> {args.report}")


if __name__ == "__main__":
    main()
