#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/JuliaCI/Coverage.jl
#######################################################################

using Coverage, Test, LibGit2

if VERSION < v"1.1"
isnothing(x) = false
isnothing(x::Nothing) = true
end

@testset "Coverage" begin
withenv("DISABLE_AMEND_COVERAGE_FROM_SRC" => nothing) do

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
    @test Coverage.isfuncexpr(:(f() = x))
    @test Coverage.isfuncexpr(:(function() end))
    @test Coverage.isfuncexpr(:(function g() end))
    @test Coverage.isfuncexpr(:(function g() where {T} end))
    @test !Coverage.isfuncexpr("2")
    @test !Coverage.isfuncexpr(:(f = x))
    @test Coverage.isfuncexpr(:(() -> x))
    @test Coverage.isfuncexpr(:(x -> x))
    @test Coverage.isfuncexpr(:(f() where A = x))
    @test Coverage.isfuncexpr(:(f() where A where B = x))
end

@testset "Processing coverage" begin
    cd(dirname(@__DIR__)) do
        datadir = joinpath("test", "data")
        # Process a saved set of coverage data...
        r = process_file(joinpath(datadir, "Coverage.jl"))

        # ... and memory data
        malloc_results = analyze_malloc(datadir)
        filename = joinpath(datadir, "testparser.jl.9172.mem")
        @test malloc_results == [Coverage.MallocInfo(96669, filename, 2)]

        lcov = IOBuffer()
        # we only have a single file, but we want to test on the Vector of file results
        LCOV.write(lcov, FileCoverage[r])
        expected = read(joinpath(datadir, "tracefiles", "expected.info"), String)
        if Sys.iswindows()
            expected = replace(expected, "\r\n" => "\n")
            expected = replace(expected, "SF:test/data/Coverage.jl\n" => "SF:test\\data\\Coverage.jl\n")
        end
        @test String(take!(lcov)) == expected

        # LCOV.writefile is a short-hand for writing to a file
        lcov = joinpath(datadir, "lcov_output_temp.info")
        LCOV.writefile(lcov, FileCoverage[r])
        expected = read(joinpath(datadir, "tracefiles", "expected.info"), String)
        if Sys.iswindows()
            expected = replace(expected, "\r\n" => "\n")
            expected = replace(expected, "SF:test/data/Coverage.jl\n" => "SF:test\\data\\Coverage.jl\n")
        end
        @test String(read(lcov)) == expected
        # tear down test file
        rm(lcov)

        # test that reading the LCOV file gives the same data
        lcov = LCOV.readfolder(datadir)
        @test length(lcov) == 1
        r2 = lcov[1]
        r2_filename = r2.filename
        if Sys.iswindows()
            r2_filename = replace(r2_filename, '/' => '\\')
        end
        @test r2_filename == r.filename
        @test r2.source == ""
        @test r2.coverage == r.coverage[1:length(r2.coverage)]
        @test all(isnothing, r.coverage[(length(r2.coverage) + 1):end])
        lcov2 = [FileCoverage(r2.filename, "sourcecode", Coverage.CovCount[nothing, 1, 0, nothing, 3]),
                 FileCoverage("file2.jl", "moresource2", Coverage.CovCount[1, nothing, 0, nothing, 2]),]
        lcov = merge_coverage_counts(lcov, lcov2, lcov)
        @test length(lcov) == 2
        r3 = lcov[1]
        @test r3.filename == r2.filename
        @test r3.source == "sourcecode"
        r3cov = Coverage.CovCount[x === nothing ? nothing : x * 2 for x in r2.coverage]
        r3cov[2] += 1
        r3cov[3] = 0
        r3cov[5] = 3
        @test r3.coverage == r3cov
        r4 = lcov[2]
        @test r4.filename == "file2.jl"
        @test r4.source == "moresource2"
        @test r4.coverage == lcov2[2].coverage

        # Test a file from scratch
        srcname = joinpath("test", "data", "testparser.jl")
        covname = srcname*".cov"
        # clean out any previous coverage files. Don't use clean_folder because we
        # need to preserve the pre-baked coverage file Coverage.jl.cov
        clean_file(srcname)
        cmdstr = "include($(repr(srcname))); using Test; @test f2(2) == 4"
        run(`$(Base.julia_cmd()) --startup-file=no --code-coverage=user -e $cmdstr`)
        r = process_file(srcname, datadir)

        target = Coverage.CovCount[nothing, 2, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing]
        target_disabled = map(x -> (x !== nothing && x > 0) ? x : nothing, target)
        @test r.coverage == target

        covtarget = (sum(x->x !== nothing && x > 0, target), sum(x->x !== nothing, target))
        @test get_summary(r) == covtarget
        @test get_summary(process_folder(datadir)) == (98, 106)

        r_disabled = withenv("DISABLE_AMEND_COVERAGE_FROM_SRC" => "yes") do
            process_file(srcname, datadir)
        end

        @test r_disabled.coverage == target_disabled
        amend_coverage_from_src!(r_disabled.coverage, r_disabled.filename)
        @test r_disabled.coverage == target

        # Handle an empty coverage vector
        emptycov = FileCoverage("", "", [])
        @test get_summary(emptycov) == (0, 0)

        @test isempty(Coverage.process_cov(joinpath("test", "fakefile"), datadir))

        # test clean_folder
        # set up the test folder
        datadir_temp = joinpath("test", "data_temp")
        cp(datadir, datadir_temp)
        # run clean_folder
        clean_folder(datadir_temp)
        # .cov files should be deleted
        @test !isfile(joinpath(datadir_temp, "Coverage.jl.cov"))
        # other files should remain untouched
        @test isfile(joinpath(datadir_temp, "Coverage.jl"))
        # tear down test data
        rm(datadir_temp; recursive=true)
    end
