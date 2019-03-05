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
    Documenter,
    AppVeyor,
    TravisCI,
    GitLabCI,
    Codecov,
    Coveralls

const DEFAULTS_DIR = normpath(joinpath(@__DIR__, "..", "defaults"))
default_file(file::AbstractString) = joinpath(DEFAULTS_DIR, file)

"""
A plugin to be added to a [`Template`](@ref), which adds some functionality or integration.
"""
abstract type AbstractPlugin end

include("licenses.jl")
include("template.jl")
include("generate.jl")
include("plugin.jl")
include(joinpath("plugins", "generated.jl"))
include(joinpath("plugins", "documenter.jl"))

const BADGE_ORDER = [
    Documenter{GitLabCI},
    Documenter{TravisCI},
    TravisCI,
    AppVeyor,
    GitLabCI,
    Codecov,
    Coveralls,
]

end
