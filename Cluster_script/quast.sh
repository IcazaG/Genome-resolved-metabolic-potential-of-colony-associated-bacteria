#!/bin/bash
#SBATCH --job-name=quast
#SBATCH --output=quast%j.out
#SBATCH --error=quast%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=00:30:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate megahit   # QUAST suele estar en el mismo entorno que MEGAHIT o en uno propio

cd ~/meta

# Comparar los dos ensamblajes (si existen ambos)
quast.py temp/megahit/final.contigs.fa temp/metaspades/contigs.fasta \
        -o result/quast_comparison -t 8

echo "QUAST finalizado"