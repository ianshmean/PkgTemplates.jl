function make_template(::Val{true}; kwargs...)
    @info "Default values are shown in [brackets]"

    # Getting the leaf types in a separate thread eliminates an awkward wait after
    # "Select plugins" is printed.
    plugin_types = @async leaves(Plugin)

    opts = Dict{Symbol, Any}()
    fast = get(kwargs, :fasts, false)

    opts[:user] = get(kwargs, :user) do
        prompt_string("Username", defaultkw(:user))
    end

    git = opts[:git] = get(kwargs, :git) do
        default = defaultkw(:git)
        fast ? default : prompt_bool("Create Git repositories for packages", default)
    end

    opts[:host] = get(kwargs, :host) do
        default = defaultkw(:host)
        if fast || !git
            default
        else
            prompt_string("Code hosting service", default)
        end
    end

    opts[:license] = get(kwargs, :license) do
        default = defaultkw(:license)
        if fast
            default
        else
            # TODO: Break this out into something reusable?
            println("License:")
            choices = ["None"; split(sprint(available_licenses), "\n")]
            licenses = ["" => ""; pairs(LICENCES)]
            menu = RadioMenu(choices...)
            # If the user breaks out of the menu with Ctrl-c, the result is -1, the absolute
            # value of which correponds to no license.
            first(licenses[abs(request(menu))])
        end
    end

    opts[:authors] = get(kwargs, :authors) do
        default = defaultkw(:authors)
        if fast || !git
            default
        else
            prompt_string("Package author(s)", isempty(default) ? "None" : default)
        end
    end

    opts[:dir] = get(kwargs, :dir) do
        default = defaultkw(:dir)
        fast ? default : prompt_string("Path to package directory", default)
    end

    opts[:julia_version] = get(kwargs, :julia_version) do
        default = defaultkw(:julia_version)
        fast ? default : prompt_bool("Minimum Julia version", default)
    end

    opts[:ssh] = get(kwargs, :ssh) do
        default = defaultkw(:ssh)
        fast || !git ? default : prompt_bool("Set remote to SSH", default)
    end

    opts[:manifest] = get(kwargs, :manifest) do
        default = defaultkw(:manifest)
        fast || !git ? default : prompt_bool("Commit Manifest.toml", default)
    end

    opts[:plugins] = get(kwargs, :plugins) do
        # TODO: Break this out into something reusable?
        println("Select plugins:")
        types = filter(T -> hasmethod(interactive, (Type{T},)), fetch(plugin_types))
        # TODO: finish
    end

    return make_template(Val(false), kwargs...)
end

prompt_string(s::AbstractString, default=nothing) = prompt(string, s, default)

function prompt_bool(s::AbstractString, default=nothing)
    return prompt(s, default) do answer
        answer = lowercase(answer)
        if answer in ["yes", "true", "y", "t"]
            true
        elseif answer in ["no", "false", "n", "f"]
            false
        else
            throw(ArgumentError("Invalid yes/no response"))
        end
    end
end

function prompt(f::Function, s::AbstractString, default)
    required = default === nothing
    print(s, " [", required ? "REQUIRED" : default, "]: ")
    answer = readline()
    return if isempty(answer)
        required && throw(ArgumentError("This argument is required"))
        default
    else
        f(answer)
    end
end
