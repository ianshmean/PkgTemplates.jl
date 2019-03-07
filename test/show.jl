@testset "Show methods" begin
    @testset "Template" begin
        pkg_dir = Sys.isunix() ? replace(default_dir, homedir() => "~") : default_dir

        t = Template(; user=me)
        expected = """
            Template:
              → User: $me
              → Host: github.com
              → License: MIT ($(LibGit2.getconfig("user.name", "")) $(year(today())))
              → Package directory: $pkg_dir
              → Minimum Julia version: v$(PkgTemplates.version_floor())
              → SSH remote: No
              → Commit Manifest.toml: No
              → Create Git repository: Yes
              → Develop packages: Yes
              → Plugins: None
            """
        @test sprint(show, t) == rstrip(expected)

        t = Template(; user=me, license="", ssh=true, manifest=true)
        expected = """
            Template:
              → User: $me
              → Host: github.com
              → License: None
              → Package directory: $pkg_dir
              → Minimum Julia version: v$(PkgTemplates.version_floor())
              → SSH remote: Yes
              → Commit Manifest.toml: Yes
              → Create Git repository: Yes
              → Develop packages: Yes
              → Plugins: None
            """
        @test sprint(show, t) == rstrip(expected)

        t = Template(; user=me, plugins=[TravisCI(), Codecov()])
        pattern = r"""
              → Plugins:
                • .*
                • .*
            """
        @test match(pattern, sprint(show, t) * "\n") !== nothing
    end

    @testset "Plugins" begin
        @testset "GeneratedPlugin" begin
            @testset "Generic case" begin
            end

            @testset "GitLabCI" begin
            end
        end

        @testset "Custom plugins" begin
            @testset "Documenter" begin
            end
        end
    end
end
