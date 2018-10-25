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
    using Compat
    using Compat.LibGit2
    using MbedTLS

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
        submit(fcs::Vector{FileCoverage}; kwargs...)

    Take a vector of file coverage results (produced by `process_folder`),
    and submits them to Coveralls. Assumes that this code is being run
    on TravisCI or AppVeyor. If running locally, use `submit_token`.
    """
    function submit(fcs::Vector{FileCoverage}; kwargs...)
        verbose = true
        for (k,v) in kwargs
            if k == :verbose
                verbose = v
            end
        end

        data = Dict{String,Any}("source_files" => map(to_json, fcs))

        if lowercase(get(ENV, "APPVEYOR", "false")) == "true"
            data["service_job_id"] = ENV["APPVEYOR_JOB_ID"]
            data["service_name"] = "appveyor"
        elseif lowercase(get(ENV, "TRAVIS", "false")) == "true"
            data["service_job_id"] = ENV["TRAVIS_JOB_ID"]
            data["service_name"] = "travis-ci"
        elseif lowercase(get(ENV, "JENKINS", "false")) == "true"
            data["service_job_id"] = ENV["BUILD_ID"]
            data["service_name"] = "jenkins-ci"
            data["git"] = query_git_info()

            # get the name of the branch if not a pull request
            if get(ENV, "CI_PULL_REQUEST", "false") == "false"
                data["git"]["branch"] = split(ENV["GIT_BRANCH"], "/")[2]
            end
        else
            error("No compatible CI platform detected")
        end

        repo_token =
                get(ENV,"COVERALLS_TOKEN") do
                    get(ENV, "REPO_TOKEN") do #backward compatibility
                        if data["service_name"] != "travis-ci"
                            error("Coveralls submission requires a COVERALLS_TOKEN environment variable")
                        end
                    end
                end
        if repo_token != nothing
            data["repo_token"] = repo_token
        end

        if verbose
            println("Submitting data to Coveralls...")
        end

        url = "https://coveralls.io/api/v1/jobs"
        body = HTTP.Form(makebody(data))
        headers = ["Content-Type" => "multipart/form-data; boundary=$(body.boundary)"]
        req = HTTP.post(url, headers, body)

        if verbose
            println("Result of submission:")
            println(String(req.body))
        end
    end

    # query_git_info
    # Pulls information about the repository that isn't available if we
    # are running somewhere other than TravisCI
    function query_git_info(dir=pwd())
        repo            = LibGit2.GitRepo(dir)
        head            = LibGit2.head(repo)
        head_cmt        = LibGit2.peel(head)
        head_oid        = LibGit2.GitHash(head_cmt)
        commit_sha      = string(head_oid)
        author_name     = string(LibGit2.author(head_cmt).name)
        author_email    = string(LibGit2.author(head_cmt).email)
        committer_name  = string(LibGit2.committer(head_cmt).name)
        committer_email = string(LibGit2.committer(head_cmt).email)
        message         = LibGit2.message(head_cmt)
        remote          = ""
        branch          = LibGit2.shortname(head)

        if branch != "HEAD" # if repo is not in detached state
            LibGit2.with(LibGit2.get(LibGit2.GitRemote, repo, branch)) do remote
                remote = LibGit2.url(remote)
            end
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
                "committer_name"    => committer_name,
                "committer_email"   => committer_email,
                "message"           => message
            )
        )
    end

    """
        submit_token(fcs::Vector{FileCoverage}, git_info=query_git_info; kwargs...)

    Take a `Vector` of file coverage results (produced by `process_folder`),
    and submits them to Coveralls. For submissions not from TravisCI.

    git_info can be either a `Dict` or a function that returns a `Dict`.
    """
    function submit_token(fcs::Vector{FileCoverage}, git_info=query_git_info; kwargs...)
        data = Dict("repo_token" => get(ENV,"COVERALLS_TOKEN") do
                            get(ENV, "REPO_TOKEN") do #backward compatibility
                                error("Coveralls submission requires a COVERALLS_TOKEN environment variable")
                            end
                        end,
                    "source_files" => map(to_json, fcs))

        verbose = true
        for (k,v) in kwargs
            if k == :verbose
                verbose = v
            end
        end

        # Attempt to parse git info via git_info, unless the user explicitly disables it by setting git_info to nothing
        try
            if isa(git_info, Function)
                data["git"] = git_info()
            elseif isa(git_info, Dict)
                data["git"] = git_info
            end
        catch
        end

        r = HTTP.post("https://coveralls.io/api/v1/jobs", body=makebody(data))

        if verbose
            println("Result of submission:")
            println(String(r.body))
        end
    end
end  # module Coveralls
