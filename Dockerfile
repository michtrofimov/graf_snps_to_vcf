FROM ubuntu:22.04

# Base system configuration
ENV SOFT=/soft
RUN mkdir -p ${SOFT}

# System packages installation (single layer for base dependencies)
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    bzip2 \
    cmake \
    g++ \
    gcc \
    libbz2-dev \
    libcurl4-openssl-dev \
    liblzma-dev \
    libncurses-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libssl-dev \
    make \
    parallel \
    wget \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# HTSlib 1.21 (release date: 2024-09-12)
ENV HTSLIB_VERSION=1.21
ENV HTSLIB=${SOFT}/htslib-${HTSLIB_VERSION}
ENV PATH="${HTSLIB}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${HTSLIB}/lib"
ENV HTSFILE="${HTSLIB}/bin/htsfile" 

RUN wget https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
    && tar -xjf htslib-${HTSLIB_VERSION}.tar.bz2 \
    && cd htslib-${HTSLIB_VERSION} \
    && ./configure --prefix=${HTSLIB} --enable-libcurl --with-libcurl --enable-s3 --enable-gcs \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf htslib-${HTSLIB_VERSION} htslib-${HTSLIB_VERSION}.tar.bz2

# -------------------------------------------------------------------
# Samtools 1.21 (release date: 2024-09-12)
ENV SAMTOOLS_VERSION=1.21
ENV SAMTOOLS=${SOFT}/samtools-${SAMTOOLS_VERSION}
ENV PATH="${SAMTOOLS}/bin:${PATH}"
ENV SAMTOOLS="${SAMTOOLS}/bin/samtools"  

RUN wget https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
    && tar -xjf samtools-${SAMTOOLS_VERSION}.tar.bz2 \
    && cd samtools-${SAMTOOLS_VERSION} \
    && ./configure --prefix=${SOFT}/samtools-${SAMTOOLS_VERSION} --with-htslib=${HTSLIB} \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf samtools-${SAMTOOLS_VERSION} samtools-${SAMTOOLS_VERSION}.tar.bz2

# -------------------------------------------------------------------
# BCFtools 1.21 (release date: 2024-09-12)
ENV BCFTOOLS_VERSION=1.21
ENV BCFTOOLS=${SOFT}/bcftools-${BCFTOOLS_VERSION}
ENV PATH="${BCFTOOLS}/bin:${PATH}"
ENV BCFTOOLS="${BCFTOOLS}/bin/bcftools"  

RUN wget https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
    && tar -xjf bcftools-${BCFTOOLS_VERSION}.tar.bz2 \
    && cd bcftools-${BCFTOOLS_VERSION} \
    && ./configure --prefix=${SOFT}/bcftools-${BCFTOOLS_VERSION} --with-htslib=${HTSLIB} \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf bcftools-${BCFTOOLS_VERSION} bcftools-${BCFTOOLS_VERSION}.tar.bz2

# -------------------------------------------------------------------
# libdeflate 1.23 (release date: 2024-12-16)
ENV LIBDEFLATE_VERSION=1.23
ENV LIBDEFLATE=${SOFT}/libdeflate-${LIBDEFLATE_VERSION}
ENV PATH="${LIBDEFLATE}/bin:${PATH}"

RUN wget https://github.com/ebiggers/libdeflate/archive/refs/tags/v${LIBDEFLATE_VERSION}.tar.gz \
    && tar -xzf v${LIBDEFLATE_VERSION}.tar.gz \
    && cd libdeflate-${LIBDEFLATE_VERSION} \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=${LIBDEFLATE} .. \
    && make -j$(nproc) \
    && make install \
    && cd ../.. \
    && rm -rf libdeflate-${LIBDEFLATE_VERSION} v${LIBDEFLATE_VERSION}.tar.gz
