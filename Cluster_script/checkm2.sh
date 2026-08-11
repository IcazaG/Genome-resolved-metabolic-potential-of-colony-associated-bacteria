#!/bin/bash
#SBATCH --job-name=checkm2
#SBATCH --output=checkm2%j.out
#SBATCH --error=checkm2%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate checkm2

cd ~/meta

checkm2 predict --threads 16 --input temp/drep99/dereplicated_genomes/ \
                --output-directory result/checkm2_output

echo "CheckM2 finalizado"