"""
A [`Plugin`](@ref) which has been generated with [`@plugin`](@ref).
You should not manually create subtypes!
"""
abstract type GeneratedPlugin <: Plugin end

source(p::GeneratedPlugin) = p.src
destination(p::GeneratedPlugin) = p.dest
gitignore(p::GeneratedPlugin) = p.gitignore
badges(p::GeneratedPlugin) = p.badges
view(p::GeneratedPlugin) = p.view

"""
    @plugin T src => dest attr::type[=default]... opts...

Generate a basic plugin which manages a single configuration file.

# Arguments
* `T`: The name of the plugin to generate.
* `src => dest`: Defines the plugin's configuration file. The key is the path to the
  default configuration file, or `nothing` if the default is no file. The value is the
  destination path, relative to the root of generated packages.
* `attr::type[=default]...`: Extra attributes for the generated plugin. They are exposed
  via keyword arguments (optional if a default is provided, otherwise not).

# Keyword Arguments
* `gitignore::Vector{<:AbstractString}=[]`: List of patterns to be added to the
  `.gitignore` of generated packages.
* `badges::Vector{Badge}=[]`: List of [`Badge`](@ref)s to be added to the `README.md` of
  generated packages.
* `view::Dict{String. Any}=Dict()`: Additional substitutions to be made in both the
  plugin's badges and its configuration file. See [`substitute`](@ref) for details.
"""
macro plugin(T, src_dest, exs...)
    src, dest = eval.(src_dest.args[2:3])

    attrs = Expr[]  # Attribute expressions, e.g. x::Bool.
    kws = Expr[]  # Keyword expressions, e.g. x::Bool or x::Bool=true.
    names = Symbol[]  # Attribute names, e.g. x.
    opts = Dict(:gitignore => [], :badges => [], :view => Dict())

    for ex in exs
        if ex.head === :(::)
            # Extra attribute with no default (mandatory keyword).
            push!(attrs, ex)
            push!(kws, ex)
            push!(names, ex.args[1])
        elseif ex.head === :(=)
            if ex.args[1] isa Symbol
                # Plugin option.
                opts[ex.args[1]] = eval(ex.args[2])
            else
                # Extra attribute with a default argument.
                push!(attrs, ex.args[1])
                push!(kws, Expr(:kw, ex.args[1], ex.args[2]))
                push!(names, ex.args[1].args[1])
            end
        else
            throw(ArgumentError(repr(ex)))
        end
    end

    gitignore = opts[:gitignore]
    badges = opts[:badges]
    view = opts[:view]

    quote
        Base.@__doc__ struct $T <: GeneratedPlugin
            src::Union{String, Nothing}
            dest::String
            gitignore::Vector{String}
            badges::Vector{Badge}
            view::Dict{String, Any}
            $(attrs...)

            function $(esc(T))(file::Union{AbstractString, Nothing}=$src; $(map(esc, kws)...))
                if file !== nothing && !isfile(file)
                    throw(ArgumentError("File $(abspath(file)) does not exist"))
                end
                return new(file, $dest, $gitignore, $badges, $view, $(map(esc, names)...))
            end
        end

        PkgTemplates.source(::Type{$(esc(T))}) = $src
    end
end

function Base.show(io::IO, p::GeneratedPlugin)
    T = nameof(typeof(p))
    src = source(p)
    cfg = src === nothing ? "no file" : replace(src, homedir() => "~")
    print(io, "$T: Configured with $cfg")
end

function Base.repr(p::GeneratedPlugin)
    T = nameof(typeof(p))
    src = source(p)
    cfg = src === nothing ? "nothing" : repr(replace(src, homedir() => "~"))
    return "$T($cfg)"
end

"""
Custom plugins are plugins whose behaviour does not follow the [`GenericPlugin`](@ref)
pattern. They can implement [`gen_plugin`](@ref), [`badges`](@ref), and
[`interactive`](@ref) in any way they choose, as long as they conform to the usual type
signature.

# Attributes
* `gitignore::Vector{AbstractString}`: Array of patterns to be added to the `.gitignore` of
  generated packages that use this plugin.

# Example
```julia
struct MyPlugin <: CustomPlugin
    gitignore::Vector{AbstractString}
    lucky::Bool

    MyPlugin() = new([], rand() > 0.8)

    function gen_plugin(p::MyPlugin, t::Template, pkg_name::AbstractString)
        return if p.lucky
            text = substitute("You got lucky with {{PKGNAME}}, {{USER}}!", t)
            gen_file(joinpath(t.dir, pkg_name, ".myplugin.yml"), text)
            [".myplugin.yml"]
        else
            println("Maybe next time.")
            String[]
        end
    end

    function badges(p::MyPlugin, user::AbstractString, pkg_name::AbstractString)
        return if p.lucky
            [
                format(Badge(
                    "You got lucky!",
                    "https://myplugin.com/badge.png",
                    "https://myplugin.com/\$user/\$pkg_name.jl",
                )),
            ]
        else
            String[]
        end
    end
end

interactive(:Type{MyPlugin}) = MyPlugin()
```

This plugin doesn't do much, but it demonstrates how [`gen_plugin`](@ref), [`badges`](@ref)
and [`interactive`](@ref) can be implemented using [`substitute`](@ref),
[`gen_file`](@ref), [`Badge`](@ref), and [`format`](@ref).

# Defining Template Files
Often, the contents of the config file that your plugin generates depends on variables like
the package name, the user's username, etc. Template files (which are stored in `defaults`)
can use [here](https://github.com/jverzani/Mustache.jl)'s syntax to define replacements.
"""
abstract type CustomPlugin <: Plugin end

