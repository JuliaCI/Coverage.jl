#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################
module Coverage

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

    export Coveralls
    module Coveralls
        using Requests
        using Coverage
        using JSON

        # ***HACK***
        # Something seems to be wrong with Coveralls, or HttpParser's
        # interaction with it. Basically, non-ASCII seems to kill it.
        # So this kills the non-ASCII - may the Unicode Gods have mercy
        # on our souls
        striputf8(s) = 
            bytestring( [int(c) > 127 ? uint8('?') : uint8(c) for c in s])

        # coveralls_process_file
        # Given a .jl file, return the Coveralls.io dictionary for this
        # file by reading in the file and its matching .cov. Don't convert
        # to JSON yet, just return dictionary. 
        # https://coveralls.io/docs/api
        # {
        #   "name" : "$filename"
        #   "source": "...\n....\n...."
        #   "coverage": [null, 1, null]
        # }
        export process_file
        function process_file(filename)
            return ["name" => filename,
                    "source" => striputf8(readall(filename)),
                    "coverage" => process_cov(filename*".cov")]
        end

        # coveralls_process_src
        # Recursively walk through a Julia package's src/ folder
        # and collect coverage statistics
        export process_folder
        function process_folder(folder="src",source_files={})
            filelist = readdir(folder)
            for file in filelist
                fullfile = joinpath(folder,file)
                println(fullfile)
                if isfile(fullfile)
                    try
                        new_sf = process_file(fullfile)
                        push!(source_files, new_sf)
                    catch
                        # Skip
                        println("Skipped $fullfile")
                    end
                else isdir(fullfile)
                    process_folder(fullfile,source_files)
                end
            end
            if folder == "src"
                return source_files
            end
        end

        # submit
        # Submit coverage to Coveralls.io
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
        export submit
        function submit(source_files)
            data = ["service_job_id" => ENV["TRAVIS_JOB_ID"],
                    "service_name" => "travis-ci",
                    "source_files" => source_files]
            r = Requests.post(URI("https://coveralls.io/api/v1/jobs"), data={"json" => JSON.json(data)}, headers={"Content-Type"=>"text/form-data"})
            dump(r.data)
        end
    end  # module Coveralls
end
