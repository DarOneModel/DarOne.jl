# A saved Darwin3 path, with an environment override for CI.
function _pinned_revision(key::AbstractString)
    for line in eachline(joinpath(@__DIR__, "..", "darwin-sources.env"))
        startswith(line, "$key=") && return split(line, "="; limit=2)[2]
    end
    error("Missing $key in darwin-sources.env")
end

function _validated_darwin(path::AbstractString)
    root = abspath(expanduser(path))
    checkouts = (
        (root, "Darwin3", ("tools/genmake2",), "DARWIN_REV"),
        (joinpath(root, "verification", base_configuration), "dar_one_config",
         ("code/SIZE.h", "code/darwin_plankton.F", "input"), "DARONE_CONFIG_REV"),
    )
    for (dir, label, required, revision_key) in checkouts
        isdir(dir) || throw(ArgumentError("$label directory does not exist: $dir"))
        for file in required
            ispath(joinpath(dir, file)) ||
                throw(ArgumentError("$label at $dir is missing $file"))
        end
        actual = try
            strip(read(`git -C $dir rev-parse HEAD`, String))
        catch
            throw(ArgumentError("$label at $dir must be a Git checkout"))
        end
        expected = _pinned_revision(revision_key)
        actual == expected || throw(ArgumentError(
            "$label at $dir is at revision $actual; DarOne requires $expected"))
    end
    return root
end

"""    set_darwin_path(path)

Remember the path to Darwin3 with `dar_one_config` under `verification/`.
"""
function set_darwin_path(path::AbstractString)
    root = _validated_darwin(path)
    Preferences.set_preferences!(@__MODULE__, "darwin_path" => root; force=true)
    return root
end

"""    darwin_root()

Return the validated Darwin3 path. `DARONE_MITGCM_PATH` overrides the saved preference.
"""
function darwin_root()
    path = get(ENV, "DARONE_MITGCM_PATH", nothing)
    path === nothing && (path = Preferences.load_preference(@__MODULE__, "darwin_path", nothing))
    path === nothing && throw(ArgumentError(
        "Darwin3 is not configured. Call set_darwin_path(path) once."))
    return _validated_darwin(path)
end

"""    executable_path(configuration=base_configuration)

Resolve the executable from the currently configured Darwin3 checkout.
"""
executable_path(configuration::AbstractString=base_configuration) =
    joinpath(darwin_root(), "verification", configuration, "build", "mitgcmuv")