"""
    Badge(hover::AbstractString, image::AbstractString, link::AbstractString) -> Badge

Container for Markdown badge data.

# Arguments
* `hover::AbstractString`: Text to appear when the mouse is hovered over the badge.
* `image::AbstractString`: URL to the image to display.
* `link::AbstractString`: URL to go to upon clicking the badge.
"""
struct Badge
    hover::String
    image::String
    link::String
end

Base.show(io::IO, b::Badge) = print(io, "[![$(b.hover)]($(b.image))]($(b.link))")

"""
    gen_plugin(p::Plugin, t::Template, pkg_name::AbstractString) -> Vector{String}

Generate any files associated with a plugin.

# Arguments
* `p::Plugin`: Plugin whose files are being generated.
* `t::Template`: Template configuration.
* `pkg_name::AbstractString`: Name of the package.

Returns an array of generated file/directory names.
"""
gen_plugin(::Plugin, ::Template, ::AbstractString) = String[]

function gen_plugin(p::GeneratedPlugin, t::Template, pkg_name::AbstractString)
    source(p) === nothing && return String[]
    text = substitute(
        read(source(p), String),
        t;
        view=merge(Dict("PKGNAME" => pkg_name), p.view),
    )
    gen_file(joinpath(t.dir, pkg_name, destination(p)), text)
    return [destination(p)]
end

"""
    badges(p::Plugin, user::AbstractString, pkg_name::AbstractString) -> Vector{String}

Generate Markdown badges for the plugin.

# Arguments
* `p::Plugin`: Plugin whose badges we are generating.
* `user::AbstractString`: Username of the package creator.
* `pkg_name::AbstractString`: Name of the package.

Returns an array of Markdown badges.
"""
badges(::Plugin, ::AbstractString, ::AbstractString) = String[]

function badges(p::GeneratedPlugin, user::AbstractString, pkg_name::AbstractString)
    # Give higher priority to replacements defined in the plugin's view.
    view = merge(Dict("USER" => user, "PKGNAME" => pkg_name), p.view)
    return map(b -> substitute(string(b), view), badges(p))
end

"""
    interactive(T::Type{<:Plugin}) -> T

Interactively create a plugin of type `T`.
"""
interactive(T::Type{<:GeneratedPlugin}) = T(promptconfig(T))

function promptconfig(T::Type{<:GeneratedPlugin})
    print(nameof(T), ": Enter the config template filename ")
    default = source(T)
    if default === nothing
        print("[None]: ")
    else
        print("(\"None\" for no file) [", replace(default, homedir() => "~"), "]: ")
    end

    file = readline()
    return if uppercase(file) == "NONE"
        nothing
    elseif isempty(file)
        default
    else
        file
    end
end

@plugin AppVeyor default_file("appveyor.yml") => ".appveyor.yml" badges=[Badge(
    "Build Status",
    "https://ci.appveyor.com/api/projects/status/github/{{USER}}/{{PKGNAME}}.jl?svg=true",
    "https://ci.appveyor.com/project/{{USER}}/{{PKGNAME}}-jl",
)]

@plugin Codecov nothing => ".codecov.yml" gitignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem"] badges=[Badge(
    "Coverage",
    "https://codecov.io/gh/{{USER}}/{{PKGNAME}}.jl/branch/master/graph/badge.svg",
    "https://codecov.io/gh/{{USER}}/{{PKGNAME}}.jl",
)]

@plugin Coveralls nothing => ".coveralls.yml" gitignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem"] badges=[Badge(
    "Coverage",
    "https://coveralls.io/repos/github/{{USER}}/{{PKGNAME}}.jl/badge.svg?branch=master",
    "https://coveralls.io/github/{{USER}}/{{PKGNAME}}.jl?branch=master",
)]

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
    cfg = promptconfig(GitLabCI)
    print("GitLabCI: enable test coverage analysis [Yes]: ")
    coverage = !in(uppercase(readline()), ["N", "NO", "FALSE", "NONE"])
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

@plugin TravisCI default_file("travis.yml") => ".travis.yml" badges=[Badge(
    "Build Status",
    "https://travis-ci.com/{{USER}}/{{PKGNAME}}.jl.svg?branch=master",
    "https://travis-ci.com/{{USER}}/{{PKGNAME}}.jl",
)]
