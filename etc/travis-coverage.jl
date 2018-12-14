using Coverage
cov_res = process_folder()
Coveralls.submit(cov_res)
Codecov.submit(cov_res)
