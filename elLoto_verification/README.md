# Genome-resolved metabolic verification pipeline

Scripts accompanying the manuscript on the genome-resolved metabolic potential
of bacteria enriched from *Microcystis*-dominated colonies (El Loto urban
wetland, southern Chile). ENA BioProject **PRJEB123320**.

These scripts cover the verification stage of the analysis: converting
KofamScan output into the format expected by KEGG-Decoder, checking pathway
assignments against diagnostic genes using two independent annotation methods,
and quantifying the effect of that verification on the resulting matrix. They
do not cover read QC, assembly or binning, which are described in the Methods
of the manuscript.

---

## Why this stage exists

Pathway-completeness scores are aggregate measures, and two distinct failure
modes can inflate them without being visible at pathway level.

**1. Unfiltered homology assignments.** KofamScan reports every candidate KO
assignment for every gene and marks with a leading asterisk those exceeding
the KO-specific adaptive score threshold. GhostKOALA and BlastKOALA, the other
inputs KEGG-Decoder accepts, return an already-filtered two-column file.
Converting KofamScan output without applying the asterisk filter therefore
passes far more assignments than are supported. In this dataset the ratio of
candidate to significant hits was of the order of 10:1 per genome.

**2. Steps shared with central metabolism.** Some pathway definitions include
reactions that occur in organisms lacking the pathway. The 3-hydroxypropionate
bicycle, for instance, counts malate dehydrogenase and PEP carboxylase among
its steps; a heterotroph with an intact TCA cycle will score above zero for it
regardless. This failure mode persists after filtering and can only be caught
by checking the reactions that are diagnostic of the pathway.

Both were present in an earlier version of this analysis. The scripts here
make each check explicit and reproducible.

---

## Layout

```
config/
  diagnostic_genes.tsv    diagnostic gene panel (editable; see below)
  genome_map.tsv          genome name equivalences between matrices
  name_map.tsv            KofamScan genome name -> Bakta file stem
scripts/
  01_filter_kofam.py      KofamScan -> KOALA format, with/without filtering
  02_verify_diagnostic_genes.py   KofamScan vs Bakta, per diagnostic gene
  03_compare_matrices.py  quantify differences between two KEGG-Decoder matrices
data/
  kofam/                  <genome>_kofam.tsv, one per genome
  bakta/                  <genome>.tsv, one per genome
results/                  outputs
```

Only Python 3.8+ and the standard library are required.

---

## Workflow

### 1. Build the KEGG-Decoder input

```bash
python scripts/01_filter_kofam.py \
    --kofam-dir data/kofam \
    --suffix _kofam.tsv \
    --out results/koala_input_filtered.txt \
    --report results/kofam_filter_report.tsv
```

The report gives, per genome, the number of candidate hits, the number passing
threshold, and the ratio between them. A ratio far above 1 indicates how much
signal the filter removes and is worth inspecting before proceeding.

To reproduce the unfiltered behaviour for comparison:

```bash
python scripts/01_filter_kofam.py \
    --kofam-dir data/kofam --no-filter \
    --out results/koala_input_unfiltered.txt
```

**Genome naming.** KEGG-Decoder derives the genome name from the substring
preceding the first underscore of each gene identifier. Names containing
underscores (`Mx_All_1`) are therefore collapsed, and every genome would be
merged into a single row. `--genome-name-mode strip` removes underscores
(`Mx_All_1` becomes `MxAll1`) and rewrites gene identifiers accordingly.
Confirm the result before running KEGG-Decoder:

```bash
cut -f1 results/koala_input_filtered.txt | cut -d'_' -f1 | sort -u | wc -l
```

This should equal the number of genomes.

### 2. Run KEGG-Decoder

```bash
python KEGG_decoder.py \
    -i results/koala_input_filtered.txt \
    -o results/matrix_filtered.tsv \
    -v static
```

KEGG-Decoder is not distributed here. See
https://github.com/bjtully/BioData/tree/master/KEGGDecoder

