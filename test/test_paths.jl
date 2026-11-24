using Test, DarOne

@testset "Darwin3 path validation" begin
    mktempdir() do dir
        @test_throws ArgumentError set_darwin_path(joinpath(dir, "missing"))
        withenv("DARONE_MITGCM_PATH" => dir) do
            @test_throws ArgumentError create_MITgcm_config("example")
        end
        mkpath(joinpath(dir, "tools"))
        write(joinpath(dir, "tools", "genmake2"), "test")
        run(`git -C $dir init -q`)
        run(`git -C $dir add .`)
        run(`git -C $dir -c user.name=Test -c user.email=test@localhost commit -qm init`)
        @test DarOne._check_checkout(dir, "Darwin3", ("tools/genmake2",),
                   strip(read(`git -C $dir rev-parse HEAD`, String))) == dir
        @test_throws ArgumentError DarOne._check_checkout(dir, "Darwin3",
                   ("tools/genmake2",), repeat("0", 40))
    end
    if haskey(ENV, "DARONE_MITGCM_PATH")
        path = ENV["DARONE_MITGCM_PATH"]
        @test set_darwin_path(path) == abspath(path)
        withenv("DARONE_MITGCM_PATH" => nothing) do
            @test darwin_root() == abspath(path)
            @test executable_path() == joinpath(darwin_root(), "verification",
                                                base_configuration, "build", "mitgcmuv")
        end
    end
end
