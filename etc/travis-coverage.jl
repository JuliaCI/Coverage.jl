if VERSION < v"0.7.0"
    cd(Pkg.dir("Coverage"))
end

using Coverage
cov_res = process_folder()
Coveralls.submit(cov_res)
Codecov.submit(cov_res)
