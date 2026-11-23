# Getting Started 

DarOne.jl is a tool for designing and running experiments simulating the marine microbiome within a single cube of water. The biogeochemical forcing is powered by the [MIT Darwin Model](https://darwinproject.mit.edu/), and DarOne.jl provides a Julia interface to build, configure, and run experiments with a simple, streamlined workflow.

![DarOne ecosystem](images/DarOne_ecosystem.png)

DarOne Model Configuration: The DarOne system models a single, well mixed parcel of water. The standard configuration consists of the DARWIN ecosystem-biogeochemical model, with free gas exchange with the atmosphere. Horizontal and other vertical fluxes are set to zero. These conditions can be modified by the user.

# Basic Structure 

DarOne is composed of three main parts: the MITgcm Darwin code, a configuration made for DarOne, and the julia interface to modify the configuration and run the model. 

- [DarOne.jl](https://github.com/DarOneModel/DarOne.jl) - Julia interface for organizing experiments and setting up parameters for model runs
    - Darwin3 and configuration checkout paths are saved once with Preferences.jl
- [darwin3](https://github.com/darwinproject/darwin3) - MITgcm source code set up to include all things Darwin 
    - [`dar_one_config`](https://github.com/barbara42/dar_one_config) - the independent repository for DarOne configuration files

Experiments are designed and run from Julia files. DarOne copies the pinned configuration into a writable workspace; build files, run folders, and simulation output live there, leaving both Git checkouts unchanged. Use `configuration_root()` to find the workspace.

![DarOne Anatomy](images/DarOne_anatomy.png)


# Installation 

Install the Julia interface from General:

```julia
using Pkg
Pkg.add("DarOne")
```

DarOne can be run in one of two ways. 
1) In a **docker container** using the DarOne_docker image, where all dependencies are handled for you 
2) On your local machine, where you have to set up the environment, download dependencies, etc 
    - this is more time consuming, and I strongly recommend using the docker image
    - instructions for local setup are below

## Setting up with docker

(1) Download and install [docker desktop](https://www.docker.com/).
- Run the docker application, which will start up the docker "daemon" 
- The docker daemon must be running in order to download the DarOne image and to start up a container

(2) Get the [DarOne docker image](https://hub.docker.com/r/birdy1123/dar1).
- using the command line, run 

    `docker pull birdy1123/dar1`

- If you go to the "Images" tab in the docker desktop UI, you should see "birdy1123/dar1"

(3) Run a container based on the DarOne docker image
- using the command line, run 

    `docker run -it birdy1123/dar1` 
- this runs the container in interactive mode (`-i`) with terminal access (`-t`) 
- you should see the prompt change to `root@some-number:/dar_one_docker#`
- once the container is running, you can also connect to a new bash terminal inside the container using the command `docker exec -it container_id /bin/bash`. The container id can be found in the Docker desktop app or the "some-number" that appears in the previous bullet point. 

You're now ready for the [beginner tutorial](https://daronemodel.github.io/DarOne.jl/build/beginner_tutorials/)!


## Setting up on local machine

Clone DarOne for its tutorials and check out the supported Darwin3 and configuration revisions. The reference commits are recorded in `darwin-sources.env`:

```bash
git clone https://github.com/DarOneModel/DarOne.jl.git
cd DarOne.jl
mkdir -p ~/src
. ./darwin-sources.env
git clone https://github.com/darwinproject/darwin3.git ~/src/darwin3
git -C ~/src/darwin3 checkout --detach "$DARWIN_REV"
git clone https://github.com/barbara42/dar_one_config.git ~/src/dar_one_config
git -C ~/src/dar_one_config checkout --detach "$DARONE_CONFIG_REV"
```

Install dependencies and save these locations **once** for the active Julia environment:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using DarOne; set_darwin_path(joinpath(homedir(), "src", "darwin3")); set_config_path(joinpath(homedir(), "src", "dar_one_config"))'
```

DarOne validates both Git commits. Subsequent sessions reuse the saved paths through Preferences.jl. To locate generated model files, run `julia --project=. -e 'using DarOne; println(configuration_root())'`.

### Dependencies 

In order to build and run the MITgcm on your machine, you need to have the following installed as well
- gfortran
- netcdf 



For the Julia code, you will need to install julia and the packages declared in `Project.toml`, including
- OrderedCollections
- Suppressor
- ClimateModels
- NCDatasets

The Julia dependencies are listed in `DarOne.jl/Project.toml`. You can automatically install the Julia dependencies from the `DarOne.jl` folder by running `julia --project=. -e 'using Pkg; Pkg.instantiate()'`.

If you get errors when building the model, see the [MITgcm getting started guide](https://mitgcm.readthedocs.io/en/latest/getting_started/getting_started.html#) to help troubleshoot.  

You can also see the dockerfile used [here](https://github.com/DarOneModel/DarOne.jl/blob/main/Dockerfile)

```
FROM --platform=linux/amd64 ubuntu:latest 
WORKDIR /dar_one_docker
COPY . . 

RUN apt-get update -y
RUN apt-get install wget -y
RUN apt-get install vim -y

# download, install, and link julia 
RUN wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.13-linux-x86_64.tar.gz
RUN tar zxvf julia-1.10.13-linux-x86_64.tar.gz
ENV PATH="${PATH}:/dar_one_docker/julia-1.10.13/bin"
# install julia packages 
ENV JULIA_PROJECT=/dar_one_docker/Dar_One
RUN julia --project=/dar_one_docker/Dar_One -e 'using Pkg; Pkg.instantiate()'

# other dependencies 
RUN apt-get install -y gfortran make 
RUN apt-get install -y python-is-python3
# future: try netcdf-bin instead? does it still work? 
RUN apt-get install -y libnetcdff-dev 
```

# Workflow

For more in-depth instructions, check out the [beginner tutorials](https://daronemodel.github.io/DarOne.jl/build/beginner_tutorials/)

In general, experiments with DarOne are divided into two main steps 
1. Building
    - grid size
    - nutrient cycling
2. Running
    - set up experiment config
    - initialize parameters

I like to separate these out into two scripts because the build step only has to be done once for each experiment setup. After you settle on what grid size to use (classically 1x1) and what nutrient setup (classically freely cycling, can also be set to constant available nutrients), you can modify all other parameters without having to re-build. 

I recommend creating a folder at the top level of the `DarOne.jl` directory with the name `your-name-experiments`, and putting all scripts you create in there.

For every DarOne script, you will first import DarOne. Run scripts using `julia --project=.` from the `DarOne.jl` folder.
```
using DarOne
```

With the source paths saved during setup, build the model with:

```
build(base_configuration)
```
Once the model has been built, you can run multiple experiments with different values for the intial parameters. I like to put the previous code in one file, and the code to initialize and run an experiment in another.

For the run script, import DarOne. The same saved source paths are reused:

```julia
using DarOne
```

Set up experiment config id 

```
config_id = "unique-experiment-name" # CHANGE ME
config_obj, rundir = create_MITgcm_config(config_id)
setup(config_obj)
```

The next step is to modify parameters (in-depth descriptions in [beginnger tutorial](https://daronemodel.github.io/DarOne.jl/build/beginner_tutorials/)). For modifying parameters, you will need to pass the `config_obj` to each update function.

Then run the model. 

```
run(config_obj)
```

To recap the basic workflow: 
- Import `DarOne`; source paths are already saved in Preferences.jl
- Build
    - set your grid size
    - set nutrients to cycle or stay constant 
    - build
- Run
    - setup experiment config
    - modify parameters 
    - run