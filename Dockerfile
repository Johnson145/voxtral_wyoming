# The default image already supports CPU and standard NVIDIA GPUs. These args let the same file
# target GPUs that need a newer CUDA/PyTorch build than the stock wheel ships — e.g. NVIDIA Spark
# DGX (GB10 / Blackwell), which requires CUDA 13 with SM_121. Leave them unset for original behaviour.
ARG BASE_IMAGE=python:3.13-slim
FROM ${BASE_IMAGE} AS runtime

# Extra apt packages required by some targets (e.g. "build-essential" for CUDA builds). Empty by default.
ARG EXTRA_APT_PACKAGES=""

# Install system dependencies and uv (global)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    ${EXTRA_APT_PACKAGES} \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv \
    && uv --version

WORKDIR /app

# Python version uv should use. On python:3.13-slim this is the bundled interpreter; on base
# images without Python (e.g. nvidia/cuda) uv downloads a managed CPython of this version.
ARG UV_PYTHON=3.13

# Optional CUDA wheel index for torch (e.g. https://download.pytorch.org/whl/cu130 for GB10).
# Empty by default -> the stock torch wheel pinned in uv.lock is used unchanged.
ARG TORCH_CUDA_INDEX=""
# torch spec to (re)install from the CUDA index; pin a version for reproducibility (e.g. torch==2.11.0+cu130).
ARG TORCH_SPEC="torch"

# Create non-root user early
RUN useradd -m -u 10001 -s /usr/sbin/nologin appuser

# Create HuggingFace cache directory with proper ownership for volume mount
RUN mkdir -p /home/appuser/.cache/huggingface && chown -R 10001:10001 /home/appuser/.cache

# Create output directory for audio files with proper ownership
RUN mkdir -p /output/audio && chown -R 10001:10001 /output

# Copy dependency files first (for better layer caching)
COPY pyproject.toml uv.lock /app/
RUN chown -R 10001:10001 /app

USER appuser

# Install dependencies only (this layer will be cached unless dependency files change)
RUN UV_PYTHON=${UV_PYTHON} uv sync --no-dev --no-install-project

# Copy project files needed for package installation (changes here won't invalidate the dependency installation layer)
COPY --chown=10001:10001 README.md LICENSE /app/
COPY --chown=10001:10001 src /app/src

# Install the project itself (fast since dependencies are already installed)
RUN UV_PYTHON=${UV_PYTHON} uv sync --no-dev

# Optionally swap the lock file's stock torch wheel for a specific CUDA build (no-op unless TORCH_CUDA_INDEX is set).
# Done after the final sync, since `uv sync` would otherwise reinstall the stock wheel from uv.lock.
RUN if [ -n "${TORCH_CUDA_INDEX}" ]; then \
        UV_PYTHON=${UV_PYTHON} uv pip install --reinstall ${TORCH_SPEC} --index-url "${TORCH_CUDA_INDEX}"; \
    fi

# Ensure virtualenv is on PATH for runtime
ENV PATH="/app/.venv/bin:${PATH}"

CMD ["voxtral-wyoming"]
