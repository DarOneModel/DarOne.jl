FROM julia:1.10.13-bookworm

ENV JULIA_PROJECT=/dar_one_docker/DarOne.jl \
    DARONE_MITGCM_PATH=/dar_one_docker/darwin3 \
    JULIA_CPU_TARGET=generic
WORKDIR /dar_one_docker

# Debian Bookworm provides Python 3.11, required by Darwin3's Cog generator.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gfortran libnetcdf-dev libnetcdff-dev \
        git tcsh python3.11 python-is-python3 vim wget ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && git config --global user.name "DarOne" \
    && git config --global user.email "darone@localhost"

# Use the same source/configuration revisions as the scientific CI.
WORKDIR /dar_one_docker/DarOne.jl
COPY darwin-sources.env ./
RUN set -eu; \
    . ./darwin-sources.env; \
    git init -q "$DARONE_MITGCM_PATH"; \
    git -C "$DARONE_MITGCM_PATH" remote add origin https://github.com/darwinproject/darwin3.git; \
    git -C "$DARONE_MITGCM_PATH" fetch --depth 1 origin "$DARWIN_REV"; \
    git -C "$DARONE_MITGCM_PATH" checkout --quiet --detach FETCH_HEAD; \
    config_path="$DARONE_MITGCM_PATH/verification/dar_one_config"; \
    git init -q "$config_path"; \
    git -C "$config_path" remote add origin https://github.com/barbara42/dar_one_config.git; \
    git -C "$config_path" fetch --depth 1 origin "$DARONE_CONFIG_REV"; \
    git -C "$config_path" checkout --quiet --detach FETCH_HEAD; \
    mkdir -p "$config_path/build" "$config_path/run"

# Cache Julia dependencies separately from DarOne's implementation. Pkg needs
# a module entry point when instantiating a named package; replace it below.
COPY Project.toml ./
RUN mkdir -p src \
    && printf 'module DarOne\nend\n' > src/DarOne.jl \
    && JULIA_NUM_PRECOMPILE_TASKS=2 julia --startup-file=no -e 'using Pkg; Pkg.instantiate()' \
    && rm src/DarOne.jl

COPY src/ src/
COPY beginner_tutorial/1_build_example.jl beginner_tutorial/1_build_example.jl

# Compile the beginner 1x1 configuration using the actual package and source.
RUN julia --startup-file=no beginner_tutorial/1_build_example.jl \
    && test -x "$DARONE_MITGCM_PATH/verification/dar_one_config/build/mitgcmuv"

# Changes to examples, input data and documentation can reuse the build layers.
COPY . .

WORKDIR /dar_one_docker
CMD ["bash"]
