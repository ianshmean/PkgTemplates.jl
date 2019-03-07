@testset "Package generation" begin
    t = Template(; user=me)
    generate(test_pkg, t; gitconfig=gitconfig)
    pkg_dir = joinpath(default_dir, test_pkg)

    # Check that the expected files all exist.
    @test isfile(joinpath(pkg_dir, "LICENSE"))
    @test isfile(joinpath(pkg_dir, "README.md"))
    @test isfile(joinpath(pkg_dir, "REQUIRE"))
    @test isfile(joinpath(pkg_dir, ".gitignore"))
    @test isdir(joinpath(pkg_dir, "src"))
    @test isfile(joinpath(pkg_dir, "src", "$test_pkg.jl"))
    @test isfile(joinpath(pkg_dir, "Project.toml"))
    @test isdir(joinpath(pkg_dir, "test"))
    @test isfile(joinpath(pkg_dir, "test", "runtests.jl"))
    @test isfile(joinpath(pkg_dir, "Manifest.toml"))
    # Check the configured remote and branches.
    # Note: This test will fail on your system if you've configured Git
    # to replace all HTTPS URLs with SSH.
    repo = LibGit2.GitRepo(pkg_dir)
    remote = LibGit2.get(LibGit2.GitRemote, repo, "origin")
    branches = map(b -> LibGit2.shortname(first(b)), LibGit2.GitBranchIter(repo))
    @test LibGit2.url(remote) == "https://github.com/$me/$test_pkg.jl"
    @test branches == ["master"]
    @test !LibGit2.isdirty(repo)
    rm(pkg_dir; recursive=true)

    # Check that the remote is an SSH URL when we want it to be.
    t = Template(; user=me, ssh=true)
    generate(t, test_pkg; gitconfig=gitconfig)  # Test the reversed-arguments method here.
    repo = LibGit2.GitRepo(pkg_dir)
    remote = LibGit2.get(LibGit2.GitRemote, repo, "origin")
    @test LibGit2.url(remote) == "git@github.com:$me/$test_pkg.jl.git"
    rm(pkg_dir; recursive=true)

    # Check that the remote is set correctly for non-default hosts.
    t = Template(; user=me, host="gitlab.com")
    generate(test_pkg, t; gitconfig=gitconfig)
    repo = LibGit2.GitRepo(pkg_dir)
    remote = LibGit2.get(LibGit2.GitRemote, repo, "origin")
    @test LibGit2.url(remote) == "https://gitlab.com/$me/$test_pkg.jl"
    rm(pkg_dir; recursive=true)

    # Check that the package ends up in the right directory.
    temp_dir = mktempdir()
    t = Template(; user=me, dir=temp_dir)
    generate(test_pkg, t; gitconfig=gitconfig)
    @test isdir(joinpath(temp_dir, test_pkg))
    rm(temp_dir; recursive=true)

    # Check that the Manifest.toml is not commited by default.
    t = Template(; user=me)
    generate(test_pkg, t; gitconfig=gitconfig)
    @test occursin("Manifest.toml", read(joinpath(pkg_dir, ".gitignore"), String))
    # I'm not sure this is the "right" way to do this.
    repo = GitRepo(pkg_dir)
    idx = LibGit2.GitIndex(repo)
    @test findall("Manifest.toml", idx) === nothing
    rm(pkg_dir; recursive=true)

    # And that it is when you tell it to be.
    t = Template(; user=me, manifest=true)
    generate(test_pkg, t; gitconfig=gitconfig)
    @test !occursin("Manifest.toml", read(joinpath(pkg_dir, ".gitignore"), String))
    # I'm not sure this is the "right" way to do this.
    repo = GitRepo(pkg_dir)
    idx = LibGit2.GitIndex(repo)
    @test findall("Manifest.toml", idx) !== nothing
    rm(pkg_dir; recursive=true)

    # Check that the created package ends up developed in the current environment.
    temp_dir = mktempdir()
    Pkg.activate(temp_dir)
    t = Template(; user=me)
    generate(test_pkg, t; gitconfig=gitconfig)
    @test haskey(Pkg.installed(), test_pkg)
    rm(pkg_dir; recursive=true)
    Pkg.activate()
    rm(temp_dir; recursive=true)
end

@testset "Git-less package generation" begin
    t = Template(; user=me)
    generate(test_pkg, t; git=false)
    @test !ispath(joinpath(t.dir, ".git"))
    @test !isfile(joinpath(t.dir, ".gitignore"))
end

@testset "Plugins" begin
    t = Template(; user=me)
    pkg_dir = joinpath(t.dir, test_pkg)

    # Check badge constructor and formatting.
    badge = Badge("A", "B", "C")
    @test badge.hover == "A"
    @test badge.image == "B"
    @test badge.link == "C"
    @test format(badge) == "[![A](B)](C)"

    p = Bar()
    @test isempty(badges(p, me, test_pkg))
    @test isempty(gen_plugin(p, t, test_pkg))

    p = Baz()
    @test isempty(badges(p, me, test_pkg))
    @test isempty(gen_plugin(p, t, test_pkg))

    include(joinpath("plugins", "travisci.jl"))
    include(joinpath("plugins", "appveyor.jl"))
    include(joinpath("plugins", "gitlabci.jl"))
    include(joinpath("plugins", "codecov.jl"))
    include(joinpath("plugins", "coveralls.jl"))
    include(joinpath("plugins", "githubpages.jl"))
    include(joinpath("plugins", "gitlabpages.jl"))
end

@testset "Documenter add kwargs" begin
    t = Template(; user=me)
    pkg_dir = joinpath(t.dir, test_pkg)

    function check_kwargs(kwargs, warn_str)
        p = Qux([], kwargs)
        @test_logs (:warn, warn_str) gen_plugin(p, t, test_pkg)

        make = readchomp(joinpath(pkg_dir, "docs", "make.jl"))
        @test occursin("\n    stringarg=\"string\",\n", make)
        @test occursin("\n    strict=true,\n", make)
        @test occursin("\n    checkdocs=:none,\n", make)

        @test !occursin("format=:markdown", make)
        @test occursin("format=Documenter.HTML()", make)
        rm(pkg_dir; recursive=true)
    end
    # Test with string kwargs
    kwargs = Dict("checkdocs" => :none,
        "strict" => true,
        "format" => :markdown,
        "stringarg" => "string",
    )
    warn_str = "Ignoring predefined Documenter kwargs \"format\" from additional kwargs"
    check_kwargs(kwargs, warn_str)

    kwargs = Dict(
        :checkdocs => :none,
        :strict => true,
        :format => :markdown,
        :stringarg => "string",
    )
    warn_str = "Ignoring predefined Documenter kwargs :format from additional kwargs"
    check_kwargs(kwargs, warn_str)

    kwargs = (checkdocs = :none, strict = true, format = :markdown, stringarg = "string")
    warn_str = "Ignoring predefined Documenter kwargs :format from additional kwargs"
    check_kwargs(kwargs, warn_str)
end

include(joinpath("interactive", "interactive.jl"))
