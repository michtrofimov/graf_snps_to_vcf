#!/bin/bash
mkdir -p data
awk 'BEGIN{OFS="\t"} NR==1 {print "#CHROM", "POS", "ID", "allele1", "allele2"; next} {print "chr"$2, $4, "rs"$1, $5, $6}' /project/graf-2.4/data/FP_SNPs.txt | grep -v "chr23" > tmp && mv tmp data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv