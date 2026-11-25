using Test, DarOne

@testset "Darwin3 paths" begin
    mktempdir() do dir
        @test_throws ArgumentError set_darwin_path(joinpath(dir, "missing"))
        withenv("DARONE_MITGCM_PATH" => dir) do
            @test_throws ArgumentError darwin_root()
        end
    end

    if haskey(ENV, "DARONE_MITGCM_PATH")
        root = abspath(expanduser(ENV["DARONE_MITGCM_PATH"]))
        @test set_darwin_path(root) == root
        withenv("DARONE_MITGCM_PATH" => nothing) do
            @test darwin_root() == root
            @test executable_path() == joinpath(root, "verification", base_configuration,
                                                "build", "mitgcmuv")
        end
    end
end
