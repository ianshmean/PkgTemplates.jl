# Returns a templated docstring for the plugins below.
function make_docstring(T::String, name::String, file::Union{String, Nothing}, url::String)
    file = repr(file === nothing ? file : replace(file, DEFAULTS_DIR => "<defaults>"))
    return """
            $T(file::Union{AbstractString, Nothing}=$file) -> $T

        Add `$T` to a [`Template`](@ref)'s plugin list to integrate your project with [$name]($url).
        """
end

"""$(make_docstring("AppVeyor", "AppVeyor", default_file("appveyor.yml"), "https://appveyor.com"))"""
@plugin AppVeyor default_file("appveyor.yml") => ".appveyor.yml" badges=Badge(
    "Build Status",
    "https://ci.appveyor.com/api/projects/status/github/{{USER}}/{{PKGNAME}}.jl?svg=true",
    "https://ci.appveyor.com/project/{{USER}}/{{PKGNAME}}-jl",
)

"""$(make_docstring("Codecov", "Codecov", nothing, "https://codecov.io"))"""
@plugin Codecov nothing => ".codecov.yml" gitignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem"] badges=Badge(
    "Coverage",
    "https://codecov.io/gh/{{USER}}/{{PKGNAME}}.jl/branch/master/graph/badge.svg",
    "https://codecov.io/gh/{{USER}}/{{PKGNAME}}.jl",
)

"""$(make_docstring("Coveralls", "Coveralls", nothing, "https://coveralls.io"))"""
@plugin Coveralls nothing => ".coveralls.yml" gitignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem"] badges=Badge(
    "Coverage",
    "https://coveralls.io/repos/github/{{USER}}/{{PKGNAME}}.jl/badge.svg?branch=master",
    "https://coveralls.io/github/{{USER}}/{{PKGNAME}}.jl?branch=master",
)

"""$(make_docstring("TravisCI", "Travis CI", default_file("travis.yml"), "https://travis-ci.com"))"""
@plugin TravisCI default_file("travis.yml") => ".travis.yml" badges=Badge(
    "Build Status",
    "https://travis-ci.com/{{USER}}/{{PKGNAME}}.jl.svg?branch=master",
    "https://travis-ci.com/{{USER}}/{{PKGNAME}}.jl",
)

"""
    GitLabCI(
        file::Union{AbstractString, Nothing}="<defaults>/gitlab-ci.yml";
        coverage::Bool=true,
    ) -> GitLabCI

Add `GitLabCI` to a [`Template`](@ref)'s plugin list to integrate your project with [GitLab CI](https://docs.gitlab.com/ce/ci).
If `coverage` is set, then code coverage analysis is enabled.
"""
@plugin GitLabCI default_file("gitlab-ci.yml") => ".gitlab-ci.yml" coverage::Bool=true
gitignore(p::GitLabCI) = p.coverage ? ["*.jl.cov", "*.jl.*.cov", "*.jl.mem"] : String[]
function badges(p::GitLabCI)
    bs = [Badge(
        "Build Status",
        "https://gitlab.com/{{USER}}/{{PKGNAME}}.jl/badges/master/build.svg",
        "https://gitlab.com/{{USER}}/{{PKGNAME}}.jl/pipelines",
    )]
    p.coverage && push!(bs, Badge(
        "Coverage",
        "https://gitlab.com/{{USER}}/{{PKGNAME}}.jl/badges/master/coverage.svg",
        "https://gitlab.com/{{USER}}/{{PKGNAME}}.jl/commits/master",
    ))
    return bs
end
function interactive(::Type{GitLabCI})
    cfg = prompt_config(GitLabCI)
    coverage = prompt_bool("GitLabCI: Enable test coverage analysis", true)
    return GitLabCI(cfg; coverage=coverage)
end
function Base.show(io::IO, p::GitLabCI)
    invoke(show, Tuple{IO, GeneratedPlugin}, io, p)
    print(io, ", coverage ", p.coverage ? "enabled" : "disabled")
end
function Base.repr(p::GitLabCI)
    s = invoke(repr, Tuple{GeneratedPlugin}, p)[1:end-1]  # Remove trailing ')'.
    return "$s; coverage=$(p.coverage))"
end
