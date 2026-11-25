# DarOne.jl

[![Tests](https://github.com/DarOneModel/DarOne.jl/actions/workflows/tests.yml/badge.svg)](https://github.com/DarOneModel/DarOne.jl/actions/workflows/tests.yml)
[![Docker](https://github.com/DarOneModel/DarOne.jl/actions/workflows/docker.yml/badge.svg)](https://github.com/DarOneModel/DarOne.jl/actions/workflows/docker.yml)

Built off of Gael Forget's MITgcmTools! (https://github.com/gaelforget/MITgcmTools.jl)

[DarOne.jl Documentation](https://daronemodel.github.io/DarOne.jl/build/getting_started/)
- [tutorials](https://daronemodel.github.io/DarOne.jl/build/beginner_tutorials/)
- [case studies](https://daronemodel.github.io/DarOne.jl/build/case_studies/)

Install the registered Julia package with:

```julia
using Pkg
Pkg.add("DarOne")
```


Documentation for the darwin3 MITgcm fortran model can be found [here](https://darwin3.readthedocs.io/en/latest/phys_pkgs/darwin_bacteria.html) 
##  Overview of program structure 


DarOne.jl is a tool for designing and running experiments simulating the marine microbiome within a single cube of water. The biogeochemical forcing is powered by the [MIT Darwin Model](https://darwinproject.mit.edu/), and DarOne.jl provides a Julia interface to build, configure, and run experiments with a simple, streamlined workflow. DarOne.jl is composed of two main parts:

- [DarOne.jl](https://github.com/DarOneModel/DarOne.jl) - Julia interface for organizing experiments and setting up parameters for model runs
- [darwin3](https://github.com/darwinproject/darwin3) - MITgcm source code set up to include all things Darwin 
    - `DarOne_config` - folder for the base configuration files for DarOne, which lives in the darwin3/verification/ folder. ([DarOne_config github](https://github.com/barbara42/dar_one_config))


DarOne can be run in one of two ways. 
1) In a **docker container** using the DarOne_docker image, where all dependencies are handled for you 
2) On your local machine, where you have to set up the environment, download dependencies, etc 
    - this is more time consuming, and I strongly recommend using the docker image
    - instructions for local setup are below

# Setting up with docker

(1) Download and install [docker desktop](https://www.docker.com/).
- Run the docker application, which will start up the docker "daemon" 
- The docker daemon must be running in order to download the DarOne image

(2) Get the DarOne Docker image from GitHub Container Registry.
- using the command line, run 

    `docker pull ghcr.io/daronemodel/darone:main`

- If you go to the "Images" tab in the docker desktop UI, you should see "ghcr.io/daronemodel/darone:main"

(3) Run a container based on the DarOne docker image
- using the command line, run 

    `docker run -it ghcr.io/daronemodel/darone:main`
- this runs the container in interactive mode (`-i`) with terminal access (`-t`) 
- you should see the prompt change to `root@some-number:/dar_one_docker#`
    - if the container is already running, you can connect to it with `docker exec -it [CONTAINER_ID] bash`
    - Note: connecting with `bash` rather than `sh` gives you more a powerful terminal (i.e. with tab completion) 
  
You're now ready for the [beginner tutorial](beginner_tutorial)!

## Building the Docker image from source

From the root of a DarOne.jl checkout, build and test the image:

```bash
docker build --platform=linux/amd64 -t darone:local .
docker run --rm --network none darone:local bash Dar_One/test/docker_smoke.sh
```

The [Dockerfile](Dockerfile) installs Julia dependencies, checks out the Darwin sources at the revisions in [`darwin-sources.env`](darwin-sources.env), and compiles the beginner model executable. The [Docker CI workflow](.github/workflows/docker.yml) builds and tests the image, publishes `:main` after successful main-branch builds, and publishes `:vX.Y.Z` images matching Julia package releases to GitHub Container Registry.

To start an interactive container from your local image:

```bash
docker run -it darone:local
```

The CI images target `linux/amd64`. On Apple Silicon, Docker can run these images using x86 emulation, which may be slower.

# Setting up on local machine

See instructions in the documentation: https://daronemodel.github.io/DarOne.jl/build/getting_started/#Setting-up-on-local-machine

After checking out the supported Darwin3 and `dar_one_config` revisions, configure the source path once:

```julia
using DarOne
set_darwin_path("/path/to/darwin3")
```

This setting is saved for the current Julia environment. The configuration repository
should be at `darwin3/verification/dar_one_config`. CI can also use `DARONE_MITGCM_PATH`.

## Example integration tests

The example test runner executes all nine beginner tutorial and case-study scripts, including Fortran builds, simulations, and the tutorial plot. It uses Darwin reference inputs and short simulation durations. Run it with a Darwin checkout containing `verification/dar_one_config` and a working GNU Fortran toolchain:

```bash
DARONE_MITGCM_PATH=/path/to/darwin3 julia --project=. test/test_examples.jl
```

# Contributing

We're excited you're here and want to contribute.

We welcome all contributions, from documentation to testing to writing code. Don't let trying to be perfect get in the way of being good – exciting ideas are more important than perfect pull requests.

In the first instance, we encourage you to open [a GitHub issue](https://github.com/DarOneModel/DarOne.jl/issues).

If you are comfortable contributing code directly, please open [a GitHub pull request](https://github.com/DarOneModel/DarOne.jl/pulls). For best practices, please see the contributing guidelines developed by [The Turing Way](https://book.the-turing-way.org/community-handbook/contributing/).