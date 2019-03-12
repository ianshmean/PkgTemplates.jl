@testset "Template" begin
    @testset "Default fields" begin
        t = Template()
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
            t = Template(; license="")
            @test t.license == ""

            t = Template(; license="MPL")
            @test t.license == "MPL"
            @test_throws ArgumentError Template(; license="FakeLicense")
        end

        @testset "Authors" begin
            t = Template(; authors="Some Guy")
            @test t.authors == "Some Guy"

            @testset "Vectors should be comma-joined" begin
                t = Template(; authors=["Guy", "Gal"])
                @test t.authors == "Guy, Gal"
            end
        end

        @testset "dir" begin
            t = Template(; dir=test_dir)
            @test t.dir == abspath(test_dir)

            @testset "'~' should be replaced by homedir" begin
                t = Template(; dir="~/$(basename(test_file))")
                @test t.dir == joinpath(homedir(), basename(test_file))
            end
        end

        @testset "julia_version" begin
            t = Template(; julia_version=v"0.1.2")
            @test t.julia_version == v"0.1.2"
        end

        @testset "ssh" begin
            t = Template(; ssh=true)
            @test t.ssh
        end

        @testset "manifest" begin
            t = Template(; manifest=true)
            @test t.manifest
        end

        @testset "git" begin
            t = Template(; git=false)
            @test !t.git

            @testset "Warnings" begin
                if isempty(LibGit2.getconfig("user.name", ""))
                    @test_logs (:warn, r"user.name") match_mode=:any Template()
                    @test_logs Template(; git=false)
                else
                    @test_logs Template()
                end
            end
        end

        @testset "plugins" begin
            t = Template(; plugins=[
                Documenter{TravisCI}(),
                TravisCI(),
                AppVeyor(),
                Codecov(),
                Coveralls(),
            ])
            @test Set(keys(t.plugins)) == Set(map(typeof, values(t.plugins))) == Set(
                [Documenter{TravisCI}, TravisCI, AppVeyor, Codecov, Coveralls])

            @testset "Duplicate plugins should warn" begin
                t = @test_logs (:warn, r"duplicates") match_mode=:any Template(;
                    plugins=[TravisCI(), TravisCI()],
                )
                @test haskey(t.plugins, TravisCI)
            end
        end
    end
end
