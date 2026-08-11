#!/bin/bash
#SBATCH --job-name=metawrap_refine
#SBATCH --output=metawrap_refine%j.out
#SBATCH --error=metawrap_refine%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate metawrap

cd ~/meta

metawrap bin_refinement -o temp/bin_refinement \
    -A temp/binning/metabat2_bins/ -B temp/binning/maxbin2_bins/ \
    -c 50 -x 10 -t 16

echo "MetaWRAP refinement finalizado"