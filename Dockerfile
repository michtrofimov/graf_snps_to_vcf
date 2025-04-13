FROM ubuntu:22.04

# Base system configuration
ENV SOFT=/soft
RUN mkdir -p ${SOFT}

# Set environment variables to suppress interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# System packages installation (single layer for base dependencies)
RUN apt-get update && apt-get install -y \
    gpg-agent \
    software-properties-common \
    gnupg2 \
    dirmngr \
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
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
# VCFtools 0.1.16 (release date: 2018-08-02)
ENV VCFTOOLS_VERSION=0.1.16
ENV VCFTOOLS=${SOFT}/vcftools-${VCFTOOLS_VERSION}
ENV PATH="${VCFTOOLS}/bin:${PATH}"
ENV VCFTOOLS="${VCFTOOLS}/bin/vcftools" 

RUN wget https://github.com/vcftools/vcftools/releases/download/v${VCFTOOLS_VERSION}/vcftools-${VCFTOOLS_VERSION}.tar.gz \
    && tar -xzf vcftools-${VCFTOOLS_VERSION}.tar.gz \
    && cd vcftools-${VCFTOOLS_VERSION} \
    && ./autogen.sh \
    && ./configure --prefix=${SOFT}/vcftools-${VCFTOOLS_VERSION} \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf vcftools-${VCFTOOLS_VERSION} vcftools-${VCFTOOLS_VERSION}.tar.gz


# Install Python 3.9 and set as default
RUN  add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get install -y --no-install-recommends \
    python3.9 \
    python3.9-dev \
    python3.9-distutils \
    python3-pip && \
    ln -sf /usr/bin/python3.9 /usr/bin/python && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install packages
RUN python -m pip install --no-cache-dir \
    pandas==2.2.3 \
    pysam==0.23.0

WORKDIR /project

COPY main.py graf_snps_to_vcf/data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv .

ENTRYPOINT ["bash"]