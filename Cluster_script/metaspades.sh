#!/bin/bash
#SBATCH --job-name=metaspades
#SBATCH --output=metaspades%j.out
#SBATCH --error=metaspades%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=200G
#SBATCH --time=12:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate metawrap   # metaSPAdes suele estar en el entorno metawrap

cd ~/meta

# Concatenar lecturas (metaSPAdes necesita un solo par de archivos)
cat temp/hr/*_1.fastq > temp/all_1.fastq
cat temp/hr/*_2.fastq > temp/all_2.fastq

metaspades.py -t 16 -m 200 \
    -1 temp/all_1.fastq -2 temp/all_2.fastq \
    -o temp/metaspades

rm temp/all_1.fastq temp/all_2.fastq

echo "metaSPAdes finalizado"