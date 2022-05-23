# Submit coverage to Coveralls.io
export Coveralls
"""
Coverage.Coveralls Module

This module provides functionality to push coverage information to the Coveralls
web service. It exports the `submit` and `submit_local` methods.
"""
module Coveralls

using Coverage
using CoverageTools
using HTTP
using JSON
using LibGit2
using MbedTLS

export submit, submit_local

#=
JSON structure for Coveralls
Accessed 2015/07/24:
https://coveralls.zendesk.com/hc/en-us/articles/201774865-API-Introduction
{
  "service_job_id": "1234567890",
  "service_name": "travis-ci",
  "source_files": [
    {
      "name": "example.rb",
      "source": "def four\n  4\nend",
      "coverage": [null, 1, null]
    },
    {
      "name": "lib/two.rb",
      "source": "def seven\n  eight\n  nine\nend",
      "coverage": [null, 1, 0, null]
    }
  ]
}
=#

# to_json
# Convert a FileCoverage instance to its Coveralls JSON representation
function to_json(fc::FileCoverage)
    name = Sys.iswindows() ? replace(fc.filename, '\\' => '/') : fc.filename
    return Dict("name"          => name,
                "source_digest" => bytes2hex(digest(MD_MD5, fc.source, "secret")),
                "coverage"      => fc.coverage)
end

# Format the body argument to HTTP.post
function makebody(data::Dict)
    iodata = IOBuffer(JSON.json(data))
    json_file = HTTP.Multipart("json_file", iodata, "application/json")
    return Dict("json_file" => json_file)
end

"""
    submit(fcs::Vector{FileCoverage}; kwargs...)

Take a vector of file coverage results (produced by `process_folder`),
and submits them to Coveralls. Assumes that this code is being run
on TravisCI, AppVeyor or Jenkins. If running locally, use `submit_local`.
"""
function submit(fcs::Vector{FileCoverage}; kwargs...)
    data = prepare_request(fcs, false)
    post_request(data)
end

function prepare_request(fcs::Vector{FileCoverage}, local_env::Bool, git_info=query_git_info)
    data = Dict{String,Any}("source_files" => map(to_json, fcs))
    # Coveralls API : https://docs.coveralls.io/api-reference
    if local_env
        # Attempt to parse git info via git_info, unless the user explicitly disables it by setting git_info to nothing
        data["service_name"] = "local"
        data["git"] = parse_git_info(git_info)
    elseif lowercase(get(ENV, "APPVEYOR", "false")) == "true"
        data["service_job_number"] = ENV["APPVEYOR_BUILD_NUMBER"]
        data["service_job_id"] = ENV["APPVEYOR_BUILD_ID"]
        data["service_name"] = "appveyor"
        appveyor_pr = get(ENV, "APPVEYOR_PULL_REQUEST_NUMBER", "")
        isempty(appveyor_pr) || (data["service_pull_request"] = appveyor_pr)
    elseif lowercase(get(ENV, "TRAVIS", "false")) == "true"
        data["service_number"] = ENV["TRAVIS_BUILD_NUMBER"]
        data["service_job_id"] = ENV["TRAVIS_JOB_ID"]
        data["service_name"] = "travis-ci"
        travis_pr = get(ENV, "TRAVIS_PULL_REQUEST", "")
        isempty(travis_pr) || (data["service_pull_request"] = travis_pr)
    elseif lowercase(get(ENV, "JENKINS", "false")) == "true"
        data["service_job_id"] = ENV["BUILD_ID"]
        data["service_name"] = "jenkins-ci"
        data["git"] = parse_git_info(git_info)

        # get the name of the branch if not a pull request
        if get(ENV, "CI_PULL_REQUEST", "false") == "false"
            data["git"]["branch"] = split(ENV["GIT_BRANCH"], "/")[2]
        end
    elseif haskey(ENV, "GITHUB_ACTION")
        data["service_job_id"] = ENV["GITHUB_RUN_ID"]
        data["service_name"] = "github"
        data["git"] = parse_git_info(git_info)

        event_path = open(JSON.Parser.parse, ENV["GITHUB_EVENT_PATH"])
        github_pr_info = get(event_path, "pull_request", Dict())
        github_pr = get(github_pr_info, "number", "")
        github_pr::Union{AbstractString, Integer}
        ((github_pr isa Integer) || (!isempty(github_pr))) && (data["service_pull_request"] = strip(string(github_pr)))
    elseif haskey(ENV, "GITLAB_CI")
        # Gitlab API: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
        branch = ENV["CI_COMMIT_BRANCH"]
        num_mr = branch == ENV["CI_DEFAULT_BRANCH"] ? "false" : ENV["CI_MERGE_REQUEST_IID"]
        data["service_pull_request"] = num_mr
        data["service_number"] = ENV["CI_PIPELINE_IID"]
        data["service_job_id"] = ENV["CI_JOB_ID"]
        data["service_name"] = "gitlab"
        data["git"] = parse_git_info(git_info)
        data["git"]["branch"] = branch
    else
        data["git"] = parse_git_info(git_info)
    end

    service_name = get(ENV, "COVERALLS_SERVICE_NAME", "")
    isempty(service_name) || (data["service_name"] = service_name)

    service_number = get(ENV, "COVERALLS_SERVICE_NUMBER", "")
    isempty(service_number) || (data["service_number"] = service_number)

    service_job_number = get(ENV, "COVERALLS_SERVICE_JOB_NUMBER", "")
    isempty(service_job_number) || (data["service_job_number"] = service_job_number)

    jobid = get(ENV, "COVERALLS_SERVICE_JOB_ID", "")
    isempty(jobid) || (data["service_job_id"] = jobid)

    flag_name = get(ENV, "COVERALLS_FLAG_NAME", "")
    isempty(flag_name) || (data["flag_name"] = flag_name)

    ci_pr = get(ENV, "COVERALLS_PULL_REQUEST", "")
    isempty(ci_pr) || (data["service_pull_request"] = ci_pr)

    if !haskey(data, "service_name")
        error("No compatible CI platform detected")
    end

    data = add_repo_token(data, local_env)
    if get(ENV, "COVERALLS_PARALLEL", "false") == "true"
        data["parallel"] = "true"
    end
    return data
