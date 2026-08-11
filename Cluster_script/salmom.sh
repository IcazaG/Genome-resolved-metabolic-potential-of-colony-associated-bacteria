#!/bin/bash
#SBATCH --job-name=salmon
#SBATCH --output=salmon%j.out
#SBATCH --error=salmon%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate salmon

cd ~/meta

salmon index -t result/NR_genes.fna -p 8 -i temp/salmon_index

for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    salmon quant -i temp/salmon_index -l A -p 8 --meta \
           -1 temp/hr/${i}_1.fastq -2 temp/hr/${i}_2.fastq \
           -o temp/salmon/${i}.quant
done

salmon quantmerge --quants temp/salmon/*.quant -o result/gene_TPM.tsv
sed -i '1 s/.quant//g' result/gene_TPM.tsv

echo "Salmon finalizado"
