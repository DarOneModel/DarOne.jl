using Test, DarOne, Scratch

@testset "Isolated Cog build source" begin
    mktempdir() do root
        Scratch.with_scratch_directory(joinpath(root, "scratch")) do
            source = joinpath(root, "darwin")
            cog = joinpath(source, "tools", "darwin", "cogapp", "cogapp.py")
            mkpath(dirname(cog))
            original = "import copy, getopt, hashlib, imp, os, re, shlex, sys, traceback\n" *
                       "self.cogmodule = imp.new_module('cog')\n"
            write(cog, original)
            config = joinpath(root, "config")
            mkpath(config)

            withenv("DARONE_MITGCM_PATH" => source, "DARONE_CONFIG_PATH" => config) do
                DarOne._with_build_source(base_configuration) do built
                    patched = read(joinpath(built, "tools", "darwin", "cogapp", "cogapp.py"), String)
                    @test occursin("ModuleType('cog')", patched)
                    write(joinpath(built, "generated.F"), "generated\n")
                end
                @test read(cog, String) == original
                DarOne._with_build_source(base_configuration) do built
                    @test !isfile(joinpath(built, "generated.F"))
                end
            end
        end
    end
end
