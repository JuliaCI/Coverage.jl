using Coverage
cov_res = process_folder()
Codecov.submit(cov_res)
Coveralls.submit(cov_res)
