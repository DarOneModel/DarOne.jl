using Test, DarOne, Scratch, Pkg

function fixture_commit(dir, files)
    mkpath(dir)
    run(`git init -q $dir`)
    for (name, contents) in files
        file = joinpath(dir, name)
        mkpath(dirname(file))
        write(file, contents)
    end
    run(`git -C $dir add .`)
    run(`git -C $dir -c user.name=Test -c user.email=test@localhost -c commit.gpgsign=false commit -qm initial`)
    return strip(read(`git -C $dir rev-parse HEAD`, String))
end

@testset "Managed source revisions" begin
    mktempdir() do root
        Scratch.with_scratch_directory(joinpath(root, "scratch")) do
            darwin = joinpath(root, "darwin remote")
            config = joinpath(root, "config remote")
            revision = fixture_commit(darwin, ["tools/genmake2" => "#!/bin/sh\n"])
            config_rev = fixture_commit(config, ["code/SIZE.h" => "original\n",
                                                  "code/darwin_plankton.F" => "plankton\n",
                                                  "input/data" => "&PARM01\n/\n"])
            # Verify that a configured source path persists in the active Julia environment.
            prefs = joinpath(root, "environment")
            mkpath(prefs)
            write(joinpath(prefs, "Project.toml"),
                  "[deps]\nDarOne = \"68a5c792-066c-4fa4-bf39-3229eee150df\"\n")
            original_project = Base.active_project()
            try
                Pkg.activate(prefs; io=devnull)
                withenv("DARONE_MITGCM_PATH" => nothing, "DARONE_CONFIG_PATH" => nothing,
                        "DARONE_DARWIN_REV" => revision, "DARONE_CONFIG_REV" => config_rev) do
                    set_darwin_path(darwin)
                    set_config_path(config)
                    @test darwin_root() == darwin
                    @test configuration_root() == config
                    @test isfile(joinpath(prefs, "LocalPreferences.toml"))
                    @test_throws ArgumentError set_config_path(root)
                    withenv("DARONE_DARWIN_REV" => repeat("0", 40)) do
                        @test_throws ArgumentError darwin_root()
                    end
                end
            finally
                Pkg.activate(dirname(original_project); io=devnull)
            end
            old = MITgcm_path[1]
            try
                MITgcm_path[1] = "/dar_one_docker/darwin3"
                withenv("DARONE_MITGCM_PATH" => nothing, "DARONE_CONFIG_PATH" => nothing,
                        "DARONE_DARWIN_URL" => darwin, "DARONE_CONFIG_URL" => config,
                        "DARONE_DARWIN_REV" => revision, "DARONE_CONFIG_REV" => config_rev) do
                    @test source_revisions() == (darwin=revision, config=config_rev)
                    source = darwin_root()
                    staged = configuration_root()
                    @test isfile(joinpath(source, "tools", "genmake2"))
                    @test isfile(joinpath(staged, "code", "SIZE.h"))
                    @test source == darwin_root() && staged == configuration_root()
                    # genmake2 may generate files in its source tree; rebuilding
                    # must leave the pinned checkout unchanged.
                    DarOne._with_build_source(base_configuration) do writable
                        write(joinpath(writable, "generated.F"), "")
                    end
                    @test !isfile(joinpath(source, "generated.F"))
                    DarOne._with_build_source(base_configuration) do writable
                        @test !isfile(joinpath(writable, "generated.F"))
                    end
                    write(joinpath(staged, "code", "SIZE.h"), "modified\n")
                    @test read(joinpath(DarOne._source_checkout(:config, config_rev),
                                        "code", "SIZE.h"), String) == "original\n"

                    write(joinpath(darwin, "new.F"), "new revision\n")
                    run(`git -C $darwin add new.F`)
                    run(`git -C $darwin -c user.name=Test -c user.email=test@localhost -c commit.gpgsign=false commit -qm newer`)
                    newer = strip(read(`git -C $darwin rev-parse HEAD`, String))
                    withenv("DARONE_DARWIN_REV" => newer) do
                        @test darwin_root() != source
                        @test configuration_root() != staged
                    end
                    @test darwin_root() == source

                    write(joinpath(config, "code", "SIZE.h"), "new config\n")
                    run(`git -C $config add code/SIZE.h`)
                    run(`git -C $config -c user.name=Test -c user.email=test@localhost -c commit.gpgsign=false commit -qm next`)
                    next_config = strip(read(`git -C $config rev-parse HEAD`, String))
                    withenv("DARONE_CONFIG_REV" => next_config) do
                        @test configuration_root() != staged
                    end
                end
            finally
                MITgcm_path[1] = old
            end
        end
    end
end
