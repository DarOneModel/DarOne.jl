# Darwin3 is configured once with Preferences.jl; CI may use an environment override.
function _pinned_revision(key::AbstractString)
    for line in eachline(joinpath(@__DIR__, "..", "darwin-sources.env"))
        startswith(line, "$key=") && return split(line, "="; limit=2)[2]
    end
    error("Missing $key in darwin-sources.env")
end

function _check_checkout(path::AbstractString, label::AbstractString,
                         required::Tuple, expected::AbstractString)
    root = abspath(expanduser(path))
    isdir(root) || throw(ArgumentError("$label directory does not exist: $root"))
    for entry in required
        ispath(joinpath(root, entry)) ||
            throw(ArgumentError("$label at $root is missing $entry"))
    end
    actual = try
        strip(read(`git -C $root rev-parse HEAD`, String))
    catch
        throw(ArgumentError("$label at $root must be a Git checkout"))
    end
    actual == expected || throw(ArgumentError(
        "$label at $root is at revision $actual; DarOne requires $expected"))
    return root
end

function _checked_darwin(path::AbstractString)
    root = _check_checkout(path, "Darwin3", ("tools/genmake2",),
                           _pinned_revision("DARWIN_REV"))
    _check_checkout(joinpath(root, "verification", base_configuration),
                    "dar_one_config", ("code/SIZE.h", "code/darwin_plankton.F", "input"),
                    _pinned_revision("DARONE_CONFIG_REV"))
    return root
end

"""    set_darwin_path(path)

Save the location of a Darwin3 checkout containing the supported `dar_one_config`.
"""
function set_darwin_path(path::AbstractString)
    root = _checked_darwin(path)
    Preferences.set_preferences!(@__MODULE__, "darwin_path" => root; force=true)
    return root
end

"""    darwin_root()

Return the configured Darwin3 checkout; validate it before use.
`DARONE_MITGCM_PATH` overrides the saved preference for CI or container runs.
"""
function darwin_root()
    path = get(ENV, "DARONE_MITGCM_PATH", nothing)
    path === nothing && (path = Preferences.load_preference(@__MODULE__, "darwin_path", nothing))
    path === nothing && throw(ArgumentError(
        "Darwin3 is not configured. Call set_darwin_path(path) once."))
    return _checked_darwin(path)
end

"""    executable_path(configuration=base_configuration)

Resolve the MITgcm executable path from the currently configured Darwin3 checkout.
"""
executable_path(configuration::AbstractString=base_configuration) =
    joinpath(darwin_root(), "verification", configuration, "build", "mitgcmuv")
