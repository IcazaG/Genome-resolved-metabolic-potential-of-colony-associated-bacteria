# Workflow for the metagenomic analysis of bacterial communities associated with Microcystis aeruginosa colonies (El Loto wetland, southern Chile)
## 1. Quality Control

fastp v0.23.0, quality filtering (minimum Phred score Q20, minimum read length 50 bp)
KneadData v0.12.4 (+ Bowtie2),  removal of human contamination (hg38 reference)

## 2. Assembly and Gene Catalog Construction

De novo assembly compared between metaSPAdes v3.15.0 and MEGAHIT v1.2.9 (MEGAHIT selected based on superior assembly metrics; contigs ≥500 bp retained)
Gene prediction with Prodigal v2.6.3 (metagenomic mode, complete ORFs ≥300 bp)
Non-redundant gene catalog built with CD-HIT-EST (95% nucleotide identity, 90% coverage thresholds)

## 3. Functional and Taxonomic Annotation

Gene abundance quantification with Salmon v1.10.3 (metagenomic mode)
Functional annotation with eggNOG-mapper v2.1.7 (eggNOG DB v5.0.2) → COG, KEGG, CAZy annotations
Antimicrobial resistance genes identified with RGI v6.0.5 (CARD database)
Taxonomic classification of reads with Kraken2 (PlusPF-16 database), converted to GTDB nomenclature

## 4. Genome Binning, Quality Assessment, and MAG Reconstruction

Binning with metaWRAP v1.3.2 (integrates MaxBin2 and MetaBAT2); bins retained at ≥50% completeness, ≤10% contamination
Dereplication at 99% ANI with dRep v3.2.0
Genome quality assessment with CheckM2
Phylogenomic placement with GTDB-Tk
Gene prediction on MAG contigs with Prodigal v2.6.3

## 5. Metabolic Potential Inference

Core metabolic modules (carbon metabolism, carbon fixation, energy transduction, nitrogen cycling, sulfur cycling, photosynthesis) inferred with KEGG-Decoder
Visualized as a heatmap of module completeness scores (0–1)
