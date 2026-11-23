using Test, DarOne

@testset "Darwin3 paths" begin
    mktempdir() do root
        darwin = joinpath(root, "darwin source")
        config = joinpath(root, "separate config")
        nested = joinpath(darwin, "verification", base_configuration)
        mkpath(nested)
        mkpath(config)

        withenv("DARONE_MITGCM_PATH" => darwin, "DARONE_CONFIG_PATH" => config) do
            @test darwin_root() == darwin
            @test configuration_root() == config
            @test executable_path() == joinpath(config, "build", "mitgcmuv")
            _, run = create_MITgcm_config("trial")
            @test run == joinpath(config, "run", "trial", "run")
            @test DarOne._expand_input_paths("../input/x\n../../shared/y\n", base_configuration) ==
                  joinpath(config, "input", "x") * "\n" *
                  joinpath(darwin, "verification", "shared", "y") * "\n"
        end

        withenv("DARONE_MITGCM_PATH" => darwin, "DARONE_CONFIG_PATH" => nothing,
                "DARONE_CONFIG_REV" => nothing) do
            @test configuration_root() == nested
        end

        old = MITgcm_path[1]
        try
            withenv("DARONE_MITGCM_PATH" => nothing) do
                MITgcm_path[1] = darwin
                @test darwin_root() == darwin
            end
        finally
            MITgcm_path[1] = old
        end
    end
end
