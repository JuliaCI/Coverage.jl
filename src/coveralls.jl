# Submit coverage to Coveralls.io
export Coveralls
"""
Coverage.Coveralls Module

This module provides functionality to push coverage information to the Coveralls
web service. It exports the `submit` and `submit_token` methods.
"""
module Coveralls
    using Coverage, HTTP, JSON

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
    to_json(fc::FileCoverage) = Dict("name"     => fc.filename,
                                     "source"   => fc.source,
                                     "coverage" => fc.coverage)

    """
        submit(fcs::Vector{FileCoverage})

    Take a vector of file coverage results (produced by `process_folder`),
    and submits them to Coveralls. Assumes that this code is being run
    on TravisCI. If running locally, use `submit_token`.
    """
    function submit(fcs::Vector{FileCoverage})
        data = Dict("service_job_id"    => ENV["TRAVIS_JOB_ID"],
                    "service_name"      => "travis-ci",
                    "source_files"      => map(to_json, fcs))
        println("Submitting data to Coveralls...")
        req = HTTP.post(
                "https://coveralls.io/api/v1/jobs",
                files = [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
        println("Result of submission:")
        println(String(req.data))
    end

    # query_git_info
    # Pulls information about the repository that isn't available if we
    # are running somewhere other than TravisCI
    import Git
    function query_git_info(dir="")
        commit_sha      = Git.readchomp(`rev-parse HEAD`, dir=dir)
        author_name     = Git.readchomp(`log -1 --pretty=format:"%aN"`, dir=dir)
        author_email    = Git.readchomp(`log -1 --pretty=format:"%aE"`, dir=dir)
        committer_name  = Git.readchomp(`log -1 --pretty=format:"%cN"`, dir=dir)
        committer_email = Git.readchomp(`log -1 --pretty=format:"%cE"`, dir=dir)
        message         = Git.readchomp(`log -1 --pretty=format:"%s"`, dir=dir)
        remote          = Git.readchomp(`config --get remote.origin.url`, dir=dir)
        branch          = Git.branch(dir=dir)

        # Normalize remote url to https
        remote = "https" * Git.normalize_url(remote)[4:end]

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

        r = HTTP.post("https://coveralls.io/api/v1/jobs",
            files = [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
        println("Result of submission:")
        println(String(r.data))
    end
end  # module Coveralls
