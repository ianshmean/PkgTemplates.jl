module PkgTemplates

using Dates
using InteractiveUtils
using LibGit2
using Mustache
using Pkg
using REPL.TerminalMenus
using URIParser

export
    # Template/package generation.
    Template,
    generate,
    interactive_template,
    generate_interactive,
    # Licenses.
    show_license,
    available_licenses,
    # Plugins.
    GitHubPages,
    AppVeyor,
    TravisCI,
    GitLabCI,
    CirrusCI,
    Codecov,
    Coveralls

"""
A plugin to be added to a [`Template`](@ref), which adds some functionality or integration.
New plugins should almost always extend [`GenericPlugin`](@ref) or [`CustomPlugin`](@ref).
"""
abstract type Plugin end

include("licenses.jl")
include("template.jl")
include("generate.jl")
include("plugin.jl")
include(joinpath("plugins", "documenter.jl"))
include(joinpath("plugins", "coveralls.jl"))
include(joinpath("plugins", "appveyor.jl"))
include(joinpath("plugins", "codecov.jl"))
include(joinpath("plugins", "travisci.jl"))
include(joinpath("plugins", "gitlabci.jl"))
include(joinpath("plugins", "cirrusci.jl"))
include(joinpath("plugins", "githubpages.jl"))

const DEFAULTS_DIR = normpath(joinpath(@__DIR__, "..", "defaults"))
const BADGE_ORDER = [GitHubPages, TravisCI, AppVeyor, GitLabCI, Codecov, Coveralls]

end
