#! bin/bash
set -xeu

<<COMMENTOUT

$ bash MakeCountTable_SRR.sh tpTregTconv_rnaseq_experiment_table.csv outdir mouse

- fastqかSRRの判別
- trimmomatic
- gtf, transcript file をGENCODEから
- salmon

COMMENTOUT

# 実験テーブル.csv
EX_MATRIX_FILE=$1
RUNINDOCKER=1
THREADS=8
REF_SPIECE=$2

DOCKER=docker
# DOCKER=udocker # udockerも指定できる。

SCRIPT_DIR=$(cd $(dirname $0); pwd)

if [[ $REF_SPIECE = mouse ]]; then
  BASE_REF_TRANSCRIPT=ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M19
  REF_TRANSCRIPT=gencode.vM19.transcripts.fa.gz
  SALMON_INDEX=salmon_index_mouse
#   REF_GTF=gencode.vM19.annotation.gtf.gz

elif [[ $REF_SPIECE = human ]]; then
  BASE_REF_TRANSCRIPT=ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_29
  # REF_TRANSCRIPT=gencode.v29.pc_translations.fa.gz
  REF_TRANSCRIPT=gencode.v29.transcripts.fa.gz
  SALMON_INDEX=salmon_index_human
#   REF_GTF=gencode.v29.annotation.gtf.gz
  
  
else
  echo No reference speice!
  exit
fi

COWSAY=cowsay
PREFETCH=prefetch
PFASTQ_DUMP=pfastq-dump
FASTQ_DUMP=fastq-dump
FASTQC=fastqc
MULTIQC=multiqc
TRIMMOMATIC=trimmomatic
SALMON=salmon


if [[ "$RUNINDOCKER" -eq "1" ]]; then
  echo "RUNNING IN DOCKER"
  # docker を走らせ終わったらコンテナを削除。(-rm)ホストディレクトリをコンテナにマウントする。(-v)

  DRUN="$DOCKER run --rm -v $PWD:/data --workdir /data -i"
  #--user=biodocker
  
  COWSAY_IMAGE=docker/whalesay
  SRA_TOOLKIT_IMAGE=inutano/sra-toolkit
  FASTQC_IMAGE=biocontainers/fastqc:v0.11.5_cv2
  MULTIQC_IMAGE=maxulysse/multiqc
  TRIMMOMATIC_IMAGE=fjukstad/trimmomatic
#   TRIMMOMATIC_IMAGR=comics/trimmomatic
  SALMON_IMAGE=combinelab/salmon:latest
  
  $DOCKER pull $COWSAY_IMAGE
  $DOCKER pull $SRA_TOOLKIT_IMAGE
  $DOCKER pull $FASTQC_IMAGE
  $DOCKER pull $MULTIQC_IMAGE
  $DOCKER pull $TRIMMOMATIC_IMAGE
  $DOCKER pull $SALMON_IMAGE

  COWSAY="$DRUN $COWSAY_IMAGE $COWSAY"
  PREFETCH="$DRUN -v $PWD:/root/ncbi/public/sra $SRA_TOOLKIT_IMAGE $PREFETCH"
  PFASTQ_DUMP="$DRUN $SRA_TOOLKIT_IMAGE $PFASTQ_DUMP"
  FASTQ_DUMP="$DRUN $SRA_TOOLKIT_IMAGE $FASTQ_DUMP"
  FASTQC="$DRUN $FASTQC_IMAGE $FASTQC"
  MULTIQC="$DRUN $MULTIQC_IMAGE $MULTIQC"
#   TRIMMOMATIC="$DRUN $TRIMMOMATIC_IMAGE $TRIMMOMATIC"
  TRIMMOMATIC="$DRUN $TRIMMOMATIC_IMAGE " # fjukstad/trimmomaticのentrypointのため
  SALMON="$DRUN $SALMON_IMAGE $SALMON"
   # docker run --rm -v $PWD:/data -v $PWD:/root/ncbi/public/sra --workdir /data -it inutano/sra-toolkit bash
else
  echo "RUNNING LOCAL"
fi

# 十分大きなものにする。
MAXSIZE=20G
SRA_ROOT=$HOME/ncbi/public/sra

# テスト用。ダウンロードするread数。全部使うときは0に
MAX_SPOT_ID=100000

if [ $MAX_SPOT_ID = 0 ]; then
  MAX_SPOT_ID=""
else
  $COWSAY "test mode( MAX_SPOT_ID is set)"
  MAX_SPOT_ID="-X $MAX_SPOT_ID"
fi

echo ${1}
cat $1


# # prefetch
# # 先頭一行をとばす。
# for i in `tail -n +2  $1`
# do
# name=`echo $i | cut -d, -f1`
# SRR=`echo $i | cut -d, -f2`
# #   echo "$name $fqfile"
# if [[ ! -f "$SRA_ROOT/$SRR.sra" ]] && [[ ! -f "$SRR.fastq" ]]; then
# $PREFETCH $SRR --max-size $MAXSIZE
# fi
# done
# # pfastq_dump
# for i in `tail -n +2  $1`
# do
# name=`echo $i | cut -d, -f1`
# SRR=`echo $i | cut -d, -f2`
# LAYOUT=`echo $i | cut -d, -f3`
# # SE
# if [ $LAYOUT = SE ]; then
# if [[ ! -f "$SRR.fastq.gz" ]]; then
# $PFASTQ_DUMP --threads $THREADS $SRR.sra
# gzip $SRR.fastq
# fi
# # PE
# else
# if [[ ! -f "$SRR_1.fastq.gz" ]]; then
# $PFASTQ_DUMP --threads $THREADS $SRR.sra --split-files
# gzip $SRR_1.fastq
# gzip $SRR_2.fastq
# fi
# fi
# done



