#!/bin/bash
#SBATCH --job-name=prodigal
#SBATCH --output=prodigal%j.out
#SBATCH --error=prodigal%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=01:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate prodigal

cd ~/meta

# Usar el ensamblaje de MEGAHIT (filtrado a ≥500 bp si aún no se ha hecho)
seqkit seq -m 500 temp/megahit/final.contigs.fa > temp/assembly_500.fa

prodigal -i temp/assembly_500.fa -d temp/genes.fna -o temp/genes.gff -p meta -f gff

# Conservar solo genes completos (partial=00) y ≥300 bp
seqkit seq -m 300 temp/genes.fna > temp/genes_full.fna
grep 'partial=00' temp/genes_full.fna | cut -f1 -d ' ' | sed 's/>//' > temp/complete_ids.txt
seqkit grep -f temp/complete_ids.txt temp/genes_full.fna > temp/genes_complete.fna

echo "Prodigal finalizado"
