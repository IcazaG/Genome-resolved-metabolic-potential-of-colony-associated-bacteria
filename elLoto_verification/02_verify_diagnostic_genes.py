#!/usr/bin/env python3
"""
02_verify_diagnostic_genes.py

Cross-check pathway assignments against their diagnostic genes using two
independent annotation methods, and report where they agree and disagree.

Rationale
---------
Pathway-completeness scores are aggregate measures. A pathway can score highly
without encoding the reactions that define it, either because sub-threshold
homology assignments entered the calculation, or because the pathway
definition includes steps shared with central metabolism. Neither failure mode
is visible at pathway level.

This script therefore evaluates each pathway against the enzymes that are
diagnostic of it, using:

  (a) KofamScan HMM assignments, restricted to hits above the KO-specific
      adaptive threshold; and
  (b) Bakta annotations, matched on gene symbol and on product name.

The two methods are independent in the sense that they rely on different
evidence: profile HMMs scored against per-family thresholds in the first case,
and a combination of database matching and product nomenclature in the second.
Agreement between them is treated as support; disagreement is reported rather
than resolved automatically, since either method can miss a gene.

Product-name matching is deliberately conservative. Regular expressions are
anchored to distinctive phrases, and exclusion patterns guard against known
false positives: 'hydrogenase' matches 'dehydrogenase' as a substring, and
'monooxygenase subunit' matches unrelated aromatic-compound monooxygenases.

Usage
-----
    python 02_verify_diagnostic_genes.py \
        --kofam-koala results/koala_input_filtered.txt \
        --bakta-dir data/bakta \
        --panel config/diagnostic_genes.tsv \
        --out results/diagnostic_gene_verification.tsv

Inputs
------
--kofam-koala : two-column file from 01_filter_kofam.py (genome_geneid, KO)
--bakta-dir   : directory containing <genome>.tsv Bakta annotation tables
--panel       : diagnostic gene definitions (see config/diagnostic_genes.tsv)
"""

import argparse
import csv
import os
import re
import sys
from collections import defaultdict


def load_panel(path):
    """Read the diagnostic gene panel."""
    panel = []
    with open(path) as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            if row["pathway"].startswith("#"):
                continue
            panel.append({
                "pathway": row["pathway"],
                "gene": row["gene"],
                "ko": row["ko"].strip(),
                "symbols": [s.strip().lower() for s in row["bakta_symbols"].split("|") if s.strip()],
                "include": [p.strip() for p in row["product_include"].split("|") if p.strip()],
                "exclude": [p.strip() for p in row["product_exclude"].split("|") if p.strip()],
                "role": row["role"],
            })
    return panel


def load_kofam_kos(path):
    """genome -> set of KOs, from the KOALA-format file."""
    kos = defaultdict(set)
    with open(path) as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 2 or not parts[1]:
                continue
            genome = parts[0].rsplit("_g", 1)[0]
            kos[genome].add(parts[1])
    return kos


def load_bakta(path):
    """Return list of (gene_symbol, product) from a Bakta .tsv."""
    rows = []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 8:
                continue
            rows.append((p[6].strip(), p[7]))
    return rows


def bakta_hits(annots, entry):
    """Count Bakta loci matching a diagnostic gene definition."""
    hits = []
    for symbol, product in annots:
        matched = False
        if symbol and symbol.lower() in entry["symbols"]:
            matched = True
        for pat in entry["include"]:
            if re.search(pat, product, re.I):
                matched = True
                break
        if not matched:
            continue
        if any(re.search(ex, product, re.I) for ex in entry["exclude"]):
            continue
        hits.append((symbol or "-", product))
    return hits


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kofam-koala", required=True)
    ap.add_argument("--bakta-dir", required=True)
    ap.add_argument("--panel", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bakta-suffix", default=".tsv")
    ap.add_argument("--name-map", default=None,
                    help="optional TSV mapping kofam genome name to bakta file stem")
    args = ap.parse_args()

    panel = load_panel(args.panel)
    kofam = load_kofam_kos(args.kofam_koala)
    if not kofam:
        sys.exit("No KOs parsed from --kofam-koala")

    name_map = {}
    if args.name_map:
        with open(args.name_map) as fh:
            for line in fh:
                a, b = line.rstrip("\n").split("\t")[:2]
                name_map[a] = b

    genomes = sorted(kofam)
    out_rows = []
    disagreements = 0

    for genome in genomes:
        stem = name_map.get(genome, genome)
        bpath = os.path.join(args.bakta_dir, stem + args.bakta_suffix)
        if not os.path.exists(bpath):
            print(f"  [warn] no Bakta table for {genome} (looked for {bpath})")
            annots = None
        else:
            annots = load_bakta(bpath)

        for entry in panel:
            in_kofam = entry["ko"] in kofam[genome] if entry["ko"] else None
            if annots is None:
                in_bakta, n_loci, examples = None, "", ""
            else:
                hits = bakta_hits(annots, entry)
                in_bakta = len(hits) > 0
                n_loci = len(hits)
                examples = "; ".join(sorted({p for _s, p in hits})[:2])

            if in_kofam is None or in_bakta is None:
                agreement = "not evaluated"
            elif in_kofam == in_bakta:
                agreement = "agree"
            else:
                agreement = "DISAGREE"
                disagreements += 1

            out_rows.append([
                genome, entry["pathway"], entry["gene"], entry["ko"], entry["role"],
                "" if in_kofam is None else ("yes" if in_kofam else "no"),
                "" if in_bakta is None else ("yes" if in_bakta else "no"),
                n_loci, agreement, examples,
            ])

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["genome", "pathway", "gene", "KO", "role",
                    "kofam_significant", "bakta_annotated", "bakta_loci",
                    "agreement", "bakta_product_examples"])
        w.writerows(out_rows)

    # pathway-level summary
    print(f"\n{len(genomes)} genomes x {len(panel)} diagnostic genes")
    print(f"Disagreements between methods: {disagreements} of {len(out_rows)} comparisons\n")
    print(f"{'pathway':40} {'gene':10} {'kofam':>7} {'bakta':>7}")
    per = defaultdict(lambda: [0, 0, 0])   # kofam yes, bakta yes, bakta evaluated
    for r in out_rows:
        key = (r[1], r[2])
        if r[5] == "yes":
            per[key][0] += 1
        if r[6] != "":
            per[key][2] += 1
            if r[6] == "yes":
                per[key][1] += 1
    seen = set()
    for entry in panel:
        key = (entry["pathway"], entry["gene"])
        if key in seen:
            continue
        seen.add(key)
        k, b, n_eval = per[key]
        bakta_col = f"{b:>4}/{n_eval:<3}" if n_eval else "   n/a  "
        print(f"{entry['pathway'][:40]:40} {entry['gene']:10} {k:>4}/{len(genomes):<3} {bakta_col}")
    print(f"\nWritten -> {args.out}")


if __name__ == "__main__":
    main()
