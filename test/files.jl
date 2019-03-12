@testset "File generation" begin
        t = Template(; plugins=[
            TravisCI(),
            AppVeyor(),
            Codecov(),
            Coveralls(),
            Documenter{TravisCI}(),
        ])
        dir = joinpath(t.dir, test_pkg)

    @testset "make_*" begin
        @testset "Tests" begin
            specs = PT.make_tests(t, dir)
            @test length(specs) == 1
            path, text = specs[1]
            @test path == joinpath(dir, "test", "runtests.jl")
            @test occursin("""@testset "$test_pkg.jl" begin""", text)
        end

        @testset "README" begin
            specs = PT.make_readme(t, dir)
            @test length(specs) == 1
            path, text = specs[1]
            @test path == joinpath(dir, "README.md")
            @test occursin("# $test_pkg", text)

            # Testing badge occurence and order.
            @test findfirst("github.io", text).start <
                findfirst("travis", text).start <
                findfirst("appveyor", text).start <
                findfirst("codecov", text).start <
                findfirst("coveralls", text).start
            # TODO: Test that a new plugin's badge appears last.
        end

        @testset "REQUIRE" begin
            specs = PT.make_require(t, dir)
            @test length(specs) == 1
            path, text = specs[1]
            @test path == joinpath(dir, "REQUIRE")
            @test text == "julia " * PT.version_floor(t.julia_version)
        end

        @testset ".gitignore" begin
            specs = PT.make_gitignore(t, dir)
            @test length(specs) == 1
            path, text = specs[1]
            @test path == joinpath(dir, ".gitignore")
            @test occursin("*.jl.cov", text)
            @test occursin("/docs/build/", text)

            t = Template(; git=false)
            @test isempty(PT.make_gitignore(t, dir))
        end

        @testset "License" begin
            specs = PT.make_license(t, dir)
            @test length(specs) == 1
            path, text = specs[1]
            @test path == joinpath(dir, "LICENSE")
            header = "Copyright (c) $(year(today())) $(t.authors)\n"
            @test text == header * PT.read_license("MIT")

            t = Template(; license="")
            @test isempty(PT.make_license(t, dir))
        end
    end

    @testset "gen_*" begin
        @testset "Generic" begin
            PT.gen_require(t, dir)
            @test isfile(joinpath(dir, "REQUIRE"))
        end

        @testset "Tests" begin
            # This requires a bit more setup because there we need a valid Project.toml.
            mktempdir() do dir
                dir = joinpath(dir, test_pkg)
                @suppress Pkg.generate(dir)
                t = Template(; dir=dir)
                @suppress_out PT.gen_tests(t, dir)
                @test isfile(joinpath(dir, "test", "runtests.jl"))

                # Check that our Project.toml fiddling worked.
                @test isfile(joinpath(dir, "Project.toml"))
                project = read(joinpath(dir, "Project.toml"), String)
                pattern = r"""
                    \[extras\]
                    Test = ".*"

                    \[targets\]
                    test = \["Test"\]
                    """
                @test match(pattern, project) !== nothing

                # Check that the manifest contains no deps.
                @test isfile(joinpath(dir, "Manifest.toml"))
                manifest = readlines(joinpath(dir, "Manifest.toml"))
                @test all(line -> isempty(line) || startswith(line, "#"), manifest)
            end
        end
    end
end
