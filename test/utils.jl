@testset "Utils" begin
    @testset "Version floor" begin
        @test PT.version_floor(v"1.0.0") == "1.0"
        @test PT.version_floor(v"1.0.1") == "1.0"
        @test PT.version_floor(v"1.0.1-pre") == "1.0"
        @test PT.version_floor(v"1.0.0-pre") == "1.0-"
    end

    @testset "Mustache substitution" begin
        text = PT.substitute(template_text)
        @test !occursin("PKGNAME: $test_pkg", text)
        @test !occursin("GitHubPages", text)
        @test !occursin("GitLabPages", text)
        @test !occursin("Codecov", text)
        @test !occursin("Coveralls", text)
        @test !occursin("Other", text)

        view = Dict("PKGNAME" => test_pkg, "OTHER" => true)
        text = PT.substitute(template_text, view)
        @test occursin("PKGNAME: $test_pkg", text)
        @test occursin("Other", text)

        t = Template(; user=me)
        v = t.julia_version
        view["OTHER"] = false
        text = PT.substitute(template_text, t, view)
        @test occursin("PKGNAME: $test_pkg", text)
        @test occursin("VERSION: $(v.major).$(v.minor)", text)
        @test !occursin("GitHubpages", text)
        @test !occursin("Other", text)

        t.plugins[Documenter{TravisCI}] = Documenter{TravisCI}()
        text = PT.substitute(template_text, t, view)
        @test occursin("GitHubPages", text)

        empty!(t.plugins)
        t.plugins[Codecov] = Codecov()
        text = PT.substitute(template_text, t, view)
        @test occursin("Codecov", text)

        empty!(t.plugins)
        t.plugins[Coveralls] = Coveralls()
        text = PT.substitute(template_text, t, view)
        @test occursin("Coveralls", text)

        empty!(t.plugins)
        view["OTHER"] = true
        text = PT.substitute(template_text, t, view)
        @test occursin("Other", text)
    end

    @testset "gen_file" begin
        fn = tempname()
        PT.gen_file(fn, "foo")
        @test read(fn, String) == "foo\n"

        fn = tempname()
        PT.gen_file(fn, "foo\n")
        @test read(fn, String) == "foo\n"
    end

    @testset "Default file path" begin
        @test PT.default_file("foo") == joinpath(PT.DEFAULTS_DIR, "foo")
        @test PT.default_file("foo", "bar") == joinpath(PT.DEFAULTS_DIR, "foo", "bar")
    end

    @testset "splitjl" begin
        @test PT.splitjl("foo") == "foo"
        @test PT.splitjl("foo.jl") == "foo"
    end

    @testset "leaves" begin
        @test Set(PT.leaves(Number)) == Set([
            BigFloat, Float16, Float32, Float64,
            Bool,
            BigInt, Int128, Int16, Int32, Int64, Int8,
            UInt128, UInt16, UInt32, UInt64, UInt8,
            Complex, Irrational, Rational,
        ])
    end
end
