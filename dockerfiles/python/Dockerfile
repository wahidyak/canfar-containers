# Layer 2: Python Runtime (Mamba, UV, Pixi)
FROM images.canfar.net/cadc/base:26.02

LABEL description="Python Runtime for CANFAR Science Platform"

ARG TARGETARCH
ARG PYTHON_VERSION=3.12
# renovate: datasource=github-releases depName=mamba-org/micromamba-releases
ARG MICROMAMBA_VERSION=2.5.0-1
# renovate: datasource=github-releases depName=astral-sh/uv
ARG UV_VERSION=0.10.0
# renovate: datasource=github-releases depName=prefix-dev/pixi
ARG PIXI_VERSION=0.63.2

ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"

RUN set -x \
    && if [ "${TARGETARCH}" = "arm64" ]; then ARCH="aarch64"; else ARCH="64"; fi \
    && curl -Ls https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VERSION}/micromamba-linux-${ARCH} -o ./micromamba \
    && chmod +x ./micromamba \
    && ./micromamba install \
        --root-prefix="${CONDA_DIR}" \
        --prefix="${CONDA_DIR}" \
        --yes \
        python=${PYTHON_VERSION} mamba \
    && rm ./micromamba \
    && ln -s ${CONDA_DIR}/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Install modern environment managers
RUN mamba install --yes \
        conda \
        pip \
        conda-libmamba-solver \
        pip-tools \
        uv=${UV_VERSION} \
        pixi=${PIXI_VERSION} \
    && mamba clean --all --quiet --yes

# Configure Conda for home-directory persistence
RUN mkdir -p /etc/conda && printf 'envs_dirs:\n  - ~/.conda/envs\n  - /opt/conda/envs\npkgs_dirs:\n  - ~/.conda/pkgs\n  - /opt/conda/pkgs\n' > /etc/conda/condarc

# Configure Pip for user-only installs
RUN printf '[global]\nuser = true\n' > /etc/pip.conf

# Global environment variables for user-space persistence
RUN printf 'export PATH="${HOME}/.local/bin:${PATH}"\nexport PYTHONUSERBASE="${HOME}/.local"\nexport UV_PYTHON_INSTALL_DIR="${HOME}/.local/share/uv/python"\nexport UV_CACHE_DIR="${HOME}/.cache/uv"\nexport PIXI_HOME="${HOME}/.pixi"\nexport XDG_CACHE_HOME="${HOME}/.cache"\nexport XDG_DATA_HOME="${HOME}/.local/share"\nexport XDG_CONFIG_HOME="${HOME}/.config"\n' > /etc/profile.d/opencadc.sh
