@testset "File generation" begin
    t = Template(;
        user=me,
        license="MPL",
        plugins=[Coveralls(), TravisCI(), Codecov(), GitHubPages(), AppVeyor()],
    )
    temp_dir = mktempdir()
    pkg_dir = joinpath(temp_dir, test_pkg)

    temp_file = tempname()
    gen_file(temp_file, "Hello, world")
    @test isfile(temp_file)
    @test read(temp_file, String) == "Hello, world\n"
    rm(temp_file)

    # Test the README generation.
    @test gen_readme(pkg_dir, t) == ["README.md"]
    @test isfile(joinpath(pkg_dir, "README.md"))
    readme = readchomp(joinpath(pkg_dir, "README.md"))
    rm(joinpath(pkg_dir, "README.md"))
    @test occursin("# $test_pkg", readme)
    for p in values(t.plugins)
        @test occursin(join(badges(p, t.user, test_pkg), "\n"), readme)
    end
    # Check the order of the badges.
    @test something(findfirst("github.io", readme)).start <
        something(findfirst("travis", readme)).start <
        something(findfirst("appveyor", readme)).start <
        something(findfirst("codecov", readme)).start <
        something(findfirst("coveralls", readme)).start
    # Plugins with badges but not in BADGE_ORDER should appear at the far right side.
    t.plugins[Foo] = Foo()
    gen_readme(pkg_dir, t)
    readme = readchomp(joinpath(pkg_dir, "README.md"))
    rm(joinpath(pkg_dir, "README.md"))
    @test findfirst("coveralls", readme).start < findfirst("baz", readme).start

    # Test the gitignore generation.
    @test gen_gitignore(pkg_dir, t) == [".gitignore"]
    @test isfile(joinpath(pkg_dir, ".gitignore"))
    gitignore = read(joinpath(pkg_dir, ".gitignore"), String)
    rm(joinpath(pkg_dir, ".gitignore"))
    @test occursin(".DS_Store", gitignore)
    @test occursin("Manifest.toml", gitignore)
    for p in values(t.plugins)
        for entry in p.gitignore
            @test occursin(entry, gitignore)
        end
    end
    t = Template(; user=me, manifest=true)
    @test gen_gitignore(pkg_dir, t) == [".gitignore", "Manifest.toml"]
    gitignore = read(joinpath(pkg_dir, ".gitignore"), String)
    @test !occursin("Manifest.toml", gitignore)
    rm(joinpath(pkg_dir, ".gitignore"))

    # Test the license generation.
    @test gen_license(pkg_dir, t) == ["LICENSE"]
    @test isfile(joinpath(pkg_dir, "LICENSE"))
    license = readchomp(joinpath(pkg_dir, "LICENSE"))
    rm(joinpath(pkg_dir, "LICENSE"))
    @test occursin(t.authors, license)
    @test occursin(read_license(t.license), license)

    # Test the REQUIRE generation.
    @test gen_require(pkg_dir, t) == ["REQUIRE"]
    @test isfile(joinpath(pkg_dir, "REQUIRE"))
    vf = version_floor(t.julia_version)
    @test readchomp(joinpath(pkg_dir, "REQUIRE")) == "julia $vf"
    rm(joinpath(pkg_dir, "REQUIRE"))

    # Test the test generation.
    @test gen_tests(pkg_dir, t) == ["test/"]
    @test isfile(joinpath(pkg_dir, "Project.toml"))
    project = read(joinpath(pkg_dir, "Project.toml"), String)
    @test occursin("[extras]\nTest = ", project)
    @test isdir(joinpath(pkg_dir, "test"))
    @test isfile(joinpath(pkg_dir, "test", "runtests.jl"))
    @test isfile(joinpath(pkg_dir, "Manifest.toml"))
    runtests = read(joinpath(pkg_dir, "test", "runtests.jl"), String)
    rm(joinpath(pkg_dir, "test"); recursive=true)
    @test occursin("using $test_pkg", runtests)
    @test occursin("using Test", runtests)
    manifest = read(joinpath(pkg_dir, "Manifest.toml"), String)
    @test !occursin("[[Test]]", manifest)

    rm(temp_dir; recursive=true)
end

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
