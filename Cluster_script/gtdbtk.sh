#!/bin/bash
#SBATCH --job-name=gtdbtk
#SBATCH --output=gtdbtk%j.out
#SBATCH --error=gtdbtk%j.err
#SBATCH --partition=XXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=08:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate gtdbtk2.3

cd ~/meta

export GTDBTK_DATA_PATH=~/db/gtdb

gtdbtk classify_wf --genome_dir temp/drep99/dereplicated_genomes \
    --out_dir result/gtdbtk --extension fa --skip_ani_screen --cpus 16

gtdbtk infer --msa_file result/gtdbtk/align/tax.bac120.user_msa.fasta.gz \
    --out_dir result/gtdbtk_tree --prefix tax --cpus 16

echo "GTDB-Tk finished"
