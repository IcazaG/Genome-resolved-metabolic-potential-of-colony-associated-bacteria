#!/bin/bash
#SBATCH --job-name=kofamscan
#SBATCH --output=kofamscan%j.out
#SBATCH --error=kofamscan%j.err
#SBATCH --partition=XXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate kofamscan

cd ~/meta

mkdir -p temp/mag_genes
# Predict genes from each MAG with Prodigal
for mag in result/hq_mags/*.fa; do
    base=$(basename $mag .fa)
    prodigal -i $mag -d temp/mag_genes/${base}_genes.fna -o temp/mag_genes/${base}_genes.gff -p single -f gff
    exec_annotation -o result/kofamscan/${base}_kegg.txt \
                    --profile ~/db/kofam/profiles/ \
                    --ko-list ~/db/kofam/ko_list \
                    --cpu 4 \
                    temp/mag_genes/${base}_genes.fna
done

echo "KofamScan finished"
