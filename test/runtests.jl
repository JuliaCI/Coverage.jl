#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/JuliaCI/Coverage.jl
#######################################################################

using Coverage, Compat, Compat.Test

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

    #json_data = Codecov.build_json_data(Codecov.process_folder("data"))
    #@test typeof(json_data["coverage"]["data/Coverage.jl"]) == Array{Union{Int64,Nothing},1}
    open("fakefile",true,true,true,false,false)
    @test isempty(Coverage.process_cov("fakefile",datadir))
    rm("fakefile")

    # Test `using Coverage` with non-empty command-line arguments
    script = tempname()
    write(script, """
        try
            using Coverage
            println(join(ARGS, ","))
        catch
            nothing
        end
        """)
    @test readchomp(`$(Base.julia_cmd()) $script argument`) == "argument"
    rm(script)

    # Test command-line usage
    if VERSION < v"0.7.0-DEV.3481"
        @test readchomp(`$(Base.julia_cmd()) $(joinpath("src", "Coverage.jl"))`) == "Coverage.MallocInfo[]"
    else
        @test readchomp(`$(Base.julia_cmd()) $(joinpath("src", "Coverage.jl"))`) == "Main.Coverage.MallocInfo[]"
    end
end





######################
# codecovio.jl tests #
######################

"""
extracts the api URL from stdout in a codecov.io submit call
very helpful for testing codecovio.jl
"""
function extract_codecov_url(fun)
    originalSTDOUT = STDOUT

    (outRead, outWrite) = redirect_stdout()

    fun()

    close(outWrite)

    data = String(readavailable(outRead))

    close(outRead)
    redirect_stdout(originalSTDOUT)

    lines = split(data, "\n")

    url = "None"
    get_next = false
    for line in lines
        if get_next
            url = line
            get_next = false
        end
        if contains(line, "Codecov.io API URL")
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
    @test contains(codecov_url, "codecov.io")
    @test contains(codecov_url, "commit")
    @test contains(codecov_url, "branch")
    @test !contains(codecov_url, "service")

    # default values in depreciated call
    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs) )
    @test contains(codecov_url, "codecov.io")
    @test contains(codecov_url, "commit")
    @test contains(codecov_url, "branch")
    @test !contains(codecov_url, "service")

    # env var url override
    withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

        codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true) )
        @test contains(codecov_url, "enterprise-codecov-1.com")
        @test contains(codecov_url, "commit")
        @test contains(codecov_url, "branch")
        @test !contains(codecov_url, "service")

        # function argument url override
        codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
        @test contains(codecov_url, "enterprise-codecov-2.com")
        @test contains(codecov_url, "commit")
        @test contains(codecov_url, "branch")
        @test !contains(codecov_url, "service")

        # env var token
        withenv( "CODECOV_TOKEN" => "token_name_1" ) do

            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true) )
            @test contains(codecov_url, "enterprise-codecov-1.com")
            @test contains(codecov_url, "token=token_name_1")
            @test !contains(codecov_url, "service")

            # function argument token url override
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit_local(fcs; dry_run = true, token="token_name_2") )
            @test contains(codecov_url, "enterprise-codecov-1.com")
            @test contains(codecov_url, "token=token_name_2")
            @test !contains(codecov_url, "service")
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
        @test contains(codecov_url, "codecov.io")
        @test contains(codecov_url, "service=travis-org")
        @test contains(codecov_url, "branch=t_branch")
        @test contains(codecov_url, "commit=t_commit")
        @test contains(codecov_url, "pull_request=t_pr")
        @test contains(codecov_url, "job=t_job_id")
        @test contains(codecov_url, "slug=t_slug")
        @test contains(codecov_url, "build=t_job_num")

        # env var url override
        withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
            @test contains(codecov_url, "enterprise-codecov-1.com")
            @test contains(codecov_url, "service=travis-org")
            @test contains(codecov_url, "branch=t_branch")
            @test contains(codecov_url, "commit=t_commit")
            @test contains(codecov_url, "pull_request=t_pr")
            @test contains(codecov_url, "job=t_job_id")
            @test contains(codecov_url, "slug=t_slug")
            @test contains(codecov_url, "build=t_job_num")

            # function argument url override
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
            @test contains(codecov_url, "enterprise-codecov-2.com")
            @test contains(codecov_url, "service=travis-org")
            @test contains(codecov_url, "branch=t_branch")
            @test contains(codecov_url, "commit=t_commit")
            @test contains(codecov_url, "pull_request=t_pr")
            @test contains(codecov_url, "job=t_job_id")
            @test contains(codecov_url, "slug=t_slug")
            @test contains(codecov_url, "build=t_job_num")

            # env var token
            withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test contains(codecov_url, "enterprise-codecov-1.com")
                @test contains(codecov_url, "token=token_name_1")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "job=t_job_id")
                @test contains(codecov_url, "slug=t_slug")
                @test contains(codecov_url, "build=t_job_num")

                # function argument token url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                @test contains(codecov_url, "enterprise-codecov-1.com")
                @test contains(codecov_url, "token=token_name_2")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "job=t_job_id")
                @test contains(codecov_url, "slug=t_slug")
                @test contains(codecov_url, "build=t_job_num")
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
            @test contains(codecov_url, "codecov.io")
            @test contains(codecov_url, "service=appveyor")
            @test contains(codecov_url, "branch=t_branch")
            @test contains(codecov_url, "commit=t_commit")
            @test contains(codecov_url, "pull_request=t_pr")
            @test contains(codecov_url, "job=t_account%2Ft_slug%2Ft_version")
            @test contains(codecov_url, "build=t_job_num")

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test contains(codecov_url, "enterprise-codecov-1.com")
                @test contains(codecov_url, "service=appveyor")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "job=t_account%2Ft_slug%2Ft_version")
                @test contains(codecov_url, "build=t_job_num")

                # function argument url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
                @test contains(codecov_url, "enterprise-codecov-2.com")
                @test contains(codecov_url, "service=appveyor")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "job=t_account%2Ft_slug%2Ft_version")
                @test contains(codecov_url, "build=t_job_num")

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                    @test contains(codecov_url, "enterprise-codecov-1.com")
                    @test contains(codecov_url, "token=token_name_1")
                    @test contains(codecov_url, "branch=t_branch")
                    @test contains(codecov_url, "commit=t_commit")
                    @test contains(codecov_url, "pull_request=t_pr")
                    @test contains(codecov_url, "job=t_account%2Ft_slug%2Ft_version")
                    @test contains(codecov_url, "build=t_job_num")

                    # function argument token url override
                    codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                    @test contains(codecov_url, "enterprise-codecov-1.com")
                    @test contains(codecov_url, "token=token_name_2")
                    @test contains(codecov_url, "branch=t_branch")
                    @test contains(codecov_url, "commit=t_commit")
                    @test contains(codecov_url, "pull_request=t_pr")
                    @test contains(codecov_url, "job=t_account%2Ft_slug%2Ft_version")
                    @test contains(codecov_url, "build=t_job_num")
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
        @test contains(codecov_url, "codecov.io")
        @test contains(codecov_url, "service=circleci")
        @test contains(codecov_url, "branch=t_branch")
        @test contains(codecov_url, "commit=t_commit")
        @test contains(codecov_url, "pull_request=t_pr")
        @test contains(codecov_url, "build_url=t_url")
        @test contains(codecov_url, "build=t_num")

        # env var url override
        withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
            @test contains(codecov_url, "enterprise-codecov-1.com")
            @test contains(codecov_url, "service=circleci")
            @test contains(codecov_url, "branch=t_branch")
            @test contains(codecov_url, "commit=t_commit")
            @test contains(codecov_url, "pull_request=t_pr")
            @test contains(codecov_url, "build_url=t_url")
            @test contains(codecov_url, "build=t_num")

            # function argument url override
            codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, codecov_url = "https://enterprise-codecov-2.com") )
            @test contains(codecov_url, "enterprise-codecov-2.com")
            @test contains(codecov_url, "service=circleci")
            @test contains(codecov_url, "branch=t_branch")
            @test contains(codecov_url, "commit=t_commit")
            @test contains(codecov_url, "pull_request=t_pr")
            @test contains(codecov_url, "build_url=t_url")
            @test contains(codecov_url, "build=t_num")

            # env var token
            withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true) )
                @test contains(codecov_url, "enterprise-codecov-1.com")
                @test contains(codecov_url, "token=token_name_1")
                @test contains(codecov_url, "service=circleci")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "build_url=t_url")
                @test contains(codecov_url, "build=t_num")

                # function argument token url override
                codecov_url = extract_codecov_url( () -> Coverage.Codecov.submit(fcs; dry_run = true, token="token_name_2") )
                @test contains(codecov_url, "enterprise-codecov-1.com")
                @test contains(codecov_url, "service=circleci")
                @test contains(codecov_url, "branch=t_branch")
                @test contains(codecov_url, "commit=t_commit")
                @test contains(codecov_url, "pull_request=t_pr")
                @test contains(codecov_url, "build_url=t_url")
                @test contains(codecov_url, "build=t_num")
            end
        end
    end
end
