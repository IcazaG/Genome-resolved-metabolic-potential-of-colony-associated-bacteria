#!/bin/bash
#SBATCH --job-name=kneaddata
#SBATCH --output=kneaddata%j.out
#SBATCH --error=kneaddata%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=02:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate kneaddata

cd ~/meta

# Base de datos de humano (hg38)
DB_HUMAN=~/db/kneaddata/human_genome/hg38

for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    kneaddata -i1 temp/fastp/${i}_1.fastq -i2 temp/fastp/${i}_2.fastq \
              -o temp/kneaddata_out -v -t 16 --remove-intermediate-output \
              --trimmomatic ~/miniconda3/envs/kneaddata/share/trimmomatic/ \
              --trimmomatic-options "ILLUMINACLIP:$HOME/miniconda3/envs/kneaddata/share/trimmomatic/adapters/TruSeq2-PE.fa:2:40:15 LEADING:0 TRAILING:0 SLIDINGWINDOW:4:0 MINLEN:0" \
              --reorder --bowtie2-options "--very-sensitive --dovetail" \
              -db ${DB_HUMAN}
done

# Mover las lecturas limpias a temp/hr/
mkdir -p temp/hr
for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    mv temp/kneaddata_out/${i}_1_kneaddata_paired_1.fastq temp/hr/${i}_1.fastq
    mv temp/kneaddata_out/${i}_1_kneaddata_paired_2.fastq temp/hr/${i}_2.fastq
done
rm -rf temp/kneaddata_out

echo "KneadData finalizado"