#######################################################################
# Coverage.jl
# Take Julia test coverage results and send them to various renderers
# https://github.com/JuliaCI/Coverage.jl
#######################################################################

using Coverage, Test, LibGit2

import CoverageTools

@testset "Coverage" begin
# set up base system ENV vars for testing
withenv(
    "DISABLE_AMEND_COVERAGE_FROM_SRC" => nothing,
    "COVERALLS_TOKEN" => "token_name_1",
    "COVERALLS_URL" => nothing,
    "CODECOV_URL" => nothing,
    "CODECOV_URL_PATH" => nothing,
    "CODECOV_TOKEN" => nothing,
    "CODECOV_NAME" => nothing,
    "CODECOV_FLAGS" => nothing,
    "TRAVIS" => nothing,
    "TRAVIS_BRANCH" => nothing,
    "TRAVIS_COMMIT" => nothing,
    "TRAVIS_PULL_REQUEST" => nothing,
    "TRAVIS_BUILD_NUMBER" => nothing,
    "TRAVIS_JOB_ID" => nothing,
    "TRAVIS_JOB_NUMBER" => nothing,
    "TRAVIS_REPO_SLUG" => nothing,
    "APPVEYOR" => nothing,
    "APPVEYOR_PULL_REQUEST_NUMBER" => nothing,
    "APPVEYOR_ACCOUNT_NAME" => nothing,
    "APPVEYOR_PROJECT_SLUG" => nothing,
    "APPVEYOR_BUILD_VERSION" => nothing,
    "APPVEYOR_REPO_BRANCH" => nothing,
    "APPVEYOR_REPO_COMMIT" => nothing,
    "APPVEYOR_REPO_NAME" => nothing,
    "APPVEYOR_BUILD_NUMBER" => nothing,
    "APPVEYOR_BUILD_ID" => nothing,
    "APPVEYOR_JOB_ID" => nothing,
    "GITHUB_ACTION" => nothing,
    "GITHUB_EVENT_PATH" => nothing,
    "GITHUB_HEAD_REF" => nothing,
    "GITHUB_REF" => nothing,
    "GITHUB_REPOSITORY" => nothing,
    "GITHUB_RUN_ID" => nothing,
    "GITHUB_SHA" => nothing,
    "service_job_id" => nothing,
    "JENKINS" => nothing,
    "BUILD_ID" => nothing,
    "CI_PULL_REQUEST" => nothing,
    "GIT_BRANCH" => nothing
    ) do

    @testset "codecovio.jl" begin
        # these methods are only used for testing the token generation for local repos
        # and CI whilst not breaking the current API
        construct_uri_string_local(dir=pwd(); kwargs...) = Coverage.Codecov.construct_uri_string(
            Coverage.Codecov.add_local_to_kwargs(dir; kwargs...))

        construct_uri_string_ci(; kwargs...) = Coverage.Codecov.construct_uri_string(
            Coverage.Codecov.add_ci_to_kwargs(; kwargs...))

        # empty file coverage for testing
        fcs = FileCoverage[]

        # test local submission process (but only if we are in a git repo)
        _dotgit = joinpath(dirname(@__DIR__), ".git")
        if isdir(_dotgit) || isfile(_dotgit)
            LibGit2.with(LibGit2.GitRepoExt(pwd())) do repo
                # default values
                codecov_url = construct_uri_string_local()
                @test occursin("codecov.io", codecov_url)
                @test occursin("commit=", codecov_url)
                @test occursin("branch=", codecov_url)
                @test !occursin("service", codecov_url)

                # env var url override
                withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                    codecov_url = construct_uri_string_local()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("commit=", codecov_url)
                    @test occursin("branch=", codecov_url)
                    @test !occursin("service", codecov_url)

                    # function argument url override
                    codecov_url = construct_uri_string_local(codecov_url = "https://enterprise-codecov-2.com")
                    @test occursin("enterprise-codecov-2.com", codecov_url)
                    @test occursin("commit=", codecov_url)
                    @test occursin("branch=", codecov_url)
                    @test !occursin("service", codecov_url)
                    @test !occursin("name", codecov_url)
                    @test !occursin("flags", codecov_url)

                    # env var token
                    withenv( "CODECOV_TOKEN" => "token_name_1",
                             "CODECOV_NAME" => "cv_name",
                             "CODECOV_FLAGS" => "cv_flags" ) do

                        codecov_url = construct_uri_string_local()
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_1", codecov_url)
                        @test occursin("name=cv_name", codecov_url)
                        @test occursin("flags=cv_flags", codecov_url)
                        @test !occursin("service", codecov_url)

                        # function argument token url override
                        codecov_url = construct_uri_string_local(token="token_name_2")
                        @test occursin("enterprise-codecov-1.com", codecov_url)
                        @test occursin("token=token_name_2", codecov_url)
                        @test !occursin("service", codecov_url)
                    end
                end
            end
        else
            @warn "skipping local repo tests for Codecov, since not a git repo"
        end

        # test faulty non-CI submission

        @test_throws(ErrorException("No compatible CI platform detected"),
                     Coverage.Codecov.submit(fcs; dry_run = true))

        # test travis-ci submission process

        # set up travis env
        withenv(
            "TRAVIS" => "true",
            "TRAVIS_BRANCH" => "t_branch",
            "TRAVIS_COMMIT" => "t_commit",
            "TRAVIS_PULL_REQUEST" => "t_pr",
            "TRAVIS_BUILD_NUMBER" => "t_build_num",
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
            "APPVEYOR_BUILD_ID" => "t_build_id",
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

        # test Buildkite ci submission process

        # set up Buildkite ci env
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "t_branch",
            "BUILDKITE_COMMIT" => "t_commit",
            "BUILDKITE_JOB_ID" => "t_job",
            "BUILDKITE_BUILD_NUMBER" => "t_num",
            "BUILDKITE_BUILD_URL" => "t_url",
            "BUILDKITE_PULL_REQUEST" => "t_pr",
            ) do

            # default values
            codecov_url = construct_uri_string_ci()
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=buildkite", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("build_url=t_url", codecov_url)
            @test occursin("build=t_num", codecov_url)
            @test occursin("pr=t_pr", codecov_url)

            # without PR
            withenv("BUILDKITE_PULL_REQUEST" => "false") do
                codecov_url = construct_uri_string_ci()
                @test !occursin("pr", codecov_url)
            end

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = construct_uri_string_ci()
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=buildkite", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # function argument url override
                codecov_url = construct_uri_string_ci(codecov_url="https://enterprise-codecov-2.com")
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=buildkite", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # env var token
                withenv( "CODECOV_TOKEN" => "token_name_1" ) do

                    codecov_url = construct_uri_string_ci()
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("token=token_name_1", codecov_url)
                    @test occursin("service=buildkite", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)

                    # function argument token url override
                    codecov_url = construct_uri_string_ci(token="token_name_2")
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=buildkite", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)
                end
            end
        end

        # test Gitlab ci submission process

        # set up Gitlab ci env
        withenv(
            "GITLAB_CI" => "true",
            "CI_MERGE_REQUEST_IID" => "t_pr",
            "CI_JOB_ID" => "t_proj",
            "CI_COMMIT_BRANCH" => "t_branch",
            "CI_COMMIT_SHA" => "t_commit",
            "CI_PROJECT_NAME" => "t_repo",
            "CI_PIPELINE_URL" => "t_url",
            "CI_PIPELINE_IID" => "t_num",
            "CI_DEFAULT_BRANCH" => "master",
            ) do

            # default values
            codecov_url = construct_uri_string_ci()
            @test occursin("codecov.io", codecov_url)
            @test occursin("service=gitlab", codecov_url)
            @test occursin("branch=t_branch", codecov_url)
            @test occursin("commit=t_commit", codecov_url)
            @test occursin("pull_request=t_pr", codecov_url)
            @test occursin("build_url=t_url", codecov_url)
            @test occursin("build=t_num", codecov_url)

            # env var url override
            withenv( "CODECOV_URL" => "https://enterprise-codecov-1.com" ) do

                codecov_url = construct_uri_string_ci()
                @test occursin("enterprise-codecov-1.com", codecov_url)
                @test occursin("service=gitlab", codecov_url)
                @test occursin("branch=t_branch", codecov_url)
                @test occursin("commit=t_commit", codecov_url)
                @test occursin("pull_request=t_pr", codecov_url)
                @test occursin("build_url=t_url", codecov_url)
                @test occursin("build=t_num", codecov_url)

                # function argument url override
                codecov_url = construct_uri_string_ci(codecov_url="https://enterprise-codecov-2.com")
                @test occursin("enterprise-codecov-2.com", codecov_url)
                @test occursin("service=gitlab", codecov_url)
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
                    @test occursin("service=gitlab", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
                    @test occursin("build_url=t_url", codecov_url)
                    @test occursin("build=t_num", codecov_url)

                    # function argument token url override
                    codecov_url = construct_uri_string_ci(token="token_name_2")
                    @test occursin("enterprise-codecov-1.com", codecov_url)
                    @test occursin("service=gitlab", codecov_url)
                    @test occursin("branch=t_branch", codecov_url)
                    @test occursin("commit=t_commit", codecov_url)
                    @test occursin("pull_request=t_pr", codecov_url)
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
            "APPVEYOR_BUILD_ID" => "t_build_id",
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
        url = "https://enterprise-codecov-1.com/upload/v4?token=token_name_1&build=t_job_num"
        masked = Coverage.Codecov.mask_token(url)
        @test masked == "https://enterprise-codecov-1.com/upload/v4?token=<HIDDEN>&build=t_job_num"

        @testset "Run the `Coverage.Codecov.upload_to_s3` function against the \"black hole\" server" begin
            black_hole_server = get(
                ENV,
                "JULIA_COVERAGE_BLACK_HOLE_SERVER_URL_PUT",
                "https://httpbingo.julialang.org/put",
            )
            s3url = black_hole_server
            fcs = Vector{CoverageTools.FileCoverage}(undef, 0)
            Coverage.Codecov.upload_to_s3(; s3url=s3url, fcs=fcs)
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
                "APPVEYOR_BUILD_NUMBER" => "my_job_num",
                "APPVEYOR_BUILD_ID" => "my_build_id",
                "APPVEYOR_JOB_ID" => "my_job_id") do
            @test_throws(ErrorException("Coveralls submission requires a COVERALLS_TOKEN environment variable"),
                         Coverage.Coveralls.prepare_request(fcs, false))
        end

        # test error if not local and no CI platform can be detected from ENV
        @test_throws(ErrorException("No compatible CI platform detected"),
                     Coverage.Coveralls.prepare_request(fcs, false))

        # test local submission, when we are local
        _dotgit = joinpath(dirname(@__DIR__), ".git")
        if isdir(_dotgit) || isfile(_dotgit)
            request = Coverage.Coveralls.prepare_request(fcs, true)
            @test request["repo_token"] == "token_name_1"
            @test isempty(request["source_files"])
            @test haskey(request, "git")
            @test request["git"]["remotes"][1]["name"] == "origin"
            @test !haskey(request, "service_job_id")
            @test request["service_name"] == "local"
            @test !haskey(request, "service_pull_request")
        else
            @warn "skipping local repo tests for Coveralls, since not a git repo"
        end

        # test custom (environment variables)
        withenv("COVERALLS_SERVICE_NAME" => "My CI",
                "COVERALLS_PULL_REQUEST" => "c_pr",
                "COVERALLS_SERVICE_NUMBER" => "ci_num",
                "COVERALLS_SERVICE_JOB_NUMBER" => "ci_job_num",
                "COVERALLS_SERVICE_JOB_ID" => "ci_job_id",
                "COVERALLS_FLAG_NAME" => "t_pr") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_number"] == "ci_num"
                @test request["service_job_number"] == "ci_job_num"
                @test request["service_job_id"] == "ci_job_id"
                @test request["service_name"] == "My CI"
                @test request["service_pull_request"] == "c_pr"
        end


        # test APPVEYOR
        withenv("APPVEYOR" => "true",
                "APPVEYOR_PULL_REQUEST_NUMBER" => "t_pr",
                "APPVEYOR_BUILD_NUMBER" => "my_build_num",
                "APPVEYOR_BUILD_ID" => "my_build_id") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_job_number"] == "my_build_num"
                @test request["service_job_id"] == "my_build_id"
                @test request["service_name"] == "appveyor"
                @test request["service_pull_request"] == "t_pr"
                @test !haskey(request, "parallel")
        end

        # test Travis
        withenv("TRAVIS" => "true",
                "TRAVIS_BUILD_NUMBER" => "my_job_num",
                "TRAVIS_JOB_ID" => "my_job_id",
                "TRAVIS_PULL_REQUEST" => "t_pr",
                "COVERALLS_PARALLEL" => "true") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_number"] == "my_job_num"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "travis-ci"
                @test request["service_pull_request"] == "t_pr"
                @test request["parallel"] == "true"
        end

        # test Jenkins
        withenv("JENKINS" => "true",
                "BUILD_ID" => "my_job_id",
                "CI_PULL_REQUEST" => true,
                "COVERALLS_PARALLEL" => "not") do
                my_git_info = Dict("remote_name" => "my_origin")
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "jenkins-ci"
                @test !haskey(request, "service_pull_request")
                @test !haskey(request, "parallel")

                withenv("CI_PULL_REQUEST" => "false",
                        "GIT_BRANCH" => "my_remote/my_branch",
                        "COVERALLS_SERVICE_NUMBER" => "ci_num",
                        "COVERALLS_SERVICE_JOB_NUMBER" => "ci_job_num",
                        "COVERALLS_SERVICE_JOB_ID" => "ci_job_id"
                       ) do
                        request = Coverage.Coveralls.prepare_request(fcs, false)
                        @test haskey(request, "git")
                        @test request["git"]["branch"] == "my_branch"
                        @test request["service_number"] == "ci_num"
                        @test request["service_job_number"] == "ci_job_num"
                        @test request["service_job_id"] == "ci_job_id"
                end
        end

        # test Gitlab see https://docs.coveralls.io/api-reference
        withenv("GITLAB_CI" => "true",
                "CI_PIPELINE_IID" => "my_job_num",
                "CI_JOB_ID" => "my_job_id",
                "CI_COMMIT_BRANCH" => "test",
                "CI_DEFAULT_BRANCH" => "master",
                "CI_MERGE_REQUEST_IID" => "t_pr") do
                request = Coverage.Coveralls.prepare_request(fcs, false)
                @test request["repo_token"] == "token_name_1"
                @test request["service_number"] == "my_job_num"
                @test request["service_job_id"] == "my_job_id"
                @test request["service_name"] == "gitlab"
                @test request["service_pull_request"] == "t_pr"
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

end # of withenv( => nothing)

end # of @testset "Coverage"
