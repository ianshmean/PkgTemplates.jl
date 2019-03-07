"""
    Template(; kwargs...) -> Template

Records common information used to generate a package. If you don't wish to manually
create a template, you can use [`interactive_template`](@ref) instead.

# Keyword Arguments
* `user::AbstractString=""`: GitHub (or other code hosting service) username. If left
  unset, it will take the the global git config's value (`github.user`). If that is not
  set, an `ArgumentError` is thrown. **This is case-sensitive for some plugins, so take
  care to enter it correctly.**
* `host::AbstractString="github.com"`: URL to the code hosting service where your package
  will reside. Note that while hosts other than GitHub won't cause errors, they are not
  officially supported and they will cause certain plugins will produce incorrect output.
* `license::AbstractString="MIT"`: Name of the package license. If an empty string is
  given, no license is created. [`available_licenses`](@ref) can be used to list all
  available licenses, and [`show_license`](@ref) can be used to print out a particular
  license's text.
* `authors::Union{AbstractString, Vector{<:AbstractString}}=""`: Names that appear on the
  license. Supply a string for one author or an array for multiple. Similarly to `user`,
  it will take the value of of the global git config's value if it is left unset.
* `dir::AbstractString=$(replace(Pkg.devdir(), homedir() => "~"))`: Directory in which the
  package will go. Relative paths are converted to absolute ones at template creation time.
* `julia_version::VersionNumber=$VERSION`: Minimum allowed Julia version.
* `ssh::Bool=false`: Whether or not to use SSH for the remote.
* `manifest::Bool=false`: Whether or not to commit the `Manifest.toml`.
* `git::Bool=true`: Whether or not to create a Git repository for generated packages.
* `develop::Bool=true`: Whether or not to `develop` generated packages in the active
  environment.
* `plugins::Vector{<:Plugin}=Plugin[]`: A list of plugins that the
  package will include.
* `interactive::Bool=false`: When set, creates the template interactively from user input,
  using the previous keywords as a starting point.
"""
struct Template
    user::String
    host::String
    license::String
    authors::String
    dir::String
    julia_version::VersionNumber
    ssh::Bool
    manifest::Bool
    git::Bool
    develop::Bool
    plugins::Dict{DataType, <:Plugin}
end

function Template(; kwargs...)
    interactive = Val(get(kwargs, :interactive, false))
    return make_template(interactive; kwargs...)
end

function make_template(::Val{false}; kwargs...)
    user = getkw(kwargs, :user)
    if isempty(user)
        throw(ArgumentError("No username found, set one with user=username"))
    end

    host = getkw(kwargs, :host)
    host = URI(occursin("://", host) ? host : "https://$host").host

    license = getkw(kwargs, :license)
    if !isempty(license) && !isfile(joinpath(LICENSE_DIR, license))
        throw(ArgumentError("License '$license' is not available"))
    end

    authors = getkw(kwargs, :authors)
    if authors isa Vector
        authors = join(authors, ", ")
    end

    dir = abspath(expanduser(getkw(kwargs, :dir)))

    plugins = getkw(kwargs, :plugins)
    plugin_dict = Dict{DataType, Plugin}(typeof(p) => p for p in plugins)
    if length(plugins) != length(plugin_dict)
        @warn "Plugin list contained duplicates, only the last of each type was kept"
    end

    return Template(
        user,
        host,
        license,
        authors,
        dir,
        getkw(kwargs, :julia_version),
        getkw(kwargs, :ssh),
        getkw(kwargs, :manifest),
        getkw(kwargs, :git),
        getkw(kwargs, :develop),
        plugin_dict,
    )
end

getkw(kwargs, k) = get(() -> default_kw(Val(k)), kwargs, k)

default_kw(::Val{:user}) = LibGit2.getconfig("github.user", "")
default_kw(::Val{:host}) = "https://github.com"
default_kw(::Val{:license}) = "MIT"
default_kw(::Val{:authors}) = LibGit2.getconfig("user.name", "")
default_kw(::Val{:dir}) = Pkg.devdir()
default_kw(::Val{:julia_version}) = VERSION
default_kw(::Val{:ssh}) = false
default_kw(::Val{:manifest}) = false
default_kw(::Val{:git}) = true
default_kw(::Val{:develop}) = true
default_kw(::Val{:plugins}) = Plugin[]

