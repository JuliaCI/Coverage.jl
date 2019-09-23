export Codecov

"""
Coverage.Codecov Module

This module provides functionality to push coverage information to the CodeCov.io
web service. It exports the `submit` and `submit_local` methods.
"""
module Codecov
    using HTTP
    using Coverage
    using JSON
    using LibGit2

    export submit, submit_token, submit_local, submit_generic

    #=
    JSON structure for Codecov.io
    https://codecov.io/api#post-report

    {
      "coverage": {
        "path/to/file.py": [null, 1, 0, null, true, 0, 0, 1, 1],
        "path/to/other.py": [null, 0, 1, 1, "1/3", null]
      },
      "messages": {
        "path/to/other.py": {
          "1": "custom message for line 1"
        }
      }
    }
    =#

    # Turn vector of filename : coverage pairs into a dictionary
    function to_json(fcs::Vector{FileCoverage})
        cov = Dict()
        for fc in fcs
            cov[fc.filename] = vcat(nothing, fc.coverage)
        end
        return Dict("coverage" => cov)
    end


    """
    kwargs provides default values to insert into args_array, only if they are
    not already specified in args_array.
    """
    function set_defaults(args_array; kwargs...)
        defined_names = keys(args_array)
        is_args_array = Pair{Symbol, Any}[]
        is_args_array = append!(is_args_array, args_array)
        for kwarg in kwargs
            if !(kwarg[1] in defined_names)
                push!(is_args_array, kwarg)
            end
        end
        return is_args_array
    end

    """
        submit(fcs::Vector{FileCoverage})

    Takes a vector of file coverage results (produced by `process_folder`),
    and submits them to Codecov.io. Assumes that this code is being run
    on TravisCI or AppVeyor. If running locally, use `submit_local`.
    """
    function submit(fcs::Vector{FileCoverage}; kwargs...)
        submit_generic(fcs; add_ci_to_kwargs(;kwargs...)...)
    end


    function add_ci_to_kwargs(;kwargs...)
        if lowercase(get(ENV, "APPVEYOR", "false")) == "true"
            appveyor_pr = get(ENV, "APPVEYOR_PULL_REQUEST_NUMBER", "")
            appveyor_job = join(
                [
                    ENV["APPVEYOR_ACCOUNT_NAME"],
                    ENV["APPVEYOR_PROJECT_SLUG"],
                    ENV["APPVEYOR_BUILD_VERSION"],
                ],
                "%2F",
            )
            kwargs = set_defaults(kwargs,
                service      = "appveyor",
                branch       = ENV["APPVEYOR_REPO_BRANCH"],
                commit       = ENV["APPVEYOR_REPO_COMMIT"],
                pull_request = appveyor_pr,
                job          = appveyor_job,
                slug         = ENV["APPVEYOR_REPO_NAME"],
                build        = ENV["APPVEYOR_JOB_ID"],
            )
        elseif lowercase(get(ENV, "TRAVIS", "false")) == "true"
            kwargs = set_defaults(kwargs,
                service      = "travis-org",
                branch       = ENV["TRAVIS_BRANCH"],
                commit       = ENV["TRAVIS_COMMIT"],
                pull_request = ENV["TRAVIS_PULL_REQUEST"],
                job          = ENV["TRAVIS_JOB_ID"],
                slug         = ENV["TRAVIS_REPO_SLUG"],
                build        = ENV["TRAVIS_JOB_NUMBER"],
            )
        elseif lowercase(get(ENV, "CIRCLECI", "false")) == "true"
            circle_slug = join(
                [
                    ENV["CIRCLE_PROJECT_USERNAME"],
                    ENV["CIRCLE_PROJECT_REPONAME"],
                ],
                "%2F",
            )
            kwargs = set_defaults(kwargs,
                service      = "circleci",
                branch       = ENV["CIRCLE_BRANCH"],
                commit       = ENV["CIRCLE_SHA1"],
                pull_request = get(ENV, "CIRCLE_PR_NUMBER", "false"),  # like Travis
                build_url    = ENV["CIRCLE_BUILD_URL"],
                slug         = circle_slug,
                build        = ENV["CIRCLE_BUILD_NUM"],
            )
        elseif lowercase(get(ENV, "JENKINS", "false")) == "true"
            kwargs = set_defaults(kwargs,
                service      = "jenkins",
                branch       = ENV["GIT_BRANCH"],
                commit       = ENV["GIT_COMMIT"],
                job          = ENV["JOB_NAME"],
                build        = ENV["BUILD_ID"],
                build_url    = ENV["BUILD_URL"],
                jenkins_url  = ENV["JENKINS_URL"],
            )
        elseif haskey(ENV, "BUILD_BUILDURI") # Azure Pipelines
            ref = get(ENV, "SYSTEM_PULLREQUEST_TARGETBRANCH", ENV["BUILD_SOURCEBRANCHNAME"])
            branch = startswith(ref, "refs/heads/") ? ref[12:end] : ref
            kwargs = set_defaults(kwargs,
                service      = "azure_pipelines",
                branch       = branch,
                commit       = ENV["BUILD_SOURCEVERSION"],
                pull_request = get(ENV, "SYSTEM_PULLREQUEST_PULLREQUESTNUMBER", ""),
                job          = ENV["BUILD_DEFINITIONNAME"],
                slug         = ENV["BUILD_REPOSITORY_NAME"],
                build        = ENV["BUILD_BUILDID"],
            )
        elseif haskey(ENV, "GITHUB_ACTION") # GitHub Actions
            kwargs = set_defaults(kwargs,
                service      = "custom",
                commit       = ENV["GITHUB_SHA"],
                slug         = ENV["GITHUB_REPOSITORY"],
            )
        else
            error("No compatible CI platform detected")
        end

        return kwargs
    end

    """
        submit_local(fcs::Vector{FileCoverage}, dir::AbstractString=pwd())

    Take a `Vector` of file coverage results (produced by `process_folder`),
    and submit them to Codecov.io. Assumes the submission is being made from
    a local git installation, rooted at `dir`. A repository token should be specified by a
    `token` keyword argument or the `CODECOV_TOKEN` environment variable.
    """
    function submit_local(fcs::Vector{FileCoverage}, dir::AbstractString=pwd(); kwargs...)
        submit_generic(fcs; add_local_to_kwargs(dir; kwargs...)...)
    end

    function add_local_to_kwargs(dir; kwargs...)
        LibGit2.with(LibGit2.GitRepoExt(dir)) do repo
            LibGit2.with(LibGit2.head(repo)) do headref
                branch_name = LibGit2.shortname(headref) # this function returns a String
                commit_oid  = LibGit2.GitHash(LibGit2.peel(headref))
                kwargs = set_defaults(kwargs,
                    commit = string(commit_oid),
                    branch = branch_name
                    )
            end
        end

        if haskey(ENV, "REPO_TOKEN")
            @warn "the environment variable REPO_TOKEN is deprecated, use CODECOV_TOKEN instead"
            kwargs = set_defaults(kwargs, token = ENV["REPO_TOKEN"])
        end

        return kwargs
    end

    @deprecate submit_token submit_local


    """
        submit_generic(fcs::Vector{FileCoverage})

    Takes a vector of file coverage results (produced by `process_folder`),
    and submits them to a Codecov.io instance. Keyword arguments are converted
    into a generic Codecov.io API uri.  It is essential that the keywords and
    values match the Codecov upload/v2 API specification.
    The `codecov_url` keyword argument or the CODECOV_URL environment variable
    can be used to specify the base path of the uri.
    The `dry_run` keyword can be used to prevent the http request from
    being generated.
    """
    function submit_generic(fcs::Vector{FileCoverage}; kwargs...)
        @assert length(kwargs) > 0
        dry_run = get(kwargs, :dry_run, false)
        if haskey(kwargs, :verbose)
            Base.depwarn("The verbose keyword argument is deprecated, set the environment variable " *
                         "JULIA_DEBUG=Coverage for verbose output", :submit_generic)
            verbose = kwargs[:verbose]
        else
            verbose = false
        end
        uri_str = construct_uri_string(;kwargs...)

        verbose && @info "Submitting data to Codecov..."
        verbose && @debug "Codecov.io API URL:\n" * mask_token(uri_str)

        if !dry_run
            heads   = Dict("Content-Type" => "application/json")
            data    = to_json(fcs)
            req     = HTTP.post(uri_str; body = JSON.json(data), headers = heads)
            @debug "Result of submission:" * String(req)
        end
    end

    function construct_uri_string(;kwargs...)
        if haskey(ENV, "CODECOV_URL")
            kwargs = set_defaults(kwargs, codecov_url = ENV["CODECOV_URL"])
        end

        if haskey(ENV, "CODECOV_TOKEN")
            kwargs = set_defaults(kwargs, token = ENV["CODECOV_TOKEN"])
        end

        codecov_url = "https://codecov.io"
        for (k,v) in kwargs
            if k == :codecov_url
                codecov_url = v
            end
        end
        @assert codecov_url[end] != "/" "the codecov_url should not end with a /, given url $(codecov_url)"

        uri_str = "$(codecov_url)/upload/v2?"
        for (k,v) in kwargs
            # add all except a few special key/value pairs to the URL
            # (:verbose is there for backwards compatibility with versions
            # of this code that treated it in a special way)
            if k != :codecov_url && k != :dry_run && k != :verbose
                uri_str = "$(uri_str)&$(k)=$(v)"
            end
        end

        return uri_str
    end

    function mask_token(uri_string)
        return replace(uri_string, r"token=[^&]*" => "token=<HIDDEN>")
    end

end  # module Codecov
