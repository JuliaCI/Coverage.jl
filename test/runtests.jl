#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage

c = process_cov(joinpath("src","Coverage.jl.cov"))

j = process_src_coveralls(joinpath("src","Coverage.jl"))

g = create_coveralls_travis_post({j})
