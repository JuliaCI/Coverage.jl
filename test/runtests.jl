#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage

j = process_src_coveralls(joinpath("test","data","Coverage.jl"))
g = create_coveralls_travis_post({j})
submit_coveralls(g)
