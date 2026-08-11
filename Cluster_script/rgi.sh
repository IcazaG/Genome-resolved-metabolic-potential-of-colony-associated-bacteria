#!/bin/bash
#SBATCH --job-name=rgi
#SBATCH --output=rgi%j.out
#SBATCH --error=rgi%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate rgi

cd ~/meta

rgi main -i result/NR_proteins.faa -t protein \
         -n 16 -a DIAMOND --include_loose --clean \
         -o result/card_proteins

echo "RGI finalizado"