### 3. Verify pathway assignments against diagnostic genes

```bash
python scripts/02_verify_diagnostic_genes.py \
    --kofam-koala results/koala_input_filtered.txt \
    --bakta-dir data/bakta \
    --panel config/diagnostic_genes.tsv \
    --name-map config/name_map.tsv \
    --out results/diagnostic_gene_verification.tsv
```

For each genome and each gene in the panel, this records whether the gene was
called by KofamScan above threshold, whether Bakta annotated it, and whether
the two agree. Disagreements are reported, not resolved: either method can
miss a gene, and which to believe is a judgement that depends on the case.

The panel distinguishes two roles. Genes marked `diagnostic` define the
pathway; genes marked `shared` also occur in central metabolism and cannot
support the pathway on their own. A pathway scoring above zero while all its
diagnostic genes are absent is being carried by shared steps.

**Product-name matching** is deliberately conservative and uses exclusion
patterns to guard against homonyms. Two encountered here:

- `hydrogenase` matches `dehydrogenase` and `transhydrogenase` as substrings.
- `monooxygenase subunit` matches unrelated enzymes such as vanillate
  O-demethylase monooxygenase.

Add exclusions to `product_exclude` when extending the panel. Note that `|`
separates alternative patterns within a field, so a pattern containing
alternation must be written as separate entries rather than using an inline
group.

### 4. Quantify the effect

```bash
python scripts/03_compare_matrices.py \
    --a results/matrix_unfiltered.tsv --label-a unfiltered \
    --b results/matrix_filtered.tsv   --label-b filtered \
    --genome-map config/genome_map.tsv \
    --verification results/diagnostic_gene_verification.tsv \
    --out results/matrix_comparison.tsv \
    --changed-only
```

`--genome-map` is required when the two matrices use different naming schemes;
without it, genomes will not be matched and the comparison will be empty.

---

## Interpreting the output

A pathway whose genome count falls when the filter is applied, and whose
diagnostic genes are absent from every genome under both annotation methods,
was being scored on sub-threshold assignments. A pathway that retains a
non-zero score after filtering while its diagnostic genes remain absent is
being scored on steps shared with central metabolism. Neither should be
reported as evidence of the pathway.

A useful internal check is whether the corrected matrix recovers distributions
that are expected on biological grounds. In this dataset, Photosystem I and II
resolve to the two cyanobacterial genomes and to no others after filtering,
which the unfiltered matrix did not.

---

## Extending the panel

`config/diagnostic_genes.tsv` is a plain TSV and is intended to be edited. Each
row is one gene:

| column | meaning |
|---|---|
| `pathway` | pathway label, free text |
| `gene` | gene label used in reports |
| `ko` | KEGG orthologue checked in the filtered KofamScan output |
| `bakta_symbols` | accepted gene symbols, `\|`-separated |
| `product_include` | regular expressions matched against the Bakta product |
| `product_exclude` | regular expressions that veto a match |
| `role` | `diagnostic` or `shared` |

Lines whose `pathway` begins with `#` are ignored.

---

## Software versions used

| tool | version |
|---|---|
| MEGAHIT | 1.2.9 |
| metaWRAP | 1.3.2 (MetaBAT2, MaxBin2) |
| dRep | 3.2.0 |
| CheckM2 | 1.0.2 |
| GTDB-Tk | 2.x |
| KofamScan | 1.3.0 |
| Bakta | 1.12.0 (database v6.0) |
| tRNAscan-SE | 2.0.13 |
| KEGG-Decoder | as distributed in BioData |

## Data availability

Raw reads and metagenome-assembled genomes are deposited at the European
Nucleotide Archive under BioProject PRJEB123320.

## Citation

Icaza G., Canales C., Huanca P., Rocha J.D (submitted). *Genome-resolved metabolic
potential of colony-associated phycosphere bacteria selectively enriched from
Microcystis aeruginosa blooms in a Chilean urban wetland.*

