#!/bin/bash
#SBATCH --job-name=trnascan
#SBATCH --output=trnascan%j.out
#SBATCH --error=trnascan%j.err
#SBATCH --partition=XXXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=00:30:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate trnascan

cd ~/meta

for mag in result/hq_mags/*.fa; do
    base=$(basename $mag .fa)
    tRNAscan-SE -B -o result/trnascan/${base}_tRNA.out --thread 8 $mag
done

echo "tRNAscan-SE finalizado"
