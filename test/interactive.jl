@testset "Interactive functions" begin
    CR = "\r"
    LF = "\n"
    CRLF = "\r\n"

    @testset "Interactive Template" begin
        print(stdin.buffer, me, LF)  # User
        print(stdin.buffer, LF)  # Git
        print(stdin.buffer, LF)  # Host
        print(stdin.buffer, CRLF)  # License
        print(stdin.buffer, LF)  # Authors
        print(stdin.buffer, LF)  # Directory
        print(stdin.buffer, LF)  # Version
        print(stdin.buffer, LF)  # SSH
        print(stdin.buffer, LF)  # Manifest
        print(stdin.buffer, LF)  # Develop
        print(stdin.buffer, "d")  # Plugins

        t = Template(; interactive=true)

        # The default license in interactive mode is not the actual default,
        # since we can't set the initial selection of the menu.
        @test sprint(show, t) == sprint(show, Template(; user=me, license=""))

        @testset "Provided keywords are not prompted" begin
            print(stdin.buffer, me, LF)  # User
            print(stdin.buffer, LF)  # Git
            print(stdin.buffer, LF)  # Host
            # License menu would be here.
            print(stdin.buffer, LF)  # Authors
            print(stdin.buffer, LF)  # Directory
            print(stdin.buffer, LF)  # Version
            print(stdin.buffer, LF)  # SSH
            print(stdin.buffer, LF)  # Manifest
            print(stdin.buffer, LF)  # Develop
            print(stdin.buffer, "d")  # Plugins

            t = Template(; interactive=true, license="ISC")
            @test t.license == "ISC"
        end

        @testset "Fast mode" begin
            print(stdin.buffer, me, LF)  # User
            print(stdin.buffer, "d")  # Plugins
            t = Template(; interactive=true, fast=true)
            @test sprint(show, t) == sprint(show, Template(; user=me))
        end
    end

    @testset "Interactive plugins" begin
    end
end
