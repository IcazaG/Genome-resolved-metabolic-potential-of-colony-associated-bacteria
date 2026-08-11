#!/bin/bash
#SBATCH --job-name=metawrap_bin
#SBATCH --output=metawrap_bin%j.out
#SBATCH --error=metawrap_bin%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=08:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate metawrap

cd ~/meta

# Utiliza el ensamblaje ≥500 bp de MEGAHIT
metawrap binning -o temp/binning -t 16 -a temp/assembly_500.fa \
    --metabat2 --maxbin2 temp/hr/*.fastq

echo "MetaWRAP binning finalizado"