#!/usr/bin/env python3
"""
03_compare_matrices.py

Compare two KEGG-Decoder output matrices and report, per pathway, how many
genomes carry it under each. Intended to quantify the effect of a change in
the input to pathway reconstruction, such as applying the KofamScan
significance filter.

Optionally annotates each pathway with the verdict from the diagnostic gene
verification produced by 02_verify_diagnostic_genes.py, so that changes can be
read alongside the gene-level evidence rather than in isolation.

Usage
-----
    python 03_compare_matrices.py \
        --a results/matrix_unfiltered.tsv --label-a unfiltered \
        --b results/matrix_filtered.tsv   --label-b filtered \
        --verification results/diagnostic_gene_verification.tsv \
        --out results/matrix_comparison.tsv

Genome names are matched after removing underscores, so MAG_1, MAG1 and
Mx_All_1 are treated as comparable where the numbering agrees. Genomes present
in only one matrix are reported and excluded from the comparison.
"""

import argparse
import csv
import os
from collections import defaultdict


def load_matrix(path):
    with open(path) as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    header = rows[0]
    data = {}
    for r in rows[1:]:
        if not r or not r[0]:
            continue
        data[r[0]] = {c: float(v) if v not in ("", None) else 0.0
                      for c, v in zip(header[1:], r[1:])}
    return header[1:], data


def norm(name):
    return name.replace("_", "").lower()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--a", required=True)
    ap.add_argument("--b", required=True)
    ap.add_argument("--label-a", default="A")
    ap.add_argument("--label-b", default="B")
    ap.add_argument("--verification", default=None)
    ap.add_argument("--out", required=True)
    ap.add_argument("--changed-only", action="store_true")
    ap.add_argument("--genome-map", default=None,
                    help="optional TSV mapping genome name in --a to genome name in --b; "
                         "required when the two matrices use different naming schemes")
    args = ap.parse_args()

    cols_a, A = load_matrix(args.a)
    cols_b, B = load_matrix(args.b)

    gmap = {}
    if args.genome_map:
        with open(args.genome_map) as fh:
            for line in fh:
                if not line.strip() or line.startswith("#"):
                    continue
                a, b = line.rstrip("\n").split("\t")[:2]
                gmap[norm(a)] = norm(b)

    map_a = {(gmap.get(norm(k), norm(k))): k for k in A}
    map_b = {norm(k): k for k in B}
    shared = sorted(set(map_a) & set(map_b))
    only_a = sorted(set(map_a) - set(map_b))
    only_b = sorted(set(map_b) - set(map_a))

    print(f"Genomes in {args.label_a}: {len(A)}   in {args.label_b}: {len(B)}   shared: {len(shared)}")
    if only_a:
        print(f"  only in {args.label_a}: {[map_a[k] for k in only_a]}")
    if only_b:
        print(f"  only in {args.label_b}: {[map_b[k] for k in only_b]}")

    shared_cols = [c for c in cols_a if c in set(cols_b)]
    print(f"Pathways compared: {len(shared_cols)}"
          f"  (only in {args.label_a}: {len(set(cols_a) - set(cols_b))},"
          f" only in {args.label_b}: {len(set(cols_b) - set(cols_a))})\n")

    verdict = {}
    if args.verification and os.path.exists(args.verification):
        diag = defaultdict(lambda: {"diagnostic_present": 0, "diagnostic_total": 0})
        with open(args.verification) as fh:
            for row in csv.DictReader(fh, delimiter="\t"):
                if row["role"] != "diagnostic":
                    continue
                key = row["pathway"]
                diag[key]["diagnostic_total"] += 1
                if row["kofam_significant"] == "yes" or row["bakta_annotated"] == "yes":
                    diag[key]["diagnostic_present"] += 1
        for k, v in diag.items():
            verdict[k] = ("no diagnostic gene detected in any genome"
                          if v["diagnostic_present"] == 0
                          else f"diagnostic genes detected ({v['diagnostic_present']} calls)")

    out = [["pathway", f"n_genomes_{args.label_a}", f"n_genomes_{args.label_b}",
            "difference", f"mean_{args.label_a}", f"mean_{args.label_b}",
            "diagnostic_gene_verdict"]]

    for c in shared_cols:
        va = [A[map_a[g]][c] for g in shared]
        vb = [B[map_b[g]][c] for g in shared]
        na = sum(1 for x in va if x > 0)
        nb = sum(1 for x in vb if x > 0)
        if args.changed_only and na == nb:
            continue
        # match verification pathway names loosely
        vv = ""
        for k in verdict:
            if k.lower().split("(")[0].strip()[:12] in c.lower():
                vv = verdict[k]
                break
        out.append([c, na, nb, nb - na,
                    round(sum(va) / len(va), 3), round(sum(vb) / len(vb), 3), vv])

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        csv.writer(fh, delimiter="\t").writerows(out)

    changed = [r for r in out[1:] if r[3] != 0]
    print(f"{'pathway':44} {args.label_a:>10} {args.label_b:>10}   diff")
    for r in sorted(changed, key=lambda x: x[3])[:40]:
        print(f"{r[0][:44]:44} {r[1]:>10} {r[2]:>10} {r[3]:>+6}")
    print(f"\nPathways with a changed genome count: {len(changed)} of {len(out)-1}")
    print(f"Written -> {args.out}")


if __name__ == "__main__":
    main()
