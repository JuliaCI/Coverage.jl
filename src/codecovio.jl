export Codecov
module Codecov
    using Requests
    using Coverage
    using JSON
    using Compat

    #=
    Example of input wanted by Codecov

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


    # process_file
    # Given a .jl file, return the Codecov.io dictionary for this
    # file by reading in the file and its matching .cov. 
    export process_file
    function process_file(filename)
        cov = vcat(nothing, amend_coverage_from_src!(process_cov(filename*".cov"), filename))
        return (filename, cov)
    end

    # process_folder
    # Recursively walk through a Julia package's src/ folder and collect
    # coverage statistics in Codecov format
    export process_folder
    function process_folder(folder="src")
        source_files = Any[]
        filelist = readdir(folder)
        for file in filelist
            fullfile = joinpath(folder,file)
            println(fullfile)
            if isfile(fullfile)
                try
                    new_sf = process_file(fullfile)
                    push!(source_files, new_sf)
                catch e
                    # Skip, probably a .cov file...
                    println("Skipped $fullfile")
                end
            else isdir(fullfile)
                append!(source_files, process_folder(fullfile))
            end
        end
        return source_files
    end

    # submit
    # Submit coverage to Codecov.io
    # https://codecov.io/api#post-json-report
    export submit, submit_token
    function submit(source_files)
        # Turn vector of filename : coverage pairs into a dictionary
        cov = Dict()
        for file in source_files
            cov[file[1]] = file[2]
        end
        data = @compat Dict("coverage" => cov)
        println(data)

        commit = ENV["TRAVIS_COMMIT"]
        branch = ENV["TRAVIS_BRANCH"]
        travis = ENV["TRAVIS_JOB_ID"]
        heads  = @compat Dict("Content-Type" => "application/json")
        println(heads)
        r = Requests.post(
                URI("https://codecov.io/upload/v1?&commit=$(commit)&branch=$(branch)&travis_job_id=$(travis)");
                json = data, headers = heads)
        dump(r)
    end

end  # module Codecov