function Base.show(io::IO, t::Template)
    maybe(s::String) = isempty(s) ? "None" : s
    spc = "  "

    println(io, "Template:")
    println(io, spc, "→ User: ", maybe(t.user))
    println(io, spc, "→ Host: ", maybe(t.host))

    print(io, spc, "→ License: ")
    if isempty(t.license)
        println(io, "None")
    else
        println(io, t.license, " ($(t.authors) ", year(today()), ")")
    end

    println(io, spc, "→ Package directory: ", replace(maybe(t.dir), homedir() => "~"))
    println(io, spc, "→ Minimum Julia version: v", version_floor(t.julia_version))
    println(io, spc, "→ SSH remote: ", t.ssh ? "Yes" : "No")
    println(io, spc, "→ Commit Manifest.toml: ", t.manifest ? "Yes" : "No")
    println(io, spc, "→ Create Git repository: ", t.git ? "Yes" : "No")
    println(io, spc, "→ Develop packages: ", t.develop ? "Yes" : "No")

    print(io, spc, "→ Plugins:")
    if isempty(t.plugins)
        print(io, " None")
    else
        for plugin in sort(collect(values(t.plugins)); by=string)
            println(io)
            buf = IOBuffer()
            show(buf, plugin)
            print(io, spc^2, "• ")
            print(io, join(split(String(take!(buf)), "\n"), "\n$(spc^2)"))
        end
    end
end

"""
    interactive_template(; fast::Bool=false) -> Template

Interactively create a [`Template`](@ref). If `fast` is set, defaults will be assumed for
all values except username and plugins.
"""
function interactive_template(; fast::Bool=false)
    default_user = LibGit2.getconfig("github.user", "")
    print("Username [", isempty(default_user) ? "REQUIRED" : default_user, "]: ")
    user = readline()
    kwargs[:user] = if !isempty(user)
        user
    elseif !isempty(default_user)
        default_user
    else
        throw(ArgumentError("Username is required"))
    end

    git = kwargs[:git] = if fast
        true
    else
        default_git = true
        print("Create a Git repository? [yes]: ")
        git = readline()
        isempty(git) ? default_git : uppercase(git) in ["Y", "YES", "T", "TRUE"]
    end

    kwargs[:host] = if fast || !git
        "https://github.com"  # If Git isn't enabled, this value never gets used.
    else
        default_host = "github.com"
        print("Code hosting service [$default_host]: ")
        host = readline()
        isempty(host) ? default_host : host
    end

    kwargs[:license] = if fast
        "MIT"
    else
        println("License:")
        io = IOBuffer()
        available_licenses(io)
        licenses = ["" => "", collect(LICENSES)...]
        menu = RadioMenu(String["None", split(String(take!(io)), "\n")...])
        # If the user breaks out of the menu with Ctrl-c, the result is -1, the absolute
        # value of which correponds to no license.
        first(licenses[abs(request(menu))])
    end

    # We don't need to ask for authors if there is no license,
    # because the license is the only place that they matter.
    kwargs[:authors] = if fast || isempty(kwargs[:license])
        LibGit2.getconfig("user.name", "")
    else
        default_authors = LibGit2.getconfig("user.name", "")
        default_str = isempty(default_authors) ? "None" : default_authors
        print("Package author(s) [$default_str]: ")
        authors = readline()
        isempty(authors) ? default_authors : authors
    end

    kwargs[:dir] = if fast
        Pkg.devdir()
    else
        default_dir = Pkg.devdir()
        print("Path to package directory [$default_dir]: ")
        dir = readline()
        isempty(dir) ? default_dir : dir
    end

    kwargs[:julia_version] = if fast
        VERSION
    else
        default_julia_version = VERSION
        print("Minimum Julia version [", version_floor(default_julia_version), "]: ")
        julia_version = readline()
        isempty(julia_version) ? default_julia_version : VersionNumber(julia_version)
    end

    kwargs[:ssh] = if fast || !git
        false
    else
        print("Set remote to SSH? [no]: ")
        uppercase(readline()) in ["Y", "YES", "T", "TRUE"]
    end

    kwargs[:manifest] = if fast || !git
        false
    else
        print("Commit Manifest.toml? [no]: ")
        uppercase(readline()) in ["Y", "YES", "T", "TRUE"]
    end

    println("Plugins:")
    # Only include plugin types which have an `interactive` method.
    plugin_types = filter(t -> hasmethod(interactive, (Type{t},)), fetch(plugin_types))
    type_names = map(t -> split(string(t), ".")[end], plugin_types)
    menu = MultiSelectMenu(String.(type_names); pagesize=length(type_names))
    selected = collect(request(menu))
    kwargs[:plugins] = convert(
        Vector{Plugin},
        map(interactive, getindex(plugin_types, selected)),
    )

    return Template(; git=git, kwargs...)
end
