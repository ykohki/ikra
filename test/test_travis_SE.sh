#!/bin/bash
free -h
cat /proc/`pgrep hogehoge`/status
cpu

cd test/Illumina_SE && bash ../../ikra.sh Illumina_SE_SRR.csv mouse --test -t 6

rm -r salmon_*
rm output.tsv

bash ../../ikra.sh Illumina_SE_fastq.csv mouse --fastq -t 6
