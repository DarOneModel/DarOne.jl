# genmake2 generates Fortran files inside its -rootdir. Build from a writable
# copy so that the pinned Darwin3 source cache stays unchanged.

function _managed_source_path(path::AbstractString)
    cache = joinpath(Scratch.get_scratch!(@__MODULE__, "darwin-sources"), "darwin")
    relative = relpath(abspath(path), abspath(cache))
    return relative != ".." && !startswith(relative, "../") && !startswith(relative, "..\\")
end

function _copy_build_source!(source::AbstractString, destination::AbstractString)
    if _managed_source_path(source)
        # Take a clean snapshot of the pinned revision from the managed checkout.
        mkpath(destination)
        run(pipeline(_git("-C", source, "archive", "--format=tar", "HEAD"),
                     `tar -xf - -C $destination`))
    else
        # Local checkouts may intentionally contain uncommitted modifications.
        cp(source, destination)
    end
    return destination
end

function _build_workspace(name::AbstractString)
    identity = string(darwin_root(), '\n', configuration_root(name))
    key = bytes2hex(sha256(identity))[1:24]
    folder = joinpath(Scratch.get_scratch!(@__MODULE__, "darwin-build-sources"), key)
    mkpath(folder)
    return folder
end

function _with_build_lock(f::Function, name::AbstractString)
    workspace = _build_workspace(name)
    return FileWatching.Pidfile.mkpidlock(joinpath(workspace, "build.lock"); stale_age=3600) do
        f(workspace)
    end
end

function _with_build_source(f::Function, name::AbstractString)
    return _with_build_lock(name) do workspace
        staging = mktempdir(workspace; prefix=".source-")
        try
            prepared = _copy_build_source!(darwin_root(), joinpath(staging, "darwin3"))
            destination = joinpath(workspace, "darwin3")
            rm(destination; recursive=true, force=true)
            mv(prepared, destination)
            return f(destination)
        finally
            rm(staging; recursive=true, force=true)
        end
    end
end
