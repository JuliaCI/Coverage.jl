#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage, Base.Test

cd(Pkg.dir("Coverage")) do
    j = Coveralls.process_file(joinpath("test","data","Coverage.jl"))
end

srcname = joinpath("data","testparser.jl")
covname = srcname*".cov"
isfile(covname) && rm(covname)
cmdstr = "include(\"$srcname\"); using Base.Test; @test f2(2) == 4"
run(`julia --code-coverage=user -e $cmdstr`)
r = Coveralls.process_file(srcname)
# The next one is the correct one, but julia & JuliaParser don't insert a line number after the 1-line @doc -> test
# target = [nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0]
target = [nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0]
@test r["coverage"][1:length(target)] == target
