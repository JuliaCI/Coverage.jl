export Codecov
module Codecov
    using Requests
    using Coverage
    using JSON
    using Compat

    export submit, submit_token

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
        return @compat Dict("coverage" => cov)
    end

    # submit
    # Take a vector of file coverage results (produced by process_folder),
    # and submits them to Codecov.io. Assumes that this code is being run
    # on TravisCI. If running locally, use submit_token.
    function submit(fcs::Vector{FileCoverage}) 
        branch  = ENV["TRAVIS_BRANCH"]
        pr      = ENV["TRAVIS_PULL_REQUEST"]
        job     = ENV["TRAVIS_JOB_ID"]
        slug    = ENV["TRAVIS_REPO_SLUG"]
        build   = ENV["TRAVIS_JOB_NUMBER"]
        commit  = ENV["TRAVIS_COMMIT"]
        uri_str = "https://codecov.io/upload/v2?service=travis-org" *
                    "&branch=$(branch)&commit=$(commit)" *
                    "&build=$(build)&pull_request=$(pr)&" *
                    "job=$(job)&slug=$(slug)"
        println("Codecov.io API URL:")
        println(uri_str)

        heads   = @compat Dict("Content-Type" => "application/json")
        data    = to_json(fcs)
        req     = Requests.post(URI(uri_str); json = data, headers = heads)
        println("Result of submission:")
        dump(req.data)
    end

    # submit_token
    # For submissions not from TravisCI.
    import Base.Git
    function submit_token(fcs::Vector{FileCoverage},
                            commit=Git.readchomp(`rev-parse HEAD`, dir=""),
                            branch=Git.branch(dir=""))
        repo_token = ENV["REPO_TOKEN"]
        uri_str = "https://codecov.io/upload/v2?&token=$(repo_token)&commit=$(commit)&branch=$(branch)"
        heads   = @compat Dict("Content-Type" => "application/json")
        data    = to_json(fcs)
        req     = Requests.post(URI(uri_str); json = data, headers = heads)
        println("Result of submission:")
        dump(req.data)
    end
end  # module Codecov
