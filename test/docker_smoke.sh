#!/usr/bin/env bash
set -euo pipefail

# Preserve the documented Docker entry point and default Julia environment.
test "$(pwd)" = /dar_one_docker
test "$DARONE_MITGCM_PATH" = /dar_one_docker/darwin3
cd /tmp
julia --startup-file=no -e 'using DarOne; @assert Base.active_project() == "/dar_one_docker/Dar_One/Project.toml"; @assert pathof(DarOne) == "/dar_one_docker/Dar_One/src/DarOne.jl"'
cd /dar_one_docker

source Dar_One/darwin-sources.env
config_path="$DARONE_MITGCM_PATH/verification/dar_one_config"
test "$(git -C "$DARONE_MITGCM_PATH" rev-parse HEAD)" = "$DARWIN_REV"
test "$(git -C "$config_path" rev-parse HEAD)" = "$DARONE_CONFIG_REV"
test -x "$config_path/build/mitgcmuv"

# Follow the documented tutorial commands using the precompiled model.
cd Dar_One/beginner_tutorial
export DARONE_EXAMPLE_ITERATIONS=12 DARONE_EXAMPLE_ID_SUFFIX=-docker-smoke
export GKSwstype=100
plot_dir=$(mktemp -d)
trap 'rm -rf "$plot_dir"' EXIT
export DARONE_PLOT_FILE="$plot_dir/beginner.png"
julia --startup-file=no --project=.. 2_run_example.jl

rundir="$config_path/run/beginner_tutorial-pro-syn-2${DARONE_EXAMPLE_ID_SUFFIX}/run"
grep -Fq 'Execution ended Normally' "$rundir"/thread-*-output.txt
shopt -s nullglob
diagnostics=("$rundir"/ecco_gud_*/3d.*.nc)
if (( ${#diagnostics[@]} == 0 )); then
    echo "No NetCDF diagnostics in $rundir" >&2
    exit 1
fi
for file in "${diagnostics[@]}"; do
    test -s "$file"
done

julia --startup-file=no --project=.. 3_plotting_example.jl
test -s "$DARONE_PLOT_FILE"

# Check the documented case-study directory and its bundled reference inputs.
cd /dar_one_docker/Dar_One/case_studies
for file in surface_tracers.nc surface_temperature.nc par_upper4.nc; do
    test -s "../data/darwin/$file"
done

echo "DarOne Docker smoke test passed."
