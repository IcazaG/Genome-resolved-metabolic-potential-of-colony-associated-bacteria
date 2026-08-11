#!/bin/bash
#SBATCH --job-name=cdhit
#SBATCH --output=cdhit%j.out
#SBATCH --error=cdhit%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate cdhit

cd ~/meta

cd-hit-est -i temp/genes_complete.fna -o result/NR_genes.fna \
           -c 0.95 -aS 0.9 -G 0 -g 0 -T 16 -M 0

# Traducir a proteínas
seqkit translate --trim result/NR_genes.fna > result/NR_proteins.faa

echo "CD-HIT finalizado"
