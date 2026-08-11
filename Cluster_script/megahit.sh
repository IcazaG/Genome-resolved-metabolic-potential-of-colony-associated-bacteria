#!/bin/bash
#SBATCH --job-name=megahit
#SBATCH --output=megahit%j.out
#SBATCH --error=megahit%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=00:25:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate megahit

cd ~/meta

/usr/bin/time -v megahit -t 16 \
    -1 $(tail -n+2 result/metadata.txt | cut -f1 | sed 's/^/temp\/hr\//;s/$/_1.fastq/' | tr '\n' ',' | sed 's/,$//') \
    -2 $(tail -n+2 result/metadata.txt | cut -f1 | sed 's/^/temp\/hr\//;s/$/_2.fastq/' | tr '\n' ',' | sed 's/,$//') \
    -o temp/megahit

echo "MEGAHIT finalizado"