end

function parse_git_info(git_info::Function)
    result = nothing
    try
        result = git_info()
    catch ex
        @warn "Parse of git information failed" exception=e, catch_backtrace()
    end
    return result
end

parse_git_info(git_info::Dict) = git_info


# query_git_info
# Pulls information about the repository that isn't available if we
# are running somewhere other than TravisCI
function query_git_info(dir=pwd())
    repo            = LibGit2.GitRepoExt(dir)
    head            = LibGit2.head(repo)
    head_cmt        = LibGit2.peel(head)
    head_oid        = LibGit2.GitHash(head_cmt)
    commit_sha      = string(head_oid)
    author_name     = string(LibGit2.author(head_cmt).name)
    author_email    = string(LibGit2.author(head_cmt).email)
    committer_name  = string(LibGit2.committer(head_cmt).name)
    committer_email = string(LibGit2.committer(head_cmt).email)
    message         = LibGit2.message(head_cmt)
    remote_name     = "origin"
    branch          = LibGit2.shortname(head)

    # determine remote url, but only if repo is not in detached state
    remote = ""
    if branch != "HEAD"
        LibGit2.with(LibGit2.get(LibGit2.GitRemote, repo, remote_name)) do rmt
            remote = LibGit2.url(rmt)
        end
    end
    LibGit2.close(repo)

    return Dict(
        "branch"    => branch,
        "remotes"   => [
            Dict(
                "name"  => remote_name,
                "url"   => remote
            )
        ],
        "head" => Dict(
            "id" => commit_sha,
            "author_name"       => author_name,
            "author_email"      => author_email,
            "committer_name"    => committer_name,
            "committer_email"   => committer_email,
            "message"           => message
        )
    )
end

"""
    submit_local(fcs::Vector{FileCoverage}, git_info=query_git_info; kwargs...)

Take a `Vector` of file coverage results (produced by `process_folder`),
and submits them to Coveralls. For submissions not from CI.

git_info can be either a `Dict` or a function that returns a `Dict`.
"""
function submit_local(fcs::Vector{FileCoverage}, git_info=query_git_info; kwargs...)
    data = prepare_request(fcs, true, git_info)
    post_request(data)
end

# posts the actual request given the data
function post_request(data)
    @info "Submitting data to Coveralls..."
    coveralls_url = get(ENV, "COVERALLS_URL", "https://coveralls.io/api/v1/jobs")
    headers = []
    req = HTTP.post(coveralls_url, headers, HTTP.Form(makebody(data)))
    @debug "Result of submission:\n" * String(req)
    nothing
end

# adds the repo token to the data
function add_repo_token(data, local_submission)
    repo_token =
            get(ENV, "COVERALLS_TOKEN") do
                get(ENV, "REPO_TOKEN") do #backward compatibility
                    # error unless we are on Travis
                    if local_submission || (data["service_name"] != "travis-ci")
                        error("Coveralls submission requires a COVERALLS_TOKEN environment variable")
                    end
                end
            end
    if repo_token !== nothing
        data["repo_token"] = repo_token
    end
    return data
end

end # module
