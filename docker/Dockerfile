# Rockchip RK356x Linux SDK build environment (linux/amd64).
# On Apple Silicon: docker build|run --platform linux/amd64
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LWS_HMI_DOCKER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    binfmt-support \
    bison \
    bsdmainutils \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    cpio \
    curl \
    imagemagick \
    device-tree-compiler \
    expect \
    fakeroot \
    file \
    flex \
    g++ \
    gcc \
    git \
    libelf-dev \
    libgmp-dev \
    libmpc-dev \
    libncurses-dev \
    libncurses5-dev \
    libssl-dev \
    libusb-1.0-0-dev \
    lz4 \
    lzop \
    make \
    mtd-utils \
    nano \
    openssl \
    parted \
    patchelf \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python2 \
    python-is-python3 \
    qemu-user-static \
    rsync \
    sudo \
    texinfo \
    time \
    u-boot-tools \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    zstd \
    && pip3 install --no-cache-dir httplib2==0.22.0 pyparsing six \
    && rm -rf /var/lib/apt/lists/*

# Passwordless sudo for rootfs image steps (mk-rootfs.sh uses sudo extensively).
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/lws-hmi-build \
    && chmod 0440 /etc/sudoers.d/lws-hmi-build

COPY docker/entrypoint.sh /usr/local/bin/lws-hmi-entrypoint.sh
RUN chmod +x /usr/local/bin/lws-hmi-entrypoint.sh

WORKDIR /work/sdk
ENTRYPOINT ["/usr/local/bin/lws-hmi-entrypoint.sh"]
