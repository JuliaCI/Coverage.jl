#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/JuliaCI/Coverage.jl
#######################################################################

using Coverage, Compat, Compat.Test
using Suppressor

@testset "Coverage" begin

@testset "iscovfile" begin
    # test our filename matching. These aren't exported functions but it's probably
    # a good idea to have explicit tests for them, as they're used to match files
    # that get deleted
    @test Coverage.iscovfile("test.jl.cov")
    @test Coverage.iscovfile("test.jl.2934.cov")
    @test Coverage.iscovfile("/home/somebody/test.jl.2934.cov")
    @test !Coverage.iscovfile("test.ji.2934.cov")
    @test !Coverage.iscovfile("test.jl.2934.cove")
    @test !Coverage.iscovfile("test.jicov")
    @test !Coverage.iscovfile("test.c.cov")
    @test Coverage.iscovfile("test.jl.cov", "test.jl")
    @test !Coverage.iscovfile("test.jl.cov", "other.jl")
    @test Coverage.iscovfile("test.jl.8392.cov", "test.jl")
    @test Coverage.iscovfile("/somedir/test.jl.8392.cov", "/somedir/test.jl")
    @test !Coverage.iscovfile("/otherdir/test.jl.cov", "/somedir/test.jl")
end

@testset "isfuncexpr" begin
    @test !Coverage.isfuncexpr("2")
end

