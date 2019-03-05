# The directory containing the default template files.
const DEFAULTS_DIR = normpath(joinpath(@__DIR__, "..", "defaults"))

# Join a basename to the default directory.
default_file(file::AbstractString) = joinpath(DEFAULTS_DIR, file)

"""
    gen_file(file::AbstractString, text::AbstractString) -> Int

Create a new file containing some given text. Always ends the file with a newline.

# Arguments
* `file::AbstractString`: Path to the file to be created.
* `text::AbstractString`: Text to write to the file.
"""
function gen_file(file::AbstractString, text::AbstractString)
    mkpath(dirname(file))
    endswith(text , "\n") || (text *= "\n")
    write(file, text)
end

"""
    version_floor(v::VersionNumber=VERSION) -> String

Format the given Julia version.

# Keyword arguments
* `v::VersionNumber=VERSION`: Version to floor.

Returns "major.minor" for the most recent release version relative to v. For prereleases
with `v.minor == v.patch == 0`, returns `"major.minor-"`.
"""
function version_floor(v::VersionNumber=VERSION)
    return if isempty(v.prerelease) || v.patch > 0
        "$(v.major).$(v.minor)"
    else
        "$(v.major).$(v.minor)-"
    end
end

"""
    substitute(
        template::AbstractString,
        [pkg_template::Template,]
        [view::Dict{String, Any},]
    ) -> String

Replace placeholders in `template` via
[`Mustache`](https://github.com/jverzani/Mustache.jl). `template` is not modified.

# Arguments
* `template::AbstractString`: Template string with placeholders to be replaced.
* `pkg_template::Template`: When supplied, adds some default replacements.
* `view::Dict{String, Any}`: When supplied, adds more replacements.
"""
function substitute(template::AbstractString, view::Dict{String, Any}=Dict{String, Any}())
    return render(template, view)
end

function substitute(
    template::AbstractString,
    pkg_template::Template,
    view::Dict{String, Any}=Dict{String, Any}(),
)
    # Don't use version_floor here because we don't want the trailing '-' on prereleases.
    v = pkg_template.julia_version
    d = Dict{String, Any}(
        "USER" => pkg_template.user,
        "VERSION" => "$(v.major).$(v.minor)",
        "GH_PAGES" => haskey(pkg_template.plugins, Documenter{TravisCI}),
        "GL_PAGES" => haskey(pkg_template.plugins, Documenter{GitLabCI}),
        "CODECOV" => haskey(pkg_template.plugins, Codecov),
        "COVERALLS" => haskey(pkg_template.plugins, Coveralls),
    )

    # d["COVERAGE"] is true whenever a coverage plugin is enabled.
    # TODO: This doesn't handle user-defined coverage plugins.
    # Maybe we need an abstract CoveragePlugin <: GenericPlugin?
    # That wouldn't be able to express types like GitLabCI, which don't always do coverage.
    d["COVERAGE"] = |(
        d["CODECOV"],
        d["COVERALLS"],
        haskey(pkg_template.plugins, GitLabCI) && pkg_template.plugins[GitLabCI].coverage,
    )
    return substitute(template, merge(d, view))
end

# Remove the trailing ".jl" from a package name.
splitjl(pkg::AbstractString) = endswith(pkg, ".jl") ? pkg[1:end-3] : pkg

# Get a list of all concrete subtypes of some type, including itself.
leaves(T::Type)::Vector{DataType} = isconcretetype(T) ? [T] : vcat(leaves.(subtypes(T))...)
