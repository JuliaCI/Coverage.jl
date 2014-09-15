module Coveralls

using Requests
using Coverage
using JSON

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
