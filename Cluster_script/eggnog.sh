#!/bin/bash
#SBATCH --job-name=eggnog
#SBATCH --output=eggnog%j.out
#SBATCH --error=eggnog%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=06:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate eggnog

cd ~/meta

emapper.py --data_dir ~/db/eggnog -i result/NR_proteins.faa \
           --cpu 16 -m diamond --override -o temp/eggnog_out

# Clean headers
grep -v '^##' temp/eggnog_out.emapper.annotations | sed '1 s/^#//' > temp/eggnog_clean.tsv

# Generate COG, KEGG, CAZy tables (requires summarizeAbundance.py from the EasyMetagenome package)
summarizeAbundance.py -i result/gene_TPM.tsv -m temp/eggnog_clean.tsv \
    -c '7,12,19' -s '*+,+,' -n raw -o result/eggnog

echo "eggNOG-mapper finished"
