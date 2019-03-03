using Coverage
cov_res = process_folder()
if Sys.KERNEL === :FreeBSD
    @info "Skipping Coveralls on FreeBSD"
else
    Coveralls.submit(cov_res)
end
Codecov.submit(cov_res)