# fastq_dump
for i in `tail -n +2  $1`
do
name=`echo $i | cut -d, -f1`
SRR=`echo $i | cut -d, -f2`
LAYOUT=`echo $i | cut -d, -f3`

# SE
if [ $LAYOUT = SE ]; then
  # fastq_dump
  if [[ ! -f "$SRR.fastq.gz" ]]; then
    $FASTQ_DUMP $SRR $MAX_SPOT_ID --gzip
  fi
  
  # fastqc
  if [[ ! -f "${SRR}_fastqc.zip" ]]; then
    $FASTQC -t $THREADS ${SRR}.fastq.gz
  fi
  
  # trimmomatic
  if [[ ! -f "${SRR}_trimmed.fastq.gz" ]]; then
    $TRIMMOMATIC \
    $LAYOUT \
    -threads $THREADS \
    -phred33 \
    -trimlog log.${SRR}.txt \
    ${SRR}.fastq.gz \
    ${SRR}_trimmed.fastq.gz \
    ILLUMINACLIP:adapters/TruSeq3-SE.fa:2:10:10 \
    LEADING:20 \
    TRAILING:20 \
    MINLEN:30
  fi

  # fastqc
  if [[ ! -f "${SRR}_fastqc.zip" ]]; then
    $FASTQC -t $THREADS ${SRR}_trimmed.fastq.gz
  fi
  
# PE
else
  # fastq_dump
  if [[ ! -f "$SRR_1.fastq.gz" ]]; then
    $FASTQ_DUMP $SRR $MAX_SPOT_ID --gzip --split-files
  fi
  
  # fastqc
  if [[ ! -f "${SRR}_1_fastqc.zip" ]]; then
    $FASTQC -t $THREADS ${SRR}_1.fastq.gz
    $FASTQC -t $THREADS ${SRR}_2.fastq.gz
  fi
  
  # trimmomatic
  if [[ ! -f "${SRR}_1_trimmed_paired.fastq.gz" ]]; then
    $TRIMMOMATIC \
    $LAYOUT \
    -threads $THREADS \
    -phred33 \
    -trimlog log.${SRR}.txt \
    ${SRR}_1.fastq.gz ${SRR}_2.fastq.gz \
    ${SRR}_1_trimmed_paired.fastq.gz ${SRR}_1_unpaired.fastq.gz \
    ${SRR}_2_trimmed_paired.fastq.gz ${SRR}_2_unpaired.fastq.gz \
#     LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36
    ILLUMINACLIP:adapters/TruSeq2-PE.fa:2:30:10 \
    LEADING:3 \
    TRAILING:3 \
    SLIDINGWINDOW:4:15 \
    MINLEN:36
  fi
  
  # fastqc
  if [[ ! -f "${SRR}_1_fastqc.zip" ]]; then
    $FASTQC -t $THREADS ${SRR}_1_trimmed_paired.fastq.gz
    $FASTQC -t $THREADS ${SRR}_2_trimmed_paired.fastq.gz
  fi
fi
done

 # multiqc
# if [[ ! -f "multiqc_report_rawfastq.html" ]]; then
#   $MULTIQC -n multiqc_report_rawfastq.html .
# fi

# download $REF_TRANSCRIPT
if [[ ! -f "$REF_TRANSCRIPT" ]]; then
  wget $BASE_REF_TRANSCRIPT/$REF_TRANSCRIPT
fi

# # download $REF_GTF
# if [[ ! -f "$REF_GTF" ]]; then
#   wget $BASE_REF_TRANSCRIPT/$REF_GTF
# fi

# instance salmon index
if [[ ! -d "$SALMON_INDEX" ]]; then
  $SALMON index --threads $THREADS --transcripts $REF_TRANSCRIPT --index $SALMON_INDEX --type quasi -k 31 --gencode
fi

for i in `tail -n +2  $1`
do
  name=`echo $i | cut -d, -f1`
  SRR=`echo $i | cut -d, -f2`
  LAYOUT=`echo $i | cut -d, -f3`
  
  # SE
  if [ $LAYOUT = SE ]; then
    if [[ ! -f "salmon_output_${SRR}/quant.sf" ]]; then
      mkdir salmon_output_${SRR}
      # libtype auto detection mode
      $SALMON quant -i $SALMON_INDEX \
      -l A \
      -r ${SRR}.fastq.gz \
      -p $THREADS \
      -o salmon_output_${SRR} \
#       -g $REF_GTF
    fi
    
   # PE
  else
    if [[ ! -f "salmon_output_${SRR}" ]]; then
      mkdir salmon_output_${SRR}
      # libtype auto detection mode
      salmon quant -i $SALMON_INDEX \
      -l A \
      -1 ${SRR}_1.fastq.gz \
      -2 ${SRR}_2.fastq.gz \
      -p $THREADS \
      -o salmon_output_${SRR} \
#       -g $REF_GTF
    fi
  fi
done

 # multiqc
if [[ ! -f "multiqc_report.html" ]]; then
  $MULTIQC -n multiqc_report.html .
fi