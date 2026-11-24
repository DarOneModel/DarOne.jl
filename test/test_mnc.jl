using Test
using DarOne
using NCDatasets

@testset "MNC NetCDF tile reading" begin
    mktempdir() do directory
        for (prefix, dimensions, trailing, tile_axis) in (
            ("grid2d", ("X", "Y"), (), 1),
            ("stacked2d", ("X", "Y"), (), 2),
            ("grid3d_depth", ("X", "Y", "RC"), (2,), 1),
            ("grid3d_time", ("X", "Y", "iter"), (2,), 1),
            ("grid4d", ("X", "Y", "RC", "iter"), (2, 3), 1),
        )
            nx, ny = tile_axis == 1 ? (4, 3) : (2, 6)
            tiles = []
            for tile_index in 1:2
                bi, bj = tile_axis == 1 ? (tile_index, 1) : (1, tile_index)
                shape = (2, 3, trailing...)
                values = reshape(Float32.(1:prod(shape)), shape) .+ 100f0 * tile_index
                push!(tiles, values)
                NCDataset(joinpath(directory, "$prefix.$tile_index.nc"), "c") do ds
                    for (name, n) in zip(dimensions, shape)
                        defDim(ds, name, n)
                    end
                    for (key, value) in ("Nx" => nx, "Ny" => ny,
                                         "sNx" => 2, "sNy" => 3, "bi" => bi, "bj" => bj)
                        ds.attrib[key] = value
                    end
                    defVar(ds, "XC", values, dimensions)
                end
            end
            result = DarOne.read_mnc(directory, prefix, "XC")
            @test size(result) == (nx, ny, trailing...)
            @test eltype(result) == Float64
            @test result == Float64.(cat(tiles...; dims=tile_axis))
        end
        @test_throws ArgumentError DarOne.read_mnc(directory, "missing", "XC")
    end
end
