FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04 AS base

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/fish-speech/.venv \
    LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"

ARG DEPENDENCIES="  \
    ca-certificates \
    curl \
    wget \
    libsox-dev \
    build-essential \
    cmake \
    libasound-dev \
    portaudio19-dev \
    libportaudio2 \
    libportaudiocpp0 \
    ffmpeg"

RUN apt-get update && \
    apt-get install -y --no-install-recommends ${DEPENDENCIES} && \
    apt-get clean

ADD https://astral.sh/uv/install.sh /uv-installer.sh

RUN sh /uv-installer.sh && rm /uv-installer.sh

ENV PATH="/root/.local/bin/:$PATH"

RUN uv python install 3.12



FROM base AS builder

WORKDIR /opt/fish-speech
COPY pyproject.toml uv.lock .

RUN uv sync --locked
RUN uv pip install --no-cache-dir huggingface_hub



FROM base AS model

COPY --from=builder /opt/fish-speech/.venv /opt/fish-speech/.venv

WORKDIR /opt/fish-speech

ARG HF_TOKEN
ENV HF_TOKEN=$HF_TOKEN

RUN uv run huggingface-cli download --resume-download fishaudio/openaudio-s1-mini \
    --local-dir checkpoints/openaudio-s1-mini \
    --repo-type model



FROM base AS runtime

COPY --from=builder /opt/fish-speech/.venv /opt/fish-speech/.venv
COPY --from=model /opt/fish-speech/checkpoints /opt/fish-speech/checkpoints

WORKDIR /opt/fish-speech
COPY . .

CMD ["uv", "run", "tools/api_server.py", \
    "--mode", "tts", \
    "--listen", "0.0.0.0:8000", \
    "--compile"]