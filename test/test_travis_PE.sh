#!/bin/bash
free -h

cd test/Illumina_PE && bash ../../ikra.sh Illumina_PE_SRR.csv mouse --test -t 6

rm -r salmon_*
rm output.tsv

bash ../../ikra.sh Illumina_PE_fastq.csv mouse --fastq -t 6
