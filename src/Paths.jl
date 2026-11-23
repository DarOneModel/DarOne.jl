# LocalPreferences.toml records user-selected source directories for this Julia
# environment. Look them up at runtime so updates take effect without reloading.
_preferred_path(key::String) = Preferences.load_preference(
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
    actual = try
        strip(read(_git("-C", root, "rev-parse", "HEAD"), String))
    catch
        throw(ArgumentError("$label at $root must be a Git checkout"))
    end
    expected = getproperty(source_revisions(), kind)
    actual == expected || throw(ArgumentError(
        "$label at $root is at Git commit $actual, but DarOne expects $expected"))
    return root
end

"""    set_darwin_path(path)

Save the location of a Darwin3 checkout at the supported Git revision.
"""
function set_darwin_path(path::AbstractString)
    root = _checked_checkout(path, :darwin)
    Preferences.set_preferences!(@__MODULE__, "darwin_path" => root; force=true)
    return root
end

"""    set_config_path(path)

Save the location of the separately checked-out `dar_one_config` repository.
"""
function set_config_path(path::AbstractString)
    root = _checked_checkout(path, :config)
    Preferences.set_preferences!(@__MODULE__, "config_path" => root; force=true)
    return root
end

"""
    darwin_root()

Resolve the Darwin3 source directory. Environment overrides take precedence
for existing CI and Docker setups; saved paths take precedence over the legacy
default. A managed-source fallback remains available.
"""
function darwin_root()
    if haskey(ENV, "DARONE_MITGCM_PATH")
        path = ENV["DARONE_MITGCM_PATH"]
        isempty(strip(path)) && throw(ArgumentError("DARONE_MITGCM_PATH cannot be empty."))
        return abspath(expanduser(path))
    end
    preferred = _preferred_path("darwin_path")
    preferred === nothing || return _checked_checkout(preferred, :darwin)
    path = MITgcm_path[1]
    isempty(strip(path)) && throw(ArgumentError("MITgcm_path[1] cannot be empty."))
    if path == _LEGACY_DOCKER_ROOT &&
       (!isdir(path) || haskey(ENV, "DARONE_DARWIN_REV") || haskey(ENV, "DARWIN_REV"))
        return _managed_darwin_root()
    end
    return abspath(expanduser(path))
end

"""
    configuration_root(name=base_configuration)

Resolve the verification configuration, preferring an explicit environment
path or the saved preference for the default configuration.
"""
function configuration_root(name::AbstractString=base_configuration)
    isempty(strip(name)) && throw(ArgumentError("Configuration name cannot be empty."))
    if name == base_configuration
        if haskey(ENV, "DARONE_CONFIG_PATH")
            path = ENV["DARONE_CONFIG_PATH"]
            isempty(strip(path)) && throw(ArgumentError("DARONE_CONFIG_PATH cannot be empty."))
            return abspath(expanduser(path))
        end
        preferred = _preferred_path("config_path")
        preferred === nothing || return _checked_checkout(preferred, :config)
        nested = joinpath(darwin_root(), "verification", name)
        (isdir(nested) && !haskey(ENV, "DARONE_CONFIG_REV")) && return nested
        return _managed_configuration_root()
    end
    return joinpath(darwin_root(), "verification", name)
end

build_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "build")
input_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "input")
run_directory(name::AbstractString=base_configuration) = joinpath(configuration_root(name), "run")
executable_path(name::AbstractString=base_configuration) = joinpath(build_directory(name), "mitgcmuv")

# Input scripts historically assume that '../' points at the configuration and
# '../../' points at Darwin3's verification directory. Preserve those logical
# meanings even when the configuration itself is checked out elsewhere.
function _expand_input_paths(content::AbstractString, name::AbstractString)
    verification = joinpath(darwin_root(), "verification") * "/"
    configuration = configuration_root(name) * "/"
    return replace(replace(content, "../../" => verification), "../" => configuration)
end
