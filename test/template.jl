@testset "Template" begin
    @testset "Default fields" begin
        let t = Template(; user=me)
            @test t.user == me
            @test t.license == "MIT"
            @test t.authors == LibGit2.getconfig("user.name", "")
            @test t.dir == default_dir
            @test t.julia_version == VERSION
            @test !t.ssh
            @test !t.manifest
            @test isempty(t.plugins)
        end
    end

    @testset "Keywords" begin
        @testset "user" begin
            @testset "If github.user is set, it should be the default" begin
                if isempty(LibGit2.getconfig("github.user", ""))
                    @test_throws ArgumentError Template()
                else
                    let t = Template()
                        @test t.user == LibGit2.getconfig("github.user", "")
                    end
                end
            end
        end

        @testset "license" begin
            let t = Template(; user=me, license="")
                @test t.license == ""
            end
            let t = Template(; user=me, license="MPL")
                @test t.license == "MPL"
            end
            @test_throws ArgumentError Template(; user=me, license="FakeLicense")
        end

        @testset "Authors" begin
            let t = Template(; user=me, authors="Some Guy")
                @test t.authors == "Some Guy"
            end

            @testset "Vectors should be comma-joined" begin
                let t = Template(; user=me, authors=["Guy", "Gal"])
                    @test t.authors == "Guy, Gal"
                end
            end
        end

        @testset "dir" begin
            let t = Template(; user=me, dir=test_file)
                @test t.dir == abspath(test_file)
            end

            if Sys.isunix()  # ~ means temporary file on Windows, not $HOME.
                @testset "'~' should be replaced by homedir" begin
                    let t = Template(; user=me, dir="~/$(basename(test_file))")
                        @test t.dir == joinpath(homedir(), basename(test_file))
                    end
                end
            end
        end

        @testset "julia_version" begin
            let t = Template(; user=me, julia_version=v"0.1.2")
                @test t.julia_version == v"0.1.2"
            end
        end

        @testset "ssh" begin
            let t = Template(; user=me, ssh=true)
                @test t.ssh
            end
        end

        @testset "manifest" begin
            let t = Template(; user=me, manifest=true)
                @test t.manifest
            end
        end

        @testset "git" begin
            let t = Template(; user=me, git=false)
                @test !t.git
            end
        end

        @testset "plugins" begin
            # The template should contain whatever plugins you give it.
            let t = Template(
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
            end

            @testset "Duplicate plugins should warn" begin
                @test_logs (:warn, r"duplicates") match_mode=:any t = Template(
                    user=me,
                    plugins=[TravisCI(), TravisCI()],
                )
            end
        end
    end
end
