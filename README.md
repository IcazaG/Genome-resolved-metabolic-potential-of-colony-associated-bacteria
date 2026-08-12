<!-- markdownlint-disable MD033 -->
<div align="center">

# Metagenome Assembly, binning, and annotation
### A reproducibility guide for *Microcystis aeruginosa* enrichment cultures (E1–E7)

[![Pipeline](https://img.shields.io/badge/base%20pipeline-EasyMetagenome-blue)](https://doi.org/10.1002/imt2.70001)
[![HPC](https://img.shields.io/badge/executed%20on-NLHPC%20%2F%20SLURM-lightgrey)]()
[![License](https://img.shields.io/badge/license-CC--BY--4.0-green)]()

</div>

> **Author:** Gonzalo Icaza
> **Affiliation:** *Alexandrium catenella* Surveillance Program · Universidad San Sebastián · Puerto Montt, Chile
> **Computing infrastructure:** NLHPC (National Laboratory for High Performance Computing), Centro de Modelamiento Matemático (CMM), Universidad de Chile
> **Base pipeline:** Adapted from [EasyMetagenome](https://doi.org/10.1002/imt2.70001) (Bai et al., 2025)
> **Associated manuscript:** Icaza et al. (2026)

---

##  Repository structure

```text
.
├── Bakta_batch/
│   ├── BaktaBatch.ps1          # Batch genome annotation via the Bakta web API (Section 11)
│   └── README.md
├── Cluster_script/              # SLURM/HPC job scripts, one per pipeline tool
│   ├── README.md
│   ├── fastp.sh                 # Section 2  — read QC
│   ├── kneaddata.sh             # Section 3  — host decontamination
│   ├── megahit.sh               # Section 4  — co-assembly (selected)
│   ├── metaspades.sh            # Section 4  — co-assembly (comparison)
│   ├── quast.sh                 # Section 4  — assembly evaluation
│   ├── prodigal.sh              # Section 5 / 11 — gene prediction
│   ├── cdhit.sh                 # Section 5  — non-redundant gene catalogue
│   ├── salmom.sh                # Section 5  — gene abundance quantification
│   ├── eggnog.sh                # Section 6  — functional annotation
│   ├── kraken2.sh                # Section 7  — read taxonomic classification
│   ├── metawrap_binning.sh      # Section 8  — genome-resolved binning
│   ├── metawrap_refine.sh       # Section 8  — bin refinement
│   ├── drep.sh                  # Section 9  — dereplication
│   ├── checkm2.sh                # Section 10 — genome quality assessment
│   ├── gtdbtk.sh                 # Section 10 — taxonomic placement
│   ├── trnascan.sh               # Section 11 — tRNA annotation
│   ├── kofamscan.sh              # Section 11 — KEGG orthologue assignment
│   └── keggdecoder.sh            # Section 11 — pathway completeness
├── elLoto_verification/         # Manual gene-by-gene verification (Section 11)
│   ├── 01_filter_kofam.py
│   ├── 02_verify_diagnostic_genes.py
│   ├── 03_compare_matrices.py
│   ├── diagnostic_genes.tsv
│   ├── genome_map.tsv
│   ├── name_map.tsv
│   └── README.md
├── Pipeline/                    # PufM phylogenetic validation (Section 12) + orchestration notes
├── LICENSE
└── README.md                    
```

## Table of contents

- [How to use this guide](#-how-to-use-this-guide)
- [0. Experimental design](#0-experimental-design-what-samples-are-being-analyzed)
- [1. Environment setup](#1-environment-setup)
- [2. Read quality control (fastp)](#2-read-quality-control-fastp)
- [3. Host decontamination (KneadData + Bowtie2)](#3-host-decontamination-kneaddata--bowtie2-hg38)
- [4. Pooled co-assembly: MEGAHIT vs. metaSPAdes](#4-pooled-co-assembly-megahit-vs-metaspades-comparison)
- [5. Gene catalogue + quantification](#5-non-redundant-gene-catalogue-prodigal--cd-hit-est-and-quantification-salmon)
- [6. Functional annotation](#6-functional-annotation-of-the-gene-catalogue)
- [7. Taxonomic classification of reads (Kraken2)](#7-taxonomic-classification-of-reads-kraken2-pluspf-16-database)
- [8. Genome-resolved binning (metaWRAP)](#8-genome-resolved-binning-metawrap-on-the-pooled-co-assembly)
- [9. Dereplication (dRep)](#9-dereplication-drep-99-ani)
- [10. Quality (CheckM2) + taxonomy (GTDB-Tk)](#10-quality-assessment-checkm2-and-taxonomic-placement-gtdb-tk)
- [11. MAG-level annotation, MIMAG + manual verification](#11-mag-level-functional-annotation-mimag-classification-and-manual-verification)
- [12. PufM phylogenetic validation](#12-targeted-phylogenetic-validation-of-pufm-orthology-k08929)
- [13. Summary of expected results](#13-summary-of-expected-results)
- [14. Reproducibility notes](#14-reproducibility-notes)

---

## How to use this guide

This document describes, step by step, how anyone with access to an HPC cluster and basic command-line skills can replicate the full bioinformatic workflow: from raw sequencing reads to functionally annotated, phylogenetically validated metagenome-assembled genomes (MAGs). 

---

## 0. Experimental design: what samples are being analyzed

- The analysis covers **seven enrichment cultures** of *Microcystis aeruginosa* (`E1`–`E7`), each listed as a row in `result/metadata.txt` under the `SampleID` column.
- **`E3` is a technical re-sequencing replicate of `E2`**, and **`E5` is a technical re-sequencing replicate of `E4`**. They come from the **same genomic DNA extract** as `E2` and `E4` respectively — simply re-sequenced (a repeat run of the same library) — not independent biological cultures or extractions.
- **Analysis rule:** `E3` and `E5` must **not** be treated as independent biological replicates in any comparison *across* cultures. If `E1`, `E2`, `E4`, `E6`, `E7` are compared as five biological replicates, `E3` and `E5` are excluded from that count.
- **Exception:** for co-assembly, **all seven read sets are pooled together**, since the goal there is maximizing sequencing depth/coverage, not statistical inference between groups.
- **Metadata-driven design:** every script in `Cluster_script/` reads the sample list from `result/metadata.txt` (`SampleID` column) instead of hardcoding sample names — reuse the repo on a new sample set by editing that file only.

| Sample | Role |
|---|---|
| E1 | Independent biological culture |
| E2 | Independent biological culture |
| E3 | Technical re-sequencing replicate of E2 |
| E4 | Independent biological culture |
| E5 | Technical re-sequencing replicate of E4 |
| E6 | Independent biological culture |
| E7 | Independent biological culture |

---

## 1. Environment setup

**Requirements**

- [ ] HPC cluster with job scheduler (here: NLHPC/SLURM) or a Linux server with ≥200 GB RAM (recommended for metaSPAdes), a multi-core CPU and at least 300 GB of hard drive space to store the databases.
- [ ] Miniconda/Anaconda, with a **separate conda environment per tool** to avoid dependency conflicts
- [ ] PowerShell 5.1+/Core, for `Bakta_batch/BaktaBatch.ps1` (Section 11)
- [ ] Python 3 with `pandas`, for `elLoto_verification/` scripts (Section 11)
- [ ] A reference database directory (`db/`) containing:
  - human reference genome **hg38** (KneadData)
  - **eggNOG v5.0.2**
  - **dbCAN2 / CAZyDB**
  - **CARD**
  - **Kraken2 PlusPF-16**
  - **GTDB**
  - **Bakta v6.0** database
  - **KOfam** profiles
  - a curated **UniProt** reference set for PufM

**Recommended folder structure for a pipeline run**

```text
meta/
├── seq/       -> raw reads (.fq.gz), R1/R2 pairs per sample
├── temp/      -> intermediate files (safe to delete once finished)
├── result/    -> final results, tables, figures, metadata.txt
└── (scripts invoked from Cluster_script/, Bakta_batch/, Pipeline/, elLoto_verification/)
```

**Starting point:** `metadata.txt` must have at least a `SampleID` column (E1…E7), and should be moved to `result/metadata.txt`. Check the file's line endings (Windows vs. Unix) before use — hidden carriage-return characters (`\r`) break shell loops.

---

## 2. Read quality control (fastp)

**Script:** [`Cluster_script/fastp.sh`](Cluster_script/fastp.sh)

| | |
|---|---|
| **Tool** | fastp `v0.23.0` (Chen et al., 2018) |
| **Parameters** | min. Phred quality **20** · min. read length **50 bp** |

**What it does:** trims sequencing adapters and low-quality bases from read ends, and discards reads that become too short after trimming. Run independently per sample (E1–E7), producing HTML/JSON reports for visual QC inspection before/after filtering.

---

## 3. Host decontamination (KneadData + Bowtie2, hg38)

**Script:** [`Cluster_script/kneaddata.sh`](Cluster_script/kneaddata.sh)

| | |
|---|---|
| **Tools** | KneadData `v0.12.4` + Bowtie2 (Langmead & Salzberg, 2012) |
| **Reference** | human genome **hg38** |

**What it does:** maps filtered reads against the human reference genome and removes anything that aligns, keeping only non-human (microbial) reads. Relevant even for environmental/culture samples, since lab handling can introduce trace human contamination.

**Expected output:** per sample, a "clean" FASTQ pair, standardized as `{sample}_1.clean.fastq` / `{sample}_2.clean.fastq`.

> [!TIP]
> Generate a read-count summary table across stages (raw → filtered → decontaminated) — useful for supplementary material.

---

## 4. Pooled co-assembly: MEGAHIT vs. metaSPAdes comparison

**Scripts:** [`Cluster_script/megahit.sh`](Cluster_script/megahit.sh) · [`Cluster_script/metaspades.sh`](Cluster_script/metaspades.sh) · [`Cluster_script/quast.sh`](Cluster_script/quast.sh)

> [!NOTE]
> The assembler choice must be justified with data.

**Design:** clean reads from all **seven** samples (E1–E7) are pooled and assembled **jointly as a single combined input**, no per-sample or per-replicate assembly. This maximizes coverage depth for low-abundance genome reconstruction.

| Assembler | Version | Trade-off | Script |
|---|---|---|---|
| MEGAHIT | `v1.2.9` | Fast, memory-efficient | `megahit.sh` |
| metaSPAdes | `v3.15.0` | Higher local quality, much more RAM/time | `metaspades.sh` |

**Evaluation:** both assemblies compared with **QUAST** (`quast.sh`) — N50, auN, max contig length, contig count.

**Selection — MEGAHIT was chosen.** Although metaSPAdes had a marginally higher N50:

| Metric | MEGAHIT | metaSPAdes |
|---|---|---|
| N50 | 2,393 bp | **2,477 bp** |
| auN | **40,629** | 37,103 |
| Max contig | **1,377,776 bp** | 1,006,773 bp |
| Raw unfiltered contigs | **414,528** | 1,485,791 (~3.6× more) |

MEGAHIT's higher auN, longer maximum contig, and far fewer raw contigs indicate lower overall fragmentation. Full comparison and per-sample read statistics → Supplementary Table S6.

**Final filter:** retain only contigs **≥500 bp** from the selected MEGAHIT assembly.

---

## 5. Non-redundant gene catalogue (Prodigal + CD-HIT-EST) and quantification (Salmon)

**Scripts:** [`Cluster_script/prodigal.sh`](Cluster_script/prodigal.sh) · [`Cluster_script/cdhit.sh`](Cluster_script/cdhit.sh) · [`Cluster_script/salmom.sh`](Cluster_script/salmom.sh)

1. **Gene prediction  Prodigal `v2.6.3`** (`prodigal.sh`), metagenomic mode (`-p meta`). Retain only **complete** ORFs (not truncated at either end), **≥300 bp**.
2. **Non-redundant catalogue  CD-HIT-EST** (`cdhit.sh`): cluster at **95% nucleotide identity**, **90% coverage** of the shorter sequence; keep one representative per cluster.
3. **Quantification  Salmon `v1.10.3`** (`salmom.sh`), metagenomic mode (`--meta`): index from the NR catalogue, quantify TPM and raw counts per sample → sample × gene abundance matrix.

---

## 6. Functional annotation of the gene catalogue

**Script:** [`Cluster_script/eggnog.sh`](Cluster_script/eggnog.sh)

| Database | Tool | Version | Provides |
|---|---|---|---|
| eggNOG v5.0.2 | eggNOG-mapper | `v2.1.7` | COG, KEGG (KO), CAZy orthology |
| CAZyDB | dbCAN2 (DIAMOND blastp) | — | Independent CAZy cross-check |
| CARD | RGI | `v6.0.5` | Antimicrobial resistance genes |

- **eggNOG-mapper** runs on translated NR-catalogue proteins (DIAMOND engine); annotations combined with Salmon TPM → quantitative functional profiles per sample.
- **dbCAN2** independently verifies eggNOG's CAZy calls via direct DIAMOND search.
- **RGI/CARD** reports both strict and "loose" AMR hits — useful for resistome surveillance in environmental/aquaculture contexts.

> [!NOTE]
> dbCAN2 and RGI/CARD calls are not wired to a dedicated script in `Cluster_script/` in the current repository layout — run them alongside `eggnog.sh`, or add `dbcan2.sh` / `rgi.sh` following the same pattern, if you need them in your own run.

---

## 7. Taxonomic classification of reads (Kraken2, PlusPF-16 database)

**Script:** [`Cluster_script/kraken2.sh`](Cluster_script/kraken2.sh)

| | |
|---|---|
| **Tool** | Kraken2 |
| **Database** | PlusPF-16 |
| **Nomenclature** | **GTDB** (not NCBI)  for consistency with MAG classification |

**What it does:** classifies each R1/R2 read pair independently per sample, without assembly.
---

## 8. Genome-resolved binning (metaWRAP) on the pooled co-assembly

**Scripts:** [`Cluster_script/metawrap_binning.sh`](Cluster_script/metawrap_binning.sh) · [`Cluster_script/metawrap_refine.sh`](Cluster_script/metawrap_refine.sh)

| | |
|---|---|
| **Tool** | metaWRAP `v1.3.2` (Uritskiy et al., 2018) |
| **Binners** | MetaBAT2 (Kang et al., 2019) + MaxBin2 (Wu et al., 2016) |

**Design:** binning (`metawrap_binning.sh`) runs on the **single pooled co-assembly**, using all seven samples' reads as coverage input — no per-sample binning.

**Refinement (`metawrap_refine.sh`):** 
- Completeness **≥ 50%**
- Contamination **≤ 10%**

---

## 9. Dereplication (dRep, 99% ANI)

**Script:** [`Cluster_script/drep.sh`](Cluster_script/drep.sh)

| | |
|---|---|
| **Tool** | dRep `v3.2.0` (Olm et al., 2017) |
| **Threshold** | 99% ANI |

Keeps only the highest-quality genome among near-identical bins. **Result: 40 dereplicated MAGs.**

---

## 10. Quality assessment (CheckM2) and taxonomic placement (GTDB-Tk)

**Scripts:** [`Cluster_script/checkm2.sh`](Cluster_script/checkm2.sh) · [`Cluster_script/gtdbtk.sh`](Cluster_script/gtdbtk.sh)

- **CheckM2** (`checkm2.sh`; Chklovski et al., 2023): completeness/contamination via ML model on single-copy marker genes.
- **GTDB-Tk** (`gtdbtk.sh`; Chaumeil et al., 2022): standardized taxonomic classification (domain → species), consistent with Section 7's nomenclature.

**High-quality selection:** completeness **>90%**, contamination **<5%** → **19 of 40** MAGs retained for metabolic reconstruction.

---

## 11. MAG-level functional annotation, MIMAG classification, and manual verification

**Scripts:**
[`Cluster_script/prodigal.sh`](Cluster_script/prodigal.sh) (per-MAG) ·
[`Bakta_batch/BaktaBatch.ps1`](Bakta_batch/BaktaBatch.ps1) ·
[`Cluster_script/trnascan.sh`](Cluster_script/trnascan.sh) ·
[`Cluster_script/kofamscan.sh`](Cluster_script/kofamscan.sh) ·
[`Cluster_script/keggdecoder.sh`](Cluster_script/keggdecoder.sh) ·
[`elLoto_verification/`](elLoto_verification/)

Applied in sequence to each high-quality MAG:

1. **Gene prediction**  Prodigal `v2.6.3` (`prodigal.sh`, metagenomic mode), per MAG.
2. **Functional + rRNA annotation**  **Bakta `v1.12.0`** (db `v6.0`), batch-run via **[`Bakta_batch/BaktaBatch.ps1`](Bakta_batch/BaktaBatch.ps1)**, a PowerShell script that automates upload, job tracking, and result download against the Bakta web API for all 19 high-quality MAGs at once (see `Bakta_batch/README.md` for configuration). rRNA (5S/16S/23S) is identified via Infernal-based covariance models within Bakta.
3. **tRNA genes**  tRNAscan-SE `v2.0.13` (`trnascan.sh`), bacterial search mode.
4. **KEGG orthologue assignment**  KofamScan `v1.3.0` (`kofamscan.sh`), adaptive per-KO score threshold.
5. **Pathway completeness**  KEGG-Decoder (`keggdecoder.sh`), for core C/N/S/energy metabolism + photosynthesis.

> [!CAUTION]
> KEGG-Decoder completeness scores are **aggregate measures** and can overstate completeness when steps overlap central metabolism. **Every reported pathway must be verified gene-by-gene** against Bakta's diagnostic enzyme calls.

### 11.1 Manual gene-by-gene verification (`elLoto_verification/`)

This is where the caution above is actually enforced in code. The `elLoto_verification/` folder implements the manual, gene-level check of every KEGG-Decoder pathway call against Bakta's diagnostic enzyme annotations, run in three ordered steps:

| Script | Purpose |
|---|---|
| `01_filter_kofam.py` | Filters raw KofamScan hits down to the diagnostic KOs relevant to each reported pathway (using `diagnostic_genes.tsv`) |
| `02_verify_diagnostic_genes.py` | Cross-references filtered KOs against each MAG's Bakta annotation (via `genome_map.tsv` / `name_map.tsv`) to confirm the diagnostic enzyme is genuinely present, gene by gene |
| `03_compare_matrices.py` | Compares the resulting verified-gene matrix against the raw KEGG-Decoder completeness matrix, flagging any pathway whose "complete" call is not fully supported at the gene level |

Supporting lookup tables:
- `diagnostic_genes.tsv`  the diagnostic enzymes that define completeness for each tracked pathway
- `genome_map.tsv`  maps internal MAG identifiers to Bakta annotation outputs
- `name_map.tsv`  maps gene/KO identifiers to human-readable pathway component names

Run this step **after** `keggdecoder.sh` and the Bakta batch annotation.

### 11.2 MIMAG "high-quality draft" checklist

(Bowers et al., 2017) — in addition to completeness/contamination:

- [ ] 5S rRNA present (Bakta)
- [ ] 16S rRNA present (Bakta)
- [ ] 23S rRNA present (Bakta)
- [ ] ≥ 18 of 20 canonical tRNA types (tRNAscan-SE)

**Community cross-check:** MAG gene content vs. eggNOG-mapper community catalogue (Section 6) → distinguishes genes absent from recovered genomes vs. genes absent from the whole enrichment.

---

## 12. Targeted phylogenetic validation of PufM orthology (K08929)

**Location:** [`Pipeline/`](Pipeline/)

> [!NOTE]
> Automated domain annotation can misassign genes sharing structural domains with non-photosynthetic protein families, hence a targeted phylogenetic check for *pufM*.

| Step | Tool / version | Detail |
|---|---|---|
| 1. Candidate ID | KofamScan output | K08929 hits in Pseudomonadota MAGs → **7 sequences** |
| 2. Alignment | MAFFT `v7.525` | L-INS-i strategy, + 30 curated UniProt references |
| 3. Trimming | trimAl | `-gappyout` → **306 columns** retained |
| 4. Tree inference | IQ-TREE `v3.1.3` | Model by BIC → **Q.PFAM+F+R4**; 1,000 UFBoot + 1,000 SH-aLRT |


> [!NOTE]
> Reference sequences follow **NCBI** nomenclature (as used by UniProt); taxonomic groupings elsewhere in the manuscript follow **GTDB**, under which Betaproteobacteria is nested within Gammaproteobacteria. Keep this distinction explicit.

---

<div align="center">

*Adapted from EasyMetagenome (Bai et al., 2025) · Executed on NLHPC/CMM, Universidad de Chile*

</div>
