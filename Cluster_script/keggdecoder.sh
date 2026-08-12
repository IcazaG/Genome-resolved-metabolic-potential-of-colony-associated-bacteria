#!/bin/bash
#SBATCH --job-name=keggdecoder
#SBATCH --output=keggdecoder%j.out
#SBATCH --error=keggdecoder%j.err
#SBATCH --partition=XXXXXX
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:30:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate kegg_decoder

cd ~/meta

# Requires that KofamScan results be converted to a file of KOs per genome.
# KEGG-Decoder expects a folder with .ko files (one per genome).
# result/kofamscan/converted to .ko

KEGG-decoder.pl -i result/kofamscan/ko_files/ -o result/kegg_decoder_output

echo "KEGG-Decoder finished"
