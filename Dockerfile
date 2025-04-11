FROM ubuntu:22.04

# Version from 12.09.2024
ENV HTSLIB_VERSION=1.21 

# Version from 12.09.2024
ENV SAMTOOLS_VERSION=1.21

# Version from 12.09.2024
ENV BCFTOOLS_VERSION=1.21

# Version from 16.12.2024
ENV LIBDEFLATE_VERSION=1.23

# Version from 02.08.2018
ENV VCFTOOLS_VERSION=1.23

# Path for tools
ENV SOFT=/soft

WORKDIR /project

RUN apt-get update && apt-get install -y \
    libncurses-dev \
    libbz2-dev \
    zlib1g-dev \
    liblzma-dev \
    wget \
    bzip2 \
    gcc \
    make \
    autoconf \
    automake \
    libcurl4-openssl-dev \
    libssl-dev \
    g++ \
    libncurses5-dev \
    libncursesw5-dev \
    parallel \
    && apt-get clean