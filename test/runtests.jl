#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage
using Base.Test

# test source file discovery
test_jl_files = src_files(folder=Pkg.dir("Coverage")*"/test")
@test test_jl_files == String[Pkg.dir("Coverage")*"/test/data/Coverage.jl",Pkg.dir("Coverage")*"/test/runtests.jl"]


cd(Pkg.dir("Coverage"))
j = Coveralls.process_file(joinpath("test","data","Coverage.jl"))
