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

# Directory for tools
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

# Install HTSlib from source
RUN wget https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 && \
    tar -vxjf htslib-${HTSLIB_VERSION}.tar.bz2 && \
    cd htslib-${HTSLIB_VERSION} && \
    ./configure --prefix=$SOFT/htslib-${HTSLIB_VERSION} --enable-libcurl --with-libcurl --enable-s3 --enable-gcs && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf htslib-${HTSLIB_VERSION} htslib-${HTSLIB_VERSION}.tar.bz2

# Install Samtools from source
RUN wget https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    tar -vxjf samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    cd samtools-${SAMTOOLS_VERSION} && \
    ./configure --prefix=$SOFT/samtools-${SAMTOOLS_VERSION} --with-htslib=$SOFT/htslib-${HTSLIB_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf samtools-${SAMTOOLS_VERSION} samtools-${SAMTOOLS_VERSION}.tar.bz2

# Install bcftools from source
RUN wget https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    tar -vxjf bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    cd bcftools-${BCFTOOLS_VERSION} && \
    ./configure --prefix=$SOFT/bcftools-${BCFTOOLS_VERSION} --with-htslib=$SOFT/htslib-${HTSLIB_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf bcftools-${BCFTOOLS_VERSION} bcftools-${BCFTOOLS_VERSION}.tar.bz2

# Add tools to PATH
ENV PATH="${SOFT}/htslib-${HTSLIB_VERSION}/bin:${SOFT}/samtools-${SAMTOOLS_VERSION}/bin:${SOFT}/bcftools-${BCFTOOLS_VERSION}/bin:${SOFT}/libdeflate-${LIBDEFLATE_VERSION}/bin:${PATH}"
