using Coverage
cov_res = process_folder()
Codecov.submit(cov_res)
haskey(ENV, "COVERALLS_URL") && Coveralls.submit(cov_res)
