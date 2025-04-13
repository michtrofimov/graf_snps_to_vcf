# graf_snps_to_vcf format

A pipeline for pre-processing GRAF (https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/GRAF_README.html) reference file 

# Installation

1. Clone a repository

```
git clone git@github.com:michtrofimov/graf_snps_to_vcf.git
cd graf_snps_to_vcf
```

2. Build docker image

```
docker build -t graf_snps_to_vcf .
```

3. Download and split-by-chromosomes GRCh38 reference genome

https://gdc.cancer.gov/about-data/gdc-data-processing/gdc-reference-files

# Running

1. Convert GRAF file to "vcf"-like format by following `FP_SNPs_README.md` vignette

2. Start docker container in interactive mode 

- mount directory of reference genome that was split-by-chromosomes 

    substitute `/mnt/data/ref/GRCh38.d1.vd1_mainChr/sepChrs/` with path to your directory

```
docker run \
    -v /mnt/data/ref/GRCh38.d1.vd1_mainChr/sepChrs/:/ref/GRCh38.d1.vd1_mainChr/sepChrs/ \
    -it \
    --entrypoint /bin/bash \
    graf_snps_to_vcf
```

3. Start script

```
python main.py -i FP_SNPs_10k_GB38_twoAllelsFormat.tsv -o annotated.tsv -d /ref/GRCh38.d1.vd1_mainChr/sepChrs/
```

4. Check log file `logs/annotation.log`