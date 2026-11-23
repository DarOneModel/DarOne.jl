using Scratch, SHA

# Supported scientific source revisions are shared with CI.
function _pinned_revision(key)
    for line in eachline(joinpath(@__DIR__, "..", "darwin-sources.env"))
        startswith(line, "$key=") && return strip(split(line, '='; limit=2)[2])
    end
    error("Missing $key in darwin-sources.env")
end

source_revisions() = (darwin=_pinned_revision("DARWIN_REV"),
                      config=_pinned_revision("DARONE_CONFIG_REV"))

_preferred_path(key) = Preferences.load_preference(
    @__MODULE__, key, nothing; force_compiletime_default=true)

function _checked_checkout(path::AbstractString, kind::Symbol)
    label = kind === :darwin ? "Darwin3" : "dar_one_config"
    root = abspath(expanduser(path))
    isdir(root) || throw(ArgumentError("$label directory does not exist: $root"))
    required = kind === :darwin ? ("tools/genmake2",) :
               ("code/SIZE.h", "code/darwin_plankton.F", "input")
    for entry in required
        ispath(joinpath(root, entry)) ||
            throw(ArgumentError("$label at $root is missing $entry"))
    end
    Sys.which("git") === nothing && throw(ArgumentError("Git is required to verify Darwin3 sources"))
    actual = try
        strip(read(`git -C $root rev-parse HEAD`, String))
    catch
        throw(ArgumentError("$label at $root must be a Git checkout"))
    end
    expected = getproperty(source_revisions(), kind)
    actual == expected || throw(ArgumentError(
        "$label at $root is at Git commit $actual, but DarOne expects $expected"))
    return root
end

"""    set_darwin_path(path)

Remember the Darwin3 checkout path for this Julia environment.
"""
function set_darwin_path(path::AbstractString)
    root = _checked_checkout(path, :darwin)
    Preferences.set_preferences!(@__MODULE__, "darwin_path" => root; force=true)
    return root
end

"""    set_config_path(path)

Remember the pinned dar_one_config checkout path for this Julia environment.
"""
function set_config_path(path::AbstractString)
    root = _checked_checkout(path, :config)
    Preferences.set_preferences!(@__MODULE__, "config_path" => root; force=true)
    return root
end

function _configured_source(kind::Symbol)
    variable = kind === :darwin ? "DARONE_MITGCM_PATH" : "DARONE_CONFIG_PATH"
    preference = kind === :darwin ? "darwin_path" : "config_path"
    path = get(ENV, variable, _preferred_path(preference))
    (path === nothing || isempty(strip(path))) && throw(ArgumentError(
        "$(kind === :darwin ? "Darwin3" : "dar_one_config") path is not configured; " *
        "call $(kind === :darwin ? "set_darwin_path" : "set_config_path")(path) once " *
        "or set $variable."))
    return _checked_checkout(path, kind)
end

"""    darwin_root()

Return the validated Darwin3 checkout configured through Preferences.jl.
"""
darwin_root() = _configured_source(:darwin)

# Extract committed sources into writable workspaces, leaving checkout files untouched.
function _copy_revision(source, destination)
    mkpath(destination)
    run(pipeline(`git -C $source archive --format=tar HEAD`, `tar -xf - -C $destination`))
    return destination
end

"""    configuration_root(name=base_configuration)

Return the persistent writable configuration workspace associated with the
configured source checkouts. The original Git checkout stays unchanged.
"""
function configuration_root(name::AbstractString=base_configuration)
    isempty(strip(name)) && throw(ArgumentError("Configuration name cannot be empty"))
    name == base_configuration || return joinpath(darwin_root(), "verification", name)
    source = _configured_source(:config)
    key = bytes2hex(sha1(string(darwin_root(), '\n', source, '\n', source_revisions())))[1:20]
    parent = joinpath(Scratch.get_scratch!(@__MODULE__, "darone-workspaces"), key)
    destination = joinpath(parent, base_configuration)
    if !isdir(destination)
        mkpath(parent)
        staging = mktempdir(parent)
        try
            _copy_revision(source, staging)
            try
                mv(staging, destination)
            catch
                isdir(destination) || rethrow()
            end
        finally
            isdir(staging) && rm(staging; recursive=true, force=true)
        end
    end
    mkpath(joinpath(destination, "build"))
    mkpath(joinpath(destination, "run"))
    return destination
end

build_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "build")
input_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "input")
run_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "run")
executable_path(name::AbstractString=base_configuration) = joinpath(build_directory(name), "mitgcmuv")

# Keep genmake2's generated Fortran files out of the pinned Darwin3 checkout.
function _with_build_source(f::Function, name::AbstractString)
    key = bytes2hex(sha1(string(darwin_root(), '\n', configuration_root(name))))[1:20]
    destination = joinpath(Scratch.get_scratch!(@__MODULE__, "darone-build-sources"), key)
    rm(destination; recursive=true, force=true)
    _copy_revision(darwin_root(), destination)
    return f(destination)
end

function _expand_input_paths(content::AbstractString, name::AbstractString)
    verification = joinpath(darwin_root(), "verification") * "/"
    configuration = configuration_root(name) * "/"
    return replace(replace(content, "../../" => verification), "../" => configuration)
end
