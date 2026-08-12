#!/bin/bash
#SBATCH --job-name=drep
#SBATCH --output=drep%j.out
#SBATCH --error=drep%j.err
#SBATCH --partition=XXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate drep

cd ~/meta

mkdir -p temp/drep_in
ln -sf $(pwd)/temp/bin_refinement/metawrap_50_10_bins/bin.* temp/drep_in/
rename 'bin' 'MAG' temp/drep_in/bin.*

dRep dereplicate temp/drep99/ -g temp/drep_in/*.fa -sa 0.99 -nc 0.30 -comp 50 -con 10 -p 16

echo "dRep finished"
