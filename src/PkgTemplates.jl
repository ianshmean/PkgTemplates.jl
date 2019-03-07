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

"""
A plugin to be added to a [`Template`](@ref), which adds some functionality or integration.
"""
abstract type Plugin end

include("licenses.jl")
include("template.jl")
include("generate.jl")
include("plugin.jl")
include("utils.jl")
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