end

@testset "codecovio.jl" begin
    # these methods are only used for testing the token generation for local repos
    # and CI whilst not breaking the current API
    construct_uri_string_local(dir=pwd(); kwargs...) = Coverage.Codecov.construct_uri_string(
        ;Coverage.Codecov.add_local_to_kwargs(dir; kwargs...)...)

    construct_uri_string_ci(;kwargs...) = Coverage.Codecov.construct_uri_string(
        ;Coverage.Codecov.add_ci_to_kwargs(;kwargs...)...)

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

        # test local submission process (but only if we are in a git repo)

        _dotgit = joinpath(dirname(@__DIR__), ".git")

        if isdir(_dotgit) || isfile(_dotgit)
            LibGit2.with(LibGit2.GitRepoExt(pwd())) do repo
                # default values
                codecov_url = construct_uri_string_local()
                @test occursin("codecov.io", codecov_url)
                @test occursin("commit", codecov_url)
                @test occursin("branch", codecov_url)
                @test !occursin("service", codecov_url)

                # env var url override
                withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                    codecov_url = construct_uri_string_local()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("commit", codecov_url)
                    @test occursin("branch", codecov_url)
                    @test !occursin("service", codecov_url)

                    # function argument url override
                    codecov_url = construct_uri_string_local(codecov_url = "https://enterprise-codecov-2.com")
                    @test occursin("enterprise-codecov-2.com", codecov_url)
                    @test occursin("commit", codecov_url)
                    @test occursin("branch", codecov_url)
                    @test !occursin("service", codecov_url)

                    # env var token
                    withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                        codecov_url = construct_uri_string_local()
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_1", codecov_url)
                        @test !occursin("service", codecov_url)

                        # function argument token url override
                        codecov_url = construct_uri_string_local(token="token_name_2")
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_2", codecov_url)
                        @test !occursin("service", codecov_url)
                    end
                end
            end
        end

        # test faulty non-CI submission

        @test_throws ErrorException Coverage.Codecov.submit(fcs; dry_run = true)

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
            codecov_url = construct_uri_string_ci()
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

                codecov_url = construct_uri_string_ci()
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=travis-org", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("job=t_job_id", codecov_url)
                @test occursin("slug=t_slug", codecov_url)
                @test occursin("build=t_job_num", codecov_url)

                # function argument url override
                codecov_url = construct_uri_string_ci(;codecov_url = "https://enterprise-codecov-2.com")
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

                    codecov_url = construct_uri_string_ci()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_job_id", codecov_url)
                    @test occursin("slug=t_slug", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # function argument token url override
                    codecov_url = construct_uri_string_ci(token="token_name_2")
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
                codecov_url = construct_uri_string_ci()
                @test occursin("codecov.io", codecov_url)
                @test occursin("service=appveyor", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                @test occursin("build=t_job_num", codecov_url)

                # env var url override
                withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                    codecov_url = construct_uri_string_ci()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=appveyor", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # function argument url override
                    codecov_url = construct_uri_string_ci(codecov_url = "https://enterprise-codecov-2.com")
                    @test occursin("enterprise-codecov-2.com", codecov_url)
                    @test occursin("service=appveyor", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                    @test occursin("build=t_job_num", codecov_url)

                    # env var token
                    withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                        codecov_url = construct_uri_string_ci()
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_1", codecov_url)
                        @test occursin("branch=t_branch", codecov_url)
                        @test occursin("commit=t_commit", codecov_url)
                        @test occursin("pull_request=t_pr", codecov_url)
                        @test occursin("job=t_account%2Ft_slug%2Ft_version", codecov_url)
                        @test occursin("build=t_job_num", codecov_url)

                        # function argument token url override
                        codecov_url = construct_uri_string_ci(token="token_name_2")
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
            codecov_url = construct_uri_string_ci()
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=circleci", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("pull_request=t_pr", codecov_url)
            @test occursin("build_url=t_url", codecov_url)
            @test occursin("build=t_num", codecov_url)

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = construct_uri_string_ci()
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=circleci", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # function argument url override
                codecov_url = construct_uri_string_ci(codecov_url="https://enterprise-codecov-2.com")
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=circleci", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = construct_uri_string_ci()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("service=circleci", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)

                    # function argument token url override
                    codecov_url = construct_uri_string_ci(token="token_name_2")
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

        # test Jenkins ci submission process

        # set up Jenkins ci env
        withenv(
            "JENKINS" => "true",
            "GIT_BRANCH" => "t_branch",
            "GIT_COMMIT" => "t_commit",
            "JOB_NAME" => "t_job",
            "BUILD_ID" => "t_num",
            "BUILD_URL" => "t_url",
            "JENKINS_URL" => "t_jenkins_url",
            ) do

            # default values
            codecov_url = construct_uri_string_ci()
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=jenkins", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("build_url=t_url", codecov_url)
            @test occursin("build=t_num", codecov_url)

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = construct_uri_string_ci()
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=jenkins", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # function argument url override
                codecov_url = construct_uri_string_ci(codecov_url="https://enterprise-codecov-2.com")
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=jenkins", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = construct_uri_string_ci()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("service=jenkins", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)

                    # function argument token url override
                    codecov_url = construct_uri_string_ci(token="token_name_2")
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=jenkins", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)
                end
            end
        end

        # test codecov token masking
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
            "CODECOV_URL" => "https://enterprise-codecov-1.com",
            "CODECOV_TOKEN" => "token_name_1"
            ) do
                codecov_url = construct_uri_string_ci()
                masked = Coverage.Codecov.mask_token(codecov_url)
                @test !occursin("token_name_1", masked)
                @test occursin("token=<HIDDEN>", masked)
        end

        # in the case above, the token is at the end. Let's test explicitly,
        # that this also works if the token occurs earlier in the url
        url = "https://enterprise-codecov-1.com/upload/v2?token=token_name_1&build=t_job_num"
        masked = Coverage.Codecov.mask_token(url)
        @test masked == "https://enterprise-codecov-1.com/upload/v2?token=<HIDDEN>&build=t_job_num"
    end
end


@testset "coveralls" begin
    # NOTE: this only returns actual content if this package is devved.
    # Hence the test is basically on this function returning something
    # (rather than erroring)
    git = Coverage.Coveralls.query_git_info()
    @test git["remotes"][1]["name"] == "origin"
    @test haskey(git["remotes"][1], "url")

    # for testing submit_***()
    fcs = FileCoverage[]

    # an error should be raised if there is no coveralls token set
    withenv("COVERALLS_TOKEN" => nothing,
            "REPO_TOKEN" => nothing,  # this is deprecrated, use COVERALLS_TOKEN
            "APPVEYOR" => "true",  # use APPVEYOR as an example to make the test reach the repo token check
            "APPVEYOR_JOB_ID" => "my_job_id") do
            @test_throws ErrorException Coverage.Coveralls.prepare_request(fcs, false)
    end

    withenv("COVERALLS_TOKEN" => "token_name_1",
            "APPVEYOR" => nothing,
            "APPVEYOR_JOB_ID" => nothing,
            "TRAVIS" => nothing,
            "TRAVIS_JOB_ID" => nothing,
            "JENKINS" => nothing,
            "BUILD_ID" => nothing,
            "CI_PULL_REQUEST" => nothing,
            "GIT_BRANCH" => nothing) do

        # test error if not local and no CI platform can be detected from ENV
        @test_throws ErrorException Coverage.Coveralls.prepare_request(fcs, false)

        # test local submission, when we are local
        _dotgit = joinpath(dirname(@__DIR__), ".git")
        if isdir(_dotgit) || isfile(_dotgit)
                request = Coverage.Coveralls.prepare_request(fcs, true)
                @test request["repo_token"] == "token_name_1"
                @test isempty(request["source_files"])
                @test haskey(request, "git")
                @test request["git"]["remotes"][1]["name"] == "origin"
        end

        # test APPVEYOR
        withenv("APPVEYOR" => "true",
                "APPVEYOR_JOB_ID" => "my_job_id") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "appveyor"
        end

        # test Travis
        withenv("TRAVIS" => "true",
                "TRAVIS_JOB_ID" => "my_job_id") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "travis-ci"
        end

        # test Jenkins
        withenv("JENKINS" => "true",
                "BUILD_ID" => "my_job_id",
                "CI_PULL_REQUEST" => true) do
                my_git_info = Dict("remote_name" => "my_origin")
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "jenkins-ci"

                withenv("CI_PULL_REQUEST" => "false",
                        "GIT_BRANCH" => "my_remote/my_branch") do
                        request = Coverage.Coveralls.prepare_request(fcs, false)
                        @test haskey(request, "git")
                        @test request["git"]["branch"] == "my_branch"
                end
        end

        # test git_info (only works with Jenkins & local at the moment)
        withenv("JENKINS" => "true",
                "BUILD_ID" => "my_job_id",
                "CI_PULL_REQUEST" => true) do
                # we can pass in our own function, that returns a dict
                my_git_info() = Dict("test" => "test")
                request = Coverage.Coveralls.prepare_request(fcs, false, my_git_info)
                @test haskey(request, "git")

                # or directly a dict
                request = Coverage.Coveralls.prepare_request(fcs, false, Dict("test" => "test"))
                @test haskey(request, "git")
            end
    end
end

end # of withenv("DISABLE_AMEND_COVERAGE_FROM_SRC" => nothing)

end # of @testset "Coverage"
