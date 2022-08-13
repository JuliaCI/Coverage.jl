using Coverage
cov_res = process_folder()
Codecov.submit(cov_res)
if Sys.isfreebsd()
    @warn "Skipping Coveralls on FreeBSD"
else
    Coveralls.submit(cov_res)
end
