@testset "Template" begin
    @testset "Default fields" begin
        t = Template(; user=me)
        @test t.user == me
        @test t.license == "MIT"
        @test t.authors == LibGit2.getconfig("user.name", "")
        @test t.dir == default_dir
        @test t.julia_version == VERSION
        @test !t.ssh
        @test !t.manifest
        @test t.git
        @test isempty(t.plugins)
    end

    @testset "Keywords" begin
        @testset "user" begin
            @testset "If github.user is set, it should be the default" begin
                if isempty(LibGit2.getconfig("github.user", ""))
                    @test_throws ArgumentError Template()
                else
                    t = Template()
                    @test t.user == LibGit2.getconfig("github.user", "")
                end
            end
        end

        @testset "license" begin
            t = Template(; user=me, license="")
            @test t.license == ""

            t = Template(; user=me, license="MPL")
            @test t.license == "MPL"
            @test_throws ArgumentError Template(; user=me, license="FakeLicense")
        end

        @testset "Authors" begin
            t = Template(; user=me, authors="Some Guy")
            @test t.authors == "Some Guy"

            @testset "Vectors should be comma-joined" begin
                t = Template(; user=me, authors=["Guy", "Gal"])
                @test t.authors == "Guy, Gal"
            end
        end

        @testset "dir" begin
            t = Template(; user=me, dir=test_dir)
            @test t.dir == abspath(test_dir)

            if Sys.isunix()  # ~ means temporary file on Windows, not $HOME.
                @testset "'~' should be replaced by homedir" begin
                    t = Template(; user=me, dir="~/$(basename(test_file))")
                    @test t.dir == joinpath(homedir(), basename(test_file))
                end
            end
        end

        @testset "julia_version" begin
            t = Template(; user=me, julia_version=v"0.1.2")
            @test t.julia_version == v"0.1.2"
        end

        @testset "ssh" begin
            t = Template(; user=me, ssh=true)
            @test t.ssh
        end

        @testset "manifest" begin
            t = Template(; user=me, manifest=true)
            @test t.manifest
        end

        @testset "git" begin
            t = Template(; user=me, git=false)
            @test !t.git

            @testset "Warnings" begin
                if isempty(LibGit2.getconfig("user.name", ""))
                    @test_logs (:warn, r"user.name") match_mode=:any Template(; user=me)
                    @test_logs Template(; user=me, git=false)
                else
                    @test_logs Template(; user=me)
                end
            end
        end

        @testset "plugins" begin
            t = Template(;
                user=me,
                plugins=[
                    Documenter{TravisCI}(),
                    TravisCI(),
                    AppVeyor(),
                    Codecov(),
                    Coveralls(),
                ],
            )
            @test Set(keys(t.plugins)) == Set(map(typeof, values(t.plugins))) == Set(
                [Documenter{TravisCI}, TravisCI, AppVeyor, Codecov, Coveralls])

            @testset "Duplicate plugins should warn" begin
                t = @test_logs (:warn, r"duplicates") match_mode=:any Template(;
                    user=me,
                    plugins=[TravisCI(), TravisCI()],
                )
                @test haskey(t.plugins, TravisCI)
            end
        end
    end
end
