#######################################################################
# Coverage.jl
# Take Julia test coverage results and bundle them up in JSONs
# https://github.com/IainNZ/Coverage.jl
#######################################################################

using Coverage, Base.Test

cd(Pkg.dir("Coverage")) do
    datadir = joinpath("test", "data")
    # Process a saved set of coverage data...
    r = process_file(joinpath(datadir,"Coverage.jl"))
    # ... and memory data
    analyze_malloc(datadir)
    lcov = IOBuffer()
    LCOV.write(lcov, r)
    @test takebuf_string(lcov) ==
    """
    """

    # Test a file from scratch
    srcname = joinpath("test", "data","testparser.jl")
    covname = srcname*".cov"
    isfile(covname) && rm(covname)
    cmdstr = "include(\"$srcname\"); using Base.Test; @test f2(2) == 4"
    run(`julia --code-coverage=user -e $cmdstr`)
    r = process_file(srcname, datadir)
    # The next one is the correct one, but julia & JuliaParser don't insert a line number after the 1-line @doc -> test
    # See https://github.com/JuliaLang/julia/issues/9663 (when this is fixed, can uncomment the next line on julia 0.4)
    target = Union{Int64,Void}[nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
    #target = Union{Int64,Void}[nothing, nothing, nothing, nothing, 1, nothing, 0, nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, 0, nothing, nothing, 0, nothing, nothing, nothing, nothing]
    @test r.coverage[1:length(target)] == target

    covtarget = (sum(x->x != nothing && x > 0, target), sum(x->x != nothing, target))
    @test get_summary(r) == covtarget
    @test get_summary(process_folder(datadir)) != covtarget

    #json_data = Codecov.build_json_data(Codecov.process_folder("data"))
    #@test typeof(json_data["coverage"]["data/Coverage.jl"]) == Array{Union{Int64,Void},1}

end
