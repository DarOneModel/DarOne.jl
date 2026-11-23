using Test, DarOne, Pkg

@testset "Configured Darwin3 paths" begin
    darwin = darwin_root()
    config = DarOne._configured_source(:config)
    workspace = configuration_root()
    @test workspace != config && isfile(joinpath(workspace, "code", "SIZE.h"))
    @test executable_path() == joinpath(workspace, "build", "mitgcmuv")
    @test create_MITgcm_config("trial")[2] == joinpath(workspace, "run", "trial", "run")

    mktempdir() do root
        withenv("DARONE_MITGCM_PATH" => root) do
            @test_throws ArgumentError darwin_root()
        end
        # Exercise persistence without changing the user's project preferences.
        write(joinpath(root, "Project.toml"),
              "[deps]\nDarOne = \"68a5c792-066c-4fa4-bf39-3229eee150df\"\n")
        active = Base.active_project()
        try
            Pkg.activate(root; io=devnull)
            withenv("DARONE_MITGCM_PATH" => nothing, "DARONE_CONFIG_PATH" => nothing) do
                set_darwin_path(darwin)
                set_config_path(config)
                @test darwin_root() == darwin
                @test configuration_root() == workspace
                @test isfile(joinpath(root, "LocalPreferences.toml"))
            end
        finally
            Pkg.activate(dirname(active); io=devnull)
        end
    end

    DarOne._with_build_source(base_configuration) do source
        write(joinpath(source, "darone-generated.F"), "")
    end
    @test !isfile(joinpath(darwin, "darone-generated.F"))
end