@testset "Processing coverage" begin
    cd(dirname(@__DIR__)) do
        datadir = joinpath("test", "data")
        # Process a saved set of coverage data...
        r = process_file(joinpath(datadir,"Coverage.jl"))
        # ... and memory data
        analyze_malloc(datadir)
        lcov = IOBuffer()
        # we only have a single file, but we want to test on the Vector of file results
        LCOV.write(lcov, FileCoverage[r])
        fn = "expected.info"
        if VERSION >= v"0.7.0-DEV.3481"
            fn = "expected07.info"
        end
        open(joinpath(datadir, fn)) do f
            @test String(take!(lcov)) == read(f, String)
        end

        # Test a file from scratch
        srcname = joinpath("test", "data","testparser.jl")
        covname = srcname*".cov"
        # clean out any previous coverage files. Don't use clean_folder because we
        # need to preserve the pre-baked coverage file Coverage.jl.cov
        clean_file(srcname)
        cmdstr = "include(\"$(escape_string(srcname))\"); using Compat, Compat.Test; @test f2(2) == 4"
        run(`$(Compat.Sys.BINDIR)/julia --code-coverage=user -e $cmdstr`)
        r = process_file(srcname, datadir)

        # Parsing seems to have changed slightly in Julia (or JuliaParser?) between v0.6 and v0.7.
        # Line 10 is the end of a @doc string (`""" ->`), and Line 11 is an expression (`f6(x) = 6x`)
        # In v0.6, the zero count goes to line 10, and in v0.7, the zero count goes (more correctly?)
        # to line 11
        # NOTE: The commit that made this change in Base was backported to 0.6.1, which necessitates
        # another VERSION check.

        if (VERSION.major == 0 && VERSION.minor == 7 && VERSION < v"0.7.0-DEV.468") || VERSION < v"0.6.1-pre.93"
            target = Union{Int64,Nothing}[nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
        elseif (VERSION.major == 0 && VERSION.minor == 6)
            target = Union{Int64,Void}[nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
        else
            target = Union{Int64,Nothing}[nothing, 1, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing]
        end
        @test r.coverage[1:length(target)] == target

        covtarget = (sum(x->x != nothing && x > 0, target), sum(x->x != nothing, target))
        @test get_summary(r) == covtarget
        @test get_summary(process_folder(datadir)) != covtarget

        # Handle an empty coverage vector
        emptycov = FileCoverage("", "", [])
        @test get_summary(emptycov) == (0, 0)

        #json_data = Codecov.build_json_data(Codecov.process_folder("data"))
        #@test typeof(json_data["coverage"]["data/Coverage.jl"]) == Array{Union{Int64,Nothing},1}
        open("fakefile",true,true,true,false,false)
        @test isempty(Coverage.process_cov("fakefile",datadir))
        rm("fakefile")
    end
end

@testset "codecovio.jl" begin
    """
    extracts the api URL from stdout in a codecov.io submit call
    very helpful for testing codecovio.jl
    """
    function extract_codecov_url(fun)
        data = @capture_out fun()
        lines = split(data, "\n")

        url = "None"
        get_next = false
        for line in lines
            if get_next
                url = line
                get_next = false
            end
            if occursin("Codecov.io API URL", line)
                get_next = true
            end
        end

        # println("url: $(url)")
        @assert url != "None" "unable to find codecov api url in stdout, check for changes in codecovio.jl"
        return url
    end

    # empty file coverage for testing
    fcs = FileCoverage[]

    # set up base system ENV vars for testing
    withenv(
        "CODECOV_URL" => nothing,
        "CODECOV_TOKEN" => nothing,
        "TRAVIS" => nothing,
        "TRAVIS_BRANCH" => nothing,
        "TRAVIS_COMMIT" => nothing,
        "TRAVIS_PULL_REQUEST" => nothing,
        "TRAVIS_JOB_ID" => nothing,
        "TRAVIS_REPO_SLUG" => nothing,
        "TRAVIS_JOB_NUMBER" => nothing,
        "APPVEYOR" => nothing,
        "APPVEYOR_PULL_REQUEST_NUMBER" => nothing,
        "APPVEYOR_ACCOUNT_NAME" => nothing,
        "APPVEYOR_PROJECT_SLUG" => nothing,
        "APPVEYOR_BUILD_VERSION" => nothing,
        "APPVEYOR_REPO_BRANCH" => nothing,
        "APPVEYOR_REPO_COMMIT" => nothing,
        "APPVEYOR_REPO_NAME" => nothing,
        "APPVEYOR_JOB_ID" => nothing,
        ) do

        # test local submission process

        # default values
        codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true) )
        @test occursin("codecov.io", codecov_url)
        @test occursin("commit", codecov_url)
        @test occursin("branch", codecov_url)
        @test !occursin("service", codecov_url)

        # env var url override
        withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true) )
            @test occursin("enterprise-codecov-1.com", codecov_url)
            @test occursin("commit", codecov_url)
            @test occursin("branch", codecov_url)
            @test !occursin("service", codecov_url)

            # function argument url override
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
            @test occursin("enterprise-codecov-2.com", codecov_url)
            @test occursin("commit", codecov_url)
            @test occursin("branch", codecov_url)
            @test !occursin("service", codecov_url)

            # env var token
            withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true) )
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("token=token_name_1", codecov_url)
                @test !occursin("service", codecov_url)

                # function argument token url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true, token="token_name_2") )
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("token=token_name_2", codecov_url)
                @test !occursin("service", codecov_url)
            end
        end


        # test faulty non-CI submission

        @test_throws ErrorException extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )

        # test travis-ci submission process

        # set up travis env
        withenv(
            "TRAVIS" => "true",
            "TRAVIS_BRANCH" => "t_branch",
            "TRAVIS_COMMIT" => "t_commit",
            "TRAVIS_PULL_REQUEST" => "t_pr",
            "TRAVIS_JOB_ID" => "t_job_id",
            "TRAVIS_REPO_SLUG" => "t_slug",
            "TRAVIS_JOB_NUMBER" => "t_job_num",
            ) do

            # default values
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=travis-org", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("pull_request=t_pr", codecov_url)
            @test occursin("job=t_job_id", codecov_url)
            @test occursin("slug=t_slug", codecov_url)
            @test occursin("build=t_job_num", codecov_url)

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=travis-org", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("job=t_job_id", codecov_url)
                @test occursin("slug=t_slug", codecov_url)
                @test occursin("build=t_job_num", codecov_url)

                # function argument url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=travis-org", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("job=t_job_id", codecov_url)
                @test occursin("slug=t_slug", codecov_url)
                @test occursin("build=t_job_num", codecov_url)

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_job_id", codecov_url)
                    @test occursin("slug=t_slug", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # function argument token url override
                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_2", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_job_id", codecov_url)
                    @test occursin("slug=t_slug", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)
                end
            end
        end

        # test appveyor submission process

        # set up appveyor env
        withenv(
            "APPVEYOR" => "true",
            "APPVEYOR_PULL_REQUEST_NUMBER" => "t_pr",
            "APPVEYOR_ACCOUNT_NAME" => "t_account",
            "APPVEYOR_PROJECT_SLUG" => "t_slug",
            "APPVEYOR_BUILD_VERSION" => "t_version",
            "APPVEYOR_REPO_BRANCH" => "t_branch",
            "APPVEYOR_REPO_COMMIT" => "t_commit",
            "APPVEYOR_REPO_NAME" => "t_repo",
            "APPVEYOR_JOB_ID" => "t_job_num",
            ) do

                # default values
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test occursin("codecov.io", codecov_url)
                @test occursin("service=appveyor", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                @test occursin("build=t_job_num", codecov_url)

                # env var url override
                withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=appveyor", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # function argument url override
                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
                    @test occursin("enterprise-codecov-2.com", codecov_url)
                    @test occursin("service=appveyor", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # env var token
                    withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                        codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_1", codecov_url)
                        @test occursin("branch=t_branch", codecov_url)
                        @test occursin("commit=t_commit", codecov_url)
                        @test occursin("pull_request=t_pr", codecov_url)
                        @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                        @test occursin("build=t_job_num", codecov_url)

                        # function argument token url override
                        codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_2", codecov_url)
                        @test occursin("branch=t_branch", codecov_url)
                        @test occursin("commit=t_commit", codecov_url)
                        @test occursin("pull_request=t_pr", codecov_url)
                        @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                        @test occursin("build=t_job_num", codecov_url)
                    end
                end
            end

        # test circle ci submission process

        # set up circle ci env
        withenv(
            "CIRCLECI" => "true",
            "CIRCLE_PR_NUMBER" => "t_pr",
            "CIRCLE_PROJECT_USERNAME" => "t_proj",
            "CIRCLE_BRANCH" => "t_branch",
            "CIRCLE_SHA1" => "t_commit",
            "CIRCLE_PROJECT_REPONAME" => "t_repo",
            "CIRCLE_BUILD_URL" => "t_url",
            "CIRCLE_BUILD_NUM" => "t_num",
            ) do

            # default values
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=circleci", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("pull_request=t_pr", codecov_url)
            @test occursin("build_url=t_url", codecov_url)
            @test occursin("build=t_num", codecov_url)

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=circleci", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # function argument url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=circleci", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("service=circleci", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)

                    # function argument token url override
                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=circleci", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)
                end
            end
        end
    end
end

end
