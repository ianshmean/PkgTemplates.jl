@testset "Utils" begin
    @testset "Version floor" begin
        @test PT.version_floor(v"1.0.0") == "1.0"
        @test PT.version_floor(v"1.0.1") == "1.0"
        @test PT.version_floor(v"1.0.1-pre") == "1.0"
        @test PT.version_floor(v"1.0.0-pre") == "1.0-"
    end

    @testset "Mustache substitution" begin
        let text = PT.substitute(template_text)
            @test !occursin("PKGNAME: $test_pkg", text)
            @test !occursin("GitHubPages", text)
            @test !occursin("GitLabPages", text)
            @test !occursin("Codecov", text)
            @test !occursin("Coveralls", text)
            @test !occursin("Other", text)
        end

        view = Dict("PKGNAME" => test_pkg, "OTHER" => true)
        let text = PT.substitute(template_text, view)
            @test occursin("PKGNAME: $test_pkg", text)
            @test occursin("Other", text)
        end

        t = Template(; user=me)
        view["OTHER"] = false
        let text = PT.substitute(template_text, t, view), v  t.julia_version
            @test occursin("PKGNAME: $test_pkg", text)
            @test occursin("VERSION: $(v.major).$(v.minor)", text)
            @test !occursin("GitHubpages", text)
            @test !occursin("Other", text)
        end

        t.plugins[Documenter{TravisCI}] = Documenter{TravisCI}()
        let text = PT.substitute(template_text, t, view)
            @test occursin("GitHubPages", text)
        end

        empty!(t.plugins)
        t.plugins[Codecov] = Codecov()
        let text = PT.substitute(template_text, t, view)
            @test occursin("Codecov", text)
        end

        empty!(t.plugins)
        t.plugins[Coveralls] = Coveralls()
        let text = PT.substitute(template_text, t, view)
            @test occursin("Coveralls", text)
        end

        empty!(t.plugins)
        view["OTHER"] = true
        let text = PT.substitute(template_text, t, view)
            @test occursin("Other", text)
        end
    end

    @testset "gen_file" begin
        let fn = tempname()
            PT.gen_file(fn, "foo")
            @test read(fn, String) == "foo\n"
        end
        let fn = tempname()
            PT.gen_file(fn, "foo\n")
            @test read(fn, String) == "foo\n"
        end
    end

    @testset "Default file path" begin
        @test PT.default_file("foo") == joinpath(PT.DEFAULT_DIR, "foo")
        @test PT.default_file("foo", "bar") == joinpath(PT.DEFAULT_DIR, "foo", "bar")
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
        ])
    end
end
