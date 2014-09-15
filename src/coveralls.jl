module Coveralls

using Requests
using Coverage
using JSON

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
            "source" => readall(filename),
            "coverage" => process_cov(filename*".cov")]
end

# coveralls_process_src
# Recursively walk through a Julia package's src/ folder
# and collect coverage statistics
export process_folder
function process_folder(folder="src")
    filelist = src_files(folder=folder)
    for file in filelist
        println(file)
        try
            new_sf = process_file(file)
            push!(processed_files, new_sf)
        catch err
            if !isa(err,SystemError)
                rethrow(e)
            end
            # Skip
            println("Skipped $file")
        end
    end
    return processed_files
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
export submit, submit_token
function submit(source_files)
    data = ["service_job_id" => ENV["TRAVIS_JOB_ID"],
            "service_name" => "travis-ci",
            "source_files" => source_files]
    r = Requests.post(URI("https://coveralls.io/api/v1/jobs"), files =
        [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
    dump(r.data)
end

function submit_token(source_files)
    data = ["repo_token" => ENV["REPO_TOKEN"],
            "source_files" => source_files]
    r = post(URI("https://coveralls.io/api/v1/jobs"), files =
        [FileParam(JSON.json(data),"application/json","json_file","coverage.json")])
    dump(r.data)
end

end  # module Coveralls
