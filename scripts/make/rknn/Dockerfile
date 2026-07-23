# RKNN-Toolkit2 conversion environment (linux/amd64).
# On Apple Silicon hosts, build/run with: docker build|run --platform linux/amd64
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    python3.8 \
    python3.8-dev \
    python3-pip \
    unzip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.8 /usr/local/bin/python3 \
    && ln -sf /usr/bin/python3.8 /usr/local/bin/python

ARG RKNN_VERSION=2.3.2
COPY requirements-docker.txt /tmp/requirements-docker.txt
COPY _cache/rknn_toolkit2-${RKNN_VERSION}-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl /tmp/
COPY _cache/torch-2.4.0+cpu-cp38-cp38-linux_x86_64.whl /tmp/

# CPU-only PyTorch avoids multi-GB NVIDIA CUDA wheels (conversion does not need GPU).
RUN python3 -m pip install --upgrade 'pip<25' \
    && PIP_DEFAULT_TIMEOUT=600 python3 -m pip install --no-cache-dir -r /tmp/requirements-docker.txt \
    && PIP_DEFAULT_TIMEOUT=600 python3 -m pip install --no-cache-dir scipy==1.10.1 \
    && PIP_DEFAULT_TIMEOUT=600 python3 -m pip install --no-cache-dir opencv-python==4.8.1.78 \
    && rm -f /tmp/requirements-docker.txt

RUN python3 -m pip install --no-cache-dir /tmp/torch-2.4.0+cpu-cp38-cp38-linux_x86_64.whl \
    && python3 -m pip install /tmp/rknn_toolkit2-${RKNN_VERSION}-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
    && rm -f /tmp/torch-2.4.0+cpu-cp38-cp38-linux_x86_64.whl /tmp/rknn_toolkit2-*.whl

WORKDIR /work
COPY onnx_to_rknn.py /usr/local/bin/onnx_to_rknn.py
RUN chmod +x /usr/local/bin/onnx_to_rknn.py

ENTRYPOINT ["python3", "/usr/local/bin/onnx_to_rknn.py"]
