#!/bin/bash
#SBATCH --job-name=kraken2
#SBATCH --output=kraken2%j.out
#SBATCH --error=kraken2%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=04:00:00

export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate kraken2

cd ~/meta

DB_KRAKEN=~/db/kraken2/pluspf16g

# Kraken2
for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    kraken2 --db ${DB_KRAKEN} --paired temp/hr/${i}_1.fastq temp/hr/${i}_2.fastq \
            --threads 16 --use-names --report-zero-counts \
            --report temp/kraken2/${i}.report --output temp/kraken2/${i}.output
done

# Bracken (especie, S)
for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    bracken -d ${DB_KRAKEN} -i temp/kraken2/${i}.report -r 150 -l S -t 0 -o temp/bracken/${i}.bracken
done

# Combinar tablas (se puede usar combine_mpa.py o el script de EasyMetagenome)
# ...

echo "Kraken2 + Bracken finalizado"