@testset "Licenses" begin
    @testset "Licenses can be read" begin
        let license = sprint(show_license, "MIT")
            @test license == readchomp(joinpath(LICENSE_DIR, "MIT"))
        end
    end

    @testset "Non-existent license" begin
        @test_throws ArgumentError show_license(fake_path)
    end

    @testset "All licenses are displayed" begin
        let licenses = sprint(available_licenses)
            foreach(LICENSES) do (short, long)
                @test occursin("$short: $long", licenses)
            end
        end
        foreach(readdir(LICENSE_DIR)) do license
            @test haskey(LICENSES, license)
        end
        @test length(readdir(LICENSE_DIR)) == length(LICENSES)
    end
    @test strip(mit) == strip(read_license("MIT"))
    @test strip(read_license("MIT")) == strip(read(joinpath(LICENSE_DIR, "MIT"), String))
end
