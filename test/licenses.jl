@testset "Licenses" begin
    @testset "Licenses can be read" begin
        license = sprint(show_license, "MIT")
        @test license == readchomp(joinpath(PT.LICENSE_DIR, "MIT"))
    end

    @testset "Non-existent license" begin
        @test_throws ArgumentError show_license(fake_path)
    end

    @testset "All licenses are displayed" begin
        licenses = sprint(available_licenses)
        foreach(PT.LICENSES) do (short, long)
            @test occursin("$short: $long", licenses)
        end

        foreach(readdir(PT.LICENSE_DIR)) do license
            @test haskey(PT.LICENSES, license)
        end

        @test length(readdir(PT.LICENSE_DIR)) == length(PT.LICENSES)
    end

    mit = PT.read_license("MIT")
    @test mit == readchomp(joinpath(PT.LICENSE_DIR, "MIT"))
end
