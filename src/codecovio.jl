export Codecov

"""
Coverage.Codecov Module

This module provides functionality to push coverage information to the CodeCov.io
web service. It exports the `submit` and `submit_local` methods.
"""
module Codecov

using HTTP
using Coverage
using CoverageTools
using JSON
using LibGit2

export submit, submit_local, submit_generic

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
function set_defaults(args_array::Dict; kwargs...)
    args_array = copy(args_array)
    for kwarg in kwargs
        if !haskey(args_array, kwarg[1])
            push!(args_array, kwarg)
        end
    end
    return args_array
end

"""
    submit(fcs::Vector{FileCoverage})

Takes a vector of file coverage results (produced by `process_folder`),
and submits them to Codecov.io. Assumes that this code is being run
on TravisCI or AppVeyor. If running locally, use `submit_local`.
"""
function submit(fcs::Vector{FileCoverage}; kwargs...)
    submit_generic(fcs, add_ci_to_kwargs(; kwargs...))
end


add_ci_to_kwargs(; kwargs...) = add_ci_to_kwargs(Dict{Symbol,Any}(kwargs))
function add_ci_to_kwargs(kwargs::Dict)
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
        event_path = open(JSON.Parser.parse, ENV["GITHUB_EVENT_PATH"])
        ref = ENV["GITHUB_REF"]
        if startswith(ref, "refs/heads/")
            branch = ref[12:end]
            ga_pr = "false"
        elseif startswith(ref, "refs/tags/")
            branch = ref[11:end]
            ga_pr = "false"
        elseif startswith(ref, "refs/pull/")
            branch = ENV["GITHUB_HEAD_REF"]
            ga_pr_info = get(event_path, "pull_request", Dict())
            ga_pr = get(ga_pr_info, "number", "false")
        end
        ga_build_url = "https://github.com/$(ENV["GITHUB_REPOSITORY"])/actions/runs/$(ENV["GITHUB_RUN_ID"])"
        kwargs = set_defaults(kwargs,
            service      = "github-actions",
            branch       = branch,
            commit       = ENV["GITHUB_SHA"],
            pull_request = ga_pr,
            slug         = ENV["GITHUB_REPOSITORY"],
            build        = ENV["GITHUB_RUN_ID"],
            build_url    = ga_build_url,
        )
    elseif lowercase(get(ENV, "BUILDKITE", "false")) == "true"
        kwargs = set_defaults(kwargs,
            service      = "buildkite",
            branch       = ENV["BUILDKITE_BRANCH"],
            commit       = ENV["BUILDKITE_COMMIT"],
            job          = ENV["BUILDKITE_JOB_ID"],
            build        = ENV["BUILDKITE_BUILD_NUMBER"],
            build_url    = ENV["BUILDKITE_BUILD_URL"]
        )
        if ENV["BUILDKITE_PULL_REQUEST"] != "false"
            kwargs = set_defaults(kwargs, pr = ENV["BUILDKITE_PULL_REQUEST"])
        end
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
    submit_generic(fcs, add_local_to_kwargs(dir; kwargs...))
end

add_local_to_kwargs(dir; kwargs...) = add_local_to_kwargs(dir, Dict{Symbol,Any}(kwargs))
function add_local_to_kwargs(dir, kwargs::Dict)
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

    return kwargs
end


"""
    submit_generic(fcs::Vector{FileCoverage})

Takes a vector of file coverage results (produced by `process_folder`),
and submits them to a Codecov.io instance. Keyword arguments are converted
into a generic Codecov.io API uri.  It is essential that the keywords and
values match the Codecov upload/v2 API specification.
The `codecov_url` keyword argument or the CODECOV_URL environment variable
can be used to specify the base path of the uri.
The `codecov_url_path` keyword argument or the CODECOV_URL_PATH environment variable
can be used to specify the final path of the uri.
The `dry_run` keyword can be used to prevent the http request from
being generated.
"""
submit_generic(fcs::Vector{FileCoverage}; kwargs...) =
    submit_generic(fcs, Dict{Symbol,Any}(kwargs))
function submit_generic(fcs::Vector{FileCoverage}, kwargs::Dict)
    @assert length(kwargs) > 0
    dry_run = get(kwargs, :dry_run, false)

    uri_str = construct_uri_string(kwargs)

    @info "Submitting data to Codecov..."
    @debug "Codecov.io API URL:\n" * mask_token(uri_str)

    is_black_hole_server = parse(Bool, strip(get(ENV, "JULIA_COVERAGE_IS_BLACK_HOLE_SERVER", "false")))::Bool
    if !dry_run
        # Tell Codecov we have an upload for them
        response = HTTP.post(uri_str; headers=Dict("Accept" => "text/plain"))
        # Get the temporary URL to use for uploading to S3
        repr = String(response)
        s3url = get(split(String(response.body), '\n'), 2, "")
        repr = chomp(replace(repr, s3url => ""))
        @debug "Result of submission:" * repr
        !is_black_hole_server && upload_to_s3(; s3url=s3url, fcs=fcs)
    end
end

function upload_to_s3(; s3url, fcs)
    startswith(s3url, "https://") || error("Invalid codecov response: $s3url")
    # Upload to S3
    request = HTTP.put(s3url; body=json(to_json(fcs)),
                       header=Dict("Content-Type" => "application/json",
                                   "x-amz-storage-class" => "REDUCED_REDUNDANCY"))
    @debug "Result of submission:" * mask_token(String(request))
end

function construct_uri_string(kwargs::Dict)
    url = get(ENV, "CODECOV_URL", "")
    isempty(url) || (kwargs = set_defaults(kwargs, codecov_url = url))

    path = get(ENV, "CODECOV_URL_PATH", "")
    isempty(path) || (kwargs = set_defaults(kwargs, codecov_url_path = path))

    token = get(ENV, "CODECOV_TOKEN", "")
    isempty(token) || (kwargs = set_defaults(kwargs, token = token))

    flags = get(ENV, "CODECOV_FLAGS", "")
    isempty(flags) || (kwargs = set_defaults(kwargs; flags = flags))

    name = get(ENV, "CODECOV_NAME", "")
    isempty(name) || (kwargs = set_defaults(kwargs; name = name))

    codecov_url = get(kwargs, :codecov_url, "https://codecov.io")
    if isempty(codecov_url) || codecov_url[end] == '/'
        error("the codecov_url should not end with a /, given url $(repr(codecov_url))")
    end

    codecov_url_path = get(kwargs, :codecov_url_path, "/upload/v4")
    if isempty(codecov_url_path) || codecov_url_path[1] != '/' || codecov_url_path[end] == '/'
        error("the codecov_url_path should begin with, but not end with, a /, given url $(repr(codecov_url_path))")
    end

    uri_str = "$(codecov_url)$(codecov_url_path)?"
    for (k, v) in kwargs
        # add all except a few special key/value pairs to the URL
        # (:verbose is there for backwards compatibility with versions
        # of this code that treated it in a special way)
        if k != :codecov_url && k != :dry_run && k != :verbose
            uri_str = "$(uri_str)$(k)=$(v)&"
        end
    end

    return uri_str
end

function mask_token(uri_string)
    return replace(uri_string, r"token=[^&]*" => "token=<HIDDEN>")
end

end # module
