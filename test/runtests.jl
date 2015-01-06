#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage, Base.Test

cd(Pkg.dir("Coverage")) do
    j = Coveralls.process_file(joinpath("test","data","Coverage.jl"))
end

run(`julia --code-coverage=user -e 'include("data/testparser.jl"); using Base.Test; @test f1(2) == 4'`)
r = Coveralls.process_file(joinpath("data","testparser.jl"))
@test r["coverage"][1:5] == [1,nothing,0,nothing,0]
