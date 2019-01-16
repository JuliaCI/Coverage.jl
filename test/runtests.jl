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
        r = process_file(joinpath(datadir, "Coverage.jl"))
        # ... and memory data
        analyze_malloc(datadir)
        lcov = IOBuffer()
        # we only have a single file, but we want to test on the Vector of file results
        LCOV.write(lcov, FileCoverage[r])
        expected = read(joinpath(datadir, "tracefiles", "expected.info"), String)
        if Sys.iswindows()
            expected = replace(expected, "\r\n" => "\n")
            expected = replace(expected, "SF:test/data/Coverage.jl\n" => "SF:test\\data\\Coverage.jl\n")
        end
        @test String(take!(lcov)) == expected
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
        cmdstr = "include(\"$(escape_string(srcname))\"); using Test; @test f2(2) == 4"
        run(`$(Base.julia_cmd()) --startup-file=no --code-coverage=user -e $cmdstr`)
        r = process_file(srcname, datadir)

        target = Union{Int64,Nothing}[nothing, 2, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing]
        @test r.coverage == target

        covtarget = (sum(x->x != nothing && x > 0, target), sum(x->x != nothing, target))
        @test get_summary(r) == covtarget
        @test get_summary(process_folder(datadir)) != covtarget

        # Handle an empty coverage vector
        emptycov = FileCoverage("", "", [])
        @test get_summary(emptycov) == (0, 0)

        #json_data = Codecov.build_json_data(Codecov.process_folder("data"))
        #@test typeof(json_data["coverage"]["data/Coverage.jl"]) == Array{Union{Int64,Nothing},1}
        close(open("fakefile", read=true, write=true, create=true, truncate=false, append=false))
        @test isempty(Coverage.process_cov("fakefile", datadir))
        rm("fakefile")
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
    end
end


@testset "coveralls" begin
    # NOTE: this only returns actual content if this package is devved.
    # Hence the test is basically on this function returning something
    # (rather than erroring)
    git = Coverage.Coveralls.query_git_info()
    @test git["remotes"][1]["name"] == "origin"
    @test haskey(git["remotes"][1], "url")
end

end
