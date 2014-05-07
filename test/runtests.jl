#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage

cd(Pkg.dir("Coverage"))
j = Coveralls.process_file(joinpath("test","data","Coverage.jl"))
