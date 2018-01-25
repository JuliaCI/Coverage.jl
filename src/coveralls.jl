# Submit coverage to Coveralls.io
export Coveralls
"""
Coverage.Coveralls Module

This module provides functionality to push coverage information to the Coveralls
web service. It exports the `submit` and `submit_token` methods.
"""
module Coveralls
    using Coverage
    using HTTP
    using JSON
    using MbedTLS
    using Compat
    using Compat: @info

    export submit, submit_token

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
    to_json(fc::FileCoverage) = Dict("name"          => fc.filename,
                                     "source_digest" => digest(MD_MD5, fc.source, "secret"),
                                     "coverage"      => fc.coverage)

    # Format the body argument to HTTP.post
    makebody(data::Dict) =
        Dict("json_file" => HTTP.Multipart("json_file", IOBuffer(JSON.json(data)),
                                           "application/json"))

    """
        submit(fcs::Vector{FileCoverage})

    Take a vector of file coverage results (produced by `process_folder`),
    and submits them to Coveralls. Assumes that this code is being run
    on TravisCI or AppVeyor. If running locally, use `submit_token`.
    """
    function submit(fcs::Vector{FileCoverage})
        url = "https://coveralls.io/api/v1/jobs"
        if lowercase(get(ENV, "APPVEYOR", "false")) == "true"
            # Submission from AppVeyor requires a REPO_TOKEN environment variable
            data = Dict("service_job_id"    => ENV["APPVEYOR_JOB_ID"],
                        "service_name"      => "appveyor",
                        "source_files"      => map(to_json, fcs),
                        "repo_token"        => ENV["REPO_TOKEN"])
        elseif lowercase(get(ENV, "TRAVIS", "false")) == "true"
            data = Dict("service_job_id"    => ENV["TRAVIS_JOB_ID"],
                        "service_name"      => "travis-ci",
                        "source_files"      => map(to_json, fcs))
        else
            error("No compatible CI platform detected")
        end
        @info "Submitting data to Coveralls..."
        req = HTTP.post(url, body=makebody(data))
        @info "Result of submission:\n" * String(req.body)
        nothing
    end

    # query_git_info
    # Pulls information about the repository that isn't available if we
    # are running somewhere other than TravisCI
    import Base.LibGit2
    function query_git_info(dir=pwd())
        repo            = LibGit2.GitRepo(dir)
        head_cmt        = LibGit2.peel(LibGit2.head(repo))
        head_oid        = LibGit2.GitHash(head_cmt)
        commit_sha      = string(head_oid)
        author_name     = string(LibGit2.author(head_cmt).name)
        author_email    = string(LibGit2.author(head_cmt).email)
        committer_name  = string(LibGit2.committer(head_cmt).name)
        committer_email = string(LibGit2.committer(head_cmt).email)
        message         = LibGit2.message(head_cmt)
        remote          = ""
        branch          = LibGit2.shortname(headref)
        LibGit2.with(LibGit2.get(LibGit2.GitRemote, repo, branch)) do remote
            remote = LibGit2.url(remote)
        end
        LibGit2.close(repo)

        return Dict(
            "branch"    => branch,
            "remotes"   => [
                Dict(
                    "name"  => "origin",
                    "url"   => remote
                )
            ],
            "head" => Dict(
                "id" => commit_sha,
                "author_name"       => author_name,
                "author_email"      => author_email,
                "committer_name"    => committer_email,
                "committer_email"   => committer_email,
                "message"           => message
            )
        )
    end

    """
        submit_token(fcs::Vector{FileCoverage}, git_info=query_git_info)

    Take a `Vector` of file coverage results (produced by `process_folder`),
    and submits them to Coveralls. For submissions not from TravisCI.

    git_info can be either a `Dict` or a function that returns a `Dict`.
    """
    function submit_token(fcs::Vector{FileCoverage}, git_info=query_git_info)
        data = Dict("repo_token" => ENV["REPO_TOKEN"],
                    "source_files" => map(to_json, fcs))

        # Attempt to parse git info via git_info, unless the user explicitly disables it by setting git_info to nothing
        try
            if isa(git_info, Function)
                data["git"] = git_info()
            elseif isa(git_info, Dict)
                data["git"] = git_info
            end
        end

        r = HTTP.post("https://coveralls.io/api/v1/jobs", body=makebody(data))
        @info "Result of submission:\n" * String(r.body)
    end
end  # module Coveralls
