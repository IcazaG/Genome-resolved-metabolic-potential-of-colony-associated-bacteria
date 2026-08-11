#!/bin/bash
#SBATCH --job-name=fastp
#SBATCH --output=fastp%j.out
#SBATCH --error=fastp%j.err
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=00:30:00

# 1. Cargar conda
export PATH="$HOME/miniconda3/bin:$PATH"
source "$HOME/miniconda3/etc/profile.d/conda.sh"

# 2. Activar entorno (fastp está en kneaddata)
conda activate kneaddata

# 3. Ir al directorio del proyecto
cd ~/meta

# 4. Ejecutar fastp para todas las muestras
for i in $(tail -n+2 result/metadata.txt | cut -f1); do
    fastp -i seq/${i}_1.fq.gz -I seq/${i}_2.fq.gz \
          -o temp/fastp/${i}_1.fastq -O temp/fastp/${i}_2.fastq \
          --qualified_quality_phred 20 --length_required 50 \
          --thread 8
done

echo "fastp finalizado"