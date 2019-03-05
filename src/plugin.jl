source(::AbstractPlugin) = nothing
destination(::AbstractPlugin) = ""
gitignore(::AbstractPlugin) = String[]
badges(::AbstractPlugin) = Badge[]
view(::AbstractPlugin) = Dict{String, Any}()

"""
A plugin which has been generated with [`@plugin`](@ref).
You should not manually create subtypes!
"""
abstract type GeneratedPlugin <:AbstractPlugin end

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
* `gitignore=String[]`: List of patterns to be added to the `.gitignore` of generated
  packages. Can also be a single string.
* `badges=Badge[]`: List of [`Badge`](@ref)s to be added to the `README.md` of generated
  packages. Can also be a single badge.
* `view=Dict()`: Key-value pairs representing additional substitutions to be made in both
  the plugin's badges and its configuration file. See [`substitute`](@ref) for details.
"""
macro plugin(T, src_dest, exs...)
    src, dest = eval.(src_dest.args[2:3])

    attrs = Expr[]  # Attribute expressions, e.g. x::Bool.
    kws = Expr[]  # Keyword expressions, e.g. x::Bool or x::Bool=true.
    names = Symbol[]  # Attribute names, e.g. x.
    opts = Dict(:gitignore => [], :badges => [], :view => ())

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

    gitignore = opts[:gitignore] isa Vector ? opts[:gitignore] : [opts[:gitignore]]
    gitignore = convert(Vector{String}, gitignore)
    badges = opts[:badges] isa Vector ? opts[:badges] : [opts[:badges]]
    badges = convert(Vector{Badge}, badges)
    view = Dict(opts[:view])

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
    gen_plugin(p::AbstractPlugin, t::Template, pkg_name::AbstractString) -> Vector{String}

Generate any files associated with a plugin.

# Arguments
* `p::Plugin`: Plugin whose files are being generated.
* `t::Template`: Template configuration.
* `pkg_name::AbstractString`: Name of the package.

Returns an array of generated file/directory names.
"""
gen_plugin(::AbstractPlugin, ::Template, ::AbstractString) = String[]

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
    badges(
        p::AbstractPlugin,
        user::AbstractString,
        pkg_name::AbstractString,
    ) -> Vector{String}

Generate Markdown badges for the plugin.

# Arguments
* `p::AbstractPlugin`: Plugin whose badges we are generating.
* `user::AbstractString`: Username of the package creator.
* `pkg_name::AbstractString`: Name of the package.

Returns an array of Markdown badges.
"""
function badges(p::AbstractPlugin, user::AbstractString, pkg_name::AbstractString)
    # Give higher priority to replacements defined in the plugin's view.
    subs = merge(Dict("USER" => user, "PKGNAME" => pkg_name), view(p))
    return map(b -> substitute(string(b), subs), badges(p))
end

"""
    interactive(T::Type{<:AbstractPlugin}) -> T

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
