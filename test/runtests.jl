using PkgTemplates
using Test
using Dates
using LibGit2
using Pkg

using PkgTemplates
const PT = PkgTemplates

# Various options to be passed into templates.
const me = "christopher-dG"
const test_pkg = "TestPkg"
const fake_path = "/this/file/does/not/exist"
const test_file = tempname()
const default_dir = Pkg.devdir()
const gitconfig = GitConfig(joinpath(@__DIR__, "gitconfig"))
const template_text = """
    PKGNAME: {{PKGNAME}}
    VERSION: {{VERSION}}}
    {{#GH_PAGES}}GitHubPages{{/GH_PAGES}}
    {{#GL_PAGES}}GitLabPages{{/GL_PAGES}}
    {{#CODECOV}}Codecov{{/CODECOV}}
    {{#COVERALLS}}Coveralls{{/COVERALLS}}
    {{#OTHER}}Other{{/OTHER}}
    """
write(test_file, template_text)

mktempdir() do temp_dir
    mkdir(joinpath(temp_dir, "dev"))
    pushfirst!(DEPOT_PATH, temp_dir)
    cd(temp_dir) do
        @testset "PkgTemplates.jl" begin
            include("template.jl")
            include("show.jl")
        end
    end
end

rm(test_file; force=true)
