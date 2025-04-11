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
    cmake \
    && apt-get clean

# Install libdeflate 
RUN wget https://github.com/ebiggers/libdeflate/archive/refs/tags/v${LIBDEFLATE_VERSION}.tar.gz && \
    tar -vxzf v${LIBDEFLATE_VERSION}.tar.gz && \
    cd libdeflate-${LIBDEFLATE_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=$SOFT/libdeflate-${LIBDEFLATE_VERSION} .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && \
    rm -rf libdeflate-${LIBDEFLATE_VERSION} v${LIBDEFLATE_VERSION}.tar.gz
