#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################
module Coverage
    using Requests
    using JSON

    # process_cov
    # Given a .cov file, return the counts for each line, where the
    # lines that can't be counted are denoted with a -1
    export process_cov
    function process_cov(filename)
        fp = open(filename, "r")
        lines = readlines(fp)
        num_lines = length(lines)
        coverage = Array(Union(Nothing,Int), num_lines)
        for i = 1:num_lines
            cov_segment = lines[i][1:9]
            coverage[i] = cov_segment[9] == '-' ? nothing : int(cov_segment)
        end
        close(fp)
        return coverage
    end

    # process_src_coveralls
    # Given a .jl file, return the Coveralls.io dictionary for this
    # file by reading in the file and its matching .cov. Don't convert
    # to JSON yet, just return dictionary. 
    # https://coveralls.io/docs/api
    # {
    #   "name" : "$filename"
    #   "source": "...\n....\n...."
    #   "coverage": [null, 1, null]
    # }
    export process_src_coveralls
    function process_src_coveralls(filename)
        return ["name" => filename,
                "source" => readall(filename),
                "coverage" => process_cov(filename*".cov")]
    end

    # create_coveralls_post
    # Create the request to submit to Coveralls.io (as a dictionary, 
    # not a JSON string)
    # https://coveralls.io/docs/api
    # {
    #   "service_job_id": "1234567890",
    #   "service_name": "travis-ci",
    #   "source_files": [
    #     {
    #       "name": "example.rb",
    #       "source": "def four\n  4\nend",
    #       "coverage": [null, 1, null]
    #     },
    #     {
    #       "name": "lib/two.rb",
    #       "source": "def seven\n  eight\n  nine\nend",
    #       "coverage": [null, 1, 0, null]
    #     }
    #   ]
    # }
    export create_coveralls_travis_post
    function create_coveralls_travis_post(source_files)
        return ["service_job_id" => ENV["TRAVIS_JOB_ID"],
                "service_name" => "travis-ci",
                "source_files" => source_files]
    end

    # submit_coveralls
    # Submit coverage to Coveralls.io
    export submit_coveralls
    function submit_coveralls(data)
        println(JSON.json(data))
        post("https://coveralls.io/api/v1/jobs"; data = {"json_file" => JSON.json(data)})
    end



end